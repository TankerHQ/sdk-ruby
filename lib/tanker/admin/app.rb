# frozen_string_literal: true

module Tanker
  class Admin
    # Information from the Admin SDK concerning a Tanker application
    class App
      attr_reader :url, :id, :auth_token, :private_key

      def initialize(trustchain_url:, id:, auth_token:, private_key:)
        @trustchain_url = trustchain_url
        @id = id
        @auth_token = auth_token
        @private_key = private_key
      end

      def get_email_verification_code(email)
        CAdmin.tanker_get_email_verification_code(@trustchain_url, @id, @auth_token, email).get_string
      end

      def get_sms_verification_code(phone_number)
        CAdmin.tanker_get_sms_verification_code(@trustchain_url, @id, @auth_token, phone_number).get_string
      end
    end
  end
end
