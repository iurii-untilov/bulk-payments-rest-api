require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module BulkPayments
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true

    config.log_level = ENV.fetch("RAILS_LOG_LEVEL", config.log_level)

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
