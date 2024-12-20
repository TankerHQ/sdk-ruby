# frozen_string_literal: true

require 'faraday/net_http_persistent'

require_relative 'admin_helper'
require 'tanker/core'
require 'tanker/encryption_options'
require 'tanker/identity'

RSpec.describe Tanker do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', persistent_path: ':memory:', cache_path: ':memory:'
    # Encryption format v10 overhead
    @simple_encryption_overhead = 49
    @simple_padded_encryption_overhead = @simple_encryption_overhead + 1
  end

  after(:all) do
    @app&.delete
  end

  it 'has a version number' do
    expect(Tanker::Core::VERSION).not_to be nil
  end

  it 'has a native version number' do
    expect(Tanker::Core.native_version).not_to be nil
  end

  it 'fails to create an invalid Tanker object' do
    options = Tanker::Core::Options.new app_id: 'bad app id', persistent_path: ':memory:', cache_path: ':memory:'
    expect { Tanker::Core.new options }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'can create a valid Tanker object' do
    tanker = Tanker::Core.new @options
    expect(tanker).to be_kind_of Tanker::Core
    tanker.free
  end

  it 'throws when using a Core after free' do
    tanker = Tanker::Core.new @options
    tanker.free
    # test a method with and without args
    expect { tanker.status }.to raise_error(RuntimeError)
    expect { tanker.start(@app.create_identity) }.to raise_error(RuntimeError)
  end

  it 'can start and stop a Tanker session' do
    tanker = Tanker::Core.new @options
    identity = @app.create_identity
    status = tanker.start(identity)
    expect(status).to be(Tanker::Status::IDENTITY_REGISTRATION_NEEDED)

    tanker.register_identity(Tanker::PassphraseVerification.new('pass'))
    expect(tanker.status).to be(Tanker::Status::READY)

    tanker.stop
    expect(tanker.status).to be(Tanker::Status::STOPPED)
    tanker.free
  end

  it 'can encrypt and decrypt back' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    plaintext = 'Ghostriding in a field, playing for the cows!'
    ciphertext = tanker.encrypt_utf8 plaintext

    decrypted = tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    tanker.free
  end

  it 'can encrypt and decrypt an empty message' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    plaintext = ''
    ciphertext = tanker.encrypt_utf8 plaintext

    decrypted = tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    tanker.free
  end

  it 'encrypts and decrypts with auto padding by default' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    plaintext = 'my clear data is clear!'
    length_with_padme = 24
    ciphertext = tanker.encrypt_utf8 plaintext

    expect(ciphertext.length - @simple_padded_encryption_overhead).to eq(length_with_padme)

    decrypted = tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    tanker.free
  end

  it 'can encrypt and decrypt with auto padding' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    plaintext = 'my clear data is clear!'
    length_with_padme = 24
    encryption_options = Tanker::EncryptionOptions.new(padding_step: Tanker::Padding::AUTO)
    ciphertext = tanker.encrypt_utf8 plaintext, encryption_options

    expect(ciphertext.length - @simple_padded_encryption_overhead).to eq(length_with_padme)

    decrypted = tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    tanker.free
  end

  it 'can encrypt and decrypt with no padding' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    plaintext = 'Ghostriding in a field, playing for the cows!'
    encryption_options = Tanker::EncryptionOptions.new(padding_step: Tanker::Padding::OFF)
    ciphertext = tanker.encrypt_utf8 plaintext, encryption_options

    expect(ciphertext.length - @simple_encryption_overhead).to eq(plaintext.length)

    decrypted = tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    tanker.free
  end

  it 'can encrypt and decrypt with padding set to a number' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    plaintext = 'Ghostriding in a field, playing for the cows!'
    step_value = 13
    encryption_options = Tanker::EncryptionOptions.new(padding_step: Tanker::Padding.step(step_value))
    ciphertext = tanker.encrypt_utf8 plaintext, encryption_options

    expect((ciphertext.length - @simple_padded_encryption_overhead) % step_value).to eq(0)

    decrypted = tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    tanker.free
  end

  it 'padding cannot be instantiated with a bad step' do
    expect do
      Tanker::Padding.step('2')
    end.to raise_error(TypeError, 'expected step to be an Integer >= 2, but got a String')
    expect do
      Tanker::Padding.step(nil)
    end.to raise_error(TypeError, 'expected step to be an Integer >= 2, but got a NilClass')
    expect do
      Tanker::Padding.step(2.42)
    end.to raise_error(TypeError, 'expected step to be an Integer >= 2, but got a Float')

    expect { Tanker::Padding.step(0) }.to raise_error(ArgumentError, 'expected step to be an Integer >= 2, but got 0')
    expect { Tanker::Padding.step(1) }.to raise_error(ArgumentError, 'expected step to be an Integer >= 2, but got 1')
    expect { Tanker::Padding.step(-1) }.to raise_error(ArgumentError, 'expected step to be an Integer >= 2, but got -1')
  end

  it 'padding cannot be instantiated without the step method' do
    expect { Tanker::Padding.new(42) }.to raise_error(NoMethodError)
  end

  it 'can encrypt, share, and decrypt between two users' do
    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_public_identity = Tanker::Identity.get_public_identity bob_identity
    bob.start_anonymous bob_identity

    plaintext = 'Ossie Ossie Ossie'
    ciphertext = alice.encrypt_utf8 plaintext
    res_id = alice.get_resource_id ciphertext

    alice.share [res_id], Tanker::SharingOptions.new(share_with_users: [bob_public_identity])

    decrypted = bob.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    alice.free
    bob.free
  end

  it 'can encrypt-and-share, then decrypt, between two users' do
    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_public_identity = Tanker::Identity.get_public_identity bob_identity
    bob.start_anonymous bob_identity

    plaintext = 'Oi Oi Oi!'
    encryption_options = Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity])
    ciphertext = alice.encrypt_utf8 plaintext, encryption_options

    decrypted = bob.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    alice.free
    bob.free
  end

  it 'can encrypt without sharing with self' do
    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_public_identity = Tanker::Identity.get_public_identity bob_identity
    bob.start_anonymous bob_identity

    plaintext = 'Oi Oi Oi!'
    encryption_options = Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity], share_with_self: false)
    ciphertext = alice.encrypt_utf8 plaintext, encryption_options

    expect { alice.decrypt_utf8 ciphertext }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end

    decrypted = bob.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    alice.free
    bob.free
  end

  it 'raises when passing nil element to share_with_users' do
    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity
    bob_identity = @app.create_identity
    plaintext = 'Oi Oi Oi!'
    encryption_options = Tanker::EncryptionOptions.new(share_with_users: [nil, bob_identity])
    expect { alice.encrypt_utf8 plaintext, encryption_options }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'fails to prehash_password the empty string' do
    expect { Tanker::Core.prehash_password '' }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'can prehash_password a test vector' do
    input = 'super secretive password'
    expected = 'UYNRgDLSClFWKsJ7dl9uPJjhpIoEzadksv/Mf44gSHI='

    expect(Tanker::Core.prehash_password(input)).to eq expected
  end

  it 'can prehash_password test vector 2' do
    input = 'test éå 한국어 😃'
    expected = 'Pkn/pjub2uwkBDpt2HUieWOXP5xLn0Zlen16ID4C7jI='

    expect(Tanker::Core.prehash_password(input)).to eq expected
  end

  it 'fails to prehash and encrypt password when password is an empty string' do
    password = ''
    public_key = 'XJTPOJqdKJLCGwimhANxqrtiC2BOTmJUjJG7l4s5UhY='
    expect { Tanker::Core.prehash_and_encrypt_password(password, public_key) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'fails to prehash and encrypt password when public key is an empty string' do
    password = 'Happy birthday ! 🥳'
    public_key = ''
    expect { Tanker::Core.prehash_and_encrypt_password(password, public_key) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'fails to prehash and encrypt password when public key is not a base64-encoded string' do
    password = 'Happy birthday ! 🥳'
    public_key = '🎂'
    expect { Tanker::Core.prehash_and_encrypt_password(password, public_key) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'fails to prehash and encrypt password when public key is invalid' do
    password = 'Happy birthday ! 🥳'
    public_key = 'fake'
    expect { Tanker::Core.prehash_and_encrypt_password(password, public_key) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'can prehash and encrypt password' do
    password = 'Happy birthday ! 🥳'
    public_key = 'XJTPOJqdKJLCGwimhANxqrtiC2BOTmJUjJG7l4s5UhY='
    paep = Tanker::Core.prehash_and_encrypt_password(password, public_key)
    expect(paep).to be_kind_of String
    expect(paep.length).to be > 0
  end

  it 'can share with a provisional user' do
    message = 'No plugin updates available'
    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity

    bob_email = 'bob@tanker.io'
    bob_provisional_identity = Tanker::Identity.create_provisional_identity(@app.id, 'email', bob_email)
    bob_public_identity = Tanker::Identity.get_public_identity bob_provisional_identity

    encrypted = alice.encrypt_utf8 message, Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity])
    alice.free

    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob.start_anonymous bob_identity

    attach_result = bob.attach_provisional_identity bob_provisional_identity
    expect(attach_result.status).to eq Tanker::Status::IDENTITY_VERIFICATION_NEEDED
    expect(attach_result.verification_method).to eq Tanker::EmailVerificationMethod.new bob_email

    verif_code = @app.get_email_verification_code bob_email
    bob.verify_provisional_identity(Tanker::EmailVerification.new(bob_email, verif_code))

    decrypted = bob.decrypt_utf8 encrypted
    expect(decrypted).to eq message
    bob.free
  end

  it 'can register and attach a provisional user with a single verification' do
    message = 'No plugin updates available'
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_email = 'bob@tanker.io'
    bob_provisional_identity = Tanker::Identity.create_provisional_identity(@app.id, 'email', bob_email)
    bob_public_identity = Tanker::Identity.get_public_identity bob_provisional_identity

    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity
    encrypted = alice.encrypt_utf8 message, Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity])
    alice.free

    bob.start bob_identity
    verif_code = @app.get_email_verification_code bob_email
    bob.register_identity(Tanker::EmailVerification.new(bob_email, verif_code))
    bob.attach_provisional_identity bob_provisional_identity

    decrypted = bob.decrypt_utf8 encrypted
    expect(decrypted).to eq message
    bob.free
  end

  it 'throws if attaching an already attached provisional identity' do
    bob_email = 'bob@tanker.io'
    bob_provisional_identity = Tanker::Identity.create_provisional_identity(@app.id, 'email', bob_email)

    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob.start_anonymous bob_identity

    attach_result = bob.attach_provisional_identity bob_provisional_identity
    expect(attach_result.status).to eq Tanker::Status::IDENTITY_VERIFICATION_NEEDED
    expect(attach_result.verification_method).to eq Tanker::EmailVerificationMethod.new bob_email

    verif_code = @app.get_email_verification_code bob_email
    bob.verify_provisional_identity(Tanker::EmailVerification.new(bob_email, verif_code))

    alice = Tanker::Core.new @options
    alice_identity = @app.create_identity
    alice.start_anonymous alice_identity

    attach_result = alice.attach_provisional_identity bob_provisional_identity
    expect(attach_result.status).to eq Tanker::Status::IDENTITY_VERIFICATION_NEEDED

    verif_code2 = @app.get_email_verification_code bob_email
    expect { alice.verify_provisional_identity(Tanker::EmailVerification.new(bob_email, verif_code2)) }
      .to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::IdentityAlreadyAttached)
      expect(e.code).to eq(Tanker::Error::IDENTITY_ALREADY_ATTACHED)
    end

    alice.free
    bob.free
  end

  it 'can create a valid Tanker object and not free it' do
    Tanker::Core.new @options
    # We forget the free, the finalizer will handle it, probably when the ruby
    # process terminates. Then there is a potential deadlock if Tanker calls
    # back ruby because the ffi thread that runs the callbacks will already have
    # stopped. This test will make sure we don't have such a deadlock.
  end

  # Note that these are the tests we do in other bindings, but since Ruby
  # doesn't have an asynchronous HTTP library, the whole operation is done
  # asynchronously (in a thread pool). This means that even the error in this
  # test will be asynchronous. There is no way to trigger a sychronous error
  # with the current code. The test won't hurt, so I kept it.
  it 'reports synchronous http errors correctly' do
    # This error should be reported before any network call
    bad_options = Tanker::Core::Options.new app_id: @app.id, url: 'this is not an url at all',
                                            sdk_type: 'sdk-ruby-test',
                                            persistent_path: ':memory:', cache_path: ':memory:'
    tanker = Tanker::Core.new bad_options
    identity = @app.create_identity
    expect { tanker.start(identity) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error::NetworkError)
      expect(e.code).to eq(Tanker::Error::NETWORK_ERROR)
    end
  end

  it 'reports asynchronous http errors correctly' do
    # This error requires an (async) DNS lookup
    bad_options = Tanker::Core::Options.new app_id: @app.id, url: 'https://this-is-not-a-tanker-server.com',
                                            sdk_type: 'sdk-ruby-test',
                                            persistent_path: ':memory:', cache_path: ':memory:'
    tanker = Tanker::Core.new bad_options
    identity = @app.create_identity
    expect { tanker.start(identity) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error::NetworkError)
      expect(e.code).to eq(Tanker::Error::NETWORK_ERROR)
    end
  end

  it 'can override the faraday adapter' do
    options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                        sdk_type: 'sdk-ruby-test',
                                        persistent_path: ':memory:', cache_path: ':memory:',
                                        faraday_adapter: :net_http_persistent
    tanker = Tanker::Core.new options
    identity = @app.create_identity
    status = tanker.start(identity)
    expect(status).to be(Tanker::Status::IDENTITY_REGISTRATION_NEEDED)

    tanker.register_identity(Tanker::PassphraseVerification.new('pass'))
    expect(tanker.status).to be(Tanker::Status::READY)

    tanker.stop
    expect(tanker.status).to be(Tanker::Status::STOPPED)
    tanker.free
  end

  it 'can stop tanker while a call is in flight' do
    tanker = Tanker::Core.new @options
    identity = @app.create_identity
    tanker.start(identity)
    tanker.register_identity(Tanker::PassphraseVerification.new('pass'))

    ready = false

    # Start an encrypt asynchronously and stop tanker
    thread = Thread.new do
      ready = true
      tanker.encrypt_utf8 'plain text'
    rescue StandardError => e
      expect(e).to be_a(Tanker::Error::OperationCanceled)
      expect(e.code).to eq(Tanker::Error::OPERATION_CANCELED)
    end

    until ready
    end

    tanker.stop
    thread.join
  end
end
