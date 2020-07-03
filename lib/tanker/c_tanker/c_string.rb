# frozen_string_literal: true

require 'ffi'

module Tanker::CTanker
  # Fun fact: Strings in structs with the FFI lib are read-only,
  # you can't just assign a string literal to a cstring.
  # They'd rather not handle allocations transparently (lifetimes are tricky),
  # so we have to take care of allocations and lifetimes ourselves.
  def self.new_cstring(str_or_nil, manual = false)
    return nil if str_or_nil.nil?

    cstr = FFI::MemoryPointer.from_string(str_or_nil)
    cstr.autorelease = !manual
    cstr
  end

  def self.new_cstring_array(strings)
    cstrings = FFI::MemoryPointer.new(:pointer, strings.length)
    ruby_strings = strings.map { |id| new_cstring id }
    # keep alive the ruby objects to prevent GC
    # I could not find any other place to store these
    cstrings.instance_variable_set(:@ruby_strings, ruby_strings)
    cstrings.write_array_of_pointer(ruby_strings)
    cstrings
  end

  def self.free_manual_cstring(cstr_or_nil)
    cstr_or_nil&.free
  end
end
