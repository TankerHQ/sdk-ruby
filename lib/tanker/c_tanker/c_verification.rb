# frozen_string_literal: true

require 'ffi'
require 'tanker/core/verification'
require 'tanker/c_tanker/c_string'

module Tanker
  module CTanker
    class CEmailVerification < FFI::Struct
      layout :version, :uint8,
             :email, :pointer,
             :verification_code, :pointer

      def initialize(email, verification_code)
        super()

        # NOTE: Instance variables are required to keep the CStrings alive
        @email = CTanker.new_cstring email
        @verification_code = CTanker.new_cstring verification_code

        self[:version] = 1
        self[:email] = @email
        self[:verification_code] = @verification_code
      end
    end

    class CVerification < FFI::Struct
      layout :version, :uint8,
             :type, :uint8,
             :verification_key, :pointer,
             :email_verification, CEmailVerification,
             :passphrase, :pointer,
             :oidc_id_token, :pointer

      TYPE_EMAIL = 1
      TYPE_PASSPHRASE = 2
      TYPE_VERIFICATION_KEY = 3
      TYPE_OIDC_ID_TOKEN = 4

      def initialize(verification)
        super()

        unless verification.is_a? Tanker::Verification
          raise TypeError, 'Verification argument is not a Tanker::Verification'
        end

        # NOTE: Instance variables are required to keep the CStrings alive
        case verification
        when Tanker::EmailVerification
          self[:type] = TYPE_EMAIL
          self[:email_verification] = CEmailVerification.new verification.email, verification.verification_code
        when Tanker::PassphraseVerification
          @passphrase = CTanker.new_cstring verification.passphrase
          self[:type] = TYPE_PASSPHRASE
          self[:passphrase] = @passphrase
        when Tanker::VerificationKeyVerification
          @verification_key = CTanker.new_cstring verification.verification_key
          self[:type] = TYPE_VERIFICATION_KEY
          self[:verification_key] = @verification_key
        when Tanker::OIDCIDTokenVerification
          @oidc_id_token = CTanker.new_cstring verification.oidc_id_token
          self[:type] = TYPE_OIDC_ID_TOKEN
          self[:oidc_id_token] = @oidc_id_token
        else
          raise ArgumentError, 'Unknown Tanker::Verification type!'
        end

        self[:version] = 3
      end
    end
  end
end
