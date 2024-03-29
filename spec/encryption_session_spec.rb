# frozen_string_literal: true

require_relative 'admin_helper'
require 'tanker/core'
require 'tanker/identity'

RSpec.describe "#{Tanker} Encryption Sessions" do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', persistent_path: ':memory:', cache_path: ':memory:'
    @encryption_session_overhead = 57
    @encryption_session_padded_overhead = @encryption_session_overhead + 1
  end

  before(:each) do
    @alice_ident = @app.create_identity
    @alice_pub_ident = Tanker::Identity.get_public_identity @alice_ident
    @alice = Tanker::Core.new @options
    @alice.start_anonymous @alice_ident

    @bob_ident = @app.create_identity
    @bob_pub_ident = Tanker::Identity.get_public_identity @bob_ident
    @bob = Tanker::Core.new @options
    @bob.start_anonymous @bob_ident
  end

  after(:each) do
    @alice&.free
    @bob&.free
  end

  after(:all) do
    @app&.delete
  end

  it 'can open and close native encryption sessions' do
    sess = @alice.create_encryption_session
    expect(sess).to be_kind_of(Tanker::Core::EncryptionSession)
  end

  it 'can share with self using an encryption session' do
    plaintext = 'La Comédie Humaine'
    sess = @alice.create_encryption_session

    encrypted = sess.encrypt_utf8 plaintext
    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'can encrypt a stream with an encryption session' do
    plaintext = 'La Comédie Humaine'
    sess = @alice.create_encryption_session

    in_stream = StringIO.new plaintext
    encrypted_stream = sess.encrypt_stream in_stream
    encrypted = encrypted_stream.read
    encrypted_stream.close
    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'can share with user using an encryption session' do
    plaintext = 'La Pléiade'
    sess = @alice.create_encryption_session Tanker::EncryptionOptions.new(share_with_users: [@bob_pub_ident])

    encrypted = sess.encrypt_utf8 plaintext
    expect(@bob.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'raises when passing nil element to share_with_users' do
    result = expect do
      @alice.create_encryption_session Tanker::EncryptionOptions.new(share_with_users: [@bob_pub_ident,
                                                                                        nil])
    end
    result.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'raises when passing nil element to share_with_groups' do
    group_id = @alice.create_group [@bob_pub_ident]
    result = expect do
      @alice.create_encryption_session Tanker::EncryptionOptions.new(share_with_groups: [group_id,
                                                                                         nil])
    end
    result.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'can use an encryption session without sharing with self' do
    plaintext = 'La Pléiade'
    sess = @alice.create_encryption_session(
      Tanker::EncryptionOptions.new(share_with_users: [@bob_pub_ident], share_with_self: false)
    )

    encrypted = sess.encrypt_utf8 plaintext

    expect { @alice.decrypt_utf8 encrypted }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end

    expect(@bob.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'ensures resource IDs of the session and ciphertext match' do
    sess = @alice.create_encryption_session
    encrypted = sess.encrypt_utf8 'Les Rougon-Macquart'
    expect(@alice.get_resource_id(encrypted)).to eq(sess.resource_id)
  end

  it 'ensures ciphertexts from different sessions have different resource IDs' do
    sess1 = @alice.create_encryption_session
    sess2 = @alice.create_encryption_session
    encrypted1 = sess1.encrypt_utf8 'La Fontaine — Fables'
    encrypted2 = sess2.encrypt_utf8 'Monmoulin — Lettres'
    expect(@alice.get_resource_id(encrypted1)).to_not eq(@alice.get_resource_id(encrypted2))
  end

  it 'ensures different sessions encrypt with different keys' do
    sess_shared = @alice.create_encryption_session Tanker::EncryptionOptions.new(share_with_users: [@bob_pub_ident])
    sess_private = @alice.create_encryption_session

    plaintext = 'Les Crimes Célèbres'
    cipher_shared = sess_shared.encrypt_utf8 plaintext
    cipher_private = sess_private.encrypt_utf8 plaintext

    expect(@bob.decrypt_utf8(cipher_shared)).to eq(plaintext)
    expect { @bob.decrypt_utf8(cipher_private) }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end
  end

  it 'encrypts with padding auto by default' do
    plaintext = 'my clear data is clear!'
    length_with_padme = 24
    sess = @alice.create_encryption_session

    encrypted = sess.encrypt_utf8 plaintext

    expect(encrypted.length - @encryption_session_padded_overhead).to eq(length_with_padme)
    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'encrypts with auto padding' do
    plaintext = 'my clear data is clear!'
    length_with_padme = 24
    encryption_options = Tanker::EncryptionOptions.new(padding_step: Tanker::Padding::AUTO)
    sess = @alice.create_encryption_session encryption_options
    encrypted = sess.encrypt_utf8 plaintext

    expect(encrypted.length - @encryption_session_padded_overhead).to eq(length_with_padme)
    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'encrypts with no padding' do
    plaintext = 'L\'Assommoir'
    encryption_options = Tanker::EncryptionOptions.new(padding_step: Tanker::Padding::OFF)
    sess = @alice.create_encryption_session encryption_options
    encrypted = sess.encrypt_utf8 plaintext

    expect(encrypted.length - @encryption_session_overhead).to eq(plaintext.length)
    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end

  it 'encrypts with a padding step' do
    plaintext = 'Au Bonheur des Dames'
    step_value = 13
    options = Tanker::EncryptionOptions.new(padding_step: Tanker::Padding.step(step_value))
    sess = @alice.create_encryption_session options
    encrypted = sess.encrypt_utf8 plaintext

    expect((encrypted.length - @encryption_session_padded_overhead) % step_value).to eq 0
    expect(@alice.decrypt_utf8(encrypted)).to eq(plaintext)
  end
end
