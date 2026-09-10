module JrcVoiceQuality
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: :processing_error)
      @code = code
      super(message)
    end
  end

  class ConfigurationError < Error; end
  class RecordingError < Error; end
  class TranscriptionError < Error; end
  class AnalysisError < Error; end
  class PersistenceError < Error; end

  def self.call_id_for(call)
    value = call[:unique_id].presence || call['unique_id'].presence || call[:id].presence || call['id'].presence
    value.to_s.strip.presence
  end
end
