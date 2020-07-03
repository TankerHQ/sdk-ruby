# frozen_string_literal: true

require 'ffi'

module Tanker
  class Admin
    class CAdmin::CAppDescriptor < FFI::ManagedStruct
      layout :name, :string,
             :id, :string,
             :auth_token, :string,
             :private_key, :string,
             :public_key, :string

      def get_verification_code(email)
        CTanker.tanker_get_verification_code(email).get
      end

      def self.release(ptr)
        CAdmin.tanker_admin_app_descriptor_free ptr
      end
    end
  end
end
