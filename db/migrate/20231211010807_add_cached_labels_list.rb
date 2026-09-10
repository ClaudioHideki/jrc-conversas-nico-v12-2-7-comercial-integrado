class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information

    return unless ActsAsTaggableOn::Taggable.const_defined?(:Cache, false)

    ActsAsTaggableOn::Taggable.const_get(:Cache).included(Conversation)
  end
end
