# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

require "brakeman"

namespace :brakeman do
  desc "Run Brakeman security scan"
  task :check do
    Brakeman.run(app_path: ".", force_scan: true, print_report: true, quiet: false)
  end
end

task default: %i[spec rubocop brakeman:check]
