# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-cobertura"

  SimpleCov.start "rails" do
    add_filter "/spec/"
    add_filter "lib/devise_scim/version.rb"
    add_filter "lib/devise_scim/rspec"
    add_filter "lib/devise_scim/minitest.rb"
    add_filter "lib/generators/devise_scim/adapter_generator.rb"
    formatter SimpleCov::Formatter::CoberturaFormatter
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
