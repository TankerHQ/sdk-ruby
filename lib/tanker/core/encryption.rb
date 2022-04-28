# frozen_string_literal: true

require 'tanker/c_tanker'
require_relative 'encryption_session'

module Tanker
  class Core
    def encrypt_data(data, encryption_options = nil)
      unless data.is_a?(String)
        raise TypeError, "expected data to be an ASCII-8BIT binary String, but got a #{data.class}"
      end
      unless data.encoding == Encoding::ASCII_8BIT
        raise ArgumentError, "expected data to be an ASCII-8BIT binary String, but it was #{data.encoding} encoded"
      end

      encrypt_common data, encryption_options
    end

    def encrypt_utf8(str, encryption_options = nil)
      ASSERT_UTF8.call(str)

      encrypt_common str, encryption_options
    end

    def decrypt_data(data)
      inbuf = FFI::MemoryPointer.from_string(data)

      decrypted_size = CTanker.tanker_decrypted_size(inbuf, data.bytesize).get.address
      outbuf = FFI::MemoryPointer.new(:char, decrypted_size)

      clear_size = CTanker.tanker_decrypt(@ctanker, outbuf, inbuf, data.bytesize).get.address

      outbuf.read_string clear_size
    end

    def decrypt_utf8(data)
      decrypted = decrypt_data data
      decrypted.force_encoding(Encoding::UTF_8)
    end

    def get_resource_id(data)
      unless data.is_a?(String)
        raise TypeError, "expected data to be an ASCII-8BIT binary String, but got a #{data.class}"
      end
      unless data.encoding == Encoding::ASCII_8BIT
        raise ArgumentError, "expected data to be an ASCII-8BIT binary String, but it was #{data.encoding} encoded"
      end

      inbuf = FFI::MemoryPointer.from_string(data)
      CTanker.tanker_get_resource_id(inbuf, data.bytesize).get_string
    end

    def share(resource_ids, sharing_options)
      unless resource_ids.is_a?(Array)
        raise TypeError, "expected resource_ids to be an array of strings, but got a #{resource_ids.class}"
      end
      unless sharing_options.is_a?(SharingOptions)
        raise TypeError, "expected sharing_options to be a SharingOptions, but got a #{sharing_options.class}"
      end

      cresource_ids = CTanker.new_cstring_array resource_ids

      CTanker.tanker_share(@ctanker, cresource_ids, resource_ids.length, sharing_options).get
    end

    def create_encryption_session(encryption_options = nil)
      unless !encryption_options || encryption_options.is_a?(EncryptionOptions)
        raise TypeError, "expected encryption_options to be a EncryptionOptions, but got a #{encryption_options.class}"
      end

      csession = CTanker.tanker_encryption_session_open(@ctanker, encryption_options).get
      EncryptionSession.new(csession)
    end

    def self.prehash_password(str)
      ASSERT_UTF8.call(str)

      CTanker.tanker_prehash_password(str).get_string
    end

    private

    def encrypt_common(data, encryption_options = nil)
      unless !encryption_options || encryption_options.is_a?(EncryptionOptions)
        raise TypeError, "expected encryption_options to be a EncryptionOptions, but got a #{encryption_options.class}"
      end

      inbuf = FFI::MemoryPointer.from_string(data)

      encrypted_size = CTanker.tanker_encrypted_size data.bytesize
      outbuf = FFI::MemoryPointer.new(:char, encrypted_size)

      CTanker.tanker_encrypt(@ctanker, outbuf, inbuf, data.bytesize, encryption_options).get

      outbuf.read_string encrypted_size
    end
  end
end
