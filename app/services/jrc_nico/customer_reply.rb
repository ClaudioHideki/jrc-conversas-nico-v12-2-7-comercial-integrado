class JrcNico::CustomerReply
  # A deterministic final check: the model may still add a greeting on later turns.
  def self.normalize(text, continuation:)
    return text unless continuation
    reply = text.to_s.sub(/\A\s*(?:ol[áa]|oi|bom dia|boa tarde|boa noite)\b[!,.:;\s—-]*/i, '')
    reply = reply.sub(/\A(?:eu )?sou (?:o |a )?NICO[^.!?]*[.!?]\s*/i, '')
    reply.presence || text
  end
end

