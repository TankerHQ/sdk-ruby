# frozen_string_literal: true

require 'ffi'
require_relative 'admin/c_admin'
require_relative 'admin/c_admin/c_app_descriptor'
require_relative 'admin/c_admin/c_app_update_options'
require_relative 'admin/app'

module Tanker
  class Admin
    def initialize(admin_url:, api_url:, trustchain_url:, id_token:)
      @admin_url = admin_url
      @id_token = id_token
      @api_url = api_url
      @trustchain_url = trustchain_url
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
      App.new(
        trustchain_url: @trustchain_url,
        id: descriptor[:id],
        auth_token: descriptor[:auth_token],
        private_key: descriptor[:private_key]
      )
    end

    def delete_app(app_id)
      assert_connected
      CAdmin.tanker_admin_delete_app(@cadmin, app_id).get
    end

    def app_update(app_id, app_update_options)
      assert_connected
      CAdmin.tanker_admin_app_update(@cadmin, app_id, app_update_options).get
    end

    private

    def assert_connected
      raise 'You need to connect() before using the admin API!' if @cadmin.nil?
    end
  end

  private_constant :Admin
end
