# frozen_string_literal: true

module Mutations
  class AcquireProblemEnvironment < BaseMutation
    field :problem_environments, [Types::ProblemEnvironmentType], null: true

    # find key
    argument :problem_id, ID,      required: true

    # 通知無効
    argument :silent,     Boolean, required: false, default_value: false

    def resolve(problem_id:, silent:)
      problem = Problem.find_by(id: problem_id)
      raise RecordNotExists.new(Problem, id: problem_id) if problem.nil?

      args = { problem: problem }
      Acl.permit!(mutation: self, args: args)

      # JANOG49 bypass local problem
      Rails.logger.debug(problem.code)
      Rails.logger.debug(Rails.configuration.local_problem_code)
      if problem.code == Rails.configuration.local_problem_code
        return { problem_environments: nil }
      end

      # NOTE: ここはトランザクション外なので、同時に2つのリクエストが来たときは、ここで引っかからない
      if ProblemEnvironment.exists?(problem_id: problem_id, team: self.current_team!, status: "UNDER_CHALLENGE")
        raise ProblemEnvironmentAlreadyAssigned.new(self.current_team!, problem_id)
      end

      num_tries = 0
      max_tries = 3
      chosen_pes = ProblemEnvironment.transaction do
          pes = ProblemEnvironment.lock.where(problem_id: problem_id, status: ["READY", "", nil], external_status: "RUNNING").order(created_at: "ASC")

          # NOTE: 同じチームから同時に複数のリクエストが来た場合に後続のリクエストを失敗させるため、自チームに割り当てられたpeがないことを確認する
          #       クリティカルセクション内なので、既に割り当てられた pe があればここで発見できる
          if ProblemEnvironment.exists?(problem_id: problem_id, team: self.current_team!, status: "UNDER_CHALLENGE")
            raise ProblemEnvironmentAlreadyAssigned.new(self.current_team!, problem_id)
          end

          # 今解くことができるVMがない
          raise AvailableProblemEnvironmentNotExists.new(problem_id: problem_id) if pes.empty?

          # 複数 pes があった場合には、先頭のもの (pes.first) を選ぶ
          # また、同じ name で service が異なるものは全て選択する (実体は同一インスタンスのため)
          chosen_pes = pes.select { |pe| pe.name == pes.first.name }

          # TODO: update! で例外出たらどうなるのか確認 (add_errors(chosen_pes)) を返す必要がありそう)
          chosen_pes.each { |pe| pe.update!(status: "UNDER_CHALLENGE", team: self.current_team!) }
          chosen_pes
      rescue ActiveRecord::StatementInvalid =>  e
          # lock がタイムアウトすることもあるはずなので、数回リトライする?
          num_tries += 1
          raise e if num_tries == max_tries
          retry
      end

      Notification.notify(mutation: self.graphql_name, record: chosen_pes) unless silent

      { problem_environments: chosen_pes.map{ |pe| pe.readable(team: self.current_team!) }.compact }
    end
  end
end
