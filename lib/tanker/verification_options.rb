# frozen_string_literal: true

require 'ffi'

module Tanker
  # Options that can be given when using a verification method
  class VerificationOptions < FFI::Struct
    def initialize(with_session_token: false)
      super()

      self[:version] = 1
      self[:with_session_token] = with_session_token ? 1 : 0
    end

    layout :version, :uint8,
           :with_session_token, :uint8
  end
end
