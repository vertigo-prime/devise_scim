# frozen_string_literal: true

require "combustion"

Combustion.initialize! :all

require "rspec/rails"
require "devise"
require "factory_bot_rails"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true
end
