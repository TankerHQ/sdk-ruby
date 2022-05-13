# frozen_string_literal: true

module Tanker
  # Main entry point for the Tanker SDK. Can open a Tanker session.
  class Core
    @log_handler_lock = Mutex.new
    @log_handler_set = 0

    def self.test_and_set_log_handler
      @log_handler_lock.synchronize do
        is_set = @log_handler_set
        @log_handler_set = 1
        return is_set
      end
    end

    def self.set_log_handler(&block) # rubocop:disable Naming/AccessorMethodName
      @log_handler_set = 1
      @log_handler = lambda do |clog|
        block.call LogRecord.new clog[:category], clog[:level], clog[:file], clog[:line], clog[:message]
      end
      CTanker.tanker_set_log_handler @log_handler
    end

    def initialize(options)
      # tanker_init is not called globally to avoid potential logs at global scope
      # some frameworks like to pre-execute statements at global scope and then fork, this fork can
      # interact badly with the threads used in the log handler, so never call Tanker at global scope
      CTanker.tanker_init

      # Do not spam the console of our users.
      self.class.set_log_handler { |_| } unless self.class.test_and_set_log_handler == 1 # rubocop:disable Lint/EmptyBlock

      @http_client = Http::Client.new options.sdk_type, VERSION, options.faraday_adapter
      options[:http_options] = @http_client.tanker_http_options

      @ctanker = CTanker.tanker_create(options).get
      @freed = false
      ctanker_addr = @ctanker.address
      ObjectSpace.define_finalizer(@ctanker) do |_|
        next if @freed

        CTanker.tanker_destroy(FFI::Pointer.new(:void, ctanker_addr)).get
      end
    end

    def free
      @freed = true
      CTanker.tanker_destroy(@ctanker).get
      @ctanker = nil

      public_methods(false).each do |method|
        send(:define_singleton_method, method) do |*_|
          raise "using Tanker::Core##{method} after free"
        end
      end
    end
  end

  ASSERT_UTF8 = lambda do |str|
    raise TypeError, "expected a String, but got a #{str.class}" unless str.is_a?(String)

    encoding = str.encoding # Workaround rubocop bug
    raise ArgumentError, "expected an UTF-8 String, but it was #{encoding} encoded" unless encoding == Encoding::UTF_8
  end
  private_constant :ASSERT_UTF8
end
