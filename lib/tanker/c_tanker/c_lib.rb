# frozen_string_literal: true

require 'ffi/platform'

module Tanker::CTanker
  def self.get_path(name)
    File.expand_path "../../../vendor/tanker/#{FFI::Platform::OS}-#{FFI::Platform::ARCH}/"\
                     "#{FFI::Platform::LIBPREFIX}#{name}.#{FFI::Platform::LIBSUFFIX}", __dir__
  end
end
