# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'

module Tanker
  # Options that can be given when opening a Tanker session
  class Core::Options < FFI::Struct
    layout :version, :uint8,
           :app_id, :pointer,
           :url, :pointer,
           :writable_path, :pointer,
           :sdk_type, :pointer,
           :sdk_version, :pointer

    SDK_TYPE = 'client-ruby'
    SDK_VERSION = CTanker.new_cstring Core::VERSION

    def initialize(app_id:, url: nil, sdk_type: SDK_TYPE, writable_path: nil)
      # Note: Instance variables are required to keep the CStrings alive
      @app_id = CTanker.new_cstring app_id
      @url = CTanker.new_cstring url
      @writable_path = CTanker.new_cstring writable_path
      @sdk_type = CTanker.new_cstring sdk_type

      self[:version] = 2
      self[:app_id] = @app_id
      self[:url] = @url
      self[:writable_path] = @writable_path
      self[:sdk_type] = @sdk_type
      self[:sdk_version] = SDK_VERSION
    end
  end
end
