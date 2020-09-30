# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'bundler/audit/task'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'rubygems/tasks'
require 'json'
require 'ffi/platform'

def map_library_name(libname)
  "#{FFI::Platform::LIBPREFIX}#{libname}.#{FFI::Platform::LIBSUFFIX}"
end

def vendor_arch
  "#{FFI::Platform::OS}-#{FFI::Platform::ARCH}"
end

def define_copy_tanker
  task copy_tanker_libs:
  build_infos = Dir.glob('conan/*/conanbuildinfo.json')
  raise 'too many profile' if build_infos.size > 1
  return if build_infos.size.zero?

  deps_info = JSON.parse File.read(build_infos[0])
  tankerdep = deps_info['dependencies'].detect { |d| d['name'] == 'tanker' }
  libs = tankerdep['libs']
  dest = "vendor/tanker/#{vendor_arch}"
  desc 'create vendor directory'
  file dest do
    mkdir_p dest
  end
  libs.map { |l| map_library_name(l) }.map { |lib| File.join(tankerdep['lib_paths'][0], lib) }.each do |libname|
    target_lib = File.join(dest, File.basename(libname))
    desc "copy from #{libname}"
    file target_lib => [libname, dest] do
      cp(libname, target_lib)
    end
    task copy_tanker_libs: target_lib
  end
end
define_copy_tanker

task :tanker_libs do
  libs = Dir.glob("vendor/tanker/#{vendor_arch}/#{map_library_name('ctanker')}")
  raise 'no vendor library present and no build infos to get it from' if libs.size.zero?

  task 'copy_tanker_libs'
end

task tanker_libs: :copy_tanker_libs

task install: :tanker_libs
task build: :tanker_libs
task spec: :tanker_libs

Gem::Tasks.new
Bundler::Audit::Task.new
RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: :spec
