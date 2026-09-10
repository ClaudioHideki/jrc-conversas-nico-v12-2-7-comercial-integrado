# == Schema Information
#
# Table name: jrc_crm_campaigns
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  settings    :jsonb
#  status      :string           default("active")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :integer          not null
#  pipeline_id :bigint
#
# Indexes
#
#  index_jrc_crm_campaigns_on_account_id  (account_id)
#  index_jrc_crm_campaigns_on_status      (status)
#
module JrcCrm
  class Campaign < ApplicationRecord
    self.table_name = 'jrc_crm_campaigns'
    
    belongs_to :account
    belongs_to :pipeline, class_name: 'JrcCrm::Pipeline', optional: true
    has_many :deals
    
    validates :name, presence: true
    enum status: { active: 'active', paused: 'paused', finished: 'finished', archived: 'archived' }
  end
end
