# frozen_string_literal: true

require 'ffi'

# Log record of the log handler callback
class CLogRecord < FFI::Struct
  layout :category, :string,
         :level, :uint32,
         :file, :string,
         :line, :uint32,
         :message, :string
end
