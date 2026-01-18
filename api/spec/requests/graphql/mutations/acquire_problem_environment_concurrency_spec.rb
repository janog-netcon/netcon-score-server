
require 'rails_helper'

RSpec.describe Mutations::AcquireProblemEnvironment, type: :request, truncation: true do
  context_as_player1 do
    let(:problem) { create(:problem) }

    before do
      # Mock Gateway response with delay to trigger race condition
      allow(RestClient::Request).to receive(:execute) do
        sleep 0.5
        OpenStruct.new(
          body: {
            host: 'localhost',
            port: 22,
            user: 'user',
            password: 'password',
            name: "env-#{SecureRandom.hex(4)}"
          }.to_json
        )
      end

      # Allow permit! to pass (Acl logic)
      allow(Acl).to receive(:permit!).and_return(true)

      # Ensure config exists (truncation wipes it, and set_configs! misses this key?)
      Config.create(key: :local_problem_codes, value_type: :string, value: '')
    end

    it 'creates multiple environments when requested simultaneously (race condition)' do
      threads = []
      success_count = 0
      failure_count = 0
      mutex = Mutex.new

      2.times do
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            # Calculate Context
            # CustomContext inherits from GraphQL::Query::Context
            # initialize(query:, values:, object:)
            context = CustomContext.new(query: nil, schema: ApiSchema, values: { current_team: player1 }, object: nil)

            # Instantiate Mutation
            # BaseMutation < GraphQL::Schema::RelayClassicMutation < GraphQL::Schema::Mutation
            # initialize(object:, context:, field:)
            mutation = Mutations::AcquireProblemEnvironment.new(object: nil, context: context, field: nil)

            # Resolve
            begin
              mutation.resolve(problem_id: problem.id, silent: false)
              mutex.synchronize { success_count += 1 }
            rescue ProblemEnvironmentAlreadyAssigned
              mutex.synchronize { failure_count += 1 }
            end
          end
        end
      end

      threads.each(&:join)

      expect(success_count).to eq(1)
      expect(failure_count).to eq(1)

      # Reload association
      player1.reload

      # Without fix, we expect 2. With fix, should be 1.
      expect(ProblemEnvironment.where(team: player1, problem: problem).count).to eq(1)
    end
  end
end
