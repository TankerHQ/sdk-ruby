# frozen_string_literal: true

require 'tanker/core'

module Tanker
  module CTanker
    module ForkHook
      def _fork(*args)
        CTanker.tanker_before_fork
        Core.before_fork
        super
      ensure
        CTanker.tanker_after_fork
      end

      def self.install
        Process.singleton_class.prepend(self)
      end
    end
  end
end
