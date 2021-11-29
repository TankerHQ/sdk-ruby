# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'
require 'tanker/c_tanker/c_backends'

module Tanker
  # Options that can be given when opening a Tanker session
  class Core::Options < FFI::Struct
    layout :version, :uint8,
           :app_id, :pointer,
           :url, :pointer,
           :writable_path, :pointer,
           :sdk_type, :pointer,
           :sdk_version, :pointer,
           :http_options, CTanker::CHttpOptions,
           :cache_path, :pointer,
           :datastore_options, CTanker::CDatastoreOptions

    SDK_TYPE = 'client-ruby'
    SDK_VERSION = CTanker.new_cstring Core::VERSION

    def initialize(app_id:, url: nil, sdk_type: SDK_TYPE, writable_path: nil, cache_path: nil)
      super()

      # NOTE: Instance variables are required to keep the CStrings alive
      @app_id = CTanker.new_cstring app_id
      @url = CTanker.new_cstring url
      @writable_path = CTanker.new_cstring writable_path
      @cache_path = CTanker.new_cstring cache_path
      @sdk_type = CTanker.new_cstring sdk_type

      self[:version] = 4
      self[:app_id] = @app_id
      self[:url] = @url
      self[:writable_path] = @writable_path
      self[:cache_path] = @cache_path
      self[:sdk_type] = @sdk_type
      self[:sdk_version] = SDK_VERSION
    end
  end
end
