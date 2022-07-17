# frozen_string_literal: true

# null許容
Rails.application.config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
Rails.application.config.slack_answer_channel = ENV['SLACK_ANSWER_CHANNEL']
Rails.application.config.slack_question_channel = ENV['SLACK_QUESTION_CHANNEL']
Rails.application.config.score_server_domain = ENV['SCORE_SERVER_DOMAIN']
