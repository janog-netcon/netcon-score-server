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

      # NOTE: ここはトランザクション外なので、同時に2つのリクエストが来たときは、ここで引っかからない
      if ProblemEnvironment.exists?(problem_id: problem_id, team: self.current_team!, status: "RUNNING_IN_USE")
        raise ProblemEnvironmentAlreadyAssigned.new(self.current_team!, problem_id)
      end

      chosen_pes = ProblemEnvironment.transaction do
        pes = ProblemEnvironment.lock.where(problem_id: problem_id, status: "RUNNING")

        # NOTE: 同じチームから同時に複数のリクエストが来た場合に後続のリクエストを失敗させるため、自チームに割り当てられたpeがないことを確認する
        #       クリティカルセクション内なので、既に割り当てられた pe があればここで発見できる
        if ProblemEnvironment.exists?(problem_id: problem_id, team: self.current_team!, status: "RUNNING_IN_USE")
          raise ProblemEnvironmentAlreadyAssigned.new(self.current_team!, problem_id)
        end

        # 今解くことができるVMがない
        raise RecordNotExists.new(ProblemEnvironment, problem_id: problem_id, status: "RUNNING") if pes.empty?

        # 複数 pes があった場合には、先頭のもの (pes.first) を選ぶ
        # また、同じ name で service が異なるものは全て選択する (実体は同一インスタンスのため)
        chosen_pes = pes.select { |pe| pe.name == pes.first.name }

        # TODO: update! で例外出たらどうなるのか確認 (add_errors(chosen_pes)) を返す必要がありそう)
        chosen_pes.each { |pe| pe.update!(status: "RUNNING_IN_USE", team: self.current_team!) }
        chosen_pes
      rescue ActiveRecord::StatementInvalid =>  e
        # lock がタイムアウトすることもあるはずなので、数回リトライする?
        # この処理に時間が掛かることは今の所なさそうなので、一旦 retry は実装しないでおく
        raise e
      end

      Notification.notify(mutation: self.graphql_name, record: chosen_pes) unless silent

      { problem_environments: chosen_pes.map{ |pe| pe.readable(team: self.current_team!) }.compact }
    end
  end
end
