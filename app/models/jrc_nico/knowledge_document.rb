# == Schema Information
#
# Table name: jrc_nico_knowledge_documents
#
#  id               :bigint           not null, primary key
#  approved_at      :datetime
#  body             :text             not null
#  customer_visible :boolean          default(FALSE), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  approved_by_id   :bigint
#  author_id        :bigint           not null
#
# Indexes
#
#  idx_nico_approved_knowledge                           (account_id,approved_at)
#  index_jrc_nico_knowledge_documents_on_account_id      (account_id)
#  index_jrc_nico_knowledge_documents_on_approved_by_id  (approved_by_id)
#  index_jrc_nico_knowledge_documents_on_author_id       (author_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (approved_by_id => users.id) ON DELETE => cascade
#  fk_rails_...  (author_id => users.id) ON DELETE => cascade
#
class JrcNico::KnowledgeDocument < ApplicationRecord
  self.table_name = 'jrc_nico_knowledge_documents'
  belongs_to :account
  belongs_to :author, class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 20_000 }
  validates :approved_by, presence: true, if: :approved_at?
  scope :approved, -> { where.not(approved_at: nil) }
  before_update :invalidate_changed_approval

  def digest
    Digest::SHA256.hexdigest((customer_visible ? [title, body, true] : [title, body]).to_json)
  end

  private

  def invalidate_changed_approval
    return unless will_save_change_to_title? || will_save_change_to_body? || will_save_change_to_customer_visible?

    self.approved_at = nil
    self.approved_by = nil
  end
end
