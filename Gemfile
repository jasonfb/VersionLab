source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

gem "vite_rails", "~> 3.0"
gem "turbo-rails"

gem "rspec-rails", "~> 8.0", groups: [:development, :test]
gem "rspec-wait", "~> 1.0", groups: [:development, :test]
gem "factory_bot_rails", "~> 6.5", groups: [:development, :test]
gem "ffaker", "~> 2.25", groups: [:development, :test]
gem "vcr", "~> 6.4", groups: [:development, :test]
gem "simplecov", "~> 0.22.0", groups: [:development, :test]
gem "dotenv-rails", "~> 3.2", groups: [:development, :test]
gem "webmock", "~> 3.26", groups: [:development, :test]

gem "simplecov-rcov", "~> 0.3.7", group: :test
gem "launchy", "~> 3.1", group: :test

gem "bullet", "~> 8.1", groups: [:development, :test]
gem "active_record_query_trace", "~> 1.9", groups: [:development, :test]
gem "byebug", "~> 13.0", groups: [:development, :test]
gem "annotaterb", "~> 4.21", groups: [:development, :test]

gem "rubycritic", "~> 5.0", group: :dev

gem "hot-glue", "~> 0.7.5"

gem "cssbundling-rails", "~> 1.4"

gem "pagy", "~> 43.2"
