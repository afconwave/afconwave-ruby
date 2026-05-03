$:.push File.expand_path("../lib", __FILE__)
require "afconwave/version"

Gem::Specification.new do |s|
  s.name        = "afconwave"
  s.version     = AfconWave::VERSION
  s.summary     = "Official Ruby SDK for the AfconWave Payments API"
  s.description = "Integrate AfconWave payments, payouts, and refunds into your Ruby or Rails applications."
  s.authors     = ["AfconWave Team"]
  s.email       = ["support@afconwave.com"]
  s.homepage    = "https://github.com/afconwave/afconwave-ruby"
  s.license     = "MIT"

  s.files       = Dir["lib/**/*", "README.md", "LICENSE"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 2.5.0"
end
