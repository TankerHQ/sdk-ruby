# frozen_string_literal: true

module Tanker
  # Main entry point for the Tanker SDK. Can open a Tanker session.
  class Core
    CTanker.tanker_init

    def initialize(options)
      @revoke_event_handlers = Set.new
      @ctanker = CTanker.tanker_create(options).get
      @freed = false
      ctanker_addr = @ctanker.address
      ObjectSpace.define_finalizer(@ctanker) do |_|
        next if @freed

        CTanker.tanker_destroy(FFI::Pointer.new(:void, ctanker_addr)).get
      end

      @device_revoked_handler = lambda { |_|
        Thread.new { @revoke_event_handlers.each(&:call) }
      }
      CTanker.tanker_event_connect(@ctanker, CTanker::CTankerEvent::DEVICE_REVOKED, @device_revoked_handler, nil).get
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

    def self.set_log_handler(&block) # rubocop:disable Naming/AccessorMethodName
      @log_handler = lambda do |clog|
        block.call LogRecord.new clog[:category], clog[:level], clog[:file], clog[:line], clog[:message]
      end
      CTanker.tanker_set_log_handler @log_handler
    end

    # Do not spam the console of our users
    set_log_handler { |_| }

    def connect_device_revoked_handler(&block)
      @revoke_event_handlers.add block
    end

    def disconnect_handler(&block)
      @revoke_event_handlers.delete block
    end
  end

  ASSERT_UTF8 = lambda do |str|
    raise TypeError, "expected a String, but got a #{str.class}" unless str.is_a?(String)

    encoding = str.encoding # Workaround rubocop bug
    raise ArgumentError, "expected an UTF-8 String, but it was #{encoding} encoded" unless encoding == Encoding::UTF_8
  end
  private_constant :ASSERT_UTF8
end
