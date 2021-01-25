# frozen_string_literal: true

require_relative 'admin_helper'
require 'tanker/core'
require 'tanker/identity'

RSpec.describe Tanker do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', writable_path: ':memory:'
  end

  after(:all) do
    @app.delete
  end

  it 'has a version number' do
    expect(Tanker::Core::VERSION).not_to be nil
  end

  it 'has a native version number' do
    expect(Tanker::Core.native_version).not_to be nil
  end

  it 'fails to create an invalid Tanker object' do
    options = Tanker::Core::Options.new app_id: 'bad app id', writable_path: ':memory:'
    expect { Tanker::Core.new options }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'can create a valid Tanker object' do
    tanker = Tanker::Core.new @options
    expect(tanker).to be_kind_of Tanker::Core
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

  it 'can self-revoke' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    got_revoked_event = false
    tanker.connect_device_revoked_handler do
      # Tanker is already stopped, but let's call it anyway just to check it
      # doesn't deadlock.
      tanker.free
      got_revoked_event = true
    end

    tanker.revoke_device tanker.device_id
    expect { tanker.encrypt_utf8 'What could possibly go wrong?' }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::DeviceRevoked)
      expect(e.code).to eq(Tanker::Error::DEVICE_REVOKED)
    end
    start = Time.now
    until got_revoked_event
      raise "timeout: didn't get revoked event" if Time.now - start > 2

      sleep 0.1
    end
  end

  it 'has a correct device list' do
    tanker = Tanker::Core.new @options
    tanker.start_anonymous @app.create_identity

    devices = tanker.device_list
    expect(devices.length).to be 1
    expect(devices[0].revoked?).to be false
    expect(devices[0].device_id).to eq tanker.device_id

    tanker.free
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

  it 'can share with a provisional user' do
    message = 'No plugin updates available'
    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity

    bob_email = 'bob@tanker.io'
    bob_provisional_identity = Tanker::Identity.create_provisional_identity(@app.id, bob_email)
    bob_public_identity = Tanker::Identity.get_public_identity bob_provisional_identity

    encrypted = alice.encrypt_utf8 message, Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity])
    alice.free

    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob.start_anonymous bob_identity

    attach_result = bob.attach_provisional_identity bob_provisional_identity
    expect(attach_result.status).to eq Tanker::Status::IDENTITY_VERIFICATION_NEEDED
    expect(attach_result.verification_method).to eq Tanker::EmailVerificationMethod.new bob_email

    verif_code = @app.get_verification_code bob_email
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
    bob_provisional_identity = Tanker::Identity.create_provisional_identity(@app.id, bob_email)
    bob_public_identity = Tanker::Identity.get_public_identity bob_provisional_identity

    alice = Tanker::Core.new @options
    alice.start_anonymous @app.create_identity
    encrypted = alice.encrypt_utf8 message, Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity])
    alice.free

    bob.start bob_identity
    verif_code = @app.get_verification_code bob_email
    bob.register_identity(Tanker::EmailVerification.new(bob_email, verif_code))
    bob.attach_provisional_identity bob_provisional_identity

    decrypted = bob.decrypt_utf8 encrypted
    expect(decrypted).to eq message
    bob.free
  end
end
