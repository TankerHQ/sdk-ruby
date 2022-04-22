# frozen_string_literal: true

require 'ffi'

module FFI::Library
  # Marking a function blocking releases the global Ruby lock.
  # This is required for every function that could invoke a callback (including log handler) in another thread
  def blocking_attach_function(func, args, returns = nil)
    attach_function func, args, returns, blocking: true
  end
end

module Tanker
  module CTanker
    extend FFI::Library
    ffi_lib get_path('ctanker')
  end

  private_constant :CTanker
end
