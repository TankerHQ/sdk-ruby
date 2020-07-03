# frozen_string_literal: true

require 'ffi'
require 'tanker/c_tanker/c_string'

module Tanker
  # Options that can be given when sharing data
  class SharingOptions < FFI::Struct
    def initialize(share_with_users: [], share_with_groups: [])
      @users_objs = share_with_users.map { |id| CTanker.new_cstring id }
      users = FFI::MemoryPointer.new(:pointer, share_with_users.length)
      users.write_array_of_pointer(@users_objs)

      @groups_objs = share_with_groups.map { |id| CTanker.new_cstring id }
      groups = FFI::MemoryPointer.new(:pointer, share_with_groups.length)
      groups.write_array_of_pointer(@groups_objs)

      self[:version] = 1
      self[:recipient_public_identities] = users
      self[:nb_recipient_public_identities] = share_with_users.length
      self[:recipient_group_ids] = groups
      self[:nb_recipient_group_ids] = share_with_groups.length
    end

    layout :version, :uint8,
           :recipient_public_identities, :pointer,
           :nb_recipient_public_identities, :uint32,
           :recipient_group_ids, :pointer,
           :nb_recipient_group_ids, :uint32
  end
end
