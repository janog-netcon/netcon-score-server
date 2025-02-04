# frozen_string_literal: true

module Types
  # 全ユーザーが見える情報のみ返す
  # UIの描画に使われる
  class ContestInfoType < Types::BaseObject
    field :competition_time,      [[Types::DateTime]], null: false
    field :grading_delay_sec,     Integer,             null: false
    field :reset_delay_sec,       Integer,             null: false
    field :hide_all_score,        Boolean,             null: false
    field :realtime_grading,      Boolean,             null: false
    field :guide_page,            String,              null: false
    field :guide_page_en,         String,              null: false
    field :local_problem_codes,   String,              null: false
  end
end
