# == Schema Information
#
# Table name: jrc_nico_sessions
#
#  id         :bigint           not null, primary key
#  context    :jsonb            not null
#  messages   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_jrc_nico_sessions_on_account_id              (account_id)
#  index_jrc_nico_sessions_on_account_id_and_user_id  (account_id,user_id) UNIQUE
#  index_jrc_nico_sessions_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class JrcNico::Session < ApplicationRecord
  self.table_name = 'jrc_nico_sessions'
  belongs_to :account
  belongs_to :user
  has_many :commands, class_name: 'JrcNico::Command', dependent: :destroy

  def append(role, content)
    update!(messages: (messages + [{ role: role, content: content.to_s.first(8000), at: Time.current.iso8601 }]).last(80))
  end
end
