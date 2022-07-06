# frozen_string_literal: true

require 'tanker/c_tanker'
require_relative 'status'

module Tanker
  class Core
    extend Gem::Deprecate

    def start(identity)
      CTanker.tanker_start(@ctanker, identity).get.address
    end

    def enroll_user(identity, verifications)
      cverifs = CTanker::CVerificationList.new(verifications)
      CTanker.tanker_enroll_user(@ctanker, identity, cverifs).get
    end

    def generate_verification_key
      CTanker.tanker_generate_verification_key(@ctanker).get_string
    end

    def register_identity(verification, options = nil)
      cverif = CTanker::CVerification.new(verification)
      CTanker.tanker_register_identity(@ctanker, cverif, options).get_maybe_string
    end

    def verify_identity(verification, options = nil)
      cverif = CTanker::CVerification.new(verification)
      CTanker.tanker_verify_identity(@ctanker, cverif, options).get_maybe_string
    end

    def set_verification_method(verification, options = nil)
      cverif = CTanker::CVerification.new(verification)
      CTanker.tanker_set_verification_method(@ctanker, cverif, options).get_maybe_string
    end

    def get_verification_methods # rubocop:disable Naming/AccessorMethodName
      method_list_ptr = CTanker.tanker_get_verification_methods(@ctanker).get
      count = method_list_ptr.get(:uint32, FFI::Pointer.size)

      method_base_addr = method_list_ptr.read_pointer
      method_list = count.times.map do |i|
        method_ptr = method_base_addr + (i * CTanker::CVerificationMethod.size)
        CTanker::CVerificationMethod.new(method_ptr).to_verification_method
      end
      CTanker.tanker_free_verification_method_list method_list_ptr
      method_list
    end

    def stop
      CTanker.tanker_stop(@ctanker).get
    end

    def create_oidc_nonce
      CTanker.tanker_create_oidc_nonce(@ctanker).get_string
    end

    def oidc_test_nonce=(nonce)
      CTanker.tanker_set_oidc_test_nonce(@ctanker, nonce).get
    end

    def status
      CTanker.tanker_status(@ctanker)
    end

    def attach_provisional_identity(provisional_identity)
      attach_ptr = CTanker.tanker_attach_provisional_identity(@ctanker, provisional_identity).get
      attach_status = attach_ptr.get(:uint8, 1)
      method_ptr = attach_ptr.get_pointer(FFI::Pointer.size)
      method = (CTanker::CVerificationMethod.new(method_ptr).to_verification_method if method_ptr.address != 0)
      AttachResult.new attach_status, method
    end

    def verify_provisional_identity(verification)
      cverif = CTanker::CVerification.new(verification)
      CTanker.tanker_verify_provisional_identity(@ctanker, cverif).get
    end
  end
end
