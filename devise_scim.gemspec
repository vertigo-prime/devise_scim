# frozen_string_literal: true

require_relative "lib/devise_scim/version"

Gem::Specification.new do |spec|
  spec.name = "devise_scim"
  spec.version = DeviseScim::VERSION
  spec.authors = ["Vertigo-Prime"]
  spec.email = ["devise_scim@vinson.pro"]

  spec.summary = "SCIM 2.0 server for Rails + Devise applications."
  spec.description = "Mount a RFC 7643/7644-compliant SCIM 2.0 provider into any Rails app using Devise. Supports single- and multi-tenant deployments, bearer-token and OAuth 2.0 client-credentials auth, and a pluggable ScimAdapter."
  spec.homepage = "https://github.com/vertigo-prime/devise_scim"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bcrypt", ">= 3.1", "< 4"
  spec.add_dependency "devise", ">= 4.9", "< 6"
  spec.add_dependency "rails", ">= 7.0", "< 9"

  # Optional: doorkeeper >= 5.6 required only when OAuth auth is used.
  # The engine raises DeviseScim::ConfigurationError at boot if OAuth is
  # configured but doorkeeper is not installed.
end
