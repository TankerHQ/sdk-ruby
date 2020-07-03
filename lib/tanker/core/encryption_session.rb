# frozen_string_literal: true

require 'tanker/c_tanker'
require 'tanker/core/stream'

module Tanker
  class Core::EncryptionSession
    def initialize(csession)
      @csession = csession
      csession_addr = @csession.address
      ObjectSpace.define_finalizer(@csession) do |_|
        CTanker.tanker_encryption_session_close(FFI::Pointer.new(:void, csession_addr)).get
      end
    end

    def encrypt_data(data)
      unless data.is_a?(String)
        raise TypeError, "expected data to be an ASCII-8BIT binary String, but got a #{data.class}"
      end
      unless data.encoding == Encoding::ASCII_8BIT
        raise ArgumentError, "expected data to be an ASCII-8BIT binary String, but it was #{data.encoding} encoded"
      end

      encrypt_common(data)
    end

    def encrypt_utf8(str)
      ASSERT_UTF8.call(str)

      encrypt_common str
    end

    def encrypt_common(data)
      inbuf = FFI::MemoryPointer.from_string(data)

      encrypted_size = CTanker.tanker_encryption_session_encrypted_size data.bytesize
      outbuf = FFI::MemoryPointer.new(:char, encrypted_size)

      CTanker.tanker_encryption_session_encrypt(@csession, outbuf, inbuf, data.bytesize).get

      outbuf.read_string encrypted_size
    end

    def encrypt_stream(stream)
      Stream.do_stream_action(stream) { |cb| CTanker.tanker_encryption_session_stream_encrypt(@csession, cb, nil) }
    end

    def resource_id
      CTanker.tanker_encryption_session_get_resource_id(@csession).get_string
    end
  end
end
