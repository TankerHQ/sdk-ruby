# frozen_string_literal: true

# Status of a Tanker session
module Tanker::Status
  STOPPED = 0
  READY = 1
  IDENTITY_REGISTRATION_NEEDED = 2
  IDENTITY_VERIFICATION_NEEDED = 3
end
