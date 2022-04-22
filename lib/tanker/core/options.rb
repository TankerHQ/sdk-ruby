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
           :persistent_path, :pointer,
           :cache_path, :pointer,
           :sdk_type, :pointer,
           :sdk_version, :pointer,
           :http_options, CTanker::CHttpOptions,
           :datastore_options, CTanker::CDatastoreOptions

    SDK_TYPE = 'client-ruby'
    SDK_VERSION = CTanker.new_cstring Core::VERSION

    attr_reader :sdk_type

    def initialize(app_id:, url: nil, sdk_type: SDK_TYPE, persistent_path: nil, cache_path: nil)
      super()

      # NOTE: Instance variables are required to keep the CStrings alive
      @c_app_id = CTanker.new_cstring app_id
      @c_url = CTanker.new_cstring url
      @c_persistent_path = CTanker.new_cstring persistent_path
      @c_cache_path = CTanker.new_cstring cache_path
      @sdk_type = sdk_type
      @c_sdk_type = CTanker.new_cstring sdk_type

      self[:version] = 4
      self[:app_id] = @c_app_id
      self[:url] = @c_url
      self[:persistent_path] = @c_persistent_path
      self[:cache_path] = @c_cache_path
      self[:sdk_type] = @c_sdk_type
      self[:sdk_version] = SDK_VERSION
    end
  end
end
