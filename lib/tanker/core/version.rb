# frozen_string_literal: true

module Tanker
  class Core
    VERSION = '4.2.0'

    def self.native_version
      CTanker.tanker_version_string
    end
  end
end
