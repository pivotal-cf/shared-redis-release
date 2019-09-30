require 'yaml'
require 'helpers/environment'
require 'helpers/utilities'
require 'rspec_junit_formatter'
require 'aws-sdk'

ROOT = File.expand_path('..', __dir__)

def test_manifest
  @test_manifest ||= YAML.load_file(ENV.fetch('BOSH_MANIFEST'))
end

def deployment_name
  test_manifest.fetch('name')
end

RSpec.configure do |config|
  config.include Helpers::Environment
  config.include Helpers::Utilities
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.order = 'random'
  config.full_backtrace = true

  config.formatter = :documentation
  config.add_formatter RSpecJUnitFormatter, 'rspec.xml'
  config.full_backtrace = true
end
