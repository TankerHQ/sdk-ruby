# frozen_string_literal: true

module Tanker::CTanker
  def self.get_path(name)
    if /darwin/ =~ RUBY_PLATFORM
      ext = '.dylib'
      subdir = 'mac64'
    else
      ext = '.so'
      subdir = 'linux64'
    end

    File.expand_path "../../../vendor/libctanker/#{subdir}/tanker/lib/lib#{name}#{ext}", __dir__
  end
end
