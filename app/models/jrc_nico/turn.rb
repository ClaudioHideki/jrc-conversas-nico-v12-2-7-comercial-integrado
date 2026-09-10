# == Schema Information
#
# Table name: jrc_nico_turns
#
#  id                  :bigint           not null, primary key
#  status              :string           default("running"), not null
#  version             :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  delegation_id       :bigint           not null
#  message_id          :bigint           not null
#  outgoing_message_id :bigint
#
# Indexes
#
#  index_jrc_nico_turns_on_delegation_id  (delegation_id)
#  nico_turn_once                         (delegation_id,version,message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (delegation_id => jrc_nico_delegations.id) ON DELETE => cascade
#
class JrcNico::Turn < ApplicationRecord
  self.table_name = 'jrc_nico_turns'
  belongs_to :delegation, class_name: 'JrcNico::Delegation'
end
