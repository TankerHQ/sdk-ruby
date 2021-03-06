# frozen_string_literal: true

require 'ffi'
require 'tanker/core/verification_method'
require 'tanker/c_tanker/c_string'

module Tanker
  module CTanker
    class CVerificationMethod < FFI::Struct
      layout :version, :uint8,
             :type, :uint8,
             :value, :pointer

      TYPE_EMAIL = 1
      TYPE_PASSPHRASE = 2
      TYPE_VERIFICATION_KEY = 3
      TYPE_OIDC_ID_TOKEN = 4
      TYPE_PHONE_NUMBER = 5

      def to_verification_method
        case self[:type]
        when TYPE_EMAIL
          EmailVerificationMethod.new(self[:value].read_string.force_encoding(Encoding::UTF_8))
        when TYPE_PASSPHRASE
          PassphraseVerificationMethod.new
        when TYPE_VERIFICATION_KEY
          VerificationKeyVerificationMethod.new
        when TYPE_OIDC_ID_TOKEN
          OIDCIDTokenVerificationMethod.new
        when TYPE_PHONE_NUMBER
          PhoneNumberVerificationMethod.new(self[:value].read_string.force_encoding(Encoding::UTF_8))
        else
          raise "Unknown VerificationMethod type #{self[:type]}!"
        end
      end
    end
  end
end
