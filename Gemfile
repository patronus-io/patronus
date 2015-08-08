source "https://rubygems.org"

ruby File.read(".ruby-version").chomp

gem "rails", "4.2.3"

gem "jquery-rails", "~> 4.0"
gem "pg", "~> 0.18.2"
gem "puma", "~> 2.11.0"
gem "sass-rails", "~> 5.0"
gem "uglifier", ">= 1.3.0"
gem "warden-github-rails", "~> 1.1.0", github: "indirect/warden-github-rails"
gem "octokit"
gem "lograge"

group :development do
  gem "dotenv-rails", "~> 2.0"
  gem "pry-byebug", "~> 3.2"
  gem "web-console", "~> 2.0"
end

group :development, :test do
  gem "rspec-rails", "~> 3.3"
end

group :production do
  gem "rails_12factor"
end
