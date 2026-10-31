source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "dry-validation", "~> 1.11"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"
end

group :test do
  gem "shoulda-matchers", "~> 7.0"
end
