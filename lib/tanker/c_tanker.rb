# frozen_string_literal: true

require 'ffi'
require_relative 'c_tanker/c_lib'
require_relative 'core/options'
require_relative 'sharing_options'
require_relative 'encryption_options'
require_relative 'verification_options'
require_relative 'c_tanker/c_future'
require_relative 'c_tanker/c_verification'
require_relative 'c_tanker/c_verification_method'
require_relative 'c_tanker/c_log_record'
require_relative 'c_tanker/c_device_info'

module Tanker
  module CTanker
    typedef :pointer, :session_pointer
    typedef :pointer, :enc_sess_pointer
    typedef :pointer, :stream_pointer
    typedef :pointer, :read_operation_pointer

    callback :log_handler_callback, [CLogRecord.by_ref], :void
    callback :stream_input_source_callback, [:pointer, :int64, :read_operation_pointer, :pointer], :void

    blocking_attach_function :tanker_init, [], :void
    blocking_attach_function :tanker_version_string, [], :string
    blocking_attach_function :tanker_create, [Tanker::Core::Options], CFuture
    blocking_attach_function :tanker_destroy, [:session_pointer], CFuture
    blocking_attach_function :tanker_start, [:session_pointer, :string], CFuture
    blocking_attach_function :tanker_enroll_user, [:session_pointer, :string, CVerificationList], CFuture
    blocking_attach_function :tanker_register_identity, [:session_pointer, CVerification,
                                                         Tanker::VerificationOptions], CFuture
    blocking_attach_function :tanker_verify_identity, [:session_pointer, CVerification,
                                                       Tanker::VerificationOptions], CFuture
    blocking_attach_function :tanker_get_verification_methods, [:session_pointer], CFuture
    blocking_attach_function :tanker_set_verification_method, [:session_pointer, CVerification,
                                                               Tanker::VerificationOptions], CFuture
    blocking_attach_function :tanker_stop, [:session_pointer], CFuture
    blocking_attach_function :tanker_status, [:session_pointer], :uint32
    blocking_attach_function :tanker_generate_verification_key, [:session_pointer], CFuture
    blocking_attach_function :tanker_device_id, [:session_pointer], CFuture
    blocking_attach_function :tanker_get_device_list, [:session_pointer], CFuture

    blocking_attach_function :tanker_create_oidc_nonce, [:session_pointer], CFuture
    blocking_attach_function :tanker_set_oidc_test_nonce, [:session_pointer, :string], CFuture

    blocking_attach_function :tanker_attach_provisional_identity, [:session_pointer, :string], CFuture
    blocking_attach_function :tanker_verify_provisional_identity, [:session_pointer, CVerification], CFuture

    blocking_attach_function :tanker_encrypted_size, [:uint64, :uint32], :uint64
    blocking_attach_function :tanker_decrypted_size, [:pointer, :uint64], CFuture
    blocking_attach_function :tanker_get_resource_id, [:pointer, :uint64], CFuture

    blocking_attach_function :tanker_encrypt, [:session_pointer, :pointer, :pointer, :uint64,
                                               Tanker::EncryptionOptions], CFuture
    blocking_attach_function :tanker_decrypt, [:session_pointer, :pointer, :pointer, :uint64], CFuture
    blocking_attach_function :tanker_share, [:session_pointer, :pointer, :uint32, Tanker::SharingOptions], CFuture

    blocking_attach_function :tanker_future_wait, [CFuture], :void
    blocking_attach_function :tanker_future_has_error, [CFuture], :bool
    blocking_attach_function :tanker_future_get_error, [CFuture], CTankerError.by_ref
    blocking_attach_function :tanker_future_get_voidptr, [CFuture], :pointer
    blocking_attach_function :tanker_future_destroy, [CFuture], :void

    blocking_attach_function :tanker_create_group, [:session_pointer, :pointer, :uint64], CFuture
    blocking_attach_function :tanker_update_group_members, [:session_pointer, :string,
                                                            :pointer, :uint64, :pointer, :uint64], CFuture

    blocking_attach_function :tanker_encryption_session_open, [:session_pointer, Tanker::EncryptionOptions], CFuture
    blocking_attach_function :tanker_encryption_session_close, [:enc_sess_pointer], CFuture
    blocking_attach_function :tanker_encryption_session_encrypted_size, [:uint64], :uint64
    blocking_attach_function :tanker_encryption_session_get_resource_id, [:enc_sess_pointer], CFuture
    blocking_attach_function :tanker_encryption_session_encrypt, [:enc_sess_pointer, :pointer,
                                                                  :pointer, :uint64], CFuture
    blocking_attach_function :tanker_encryption_session_stream_encrypt, [:enc_sess_pointer,
                                                                         :stream_input_source_callback, :pointer],
                             CFuture

    blocking_attach_function :tanker_stream_encrypt, [:session_pointer, :stream_input_source_callback,
                                                      :pointer, Tanker::EncryptionOptions], CFuture
    blocking_attach_function :tanker_stream_decrypt, [:session_pointer, :stream_input_source_callback,
                                                      :pointer], CFuture
    blocking_attach_function :tanker_stream_read_operation_finish, [:read_operation_pointer, :int64], :void
    blocking_attach_function :tanker_stream_read, [:stream_pointer, :pointer, :int64], CFuture

    blocking_attach_function :tanker_stream_get_resource_id, [:stream_pointer], CFuture
    blocking_attach_function :tanker_stream_close, [:stream_pointer], CFuture

    blocking_attach_function :tanker_set_log_handler, [:log_handler_callback], :void

    blocking_attach_function :tanker_http_handle_response, [CHttpRequest, CHttpResponse], :void

    blocking_attach_function :tanker_prehash_password, [:string], CFuture

    blocking_attach_function :tanker_free_buffer, [:pointer], :void
    blocking_attach_function :tanker_free_verification_method_list, [:pointer], :void
    blocking_attach_function :tanker_free_device_list, [:pointer], :void
  end

  private_constant :CTanker
end
