# frozen_string_literal: true

module Tanker
  class Core
    VERSION = '2.5.0.beta.3'

    def self.native_version
      CTanker.tanker_version_string
    end
  end
end
