# frozen_string_literal: true

module Tanker
  class Admin
    class AppUpdateOptions
      attr_accessor :oidc_client_id,
                    :oidc_display_name,
                    :oidc_issuer,
                    :oidc_provider_group_id,
                    :preverified_verification

      def initialize(oidc_client_id: nil, oidc_display_name: nil,
                     oidc_issuer: nil, oidc_provider_group_id: nil, preverified_verification: nil)
        @oidc_client_id = oidc_client_id
        @oidc_display_name = oidc_display_name
        @oidc_issuer = oidc_issuer
        @oidc_provider_group_id = oidc_provider_group_id
        @preverified_verification = preverified_verification
      end

      def as_json(_options = {})
        providers = []
        oidc_providers_allow_delete = false
        unless @oidc_client_id.nil? || @oidc_display_name.nil? || @oidc_issuer.nil? || @oidc_provider_group_id.nil?
          providers.push({
                           client_id: @oidc_client_id,
                           display_name: @oidc_display_name,
                           oidc_provider_group_id: @oidc_provider_group_id,
                           issuer: @oidc_issuer
                         })
          oidc_providers_allow_delete = true
        end
        {
          oidc_providers: providers,
          oidc_providers_allow_delete:,
          preverified_verification_enabled: @preverified_verification
        }
      end
    end
  end
end
