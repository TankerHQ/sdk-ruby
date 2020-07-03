# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_future'

module Tanker
  class Admin
    module CAdmin
      extend FFI::Library

      ffi_lib "#{__dir__}/../../../vendor/libctanker/linux64/tanker/lib/libtanker_admin-c.so"

      typedef :pointer, :admin_pointer

      # Note: We use those CFutures with the tanker_future_* functions exposed by CTanker,
      # this is safe because we only do simple synchronous blocking calls, without using tanker_future_then.

      attach_function :tanker_admin_connect, [:string, :string], CTanker::CFuture
      attach_function :tanker_admin_create_app, [:admin_pointer, :string], CTanker::CFuture
      attach_function :tanker_admin_delete_app, [:admin_pointer, :string], CTanker::CFuture
      attach_function :tanker_admin_destroy, [:admin_pointer], CTanker::CFuture
      attach_function :tanker_admin_app_descriptor_free, [:pointer], :void
      attach_function :tanker_admin_app_update, [:admin_pointer, :string, :string, :string], CTanker::CFuture
      attach_function :tanker_get_verification_code, [:string, :string, :string, :string], CTanker::CFuture
    end

    private_constant :CAdmin
  end
end
