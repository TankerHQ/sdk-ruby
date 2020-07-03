# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'bundler/audit/task'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'rubygems/tasks'

Bundler::Audit::Task.new
RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Gem::Tasks.new

task default: :spec
