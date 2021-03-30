# frozen_string_literal: true

require 'ffi'
require 'tanker/error'
require 'tanker/c_tanker/c_lib'
require_relative 'c_tanker_error'

module Tanker
  module CTanker
    extend FFI::Library

    ffi_lib get_path('ctanker')

    class CFuture < FFI::AutoPointer
      def initialize(ptr, proc = nil, &block)
        super
        @cfuture = ptr
      end

      def self.release(ptr)
        CTanker.tanker_future_destroy ptr
      end

      def get
        CTanker.tanker_future_wait @cfuture
        if CTanker.tanker_future_has_error @cfuture
          cerr = CTanker.tanker_future_get_error @cfuture
          raise Error.from_ctanker_error(cerr)
        else
          CTanker.tanker_future_get_voidptr @cfuture
        end
      end

      def get_string # rubocop:disable Naming/AccessorMethodName (this is not a getter)
        str_ptr = get
        str = str_ptr.get_string(0).force_encoding(Encoding::UTF_8)
        CTanker.tanker_free_buffer str_ptr
        str
      end

      def get_maybe_string # rubocop:disable Naming/AccessorMethodName (this is not a getter)
        str_ptr = get
        if str_ptr.null?
          nil
        else
          str = str_ptr.get_string(0).force_encoding(Encoding::UTF_8)
          CTanker.tanker_free_buffer str_ptr
          str
        end
      end
    end
  end
end
