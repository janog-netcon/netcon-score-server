# frozen_string_literal: true

Sentry.init do |config|
  environment = ENV.fetch('RAILS_ENV', 'development')
  config.debug = environment == 'production'
  config.environment = environment
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.include_local_variables = true

  config.sample_rate = 1.0
  config.traces_sample_rate = 1.0
end
