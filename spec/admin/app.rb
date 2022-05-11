# frozen_string_literal: true

module Tanker
  class Admin
    # Information from the Admin SDK concerning a Tanker application
    class App
      attr_reader :admin, :id, :auth_token, :secret

      def initialize(admin:, id:, auth_token:, secret:)
        @admin = admin
        @id = id
        @auth_token = auth_token
        @secret = secret
      end

      def get_email_verification_code(email)
        @admin.get_email_verification_code(@id, @auth_token, email)
      end

      def get_sms_verification_code(phone_number)
        @admin.get_sms_verification_code(@id, @auth_token, phone_number)
      end
    end
  end
end
