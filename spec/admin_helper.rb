# frozen_string_literal: true

require 'singleton'
require 'securerandom'
require 'tanker/admin'
require 'tanker/identity'

class OIDCConfig
  attr_reader :client_id, :client_secret, :provider, :users

  def initialize(client_id, client_secret, provider, users)
    @client_id = client_id
    @client_secret = client_secret
    @provider = provider
    @users = users
  end
end

# Note that the AppConfig is a Singleton and not a module, because reading the env vars can fail and raise exceptions
# We want the config to be read on-demand, lazily. This avoids unecessarily raising exceptions at import time.
class AppConfig
  include Singleton

  attr_reader :id_token
  attr_reader :api_url
  attr_reader :admin_url
  attr_reader :oidc_config
  attr_reader :trustchain_url

  def self.safe_get_env(var)
    val = ENV[var]
    return val unless val.nil?

    raise "Env var #{var} is not defined, failed to get the Tanker test configuration!"
  end

  def initialize
    @id_token = AppConfig.safe_get_env 'TANKER_ID_TOKEN'
    @trustchain_url = AppConfig.safe_get_env 'TANKER_TRUSTCHAIND_URL'
    @api_url = AppConfig.safe_get_env 'TANKER_APPD_URL'
    @admin_url = AppConfig.safe_get_env 'TANKER_ADMIND_URL'

    client_id = AppConfig.safe_get_env 'TANKER_OIDC_CLIENT_ID'
    client_secret = AppConfig.safe_get_env 'TANKER_OIDC_CLIENT_SECRET'
    provider = AppConfig.safe_get_env 'TANKER_OIDC_PROVIDER'
    users = {
      martine: {
        email: AppConfig.safe_get_env('TANKER_OIDC_MARTINE_EMAIL'),
        refresh_token: AppConfig.safe_get_env('TANKER_OIDC_MARTINE_REFRESH_TOKEN')
      },
      kevin: {
        email: AppConfig.safe_get_env('TANKER_OIDC_KEVIN_EMAIL'),
        refresh_token: AppConfig.safe_get_env('TANKER_OIDC_KEVIN_REFRESH_TOKEN')
      }
    }
    @oidc_config = OIDCConfig.new client_id, client_secret, provider, users
  end
end

module Tanker
  class App
    attr_reader :admin

    def initialize
      config = AppConfig.instance
      @admin = Admin.new(
        admin_url: config.admin_url,
        id_token: config.id_token,
        api_url: config.api_url,
        trustchain_url: config.trustchain_url
      )
      @admin.connect
      @app = @admin.create_app('ruby-test')
    end

    def self.use_test_log_handler
      Tanker::Core.set_log_handler do |record|
        if record.level >= Tanker::Core::LogRecord::LEVEL_WARNING
          puts "[#{record.category}##{record.level}] #{record.file}:#{record.line} #{record.message}"
        end
      end
    end

    def url
      AppConfig.instance.api_url
    end

    def id
      @app.id
    end

    def get_email_verification_code(email)
      @app.get_email_verification_code(email)
    end

    def get_sms_verification_code(phone_number)
      @app.get_sms_verification_code(phone_number)
    end

    def delete
      @admin.delete_app @app.id
    end

    def create_identity(user_id = SecureRandom.uuid)
      Identity.create_identity @app.id, @app.private_key, user_id
    end

    def use_oidc_config(client_id, client_provider)
      app_options = Admin::AppUpdateOptions.new(oidc_client_id: client_id,
                                                oidc_client_provider: client_provider)
      @admin.app_update(@app.id, app_options)
    end

    def toggle_session_certificates(enable)
      app_options = Admin::AppUpdateOptions.new(session_certificates: enable)
      @admin.app_update(@app.id, app_options)
    end

    def toggle_preverified_verification(enable)
      app_options = Admin::AppUpdateOptions.new(preverified_verification: enable)
      @admin.app_update(@app.id, app_options)
    end
  end
end

module Tanker
  class Core
    def start_anonymous(identity)
      start_status = start identity
      case start_status
      when Status::READY
        :start_status
      when Status::IDENTITY_REGISTRATION_NEEDED
        verif = VerificationKeyVerification.new generate_verification_key
        register_identity(verif)
        status
      when Status::IDENTITY_VERIFICATION_NEEDED
        raise ArgumentError, 'This identity has already been used, create a new one'
      else
        raise "Unexpected status #{start_status}, cannot start anonymous Tanker session"
      end
    end
  end
end
