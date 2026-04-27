# frozen_string_literal: true

require "combustion"

Combustion.initialize! :all

require "rspec/rails"
require "devise"
require "factory_bot_rails"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true

  # The generator spec establishes a fresh in-memory SQLite connection at
  # file-load time, overwriting the combustion connection. Reload the schema
  # after all files are loaded so AR specs see the correct tables.
  config.before(:suite) do
    load File.expand_path("internal/db/schema.rb", __dir__)
  end
end
