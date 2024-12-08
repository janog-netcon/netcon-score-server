# frozen_string_literal: true

# null許容
Rails.application.config.slack_webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
Rails.application.config.slack_answer_channel = ENV.fetch('SLACK_ANSWER_CHANNEL', nil)
Rails.application.config.slack_question_channel = ENV.fetch('SLACK_QUESTION_CHANNEL', nil)
Rails.application.config.score_server_domain = ENV.fetch('SCORE_SERVER_DOMAIN', nil)
