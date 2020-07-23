# frozen_string_literal: true

module Tanker
  class Core
    VERSION = '2.4.3.alpha.3'

    def self.native_version
      CTanker.tanker_version_string
    end
  end
end
