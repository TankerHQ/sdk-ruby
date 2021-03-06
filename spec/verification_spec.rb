# frozen_string_literal: true

require_relative 'admin_helper'
require 'tanker/core'

RSpec.describe "#{Tanker} Verification" do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', writable_path: ':memory:'
  end

  before(:each) do
    @identity = @app.create_identity
  end

  after(:all) do
    @app.delete
  end

  it 'Can validate a new device using a verification key' do
    tanker1 = Tanker::Core.new @options
    expect(tanker1.start(@identity)).to be(Tanker::Status::IDENTITY_REGISTRATION_NEEDED)

    verif_key = tanker1.generate_verification_key
    verif_key_verification = Tanker::VerificationKeyVerification.new verif_key
    tanker1.register_identity verif_key_verification
    expect(tanker1.status).to be(Tanker::Status::READY)
    tanker1.free

    tanker2 = Tanker::Core.new @options
    expect(tanker2.start(@identity)).to be(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
    tanker2.verify_identity verif_key_verification
    expect(tanker2.status).to be(Tanker::Status::READY)
    tanker2.free
  end

  it 'Can setup and use an verification passphrase' do
    pass = 'The Beauty In The Ordinary'
    pass_verif = Tanker::PassphraseVerification.new pass

    tanker1 = Tanker::Core.new @options
    tanker1.start @identity
    tanker1.register_identity(pass_verif)
    tanker1.free

    tanker2 = Tanker::Core.new @options
    expect(tanker2.start(@identity)).to be(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
    tanker2.verify_identity pass_verif
    expect(tanker2.status).to be(Tanker::Status::READY)
    tanker2.free
  end

  it 'Can update an verification passphrase' do
    first_verif = Tanker::PassphraseVerification.new '384633km'
    second_verif = Tanker::PassphraseVerification.new 'beaming ahead'

    tanker1 = Tanker::Core.new @options
    tanker1.start @identity
    tanker1.register_identity first_verif
    tanker1.set_verification_method second_verif
    tanker1.free

    tanker2 = Tanker::Core.new @options
    expect(tanker2.start(@identity)).to be(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
    tanker2.verify_identity second_verif
    expect(tanker2.status).to be(Tanker::Status::READY)
    tanker2.free
  end

  it 'can check that the password verification method is set-up' do
    tanker = Tanker::Core.new @options
    tanker.start @identity
    tanker.register_identity Tanker::PassphraseVerification.new 'The Cost of Legacy'
    methods = tanker.get_verification_methods
    tanker.free
    expect(methods).to eq [Tanker::PassphraseVerificationMethod.new]
  end

  it 'can check that the email verification method is set-up' do
    email = 'mono@chromat.ic'
    code = @app.get_email_verification_code email

    tanker = Tanker::Core.new @options
    tanker.start @identity
    tanker.register_identity Tanker::EmailVerification.new(email, code)
    methods = tanker.get_verification_methods
    tanker.free
    expect(methods).to eq [Tanker::EmailVerificationMethod.new(email)]
  end

  it 'can check that the SMS verification method is set-up' do
    phone_number = '+33639982233'
    code = @app.get_sms_verification_code phone_number

    tanker = Tanker::Core.new @options
    tanker.start @identity
    tanker.register_identity Tanker::PhoneNumberVerification.new(phone_number, code)
    methods = tanker.get_verification_methods
    tanker.free
    expect(methods).to eq [Tanker::PhoneNumberVerificationMethod.new(phone_number)]
  end

  it 'can get the list of verification methods that have been set-up' do
    email = 'selena@strand.ed'
    code = @app.get_email_verification_code email

    tanker = Tanker::Core.new @options
    tanker.start @identity
    tanker.register_identity Tanker::PassphraseVerification.new 'Coolest Shades Ever'
    tanker.set_verification_method Tanker::EmailVerification.new(email, code)
    methods = tanker.get_verification_methods
    tanker.free

    expected_methods = [Tanker::EmailVerificationMethod.new(email), Tanker::PassphraseVerificationMethod.new]
    expect(methods.sort_by { |e| e.class.name }).to eq expected_methods
  end

  it 'can unlock with an email verification code' do
    email = 'mono@chromat.ic'

    tanker1 = Tanker::Core.new @options
    tanker1.start @identity
    tanker1.register_identity Tanker::EmailVerification.new(email, @app.get_email_verification_code(email))
    tanker1.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    tanker2.verify_identity Tanker::EmailVerification.new(email, @app.get_email_verification_code(email))
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free
  end

  it 'can unlock with an SMS verification code' do
    phone_number = '+33639982233'

    tanker1 = Tanker::Core.new @options
    tanker1.start @identity
    tanker1.register_identity Tanker::PhoneNumberVerification.new(phone_number,
                                                                  @app.get_sms_verification_code(phone_number))
    tanker1.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    tanker2.verify_identity Tanker::PhoneNumberVerification.new(phone_number,
                                                                @app.get_sms_verification_code(phone_number))
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free
  end

  it 'can use OIDC ID Tokens as verification' do
    require 'net/http'
    require 'json'

    oidc_config = AppConfig.instance.oidc_config
    martine_config = oidc_config.users[:martine]
    martine_identity = @app.create_identity martine_config[:email]

    @app.use_oidc_config(oidc_config.client_id, oidc_config.provider)

    uri = URI('https://www.googleapis.com/oauth2/v4/token')
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json; charset=utf-8')
    req.body = {
      grant_type: 'refresh_token',
      refresh_token: martine_config[:refresh_token],
      client_id: oidc_config.client_id,
      client_secret: oidc_config.client_secret
    }.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    reply = JSON.parse http.request(req).body
    oidc_token = reply['id_token']
    expect(oidc_token).to_not be_nil

    tanker1 = Tanker::Core.new @options
    tanker1.start martine_identity
    tanker1.register_identity Tanker::OIDCIDTokenVerification.new(oidc_token)
    tanker1.free

    tanker2 = Tanker::Core.new @options
    tanker2.start martine_identity
    expect(tanker2.status).to eq(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
    tanker2.verify_identity Tanker::OIDCIDTokenVerification.new(oidc_token)
    expect(tanker2.status).to eq(Tanker::Status::READY)

    methods = tanker2.get_verification_methods
    tanker2.free
    expect(methods).to eq [Tanker::OIDCIDTokenVerificationMethod.new]
  end

  describe 'session tokens' do
    before(:all) { @app.toggle_session_certificates true }
    after(:all) { @app.toggle_session_certificates false }

    it 'can get a session token with register_identity' do
      tanker = Tanker::Core.new @options
      tanker.start @identity
      options = Tanker::VerificationOptions.new(with_session_token: true)
      verif = Tanker::PassphraseVerification.new('Five hundred small segfaults')
      token = tanker.register_identity(verif, options)
      tanker.free
      expect(token).to_not be_nil
    end

    it 'can get a session token with verify_identity' do
      tanker = Tanker::Core.new @options
      tanker.start @identity
      options = Tanker::VerificationOptions.new(with_session_token: true)
      verif = Tanker::PassphraseVerification.new('Five hundred small segfaults')
      tanker.register_identity(verif)
      token = tanker.verify_identity(verif, options)
      tanker.free
      expect(token).to_not be_nil
    end

    it 'can get a session token with set_verification_method' do
      tanker = Tanker::Core.new @options
      tanker.start @identity
      options = Tanker::VerificationOptions.new(with_session_token: true)
      verif = Tanker::PassphraseVerification.new('Five hundred small segfaults')
      verif2 = Tanker::PassphraseVerification.new('One dime')
      tanker.register_identity(verif)
      token = tanker.set_verification_method(verif2, options)
      tanker.free
      expect(token).to_not be_nil
    end
  end
end
