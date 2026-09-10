class JrcCampaigns::PhoneNormalizer
  def self.call(value)
    digits = value.to_s.gsub(/\D/, '')
    return '' if digits.blank?

    "+#{digits}"
  end
end
