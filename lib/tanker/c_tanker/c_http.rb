# frozen_string_literal: true

require 'ffi'

module Tanker
  module CTanker
    class CHttpRequest < FFI::Struct
      layout :method, :string,
             :url, :string,
             :instance_id, :string,
             :authorization, :string,
             :body, :pointer,
             :body_size, :int32
    end

    class CHttpResponse < FFI::Struct
      def self.new_ok(status_code:, content_type:, body:)
        new nil, status_code, content_type, body
      end

      def self.new_error(msg)
        new msg, nil, nil, nil
      end

      def initialize(error_msg, status_code, content_type, body)
        super()

        if error_msg
          @error_msg = CTanker.new_cstring(error_msg)
          self[:error_msg] = @error_msg
        else
          @content_type = CTanker.new_cstring content_type
          @body = FFI::MemoryPointer.from_string(body)

          self[:error_msg] = nil
          self[:content_type] = @content_type
          self[:body] = @body
          self[:body_size] = body.bytesize
          self[:status_code] = status_code
        end
      end

      layout :error_msg, :pointer,
             :content_type, :pointer,
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
