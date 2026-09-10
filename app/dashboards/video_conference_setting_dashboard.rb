require 'administrate/base_dashboard'

class VideoConferenceSettingDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    account: Field::BelongsTo,
    user: Field::BelongsTo,
    moderator_url: Field::String,
    spectator_url: Field::String,
    moderator_password: Field::Password,
    spectator_password: Field::Password,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    account
    user
    updated_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    account
    user
    moderator_url
    spectator_url
    moderator_password
    spectator_password
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    account
    user
    moderator_url
    spectator_url
    moderator_password
    spectator_password
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(setting)
    "#{setting.account.name} — #{setting.user.available_name}"
  end
end
