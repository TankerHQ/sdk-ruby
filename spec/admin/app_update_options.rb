# frozen_string_literal: true

module Tanker
  class Admin
    class AppUpdateOptions
      attr_accessor :oidc_client_id, :oidc_client_provider, :preverified_verification, :user_enrollment

      def initialize(oidc_client_id: nil, oidc_client_provider: nil,
                     preverified_verification: nil, user_enrollment: nil)
        @oidc_client_id = oidc_client_id
        @oidc_client_provider = oidc_client_provider
        @preverified_verification = preverified_verification
        @user_enrollment = user_enrollment
      end

      def as_json(_options = {})
        {
          oidc_client_id: @oidc_client_id,
          oidc_provider: @oidc_client_provider,
          preverified_verification_enabled: @preverified_verification,
          enroll_users_enabled: @user_enrollment
        }
      end
    end
  end
end
