# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'tanker/core/version'

Gem::Specification.new do |spec|
  spec.name          = 'tanker-core'
  spec.version       = Tanker::Core::VERSION
  spec.authors       = ['Tanker team']
  spec.email         = ['tech@tanker.io']

  spec.summary       = 'Ruby SDK for Tanker'
  spec.description   = <<~DESCRIPTION
    Ruby bindings for the Tanker SDK.
    Tanker is a platform as a service that allows you to easily protect your users' data with end-to-end encryption through a SDK
  DESCRIPTION
  spec.homepage      = 'https://tanker.io'
  spec.license       = 'Apache-2.0'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/TankerHQ/sdk-ruby'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    'README.rst',
    'LICENSE',
    'lib/**/*',
    'vendor/libctanker/linux64/tanker/lib/libctanker.so',
    'vendor/libctanker/mac64/tanker/lib/libctanker.dylib',
  ]

  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'ffi', '~> 1.13'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'bundler-audit', '~> 0.7'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.85.1'
  spec.add_development_dependency 'rubygems-tasks', '~> 0.2.5'
  spec.add_development_dependency 'tanker-identity', '~> 0.1'
end
