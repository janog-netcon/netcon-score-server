# frozen_string_literal: true

FactoryBot.define do
  factory :problem_environment do
    # composite primary key
    sequence(:name) {|n| "server#{n}" }
    sequence(:service) { %w[SSH HTTP HTTPS].sample }
    team { nil }
    problem { nil }

    status {
      # "ABANDONED"
      "UNDER_CHALLENGE"
    } # NOT_READY READY UNDER_CHALLENGE UNDER_SCORING ABANDONED
    sequence(:host) {|n| "host#{n}.local" }
    sequence(:user) {|n| "user#{n}" }
    sequence(:password) {|n| "password#{n}" }
    sequence(:port) {|n| n }
    secret_text { Random.rand(3).zero? ? Array.new(Random.rand(1..2)) { Faker::Books::Dune.quote }.join("\n") : '' }
    created_at { Time.current - Random.rand(60).minutes - Random.rand(60).seconds }
    updated_at { created_at }
  end
end
