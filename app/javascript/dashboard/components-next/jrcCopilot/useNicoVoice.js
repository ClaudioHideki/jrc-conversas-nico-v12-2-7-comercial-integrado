import { ref, onBeforeUnmount, watch } from 'vue';

export const useNicoVoice = ({ onTranscript, transcribe, inCall }) => {
  const supported = Boolean(
    navigator.mediaDevices?.getUserMedia && window.MediaRecorder
  );
  const listening = ref(false);
  const transcribing = ref(false);
  const error = ref('');
  const speakingEnabled = ref(false);
  let recorder;
  let stream;
  let timer;
  let request;
  let generation = 0;
  const release = () => {
    clearTimeout(timer);
    stream?.getTracks().forEach(track => track.stop());
    stream = undefined;
  };
  // Cancellation never sends recorded audio or retains a late transcript after changing account/call.
  const stop = () => {
    generation += 1;
    request?.abort();
    if (recorder?.state === 'recording') recorder.stop();
    release();
    listening.value = false;
    transcribing.value = false;
  };
  const start = async () => {
    error.value = '';
    if (!supported || inCall.value || transcribing.value) return;
    if (listening.value) {
      recorder?.stop();
      return;
    }
    stop();
    const current = generation;
    window.speechSynthesis?.cancel();
    try {
      const acquired = await navigator.mediaDevices.getUserMedia({
        audio: true,
      });
      if (current !== generation || inCall.value) {
        acquired.getTracks().forEach(track => track.stop());
        return;
      }
      stream = acquired;
      const mimeType = ['audio/webm', 'audio/mp4', 'audio/ogg'].find(type =>
        MediaRecorder.isTypeSupported(type)
      );
      if (!mimeType) throw new Error('unsupported_format');
      recorder = new MediaRecorder(stream, {
        mimeType,
        audioBitsPerSecond: 64000,
      });
      const chunks = [];
      let size = 0;
      recorder.ondataavailable = event => {
        size += event.data.size;
        if (size > 4194304) {
          stop();
          error.value = 'too_large';
        } else chunks.push(event.data);
      };
      recorder.onerror = () => {
        stop();
        error.value = 'recording_failed';
      };
      recorder.onstop = async () => {
        if (current !== generation) return;
        release();
        listening.value = false;
        transcribing.value = true;
        request = new AbortController();
        try {
          const { data } = await transcribe(
            new Blob(chunks, { type: mimeType }),
            request.signal
          );
          if (current === generation && !inCall.value) onTranscript(data.text);
        } catch (e) {
          if (current === generation && e.code !== 'ERR_CANCELED')
            error.value = 'transcription_failed';
        } finally {
          if (current === generation) transcribing.value = false;
        }
      };
      recorder.start(1000);
      listening.value = true;
      timer = setTimeout(
        () => recorder?.state === 'recording' && recorder.stop(),
        60000
      );
    } catch {
      stop();
      error.value = 'unavailable';
    }
  };
  const speak = text => {
    if (
      !speakingEnabled.value ||
      inCall.value ||
      !window.speechSynthesis ||
      !text
    )
      return;
    stop();
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text.slice(0, 1000));
    utterance.lang = 'pt-BR';
    window.speechSynthesis.speak(utterance);
  };
  watch(speakingEnabled, value => {
    if (!value) window.speechSynthesis?.cancel();
  });
  watch(inCall, value => {
    if (value) {
      stop();
      window.speechSynthesis?.cancel();
    }
  });
  onBeforeUnmount(() => {
    stop();
    window.speechSynthesis?.cancel();
  });
  return {
    supported,
    listening,
    transcribing,
    error,
    speakingEnabled,
    start,
    stop,
    speak,
  };
};
