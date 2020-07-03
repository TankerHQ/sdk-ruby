# frozen_string_literal: true

require 'English'
require 'tanker/c_tanker'

module Tanker
  class Core
    def encrypt_stream(stream, encryption_options = nil)
      Stream.do_stream_action(stream) { |cb| CTanker.tanker_stream_encrypt(@ctanker, cb, nil, encryption_options) }
    end

    def decrypt_stream(stream)
      Stream.do_stream_action(stream) { |cb| CTanker.tanker_stream_decrypt(@ctanker, cb, nil) }
    end
  end

  module Stream
    def self.do_stream_action(stream)
      in_wrapper = IoToTankerStreamWrapper.new(stream)
      tanker_stream = (yield in_wrapper.read_method).get
      out_wrapper = TankerStreamToIoWrapper.new(tanker_stream, in_wrapper)

      out_io = out_wrapper.init_io

      # The chain of possession is
      # returned IO -> out_wrapper -> in_wrapper
      # This allows us to close all the chain when the returned IO is closed
      out_io.instance_eval do
        @tanker_out_wrapper = out_wrapper

        extend IoMixin
      end

      out_io
    end
  end

  module IoMixin
    def read(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def read_nonblock(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def readbyte(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def readchar(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def readline(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def readlines(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def readpartial(*)
      out = super
      raise @tanker_out_wrapper.error if @tanker_out_wrapper.error

      out
    end

    def close(*)
      if @tanker_out_wrapper
        @tanker_out_wrapper.close
        @tanker_out_wrapper = nil
      end

      super
    end
  end

  # IMPORTANT: about synchronization
  # Because of a design flaw in the Tanker C streaming API, it is difficult to
  # handle cancelation. When canceling a read (closing the stream), Tanker
  # doesn't forward the cancelation request to the input stream (there's no
  # callback for that), which means that the callback maybe writing to a buffer
  # that's being freed. We worked around that by adding a mutex and locking it
  # in both the output stream and the input stream.
  # Things to be careful about:
  # - Do not copy data to the Tanker buffer if tanker_stream_close has been
  # called
  # - Do not call tanker_stream_read_operation_finish if tanker_stream_close has
  # been called
  # - On the output stream, do not call tanker_stream_read on a closed/closing
  # stream. Though it is ok to close the stream after the call, but before the
  # future is resolved.
  class IoToTankerStreamWrapper
    attr_reader :error
    attr_reader :read_method
    attr_reader :mutex

    def initialize(read_in)
      @read_in = read_in
      # This is the object we will pass to ffi, it must be kept alive
      @read_method = method(:read)
      @closed = false
      @mutex = Mutex.new
    end

    def close
      raise 'mutex should be locked by the caller' unless @mutex.owned?

      @closed = true
      @read_in.close
    end

    def read(buffer, buffer_size, operation, _)
      # We must not block Tanker's thread, for performance but also to avoid
      # deadlocks, so let's run this function somewhere else
      Thread.new do
        do_read(buffer, buffer_size, operation)
      end
    end

    private

    def do_read(buffer, buffer_size, operation)
      @mutex.synchronize do
        return if @closed

        if @read_in.eof?
          CTanker.tanker_stream_read_operation_finish(operation, 0)
          return
        end
      end

      rbbuf = @read_in.readpartial(buffer_size)

      @mutex.synchronize do
        return if @closed

        buffer.put_bytes(0, rbbuf)
        CTanker.tanker_stream_read_operation_finish(operation, rbbuf.size)
      end
    rescue StandardError => e
      @mutex.synchronize do
        return if @closed

        @error = e
        CTanker.tanker_stream_read_operation_finish(operation, -1)
      end
    end
  end

  class TankerStreamToIoWrapper
    attr_reader :error

    def initialize(tanker_stream, substream)
      @tanker_stream = tanker_stream
      @substream = substream

      # The user will only read on the pipe, so we need something that reads
      # from Tanker and writes to the pipe, it's this thread.
      Thread.new { read_thread }
    end

    def init_io
      read, @write = IO.pipe
      read
    end

    def close
      tanker_stream = nil
      @substream.mutex.synchronize do
        @substream.close
        tanker_stream = @tanker_stream
        @tanker_stream = nil
      end
      CTanker.tanker_stream_close(tanker_stream).get
    end

    private

    READ_SIZE = 1024 * 1024

    def read_thread
      ffibuf = FFI::MemoryPointer.new(:char, READ_SIZE)
      begin
        loop do
          nb_read_fut = nil
          @substream.mutex.synchronize do
            unless @tanker_stream
              raise TankerError, { error_code: Errors::OPERATION_CANCELED, error_message: 'stream operation canceled' }
            end

            nb_read_fut = CTanker.tanker_stream_read(@tanker_stream, ffibuf, READ_SIZE)
          end
          nb_read = nb_read_fut.get.address
          break if nb_read.zero? # EOF

          @write.write(ffibuf.read_string(nb_read))
        end
      rescue StandardError => e
        @error = @substream.error || e
      ensure
        @write.close
      end
    end
  end

  private_constant :Stream
  private_constant :IoMixin
  private_constant :IoToTankerStreamWrapper
  private_constant :TankerStreamToIoWrapper
end
