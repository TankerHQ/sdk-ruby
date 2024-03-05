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

    class CPhoneNumberVerification < FFI::Struct
      layout :version, :uint8,
             :phone_number, :pointer,
             :verification_code, :pointer

      def initialize(phone_number, verification_code)
        super()

        # NOTE: Instance variables are required to keep the CStrings alive
        @phone_number = CTanker.new_cstring phone_number
        @verification_code = CTanker.new_cstring verification_code

        self[:version] = 1
        self[:phone_number] = @phone_number
        self[:verification_code] = @verification_code
      end
    end

    class COIDCVerification < FFI::Struct
      layout :version, :uint8,
             :subject, :pointer,
             :provider_id, :pointer

      def initialize(subject, provider_id)
        super()

        # NOTE: Instance variables are required to keep the CStrings alive
        @subject = CTanker.new_cstring subject
        @provider_id = CTanker.new_cstring provider_id

        self[:version] = 1
        self[:subject] = @subject
        self[:provider_id] = @provider_id
      end
    end

    class CVerification < FFI::Struct
      layout :version, :uint8,
             :type, :uint8,
             :verification_key, :pointer,
             :email_verification, CEmailVerification,
             :passphrase, :pointer,
             :e2e_passphrase, :pointer,
             :oidc_id_token, :pointer,
             :phone_number_verification, CPhoneNumberVerification,
             :preverified_email, :pointer,
             :preverified_phone_number, :pointer,
             :preverified_oidc, COIDCVerification

      TYPE_EMAIL = 1
      TYPE_PASSPHRASE = 2
      TYPE_VERIFICATION_KEY = 3
      TYPE_OIDC_ID_TOKEN = 4
      TYPE_PHONE_NUMBER = 5
      TYPE_PREVERIFIED_EMAIL = 6
      TYPE_PREVERIFIED_PHONE_NUMBER = 7
      TYPE_E2E_PASSPHRASE = 8
      TYPE_PREVERIFIED_OIDC = 9

      def initialize(verification) # rubocop:disable Metrics/CyclomaticComplexity Not relevant for a case/when
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
        when Tanker::PhoneNumberVerification
          self[:type] = TYPE_PHONE_NUMBER
          self[:phone_number_verification] =
            CPhoneNumberVerification.new verification.phone_number, verification.verification_code
        when Tanker::PreverifiedEmailVerification
          @preverified_email = CTanker.new_cstring verification.preverified_email
          self[:type] = TYPE_PREVERIFIED_EMAIL
          self[:preverified_email] = @preverified_email
        when Tanker::PreverifiedPhoneNumberVerification
          @preverified_phone_number = CTanker.new_cstring verification.preverified_phone_number
          self[:type] = TYPE_PREVERIFIED_PHONE_NUMBER
          self[:preverified_phone_number] = @preverified_phone_number
        when Tanker::E2ePassphraseVerification
          @e2e_passphrase = CTanker.new_cstring verification.e2e_passphrase
          self[:type] = TYPE_E2E_PASSPHRASE
          self[:e2e_passphrase] = @e2e_passphrase
        when Tanker::PreverifiedOIDCVerification
          @preverified_oidc = COIDCVerification.new verification.subject, verification.provider_id
          self[:type] = TYPE_PREVERIFIED_OIDC
          self[:preverified_oidc] = @preverified_oidc
        else
          raise ArgumentError, 'Unknown Tanker::Verification type!'
        end

        self[:version] = 7
      end
    end

    class CVerificationList < FFI::Struct
      layout :version, :uint8,
             :verifications, :pointer,
             :count, :uint32

      def initialize(verifications)
        super()

        unless verifications.is_a?(Array)
          raise TypeError, 'Verifications argument is not an Array[Tanker::Verification]'
        end

        self[:version] = 1
        self[:count] = verifications.length

        # NOTE: Instance variables are required to keep the CVerifications alive
        @verifications = []
        self[:verifications] = FFI::MemoryPointer.new(CVerification, self[:count])
        verifications.each_with_index do |verification, idx|
          @verifications.push(CVerification.new(verification))
          # NOTE: memcopy
          str = @verifications[idx].pointer.read_bytes CVerification.size
          self[:verifications].put_bytes(idx * CVerification.size, str, 0, CVerification.size)
        end
      end
    end
  end
end
