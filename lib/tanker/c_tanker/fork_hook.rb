# frozen_string_literal: true

require 'tanker/core'
require 'tanker/core/http'

module Tanker
  module ForkHook
    def _fork(*args)
      puts "### PID=#{Process.pid} TANKER-CORE BEFORE FORK HOOK"
      CTanker.tanker_before_fork
      Core.before_fork
      Http::ThreadPool.before_fork

      res = super

      CTanker.tanker_after_fork
      puts "### PID=#{Process.pid} TANKER-CORE AFTER FORK HOOK"
      res
    end
    prepend_features(Process.singleton_class)
  end
end
