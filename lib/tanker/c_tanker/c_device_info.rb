# frozen_string_literal: true

require 'ffi'

module Tanker
  module CTanker
    class CDeviceInfo < FFI::Struct
      layout :device_id, :string,
             :is_revoked, :bool

      attr_reader :device_id

      def initialize(pointer)
        super pointer
        @device_id = self[:device_id]
        @is_revoked = self[:is_revoked]
      end

      def revoked?
        @is_revoked
      end
    end
  end
end
