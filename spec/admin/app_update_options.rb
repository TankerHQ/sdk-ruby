# frozen_string_literal: true

module Tanker
  class Admin
    class AppUpdateOptions
      attr_accessor :oidc_client_id, :oidc_display_name, :oidc_issuer, :preverified_verification, :user_enrollment

      def initialize(oidc_client_id: nil, oidc_display_name: nil,
                     oidc_issuer: nil, preverified_verification: nil, user_enrollment: nil)
        @oidc_client_id = oidc_client_id
        @oidc_display_name = oidc_display_name
        @oidc_issuer = oidc_issuer
        @preverified_verification = preverified_verification
        @user_enrollment = user_enrollment
      end

      def as_json(_options = {})
        providers = []
        oidc_providers_allow_delete = false
        unless @oidc_client_id.nil? || @oidc_display_name.nil? || @oidc_issuer.nil?
          providers.push({
                           client_id: @oidc_client_id,
                           display_name: @oidc_display_name,
                           issuer: @oidc_issuer
                         })
          oidc_providers_allow_delete = true
        end
        {
          oidc_providers: providers,
          oidc_providers_allow_delete:,
          preverified_verification_enabled: @preverified_verification,
          enroll_users_enabled: @user_enrollment
        }
      end
    end
  end
end
