# frozen_string_literal: true

# レコード単位、カラム単位のフィルタを行う
# メソッドチェーンでクエリを構築できるようにモデルにincludeして使う
module Readable
  extend ActiveSupport::Concern

  def readable(team:)
    readable?(team: team) ? filter_columns(team: team) : nil
  end

  def readable?(team:)
    self.class.readable_records(team: team).exists?(id: id)
  end

  def filter_columns(team:)
    self.class.reject_columns(team: team).each {|key| self[key] = nil }
    self
  end

  module ClassMethods
    def readables(team:)
      # TODO: superclass.to_sで比較してインターフェースを統一する
      readable_records(team: team).filter_columns(team: team)
    end

    def filter_columns(team:)
      cols = readable_columns(team: team)
      cols.empty? ? none : select(*cols)
    end

    def readable_columns(team:)
      column_names - reject_columns(team: team)
    end

    # ブラックリスト方式のカラムフィルタ
    # そのteamが閲覧できないカラムを返す
    def reject_columns(team:)
      # 文字列として比較しないとautoload環境では正しく動作しない
      case self.to_s
      when 'Answer'
        %w[confirming] unless team.staff?
      when 'Attachment'
        %w[data]
      when 'Category'
        %w[code] unless team.staff?
      when 'Problem'
        %w[code secret_text writer] unless team.staff?
      when 'ProblemBody'
        %w[corrects genre] if team.player?
      when 'ProblemEnvironment'
        %w[external_status secret_text] unless team.staff?
      when 'Team'
        list = %w[password_digest]
        list << 'secret_text' unless team.staff?
        list
      when 'Config', 'FirstCorrectAnswer', 'Issue', 'IssueComment', 'Notice', 'Penalty', 'ProblemSupplement', 'Score'
        # permit all
        %w[]
      else
        raise UnhandledClass, self
      end
        .presence || []
    end

    def readable_records(team:)
      # 文字列として比較しないとautoload環境では正しく動作しない
      klass = self.to_s

      # 運営は常に全テーブルの全レコード取得可能
      return all if team.staff?

      # 参加者や見学者は常に取得不可
      return none if %w[Config].include?(klass)

      # 参加者や見学者は競技時間外やコンテスト中断時にはお知らせ以外は取得不可能
      return none if !Config.competition? && %w[Notice].exclude?(klass)

      # 誰でも取得可能
      # Problem自体は常時見れるがProblemBody(問題文)はそうではない
      return all if %w[Category Problem].include?(klass)

      # 見学者（NETCON guest）には以下のルールで取得させる
      if team.audience?
        case klass
        when 'Team'
          # 参加者と同じ権限でチームの確認が可能
          return where(role: -Float::INFINITY..Team.roles[team.role])
        when 'Category'
          # Categoryは常に取得可能
          return all
        when 'ProblemBody', 'ProblemSupplement'
          return where(problem: Problem.opened(team: team))
        when 'ProblemEnvironment'
          # 勝手に別の参加者の問題環境が見えないようにするために取得不可
          return none
        when 'Notice'
          # 通知は全体宛のもののみ取得可能
          return where(team: [nil])
        else # rubocop:disable Lint/DuplicateBranch
          # 他のパラメータは取得不可
          return none
        end
      end

      case klass
      when 'Answer'
        where(team: team, problem: Problem.opened(team: team))
      when 'Attachment'
        # レコードが取得不可でもtokenがあればデータ本体は取得可能
        where(team: team)
      when 'Score'
        return none if Config.hide_all_score

        # joins(:answer).merge(Answer.delay_filter).where(answers: { team: team })
        where(answer: Answer.readable_records(team: team).delay_filter)
      when 'Issue' # rubocop:disable Lint/DuplicateBranch
        where(team: team, problem: Problem.opened(team: team))
      when 'IssueComment'
        where(issue: Issue.readable_records(team: team))
      when 'Penalty' # rubocop:disable Lint/DuplicateBranch
        where(team: team, problem: Problem.opened(team: team))
      when 'ProblemBody', 'ProblemSupplement'
        where(problem: Problem.opened(team: team))
      when 'ProblemEnvironment'
        # playerには割り当てられた問題環境しか見せない
        # NOTE: 'UNDER_SCORING' 状態のVMは見えないことが望ましいが、採点中のVMがあることをUIが知るすべとして暫定的にこうしている
        where(team: team, problem: Problem.opened(team: team), status: %w[UNDER_CHALLENGE UNDER_SCORING])
      when 'Team'
        # 自分以下の権限のチームを取得できる
        where(role: -Float::INFINITY..Team.roles[team.role])
      when 'Notice'
        # プレイヤーと見学者は全体宛か、自チーム向けのみ
        # team == nil 全体お知らせ
        where(team: [nil, team.id])
      when 'FirstCorrectAnswer'
        # 使用予定なし
        raise UnhandledClass, self
      when 'Scoreboard', 'Session' # rubocop:disable Lint/DuplicateBranch
        # このクラスはモデル本体に記載
        raise UnhandledClass, self
      else # rubocop:disable Lint/DuplicateBranch
        raise UnhandledClass, self
      end
    end
  end
end
