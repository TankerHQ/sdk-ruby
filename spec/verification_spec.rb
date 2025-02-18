# frozen_string_literal: true

require_relative 'admin_helper'
require 'tanker/core'

require 'base64'
require 'json'
require 'net/http'

def get_id_token(oidc_config, user)
  uri = URI('https://www.googleapis.com/oauth2/v4/token')
  req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json; charset=utf-8')
  req.body = {
    grant_type: 'refresh_token',
    refresh_token: oidc_config.users[user][:refresh_token],
    client_id: oidc_config.client_id,
    client_secret: oidc_config.client_secret
  }.to_json
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  reply = JSON.parse http.request(req).body
  reply['id_token']
end

def extract_subject(id_token)
  jwt_body = id_token.split('.')[1]
  jbody = JSON.parse Base64.urlsafe_decode64(jwt_body)
  jbody['sub']
end

def create_paep_verification(passphrase)
  public_key = AppConfig.instance.enroll_passphrase_public_encryption_key
  paep = Tanker::Core.prehash_and_encrypt_password(passphrase, public_key)
  Tanker::PrehashedAndEncryptedPassphraseVerification.new paep
end

RSpec.describe "#{Tanker} Verification" do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', persistent_path: ':memory:', cache_path: ':memory:'

    @oidc_config = AppConfig.instance.oidc_config
    @martine_id_token = get_id_token(@oidc_config, :martine)
    @martine_subject = extract_subject(@martine_id_token)
    expect(@martine_id_token).to_not be_nil
  end

  before(:each) do
    @identity = @app.create_identity
  end

  after(:all) do
    @app&.delete
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
    martine_identity = @app.create_identity @oidc_config.users[:martine][:email]
    oidc_token = @martine_id_token

    @app.use_oidc_config(@oidc_config.client_id, @oidc_config.display_name, @oidc_config.issuer)

    tanker1 = Tanker::Core.new @options
    nonce = tanker1.create_oidc_nonce
    tanker1.start martine_identity
    tanker1.oidc_test_nonce = nonce
    tanker1.register_identity Tanker::OIDCIDTokenVerification.new(oidc_token)
    tanker1.free

    tanker2 = Tanker::Core.new @options
    nonce = tanker2.create_oidc_nonce
    tanker2.start martine_identity
    expect(tanker2.status).to eq(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
    tanker2.oidc_test_nonce = nonce
    tanker2.verify_identity Tanker::OIDCIDTokenVerification.new(oidc_token)
    expect(tanker2.status).to eq(Tanker::Status::READY)

    methods = tanker2.get_verification_methods
    tanker2.free

    expect(methods.length).to eq 1
    expect(methods[0]).to be_a Tanker::OIDCIDTokenVerificationMethod
    expect(methods[0].provider_display_name).to eq @oidc_config.display_name
  end

  it 'can use OIDC authorization code verification' do
    app_config = @app.use_oidc_config('tanker', 'fake-oidc', @oidc_config.fake_oidc_issuer_url)
    provider_id = app_config['app']['oidc_providers'][0]['id']
    subject_cookie = 'fake_oidc_subject=martine'

    tanker1 = Tanker::Core.new @options
    tanker1.start @identity

    verification1 = tanker1.authenticate_with_idp(provider_id, subject_cookie)
    verification2 = tanker1.authenticate_with_idp(provider_id, subject_cookie)

    tanker1.register_identity verification1
    tanker1.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    tanker2.verify_identity verification2
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free

    tanker3 = Tanker::Core.new @options
    tanker3.start @identity
    verification3 = tanker3.authenticate_with_idp(provider_id, 'fake_oidc_subject=not-martine')
    expect { tanker3.verify_identity verification3 }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidVerification)
      expect(e.code).to eq(Tanker::Error::INVALID_VERIFICATION)
    end
    tanker3.free
  end

  it 'can set OIDC authorization code verification' do
    app_config = @app.use_oidc_config('tanker', 'fake-oidc', @oidc_config.fake_oidc_issuer_url)
    provider_id = app_config['app']['oidc_providers'][0]['id']
    subject_cookie = 'fake_oidc_subject=martine'

    tanker1 = Tanker::Core.new @options
    tanker1.start @identity

    tanker1.register_identity Tanker::PassphraseVerification.new('**********')

    verification1 = tanker1.authenticate_with_idp(provider_id, subject_cookie)
    tanker1.set_verification_method verification1
    tanker1.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    verification2 = tanker2.authenticate_with_idp(provider_id, subject_cookie)
    tanker2.verify_identity verification2
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free

    tanker3 = Tanker::Core.new @options
    tanker3.start @identity
    verification3 = tanker3.authenticate_with_idp(provider_id, 'fake_oidc_subject=not-martine')
    expect { tanker3.verify_identity verification3 }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidVerification)
      expect(e.code).to eq(Tanker::Error::INVALID_VERIFICATION)
    end
    tanker3.free
  end

  describe 'preverified methods' do
    it 'fails to register with preverified email' do
      email = 'mono@chromat.ic'

      tanker = Tanker::Core.new @options
      tanker.start @identity

      expect { tanker.register_identity Tanker::PreverifiedEmailVerification.new(email) }.to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker.free
    end

    it 'fails to register with preverified phone number' do
      phone_number = '+33639982233'

      tanker = Tanker::Core.new @options
      tanker.start @identity

      expect { tanker.register_identity Tanker::PreverifiedPhoneNumberVerification.new(phone_number) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker.free
    end

    it 'fails to register with preverified oidc' do
      app_config = @app.use_oidc_config(@oidc_config.client_id, @oidc_config.display_name, @oidc_config.issuer)
      provider_id = app_config['app']['oidc_providers'][0]['id']

      tanker = Tanker::Core.new @options
      tanker.start @identity

      expect { tanker.register_identity Tanker::PreverifiedOIDCVerification.new('subject', provider_id) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker.free
    end

    it 'fails to register with a prehashed and encrypted passphrase' do
      tanker = Tanker::Core.new @options
      tanker.start @identity

      paep_verification = create_paep_verification('p@assword')

      expect { tanker.register_identity paep_verification }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker.free
    end

    it 'fails to verify with preverified email' do
      email = 'mono@chromat.ic'

      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker1.register_identity Tanker::EmailVerification.new(email, @app.get_email_verification_code(email))
      tanker1.free

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity

      expect { tanker2.verify_identity Tanker::PreverifiedEmailVerification.new(email) }.to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker2.free
    end

    it 'fails to verify with preverified phone number' do
      phone_number = '+33639982233'

      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker1.register_identity(
        Tanker::PhoneNumberVerification.new(phone_number, @app.get_sms_verification_code(phone_number))
      )
      tanker1.free

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity

      expect { tanker2.verify_identity Tanker::PreverifiedPhoneNumberVerification.new(phone_number) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker2.free
    end

    it 'fails to verify with preverified oidc' do
      app_config = @app.use_oidc_config(@oidc_config.client_id, @oidc_config.display_name, @oidc_config.issuer)
      provider_id = app_config['app']['oidc_providers'][0]['id']

      tanker1 = Tanker::Core.new @options
      nonce = tanker1.create_oidc_nonce
      tanker1.start @identity
      tanker1.oidc_test_nonce = nonce
      tanker1.register_identity Tanker::OIDCIDTokenVerification.new(@martine_id_token)
      tanker1.free

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity

      expect { tanker2.verify_identity Tanker::PreverifiedOIDCVerification.new(@martine_subject, provider_id) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker2.free
    end

    it 'fails to verify with a prehashed and encrypted passphrase' do
      passphrase = 'p@ssword'
      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker1.register_identity Tanker::PassphraseVerification.new(passphrase)
      tanker1.free

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity

      paep_verification = create_paep_verification(passphrase)

      expect { tanker2.verify_identity paep_verification }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker2.free
    end

    it 'sets verification method with preverified email' do
      email = 'mono@chromat.ic'

      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker1.register_identity Tanker::PassphraseVerification.new 'The truth does not exist'
      tanker1.set_verification_method Tanker::PreverifiedEmailVerification.new(email)
      methods = tanker1.get_verification_methods
      tanker1.free
      expect(methods).to eq [Tanker::PreverifiedEmailVerificationMethod.new(email),
                             Tanker::PassphraseVerificationMethod.new]

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity
      tanker2.verify_identity Tanker::EmailVerification.new(email, @app.get_email_verification_code(email))
      expect(tanker2.status).to eq(Tanker::Status::READY)
      methods = tanker2.get_verification_methods
      tanker2.free
      expect(methods).to eq [Tanker::EmailVerificationMethod.new(email), Tanker::PassphraseVerificationMethod.new]
    end

    it 'sets verification method with preverified phone number' do
      phone_number = '+33639982233'

      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker1.register_identity Tanker::PassphraseVerification.new 'Ruby is the best language'
      tanker1.set_verification_method Tanker::PreverifiedPhoneNumberVerification.new(phone_number)
      methods = tanker1.get_verification_methods
      tanker1.free
      expect(methods).to eq [Tanker::PreverifiedPhoneNumberVerificationMethod.new(phone_number),
                             Tanker::PassphraseVerificationMethod.new]

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity
      tanker2.verify_identity Tanker::PhoneNumberVerification.new(
        phone_number, @app.get_sms_verification_code(phone_number)
      )
      expect(tanker2.status).to eq(Tanker::Status::READY)
      methods = tanker2.get_verification_methods
      tanker2.free
      expect(methods).to eq [Tanker::PhoneNumberVerificationMethod.new(phone_number),
                             Tanker::PassphraseVerificationMethod.new]
    end

    it 'sets verification method with preverified oidc' do
      app_config = @app.use_oidc_config(@oidc_config.client_id, @oidc_config.display_name, @oidc_config.issuer)
      provider_id = app_config['app']['oidc_providers'][0]['id']
      display_name = app_config['app']['oidc_providers'][0]['display_name']

      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker1.register_identity Tanker::PassphraseVerification.new 'The truth does not exist'
      tanker1.set_verification_method Tanker::PreverifiedOIDCVerification.new(@martine_subject, provider_id)
      methods = tanker1.get_verification_methods
      tanker1.free
      expect(methods).to eq [Tanker::PassphraseVerificationMethod.new,
                             Tanker::OIDCIDTokenVerificationMethod.new(provider_id, display_name)]

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity
      nonce = tanker2.create_oidc_nonce
      tanker2.oidc_test_nonce = nonce
      tanker2.verify_identity Tanker::OIDCIDTokenVerification.new(@martine_id_token)
      expect(tanker2.status).to eq(Tanker::Status::READY)
      tanker2.free
    end

    it 'fails to set verification method to prehashed and encrypted passphrase' do
      passphrase = '42 is the Answer to the Ultimate Question of Life, the Universe, and Everything'
      tanker = Tanker::Core.new @options
      tanker.start @identity
      tanker.register_identity Tanker::PassphraseVerification.new passphrase

      paep_verification = create_paep_verification(passphrase)

      expect { tanker.set_verification_method paep_verification }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end

      tanker.free
    end
  end

  describe 'session tokens' do
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

    it 'can get a session token with set_verification_method with passphrase' do
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

    it 'can get a session token with set_verification_method with email' do
      tanker = Tanker::Core.new @options
      tanker.start @identity
      verif = Tanker::PassphraseVerification.new('Five hundred small segfaults')
      tanker.register_identity(verif)

      email = 'mono@chromat.ic'
      code = @app.get_email_verification_code email
      options = Tanker::VerificationOptions.new(with_session_token: true)
      verif2 = Tanker::EmailVerification.new(email, code)

      token = tanker.set_verification_method(verif2, options)
      tanker.free
      expect(token).to_not be_nil
    end

    it 'can get a session token with set_verification_method with phone number' do
      tanker = Tanker::Core.new @options
      tanker.start @identity
      verif = Tanker::PassphraseVerification.new('Five hundred small segfaults')
      tanker.register_identity(verif)

      phone_number = '+33639982233'
      code = @app.get_sms_verification_code phone_number
      options = Tanker::VerificationOptions.new(with_session_token: true)
      verif2 = Tanker::PhoneNumberVerification.new(phone_number, code)

      token = tanker.set_verification_method(verif2, options)
      tanker.free
      expect(token).to_not be_nil
    end
  end

  describe 'user enrollment' do
    before(:each) { @server = Tanker::Core.new @options }
    after(:each) { @server.free }

    it 'fails with passphrase' do
      expect { @server.enroll_user(@identity, [Tanker::PassphraseVerification.new('The Beauty In The Ordinary')]) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end
    end

    it 'fails with email' do
      email = 'mono@chromat.ic'
      verif = Tanker::EmailVerification.new(email, @app.get_email_verification_code(email))
      expect { @server.enroll_user(@identity, [verif]) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end
    end

    it 'fails with phone number' do
      phone_number = '+33639982233'
      verif = Tanker::PhoneNumberVerification.new(phone_number, @app.get_sms_verification_code(phone_number))
      expect { @server.enroll_user(@identity, [verif]) }
        .to(raise_error) do |e|
        expect(e).to be_a(Tanker::Error)
        expect(e).to be_a(Tanker::Error::InvalidArgument)
        expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
      end
    end

    it 'works with preverified methods' do
      app_config = @app.use_oidc_config(@oidc_config.client_id, @oidc_config.display_name, @oidc_config.issuer)
      provider_id = app_config['app']['oidc_providers'][0]['id']

      phone_number = '+33639982233'
      email = 'mono@chromat.ic'
      passphrase = 'Penny Lane is in my ears and in my eyes'
      @server.enroll_user(@identity, [
                            Tanker::PreverifiedPhoneNumberVerification.new(phone_number),
                            Tanker::PreverifiedEmailVerification.new(email),
                            Tanker::PreverifiedOIDCVerification.new(@martine_subject, provider_id),
                            create_paep_verification(passphrase)
                          ])

      tanker1 = Tanker::Core.new @options
      tanker1.start @identity
      tanker2 = Tanker::Core.new @options
      tanker2.start @identity
      tanker3 = Tanker::Core.new @options
      tanker3.start @identity
      tanker4 = Tanker::Core.new @options
      tanker4.start @identity

      expect(tanker1.status).to eq(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
      tanker1.verify_identity Tanker::EmailVerification.new(
        email, @app.get_email_verification_code(email)
      )
      expect(tanker1.status).to eq(Tanker::Status::READY)

      expect(tanker2.status).to eq(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
      tanker2.verify_identity Tanker::PhoneNumberVerification.new(
        phone_number, @app.get_sms_verification_code(phone_number)
      )
      expect(tanker2.status).to eq(Tanker::Status::READY)

      expect(tanker3.status).to eq(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
      nonce = tanker3.create_oidc_nonce
      tanker3.oidc_test_nonce = nonce
      tanker3.verify_identity Tanker::OIDCIDTokenVerification.new(@martine_id_token)
      expect(tanker3.status).to eq(Tanker::Status::READY)

      expect(tanker4.status).to eq(Tanker::Status::IDENTITY_VERIFICATION_NEEDED)
      tanker4.verify_identity Tanker::PassphraseVerification.new(passphrase)
      expect(tanker4.status).to eq(Tanker::Status::READY)

      tanker1.free
      tanker2.free
      tanker3.free
      tanker4.free
    end
  end

  describe 'e2e passphrase' do
    it 'can register an e2e passphrase' do
      passphrase = Tanker::E2ePassphraseVerification.new 'The Cost of Legacy'
      tanker = Tanker::Core.new @options
      tanker.start @identity
      tanker.register_identity passphrase
      methods = tanker.get_verification_methods
      tanker.free
      expect(methods).to eq [Tanker::E2ePassphraseVerificationMethod.new]

      tanker2 = Tanker::Core.new @options
      tanker2.start @identity
      tanker2.verify_identity passphrase
      expect(tanker2.status).to eq(Tanker::Status::READY)
      tanker2.free
    end
  end

  it 'can update an e2e passphrase' do
    old_passphrase = Tanker::E2ePassphraseVerification.new 'brady'
    new_passphrase = Tanker::E2ePassphraseVerification.new 'tachy'
    tanker = Tanker::Core.new @options
    tanker.start @identity
    tanker.register_identity old_passphrase
    tanker.set_verification_method new_passphrase
    tanker.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    expect { tanker2.verify_identity old_passphrase }
      .to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidVerification)
      expect(e.code).to eq(Tanker::Error::INVALID_VERIFICATION)
    end
    tanker2.verify_identity new_passphrase
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free
  end

  it 'can switch to an e2e passphrase' do
    old_passphrase = Tanker::PassphraseVerification.new 'brady'
    new_passphrase = Tanker::E2ePassphraseVerification.new 'tachy'
    tanker = Tanker::Core.new @options
    tanker.start @identity
    options = Tanker::VerificationOptions.new(allow_e2e_method_switch: true)
    tanker.register_identity old_passphrase
    tanker.set_verification_method(new_passphrase, options)
    tanker.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    expect { tanker2.verify_identity old_passphrase }
      .to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::PreconditionFailed)
      expect(e.code).to eq(Tanker::Error::PRECONDITION_FAILED)
    end
    tanker2.verify_identity new_passphrase
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free
  end

  it 'can switch from an e2e passphrase' do
    old_passphrase = Tanker::E2ePassphraseVerification.new 'brady'
    new_passphrase = Tanker::PassphraseVerification.new 'tachy'
    tanker = Tanker::Core.new @options
    tanker.start @identity
    options = Tanker::VerificationOptions.new(allow_e2e_method_switch: true)
    tanker.register_identity old_passphrase
    tanker.set_verification_method(new_passphrase, options)
    tanker.free

    tanker2 = Tanker::Core.new @options
    tanker2.start @identity
    expect { tanker2.verify_identity old_passphrase }
      .to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::PreconditionFailed)
      expect(e.code).to eq(Tanker::Error::PRECONDITION_FAILED)
    end
    tanker2.verify_identity new_passphrase
    expect(tanker2.status).to eq(Tanker::Status::READY)
    tanker2.free
  end

  it 'cannot switch to an e2e passphrase without allow_e2e_method_switch flag' do
    old_passphrase = Tanker::PassphraseVerification.new 'brady'
    new_passphrase = Tanker::E2ePassphraseVerification.new 'tachy'
    tanker = Tanker::Core.new @options
    tanker.start @identity
    tanker.register_identity old_passphrase
    expect { tanker.set_verification_method new_passphrase }
      .to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
    tanker.free
  end
end
