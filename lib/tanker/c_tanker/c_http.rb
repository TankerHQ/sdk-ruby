# frozen_string_literal: true

require 'ffi'

module Tanker
  module CTanker
    extend FFI::Library

    class CHttpRequestHeader < FFI::Struct
      layout :name, :string,
             :value, :string
    end

    class CHttpRequest < FFI::Struct
      layout :method, :string,
             :url, :string,
             :headers, :pointer,
             :num_headers, :int32,
             :body, :pointer,
             :body_size, :int32
    end

    class CHttpResponseHeader < FFI::Struct
      layout :name, :pointer,
             :value, :pointer

      def initialize(name, value)
        super()

        @name = CTanker.new_cstring name
        @value = CTanker.new_cstring value

        self[:name] = @name
        self[:value] = @value
      end
    end

    class CHttpResponse < FFI::Struct
      def self.new_ok(status_code:, headers:, body:)
        new nil, status_code, headers, body
      end

      def self.new_error(msg)
        new msg, nil, nil, nil
      end

      def initialize(error_msg, status_code, headers, body)
        super()

        if error_msg
          @error_msg = CTanker.new_cstring(error_msg)
          self[:error_msg] = @error_msg
        else
          raise TypeError, 'headers argument is not an Array[HttpHeader]' unless headers.is_a?(Array)

          @body = FFI::MemoryPointer.from_string(body)

          self[:error_msg] = nil
          self[:num_headers] = headers.length
          self[:body] = @body
          self[:body_size] = body.bytesize
          self[:status_code] = status_code

          @headers = []
          self[:headers] = FFI::MemoryPointer.new(CHttpResponseHeader, self[:num_headers])
          headers.each_with_index do |header, idx|
            @headers.push(CHttpResponseHeader.new(header.name, header.value))
            # NOTE: memcopy
            str = @headers[idx].pointer.read_bytes CHttpResponseHeader.size
            self[:headers].put_bytes(idx * CHttpResponseHeader.size, str, 0, CHttpResponseHeader.size)
          end
        end
      end

      layout :error_msg, :pointer,
             :headers, :pointer,
             :num_headers, :int32,
             :body, :pointer,
             :body_size, :int64,
             :status_code, :int32
    end

    typedef :pointer, :http_request_handle

    callback :http_send_request, [CHttpRequest, :pointer], :http_request_handle
    callback :http_cancel_request, [CHttpRequest, :http_request_handle, :pointer], :void

    class CHttpOptions < FFI::Struct
      layout :send_request, :http_send_request,
             :cancel_request, :http_cancel_request,
             :data, :pointer

      def initialize(send_request, cancel_request)
        super()

        self[:send_request] = send_request
        self[:cancel_request] = cancel_request
        self[:data] = nil
      end
    end
  end
end
