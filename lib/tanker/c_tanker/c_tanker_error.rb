# frozen_string_literal: true

require 'ffi'

module Tanker::CTanker
  # Errors returned by native tanker futures
  class CTankerError < FFI::Struct
    layout :error_code, :int,
           :error_message, :string
  end
end
