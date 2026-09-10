require 'set'

class JrcCampaigns::Sanitizer
  def initialize(account:, user:, name:, entries:)
    @account = account
    @user = user
    @name = name
    @entries = entries
  end

  def perform
    JrcCampaigns::SanitizedList.transaction do
      list = account.jrc_campaign_sanitized_lists.create!(name: name, created_by: user)
      seen = Set.new
      stats = Hash.new(0)

      entries.each do |raw|
        data = raw.respond_to?(:to_h) ? raw.to_h.with_indifferent_access : { phone: raw.to_s }
        phone = data[:phone] || data[:telefone] || data[:phone_number]
        normalized = JrcCampaigns::PhoneNormalizer.call(phone)
        status, reason = classify(normalized, seen)
        seen << normalized if normalized.present?
        stats[status] += 1

        list.entries.create!(
          name: data[:name] || data[:nome],
          phone_number: phone,
          normalized_phone: normalized,
          status: status,
          reason: reason,
          metadata: data.except(:name, :nome, :phone, :telefone, :phone_number)
        )
      end

      list.update!(stats: stats.merge('total' => entries.size))
      list
    end
  end

  private

  attr_reader :account, :user, :name, :entries

  def blacklisted_phones
    @blacklisted_phones ||= account.jrc_campaign_blacklists.pluck(:phone_number).to_set
  end

  def classify(normalized, seen)
    return ['invalid', 'Telefone vazio ou inválido'] unless normalized.match?(/\A\+[1-9]\d{7,14}\z/)
    return ['duplicate', 'Telefone duplicado na lista'] if seen.include?(normalized)
    return ['blacklisted', 'Telefone presente na blacklist'] if blacklisted_phones.include?(normalized)

    ['valid', nil]
  end
end
