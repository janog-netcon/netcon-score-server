# frozen_string_literal: true

# Slack通知のための汎用的なJob
# 外部サービスにアクセスする処理は
# ネットワークの遅延や相手サーバーダウンなどが原因で
# 長時間止まったり失敗したりする
# JobにするとAPIのレスポンスに影響しないしリトライが楽
class SlackNotifierJob < ApplicationJob
  queue_as :default

  def perform(message, mutation)
    return if Rails.application.config.slack_webhook_url.blank? or RaRails.application.config.slack_answer_channel or Rails.application.config.slack_question_channel

    case mutation
    when "AddAnswer"
      notifier = Slack::Notifier.new(Rails.application.config.slack_webhook_url) do
        defaults channel: Rails.application.config.slack_answer_channel
      end
    when 'AddIssueComment', 'StartIssue'
      notifier = Slack::Notifier.new(Rails.application.config.slack_webhook_url) do
        defaults channel: Rails.application.config.slack_question_channel
      end

    notifier.ping(message)
  end
end
