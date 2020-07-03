# frozen_string_literal: true

class Tanker::Core
  class AttachResult
    attr_reader :status, :verification_method

    def initialize(status, verification_method)
      @status = status
      @verification_method = verification_method
    end
  end
end
