# frozen_string_literal: true

require 'ffi'
require_relative 'admin/c_admin'
require_relative 'admin/c_admin/c_app_descriptor'
require_relative 'admin/app'

module Tanker
  class Admin
    def initialize(admin_url, id_token, api_url)
      @admin_url = admin_url
      @id_token = id_token
      @api_url = api_url
    end

    # Authenticate to the Tanker admin server API
    # This must be called before doing any other operation
    def connect
      @cadmin = CAdmin.tanker_admin_connect(@admin_url, @id_token).get
      cadmin_addr = @cadmin.address
      ObjectSpace.define_finalizer(@cadmin) do |_|
        CAdmin.tanker_admin_destroy(FFI::Pointer.new(:void, cadmin_addr)).get
      end
    end

    def create_app(name)
      assert_connected
      descriptor_ptr = CAdmin.tanker_admin_create_app(@cadmin, name).get
      descriptor = CAdmin::CAppDescriptor.new(descriptor_ptr)
      App.new(@api_url, descriptor[:id], descriptor[:auth_token], descriptor[:private_key])
    end

    def delete_app(app_id)
      assert_connected
      CAdmin.tanker_admin_delete_app(@cadmin, app_id).get
    end

    def app_update(app_id, oidc_client_id, oidc_client_provider)
      assert_connected
      CAdmin.tanker_admin_app_update(@cadmin, app_id, oidc_client_id, oidc_client_provider).get
    end

    private

    def assert_connected
      raise 'You need to connect() before using the admin API!' if @cadmin.nil?
    end
  end

  private_constant :Admin
end
