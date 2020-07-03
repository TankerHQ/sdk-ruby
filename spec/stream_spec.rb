# frozen_string_literal: true

require_relative 'admin_helper'
require 'tanker/core'
require 'tanker/identity'

RSpec.describe "#{Tanker} streams" do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url, writable_path: ':memory:'

    @tanker = Tanker::Core.new @options
    @tanker.start_anonymous @app.create_identity
  end

  after(:all) do
    @tanker.stop

    @app.delete
  end

  it 'can encrypt a stream and decrypt back' do
    plaintext = 'la ram c\'est du cpu!'
    in_stream = StringIO.new(plaintext)
    out_stream = @tanker.encrypt_stream in_stream
    ciphertext = out_stream.read
    out_stream.close

    decrypted = @tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)
  end

  it 'can encrypt and decrypt a stream' do
    plaintext = 'Memory *is* RAM!'

    in_stream = StringIO.new(plaintext)
    encrypted_stream = @tanker.encrypt_stream in_stream
    decrypted_stream = @tanker.decrypt_stream encrypted_stream

    decrypted = decrypted_stream.read
    decrypted_stream.close

    expect(decrypted).to eq(plaintext)
    encrypted_stream.close
  end

  it 'can encrypt and share a stream' do
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_public_identity = Tanker::Identity.get_public_identity bob_identity
    bob.start_anonymous bob_identity

    plaintext = 'Memory *is* RAM!'

    in_stream = StringIO.new(plaintext)
    encrypted_stream = @tanker.encrypt_stream(
      in_stream,
      Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity])
    )
    ciphertext = encrypted_stream.read
    encrypted_stream.close

    decrypted = bob.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)
  end

  it 'can encrypt and not share a stream with self' do
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_public_identity = Tanker::Identity.get_public_identity bob_identity
    bob.start_anonymous bob_identity

    plaintext = 'Memory *is* RAM!'

    in_stream = StringIO.new(plaintext)
    encrypted_stream = @tanker.encrypt_stream(
      in_stream,
      Tanker::EncryptionOptions.new(share_with_users: [bob_public_identity], share_with_self: false)
    )
    ciphertext = encrypted_stream.read
    encrypted_stream.close

    expect { @tanker.decrypt_utf8 ciphertext }.to raise_error(Tanker::Error) do |e|
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end

    decrypted = bob.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)
  end

  it 'throws the same errors as the inner stream' do
    class MyError < RuntimeError; end

    module ErrorOnRead
      def read(*)
        raise MyError
      end
    end

    plaintext = 'cat /dev/zero'
    in_stream = StringIO.new(plaintext)
    in_stream.extend ErrorOnRead

    encrypted_stream = @tanker.encrypt_stream in_stream
    expect { encrypted_stream.read }.to raise_error(MyError)
    encrypted_stream.close
  end

  it 'throws a decryption error if the buffer is corrupt' do
    # big buffer to force stream encryption
    plaintext = 'la ram c\'est du cpu!' * 100_000
    ciphertext = @tanker.encrypt_utf8 plaintext

    ciphertext += 'lol' # corrupt the buffer

    encrypted_stream = StringIO.new(ciphertext)
    decrypted_stream = @tanker.decrypt_stream encrypted_stream

    expect { decrypted_stream.read } .to raise_error(Tanker::Error) do |e|
      expect(e.code).to eq(Tanker::Error::DECRYPTION_FAILED)
    end
    decrypted_stream.close
  end

  it 'can encrypt and decrypt a very long stream' do
    plaintext_10mb = 'This string is 32 bytes long...?' * 32 * 1024 * 10

    in_stream = StringIO.new(plaintext_10mb)

    encrypted_stream = @tanker.encrypt_stream in_stream
    decrypted_stream = @tanker.decrypt_stream encrypted_stream

    decrypted = decrypted_stream.read
    decrypted_stream.close
    expect(decrypted).to eq(plaintext_10mb)
  end

  it 'can close a stream half-way through' do
    plaintext_10mb = 'This string is 32 bytes long...?' * 32 * 1024 * 10

    in_stream = StringIO.new(plaintext_10mb)

    encrypted_stream = @tanker.encrypt_stream in_stream
    encrypted_stream.read(2 * 1024 * 1024)
    encrypted_stream.close
  end
end
