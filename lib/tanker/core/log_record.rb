# frozen_string_literal: true

class Tanker::Core
  class LogRecord
    attr_reader :category, :level, :file, :line, :message

    LEVEL_DEBUG = 1
    LEVEL_INFO = 2
    LEVEL_WARNING = 3
    LEVEL_ERROR = 4

    def initialize(category, level, file, line, message)
      @category = category
      @level = level
      @file = file
      @line = line
      @message = message
    end
  end
end
