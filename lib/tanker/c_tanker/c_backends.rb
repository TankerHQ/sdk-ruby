# frozen_string_literal: true

require 'ffi'
require 'tanker/core/verification'
require 'tanker/c_tanker/c_string'

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

    class CHttpOptions < FFI::Struct
      layout :send_request, :pointer,
             :cancel_request, :pointer,
             :data, :pointer
    end
  end
end
