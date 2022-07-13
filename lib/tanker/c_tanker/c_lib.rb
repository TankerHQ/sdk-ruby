# frozen_string_literal: true

require 'ffi'
require 'ffi/platform'

module FFI::Library
  # Marking a function blocking releases the global Ruby lock.
  # This is required for every function that could invoke a callback (including log handler) in another thread
  def blocking_attach_function(func, args, returns = nil)
    attach_function func, args, returns, blocking: true
  end
end

module Tanker
  module CTanker
    def self.get_path(name)
      File.expand_path "../../../vendor/tanker/#{FFI::Platform::OS}-#{FFI::Platform::ARCH}/" \
                       "#{FFI::Platform::LIBPREFIX}#{name}.#{FFI::Platform::LIBSUFFIX}", __dir__
    end

    extend FFI::Library
    ffi_lib get_path('ctanker')
  end
end
