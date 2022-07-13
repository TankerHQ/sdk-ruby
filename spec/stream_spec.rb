# frozen_string_literal: true

require 'stringio'
require_relative 'admin_helper'
require 'tanker/core'
require 'tanker/identity'

def without_warnings
  old_verbose = $VERBOSE
  $VERBOSE = nil
  yield
ensure
  $VERBOSE = old_verbose
end

def with_default_encoding(encoding)
  old_internal_encoding = nil
  old_external_encoding = nil
  # Changing default encodings triggers a warning, but we need it for tests
  without_warnings do
    old_internal_encoding = Encoding.default_internal
    old_external_encoding = Encoding.default_external
    Encoding.default_internal = encoding
    Encoding.default_external = encoding
  end
  yield
ensure
  without_warnings do
    Encoding.default_internal = old_internal_encoding
    Encoding.default_external = old_external_encoding
  end
end

class BrokenStringIO < StringIO
  class Error < RuntimeError; end

  def read(*)
    raise Error
  end
end

RSpec.describe "#{Tanker} streams" do
  before(:all) do
    Tanker::App.use_test_log_handler
    @app = Tanker::App.new
    @options = Tanker::Core::Options.new app_id: @app.id, url: @app.url,
                                         sdk_type: 'sdk-ruby-test', persistent_path: ':memory:', cache_path: ':memory:'

    @tanker = Tanker::Core.new @options
    @tanker.start_anonymous @app.create_identity
  end

  after(:all) do
    @tanker&.free

    @app&.delete
  end

  it 'can encrypt a stream and decrypt back' do
    plaintext = 'la ram c\'est du cpu!'
    in_stream = StringIO.new(plaintext)
    out_stream = @tanker.encrypt_stream in_stream
    ciphertext = out_stream.read
    out_stream.close

    expect(ciphertext.encoding).to eq(Encoding::ASCII_8BIT)
    decrypted = @tanker.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)
  end

  it 'can encrypt a stream and decrypt back with UTF-8 default internal encoding' do
    with_default_encoding(Encoding::UTF_8) do
      plaintext = 'la ram c\'est du cpu!'
      in_stream = StringIO.new(plaintext)
      out_stream = @tanker.encrypt_stream in_stream
      ciphertext = out_stream.read
      out_stream.close

      expect(ciphertext.encoding).to eq(Encoding::ASCII_8BIT)
      decrypted = @tanker.decrypt_utf8 ciphertext
      expect(decrypted).to eq(plaintext)
    end
  end

  it 'can encrypt a stream and decrypt back with ASCII-8BIT default external encoding' do
    with_default_encoding(Encoding::ASCII_8BIT) do
      plaintext = 'la ram c\'est du cpu!'
      in_stream = StringIO.new(plaintext)
      out_stream = @tanker.encrypt_stream in_stream
      ciphertext = out_stream.read
      out_stream.close

      expect(ciphertext.encoding).to eq(Encoding::ASCII_8BIT)
      decrypted = @tanker.decrypt_utf8 ciphertext
      expect(decrypted).to eq(plaintext)
    end
  end

  it 'can encrypt and decrypt a stream' do
    plaintext = 'Memory *is* RAM!'

    in_stream = StringIO.new(plaintext)
    encrypted_stream = @tanker.encrypt_stream in_stream
    decrypted_stream = @tanker.decrypt_stream encrypted_stream

    decrypted = decrypted_stream.read
    decrypted_stream.close

    expect(decrypted.encoding).to eq(Encoding::ASCII_8BIT)
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

    bob.free
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

    expect { @tanker.decrypt_utf8 ciphertext }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end

    decrypted = bob.decrypt_utf8 ciphertext
    expect(decrypted).to eq(plaintext)

    bob.free
  end

  it 'raises when passing nil element to share_with_users' do
    alice_identity = @app.create_identity
    alice_public_identity = Tanker::Identity.get_public_identity alice_identity
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob.start_anonymous bob_identity

    plaintext = 'Memory *is* RAM!'
    in_stream = StringIO.new(plaintext)

    result = expect do
      @tanker.encrypt_stream(in_stream,
                             Tanker::EncryptionOptions.new(share_with_users: [alice_public_identity, nil]))
    end
    result.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end

    bob.free
  end

  it 'raises when passing nil element to share_with_groups' do
    bob = Tanker::Core.new @options
    bob_identity = @app.create_identity
    bob_public_identity = Tanker::Identity.get_public_identity bob_identity
    bob.start_anonymous bob_identity
    group_id = bob.create_group [bob_public_identity]

    plaintext = 'Memory *is* RAM!'
    in_stream = StringIO.new(plaintext)

    result = expect do
      @tanker.encrypt_stream(in_stream,
                             Tanker::EncryptionOptions.new(share_with_groups: [group_id, nil]))
    end

    result.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::InvalidArgument)
      expect(e.code).to eq(Tanker::Error::INVALID_ARGUMENT)
    end

    bob.free
  end

  it 'throws the same errors as the inner stream' do
    plaintext = 'cat /dev/zero'
    in_stream = BrokenStringIO.new(plaintext)

    encrypted_stream = @tanker.encrypt_stream in_stream
    expect { encrypted_stream.read }.to raise_error(BrokenStringIO::Error)
    encrypted_stream.close
  end

  it 'throws a decryption error if the buffer is corrupt' do
    # big buffer to force stream encryption
    plaintext = 'la ram c\'est du cpu!' * 100_000
    ciphertext = @tanker.encrypt_utf8 plaintext

    ciphertext += 'lol' # corrupt the buffer

    encrypted_stream = StringIO.new(ciphertext)
    decrypted_stream = @tanker.decrypt_stream encrypted_stream

    expect { decrypted_stream.read }.to(raise_error) do |e|
      expect(e).to be_a(Tanker::Error)
      expect(e).to be_a(Tanker::Error::DecryptionFailed)
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

  it 'can encrypt with padding' do
    plaintext_10mb = format('%sxx', '012' * 1024 * 1024)

    in_stream = StringIO.new(plaintext_10mb)

    encrypted_stream = @tanker.encrypt_stream in_stream, Tanker::EncryptionOptions.new(
      padding_step: Tanker::Padding.step(500)
    )
    encrypted = encrypted_stream.read
    encrypted_stream.close
    expect(encrypted.length).to eq(3_146_248)
    in_stream = StringIO.new(encrypted)
    decrypted_stream = @tanker.decrypt_stream in_stream

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
