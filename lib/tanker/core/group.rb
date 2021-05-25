# frozen_string_literal: true

require 'tanker/c_tanker'

module Tanker
  class Core
    def create_group(member_identities)
      cmember_identities = CTanker.new_cstring_array member_identities
      CTanker.tanker_create_group(@ctanker, cmember_identities, member_identities.length).get_string
    end

    def update_group_members(group_id, users_to_add: [], users_to_remove: []) 
      cadd_identities = CTanker.new_cstring_array users_to_add
      cremove_identities = CTanker.new_cstring_array users_to_remove
      CTanker.tanker_update_group_members(@ctanker, group_id, cadd_identities, users_to_add.length, cremove_identities, users_to_remove.length).get
    end
  end
end
