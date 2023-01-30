# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'tanker/core/version'

Gem::Specification.new do |spec|
  spec.name        = 'tanker-core'
  spec.version     = Tanker::Core::VERSION
  spec.authors     = ['Tanker team']

  spec.summary     = 'Ruby SDK for Tanker'
  spec.description = <<~DESCRIPTION
    Ruby bindings for the Tanker SDK.
    Tanker is a platform as a service that allows you to easily protect your users' data with end-to-end encryption through a SDK
  DESCRIPTION
  spec.license = 'Apache-2.0'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7.0')

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = 'https://github.com/TankerHQ/sdk-ruby'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    'README.rst',
    'LICENSE',
    'lib/**/*',
    # Keep this in sync with run-ci.py
    'vendor/tanker/linux-x86_64/libctanker.so',
    'vendor/tanker/darwin-x86_64/libctanker.dylib',
    'vendor/tanker/darwin-aarch64/libctanker.dylib',
  ]

  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'faraday', '~> 0.17.5'
  spec.add_runtime_dependency 'ffi', '~> 1.13'
end
