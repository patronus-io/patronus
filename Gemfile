source "https://rubygems.org"

ruby File.read(".ruby-version").chomp

gem "rails", "4.2.3"

gem "faraday-http-cache"
gem "jquery-rails", "~> 4.0"
gem "lograge"
gem "octokit"
gem "pg", "~> 0.18.2"
gem "puma", "~> 3.4.0"
gem "sass-rails", "~> 5.0"
gem "uglifier", ">= 1.3.0"
gem "warden-github-rails", "~> 1.2"

group :development do
  gem "pry-byebug", "~> 3.2"
  gem "pry-rails", "~> 0.3.4"
  gem "web-console", "~> 2.0"
end

group :development, :test do
  gem "rspec-rails", "~> 3.3"
  gem "dotenv-rails", "~> 2.0"
end

group :test do
  gem 'capybara', '~> 2.7.1'
  gem 'guard-rspec', '~> 4.7.2'
  gem 'vcr', '~> 3.0.3'
  gem 'webmock', '~> 2.1.0'
end

group :production do
  gem "memcachier"
  gem "dalli"
  gem "rails_12factor"
end
