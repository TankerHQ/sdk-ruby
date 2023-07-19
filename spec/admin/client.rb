# frozen_string_literal: true

require 'faraday'

require_relative 'app'
require_relative 'app_update_options'

module Tanker
  class Admin
    class Client
      def self.init_conn(conn)
        conn.request :json
        conn.response :raise_error
        ## in case of verbosity need
        # require 'logger'
        # conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :json
        conn.adapter :net_http
        conn
      end

      def initialize(app_management_token:, # rubocop:disable Metrics/ParameterLists
                     app_management_url:,
                     api_url:,
                     environment_name:,
                     trustchain_url:,
                     verification_api_token:)
        @app_management_token = app_management_token
        @app_management_url = app_management_url
        @api_url = api_url
        @environment_name = environment_name
        @trustchain_url = trustchain_url
        @verification_api_token = verification_api_token
        @conn = Faraday.new(url: "#{@app_management_url}/v1/apps") do |conn|
          conn.request :authorization, 'Bearer', @app_management_token
          self.class.init_conn(conn)
        end
      end

      def create_app(name)
        response = @conn.post do |req|
          req.body = { name: name, environment_name: @environment_name }
          req.headers['Accept'] = 'application/json'
        end
        App.new(
          admin: self,
          id: response.body['app']['id'],
          secret: response.body['app']['secret']
        )
      end

      def delete_app(app_id)
        capp_id = Faraday::Utils.escape(app_id)
        @conn.delete(capp_id)
      end

      def app_update(app_id, app_update_options)
        capp_id = Faraday::Utils.escape(app_id)
        response = @conn.patch(capp_id) do |req|
          req.body = app_update_options.as_json
        end
        response.body
      end

      def get_email_verification_code(app_id, email)
        conn = Faraday.new(url: @api_url) do |f|
          self.class.init_conn(f)
        end
        response = conn.post('/verification/email/code',
                             { email: email, app_id: app_id, auth_token: @verification_api_token })
        response.body['verification_code']
      end

      def get_sms_verification_code(app_id, phone_number)
        conn = Faraday.new(url: @api_url) do |f|
          self.class.init_conn(f)
        end
        response = conn.post('/verification/sms/code',
                             { phone_number: phone_number, app_id: app_id, auth_token: @verification_api_token })
        response.body['verification_code']
      end
    end
  end
end
