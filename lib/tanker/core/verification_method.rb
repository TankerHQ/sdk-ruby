# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'

module Tanker
  class VerificationMethod
    def ==(other)
      self.class == other.class
    end
  end

  class PassphraseVerificationMethod < VerificationMethod; end
  class VerificationKeyVerificationMethod < VerificationMethod; end
  class OIDCIDTokenVerificationMethod < VerificationMethod; end
  class EmailVerificationMethod < VerificationMethod
    attr_reader :email

    def initialize(email)
      super()
      @email = email
    end

    def ==(other)
      super && email == other.email
    end
  end

  class PhoneNumberVerificationMethod < VerificationMethod
    attr_reader :phone_number

    def initialize(phone_number)
      super()
      @phone_number = phone_number
    end

    def ==(other)
      super && phone_number == other.phone_number
    end
  end
end
