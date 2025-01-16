# frozen_string_literal: true

class Answer < ApplicationRecord
  validates :bodies,     presence: true, answer_bodies: true
  validates :confirming, boolean:  true
  validates :problem,    presence: true, uniqueness: { scope: %i[team_id created_at] }
  validates :team,       presence: true
  validates :score,      presence: false

  belongs_to :problem
  belongs_to :team
  has_one :score, dependent: :destroy, autosave: true
  has_one :first_correct_answer, dependent: :destroy, autosave: false

  # for bodies validation
  def mode
    problem.body.mode
  end

  # for bodies validation
  def candidates
    problem.body.candidates
  end

  # ProblemBody#modeに従って採点を行いScoreレコードを作成する
  # 手動採点なら引数で値を渡す。
  # 自動採点なら渡さない
  # 失敗したらfalseが返る
  def grade(percent:)
    # self.scoreに代入すると即座にsaveされるので注意
    score = self.score || Score.new
    score.answer ||= self

    # 問題形式にかかわらず、percentを計算する。計算精度注意。
    score.percent = percent
    score.point = percent && percent * problem.body.perfect_point / 100

    # nil許容
    score.update(solved: problem.body.solved_criterion <= score.percent.to_i)
  end

  def correct_count
    problem.body.corrects.zip(bodies).count {|correct, body| Set.new(correct) == Set.new(body) }
  end

  class << self
    def delay_filter
      # created_at + Config.grading_delay_sec.seconds <= Time.current
      where(created_at: Time.zone.at(0)..(Time.current - Config.grading_delay_sec.seconds))
    end

    def find_actual_fca(team:, problem:)
      where(team: team, problem: problem)
        .joins(:score)
        .where(scores: { solved: true })
        .order(:created_at)
        .first
    end
  end
end
