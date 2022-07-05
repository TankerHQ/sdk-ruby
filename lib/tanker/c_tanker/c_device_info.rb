# frozen_string_literal: true

require 'ffi'

module Tanker
  module CTanker
    class CDeviceInfo < FFI::Struct
      layout :device_id, :string

      attr_reader :device_id

      def initialize(pointer)
        super pointer
        @device_id = self[:device_id]
      end
    end
  end
end
