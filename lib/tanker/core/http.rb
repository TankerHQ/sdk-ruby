# frozen_string_literal: true

require 'faraday'

module Tanker
  module Http
    class HttpRequest
      @@mutex = Mutex.new # rubocop:disable Style/ClassVars I have no idea why you don't like class vars
      @@current_request_id = 0 # rubocop:disable Style/ClassVars
      # Hash(id => request)
      @@running_requests = {} # rubocop:disable Style/ClassVars

      attr_reader :id
      attr_reader :method
      attr_reader :url
      attr_reader :instance_id
      attr_reader :authorization
      attr_reader :body
      attr_reader :crequest

      def self.method_str_to_symbol(method)
        case method
        when 'GET' then :get
        when 'POST' then :post
        when 'PATCH' then :patch
        when 'PUT' then :put
        when 'DELETE' then :delete
        else raise "unknown HTTP method #{method}"
        end
      end

      def initialize(crequest:)
        @@mutex.synchronize do
          @@current_request_id += 1 # rubocop:disable Style/ClassVars
          @id = @@current_request_id
          @@running_requests[@id] = self
        end

        @method = self.class.method_str_to_symbol crequest[:method]
        @url = crequest[:url]
        @instance_id = crequest[:instance_id]
        @authorization = crequest[:authorization]
        @body = crequest[:body].read_string_length(crequest[:body_size])

        # Keep the crequest because we need its address to answer to Tanker
        @crequest = crequest
      end

      # Since Ruby's HTTP libraries are not asynchronous, they do not support cancelation either.
      # When a request is canceled, we let it run until the end, and then we discard its result.
      def self.cancel(id)
        @@mutex.synchronize do
          @@running_requests.delete id
        end
      end

      def complete_if_not_canceled(&block)
        @@mutex.synchronize do
          unless @@running_requests.delete @id
            # Request has been canceled, don't call Tanker back
            return
          end

          block.call
        end
      end
    end

    module ThreadPool
      THREAD_POOL_SIZE = 4
      @queue = nil

      def self.init
        # Queue is a concurrent queue in Ruby
        @queue = Queue.new
        @http_thread_pool = THREAD_POOL_SIZE.times do
          Thread.new do
            thread_loop
          end
        end
      end

      def self.thread_loop
        loop do
          work = @queue.pop
          work.call
        end
      end

      def self.push(proc)
        init if @queue.nil?
        @queue << proc
      end
    end

    class Client
      attr_reader :tanker_http_options

      def initialize(sdk_type, sdk_version, faraday_adapter)
        @sdk_type = sdk_type
        @sdk_version = sdk_version
        @conn = Faraday.new do |conn|
          conn.adapter faraday_adapter || Faraday.default_adapter
        end

        # This could be a proc, but for some reason, ffi gives the wrong type
        # for crequest if we don't specify it explicitly here
        @c_send_request = FFI::Function.new(:pointer, [CTanker::CHttpRequest.by_ref, :pointer]) do |crequest, cdata|
          next send_request crequest, cdata
        rescue Exception => e # rubocop:disable Lint/RescueException I do want to rescue all exceptions
          cresponse = CTanker::CHttpResponse.new_error e.message
          CTanker.tanker_http_handle_response(crequest, cresponse)
        end
        @c_cancel_request = proc do |crequest, request_id, cdata|
          cancel_request crequest, request_id, cdata
        rescue Exception => e # rubocop:disable Lint/RescueException I do want to rescue all exceptions
          # This is not recoverable and won't be logged by FFI, let's do our best and log it here just before we crash
          puts "fatal error when canceling HTTP request:\n#{e.full_message}"
          raise
        end

        @tanker_http_options = CTanker::CHttpOptions.new @c_send_request, @c_cancel_request
      end

      def process_request(request)
        fresponse = Faraday.run_request(request.method, request.url, request.body, {
          'X-Tanker-SdkType' => @sdk_type,
          'X-Tanker-SdkVersion' => @sdk_version,
          'Authorization' => request.authorization,
          'X-Tanker-Instanceid' => request.instance_id,
          # net-http really wants a Content-Type
          'Content-Type' => 'application/data'
        }.compact)

        request.complete_if_not_canceled do
          cresponse = CTanker::CHttpResponse.new_ok status_code: fresponse.status,
                                                    content_type: fresponse.headers['content-type'],
                                                    body: fresponse.body
          CTanker.tanker_http_handle_response(request.crequest, cresponse)
        end
      rescue Faraday::ConnectionFailed => e
        # This can happen if Faraday is using a proxy, and it rejects the request
        # If we get a 500 from the proxy, we want to differentiate this from a real server error
        cresponse = CTanker::CHttpResponse.new_error "#{e.class}: #{e.message}"
        CTanker.tanker_http_handle_response(request.crequest, cresponse)
      rescue Exception => e # rubocop:disable Lint/RescueException I do want to rescue all exceptions
        # NOTE: when debugging, you might want to uncomment this to print a full backtrace
        # puts "HTTP request error:\n#{e.full_message}"
        cresponse = CTanker::CHttpResponse.new_error e.message
        CTanker.tanker_http_handle_response(request.crequest, cresponse)
      end

      def send_request(crequest, _cdata)
        request = HttpRequest.new crequest: crequest
        ThreadPool.push(proc do
          process_request request
        end)
        FFI::Pointer.new :void, request.id
      end

      def cancel_request(_crequest, prequest_id, _cdata)
        request_id = prequest_id.to_i
        HttpRequest.cancel(request_id)
      end
    end
  end

  private_constant :Http
end
