class JrcNico::RecipientChoice
  NUMBER_WORDS = {
    'zero' => '0', 'um' => '1', 'uma' => '1', 'dois' => '2', 'duas' => '2', 'tres' => '3',
    'quatro' => '4', 'cinco' => '5', 'seis' => '6', 'sete' => '7', 'oito' => '8', 'nove' => '9',
    'dez' => '10', 'onze' => '11', 'doze' => '12', 'vinte' => '20', 'trinta' => '30',
    'quarenta' => '40', 'cinquenta' => '50', 'sessenta' => '60', 'setenta' => '70', 'oitenta' => '80', 'noventa' => '90'
  }.freeze

  def self.spoken_numbers(text)
    pattern = /\b(?:#{NUMBER_WORDS.keys.join('|')})\b/
    words = text.scan(pattern)
    parts = []
    words.each do |word|
      value = NUMBER_WORDS.fetch(word)
      if parts.last&.match?(/\A[2-9]0\z/) && value.match?(/\A[1-9]\z/)
        parts[-1] = (parts.last.to_i + value.to_i).to_s
      else
        parts << value
      end
    end
    number = parts.join
    number.length.between?(10, 13) ? [number] : []
  end

  def self.match(message, contacts)
    text = I18n.transliterate(message.to_s).downcase
    numbers = text.scan(/\+?\d[\d\s().-]{6,}\d/).map { |number| number.gsub(/\D/, '') }
    numbers += spoken_numbers(text) if numbers.empty?
    phone_matches = contacts.select do |contact|
      phone = contact.phone_number.to_s.gsub(/\D/, '')
      numbers.any? { |number| phone.present? && (number == phone || (number.length >= 10 && phone == "55#{number}")) }
    end
    return phone_matches if numbers.any?

    emails = text.scan(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/)
    return contacts.select { |contact| emails.include?(contact.email.to_s.downcase) } if emails.any?

    contacts.select do |contact|
      name = I18n.transliterate(contact.name.to_s).downcase.strip
      email = contact.email.to_s.downcase.strip
      text.match?(/(?:contato|id)\s*#?#{contact.id}\b/) ||
        (name.present? && text.match?(/(?<!\w)#{Regexp.escape(name)}(?!\w)/)) ||
        (email.present? && text.include?(email))
    end
  end
end
