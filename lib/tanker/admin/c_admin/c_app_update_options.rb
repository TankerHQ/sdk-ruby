# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'

module Tanker
  class Admin
    class AppUpdateOptions < FFI::Struct
      def initialize(oidc_client_id: nil, oidc_client_provider: nil,
                     preverified_verification: nil, user_enrollment: nil)
        super()
        self[:version] = 4
        unless oidc_client_id.nil?
          @oidc_client_id = CTanker.new_cstring oidc_client_id
          self[:oidc_client_id] = @oidc_client_id
        end
        unless oidc_client_provider.nil?
          @oidc_client_provider = CTanker.new_cstring oidc_client_provider
          self[:oidc_client_provider] = @oidc_client_provider
        end
        unless preverified_verification.nil?
          boolptr = FFI::MemoryPointer.new(:bool, 1)
          boolptr.put(:bool, 0, preverified_verification)
          @preverified_verification = boolptr
          self[:preverified_verification] = @preverified_verification
        end
        unless user_enrollment.nil? # rubocop:disable Style/GuardClause no different than the other parameters
          boolptr = FFI::MemoryPointer.new(:bool, 1)
          boolptr.put(:bool, 0, user_enrollment)
          @user_enrollment = boolptr
          self[:user_enrollment] = @user_enrollment
        end
      end

      layout :version, :uint8,
             :oidc_client_id, :pointer,
             :oidc_client_provider, :pointer,
             :preverified_verification, :pointer,
             :user_enrollment, :pointer
    end
  end
end
