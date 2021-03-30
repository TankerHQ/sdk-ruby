# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'

module Tanker
  class Admin
    class AppUpdateOptions < FFI::Struct
      def initialize(oidc_client_id: nil, oidc_client_provider: nil, session_certificates: nil)
        self[:version] = 1
        unless oidc_client_id.nil?
          @oidc_client_id = CTanker.new_cstring oidc_client_id
          self[:oidc_client_id] = @oidc_client_id
        end
        unless oidc_client_provider.nil?
          @oidc_client_provider = CTanker.new_cstring oidc_client_provider
          self[:oidc_client_provider] = @oidc_client_provider
        end
        unless session_certificates.nil? # rubocop:disable Style/GuardClause no different than the other two above
          boolptr = FFI::MemoryPointer.new(:bool, 1)
          boolptr.put(:bool, 0, session_certificates)
          @session_certificates = boolptr
          self[:session_certificates] = @session_certificates
        end
      end

      layout :version, :uint8,
             :oidc_client_id, :pointer,
             :oidc_client_provider, :pointer,
             :session_certificates, :pointer
    end
  end
end
