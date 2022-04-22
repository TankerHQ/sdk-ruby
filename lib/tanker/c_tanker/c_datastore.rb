# frozen_string_literal: true

require 'ffi'

module Tanker
  module CTanker
    class CDatastoreOptions < FFI::Struct
      layout :open, :pointer,
             :close, :pointer,
             :nuke, :pointer,
             :put_serialized_device, :pointer,
             :find_serialized_device, :pointer,
             :put_cache_values, :pointer,
             :find_cache_values, :pointer
    end
  end
end
