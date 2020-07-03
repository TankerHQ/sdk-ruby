# frozen_string_literal: true

require 'ffi'

module Tanker::CTanker
  # Tanker events for which handlers can be attached
  module CTankerEvent
    SESSION_CLOSED = 0
    DEVICE_REVOKED = 1
  end
end
