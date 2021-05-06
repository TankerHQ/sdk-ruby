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
end
