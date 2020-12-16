# frozen_string_literal: true

require 'tanker/c_tanker/c_tanker_error'

module Tanker
  # Main error class for errors returned by native tanker futures
  class Error < StandardError
    attr_reader :code
    attr_reader :message

    def initialize(ctanker_error)
      @code = ctanker_error[:error_code]
      @message = ctanker_error[:error_message]
      super(@message)
    end

    # Error code constants
    INVALID_ARGUMENT = 1
    INTERNAL_ERROR = 2
    NETWORK_ERROR = 3
    PRECONDITION_FAILED = 4
    OPERATION_CANCELED = 5
    DECRYPTION_FAILED = 6
    GROUP_TOO_BIG = 7
    INVALID_VERIFICATION = 8
    TOO_MANY_ATTEMPTS = 9
    EXPIRED_VERIFICATION = 10
    IO_ERROR = 11
    DEVICE_REVOKED = 12
    CONFLICT = 13
    UPGRADE_REQUIRED = 14

    # Error subclasses
    class InvalidArgument < self; end
    class InternalError < self; end
    class NetworkError < self; end
    class PreconditionFailed < self; end
    class OperationCanceled < self; end
    class DecryptionFailed < self; end
    class GroupTooBig < self; end
    class InvalidVerification < self; end
    class TooManyAttempts < self; end
    class ExpiredVerification < self; end
    class IOError < self; end
    class DeviceRevoked < self; end
    class Conflict < self; end
    class UpgradeRequired < self; end

    class << self
      ERROR_CODE_TO_CLASS = {
        INVALID_ARGUMENT => InvalidArgument,
        INTERNAL_ERROR => InternalError,
        NETWORK_ERROR => NetworkError,
        PRECONDITION_FAILED => PreconditionFailed,
        OPERATION_CANCELED => OperationCanceled,
        DECRYPTION_FAILED => DecryptionFailed,
        GROUP_TOO_BIG => GroupTooBig,
        INVALID_VERIFICATION => InvalidVerification,
        TOO_MANY_ATTEMPTS => TooManyAttempts,
        EXPIRED_VERIFICATION => ExpiredVerification,
        IO_ERROR => IOError,
        DEVICE_REVOKED => DeviceRevoked,
        CONFLICT => Conflict,
        UPGRADE_REQUIRED => UpgradeRequired
      }.freeze

      private_constant :ERROR_CODE_TO_CLASS

      def from_ctanker_error(ctanker_error)
        error_code = ctanker_error[:error_code]
        error_class = ERROR_CODE_TO_CLASS[error_code]

        if error_class.nil?
          InternalError.new(
            error_code: INTERNAL_ERROR,
            error_message: "Unknown error code returned by ctanker: #{error_code} - #{ctanker_error[:error_message]}"
          )
        else
          error_class.new ctanker_error
        end
      end
    end
  end
end
