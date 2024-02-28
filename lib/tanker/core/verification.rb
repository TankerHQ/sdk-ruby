# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'

module Tanker
  class Verification; end # rubocop:disable Lint/EmptyClass

  class EmailVerification < Verification
    attr_reader :email, :verification_code

    def initialize(email, verif_code)
      super()

      ASSERT_UTF8.call(email)
      ASSERT_UTF8.call(verif_code)

      @email = email
      @verification_code = verif_code
    end
  end

  class PassphraseVerification < Verification
    attr_reader :passphrase

    def initialize(passphrase)
      super()

      ASSERT_UTF8.call(passphrase)

      @passphrase = passphrase
    end
  end

  class VerificationKeyVerification < Verification
    attr_reader :verification_key

    def initialize(verif_key)
      super()

      ASSERT_UTF8.call(verif_key)

      @verification_key = verif_key
    end
  end

  class OIDCIDTokenVerification < Verification
    attr_reader :oidc_id_token

    def initialize(oidc_id_token)
      super()

      ASSERT_UTF8.call(oidc_id_token)

      @oidc_id_token = oidc_id_token
    end
  end

  class PhoneNumberVerification < Verification
    attr_reader :phone_number, :verification_code

    def initialize(phone_number, verif_code)
      super()

      ASSERT_UTF8.call(phone_number)
      ASSERT_UTF8.call(verif_code)

      @phone_number = phone_number
      @verification_code = verif_code
    end
  end

  class PreverifiedEmailVerification < Verification
    attr_reader :preverified_email

    def initialize(preverified_email)
      super()

      ASSERT_UTF8.call(preverified_email)

      @preverified_email = preverified_email
    end
  end

  class PreverifiedPhoneNumberVerification < Verification
    attr_reader :preverified_phone_number

    def initialize(preverified_phone_number)
      super()

      ASSERT_UTF8.call(preverified_phone_number)

      @preverified_phone_number = preverified_phone_number
    end
  end

  class PreverifiedOIDCVerification < Verification
    attr_reader :provider_id, :subject

    def initialize(subject, provider_id)
      super()

      ASSERT_UTF8.call(provider_id)
      ASSERT_UTF8.call(subject)

      @provider_id = provider_id
      @subject = subject
    end
  end

  class E2ePassphraseVerification < Verification
    attr_reader :e2e_passphrase

    def initialize(e2e_passphrase)
      super()

      ASSERT_UTF8.call(e2e_passphrase)

      @e2e_passphrase = e2e_passphrase
    end
  end
end
