# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'patronus/version'

Gem::Specification.new do |spec|
  spec.name          = "patronus"
  spec.version       = Patronus::VERSION
  spec.authors       = ["segiddins, indirect"]
  spec.email         = ["segiddins@segiddins.me", "andre@arko.net"]

  spec.summary       = %q{Keep dementors away from your production branches.}
  spec.description   = %q{Keep dementors away from your production branches.}
  spec.homepage      = "http://patronus-staging.herokuapp.com"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "4.2.3"
  spec.add_dependency "faraday-http-cache"
  spec.add_dependency "jquery-rails", "~> 4.0"
  spec.add_dependency "lograge"
  spec.add_dependency "octokit"
  spec.add_dependency "pg", "~> 0.18.2"
  spec.add_dependency "puma", "~> 2.11.0"
  spec.add_dependency "sass-rails", "~> 5.0"
  spec.add_dependency "uglifier", ">= 1.3.0"
  spec.add_dependency "warden-github-rails", "~> 1.2"
  spec.add_dependency "memcachier"
  spec.add_dependency "dalli"
  spec.add_dependency "rails_12factor"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "dotenv-rails", "~> 2.0"
  spec.add_development_dependency "pry-byebug", "~> 3.2"
  spec.add_development_dependency "pry-rails", "~> 0.3.4"
  spec.add_development_dependency "web-console", "~> 2.0"
  spec.add_development_dependency "rspec-rails", "~> 3.3"
end
