import { effectScope, ref } from 'vue';
import { useNicoVoice, NICO_VOICE_REVIEW_MS } from '../useNicoVoice';

describe('NICO voice review and cancellation', () => {
  let scope;
  let voice;
  let recorder;
  let track;
  let inCall;
  let context;
  let canSubmit;
  let transcribe;
  let onTranscript;
  let onSubmit;
  let utterance;

  beforeEach(() => {
    vi.useFakeTimers();
    track = { stop: vi.fn() };
    class Recorder {
      static isTypeSupported() {
        return true;
      }

      constructor() {
        recorder = this;
        this.state = 'inactive';
      }

      start() {
        this.state = 'recording';
      }

      stop() {
        this.state = 'inactive';
        this.ondataavailable({ data: new Blob(['audio']) });
        this.onstop();
      }
    }
    vi.stubGlobal('MediaRecorder', Recorder);
    vi.stubGlobal('SpeechSynthesisUtterance', function Utterance(text) {
      return { text };
    });
    vi.stubGlobal('window', {
      MediaRecorder: Recorder,
      speechSynthesis: {
        cancel: vi.fn(),
        speak: vi.fn(value => {
          utterance = value;
          value.onstart();
        }),
      },
    });
    vi.stubGlobal('navigator', {
      mediaDevices: {
        getUserMedia: vi.fn().mockResolvedValue({ getTracks: () => [track] }),
      },
    });
    inCall = ref(false);
    context = ref('1:14');
    canSubmit = ref(true);
    transcribe = vi
      .fn()
      .mockResolvedValue({ data: { text: 'Crie um contato de teste' } });
    onTranscript = vi.fn();
    onSubmit = vi.fn();
    scope = effectScope();
    scope.run(() => {
      voice = useNicoVoice({
        onTranscript,
        onSubmit,
        transcribe,
        inCall,
        context,
        canSubmit,
      });
    });
  });
  afterEach(() => {
    scope.stop();
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('shows the transcript before submitting it exactly once after the review window', async () => {
    await voice.start();
    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledWith({
      audio: true,
    });
    expect(transcribe).not.toHaveBeenCalled();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    expect(onTranscript).toHaveBeenCalledWith('Crie um contato de teste');
    expect(voice.reviewing.value).toBe(true);
    expect(track.stop).toHaveBeenCalledOnce();
    await recorder.onstop();
    await vi.advanceTimersByTimeAsync(NICO_VOICE_REVIEW_MS - 1);
    expect(onSubmit).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(onSubmit).toHaveBeenCalledExactlyOnceWith(
      'Crie um contato de teste'
    );
    await vi.advanceTimersByTimeAsync(5000);
    expect(onSubmit).toHaveBeenCalledOnce();
    expect(transcribe).toHaveBeenCalledOnce();
  });

  it('editing or cancelling review keeps the transcript available and prevents auto submit', async () => {
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    voice.cancelReview();
    await vi.advanceTimersByTimeAsync(2000);
    expect(voice.reviewing.value).toBe(false);
    expect(onTranscript).toHaveBeenCalledOnce();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('does not request a second microphone while permission is pending and releases a late stream', async () => {
    let grant;
    navigator.mediaDevices.getUserMedia.mockImplementation(
      () =>
        new Promise(resolve => {
          grant = resolve;
        })
    );
    const starting = voice.start();
    await voice.start();
    expect(voice.requesting.value).toBe(true);
    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledOnce();
    voice.stop();
    grant({ getTracks: () => [track] });
    await starting;
    expect(track.stop).toHaveBeenCalledOnce();
    expect(voice.listening.value).toBe(false);
    expect(transcribe).not.toHaveBeenCalled();
  });

  it('an incoming call cancels capture without uploading audio', async () => {
    await voice.start();
    inCall.value = true;
    expect(voice.listening.value).toBe(false);
    expect(track.stop).toHaveBeenCalledOnce();
    expect(transcribe).not.toHaveBeenCalled();
    await voice.start();
    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledOnce();
  });

  it('a call during review prevents automatic submission', async () => {
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    inCall.value = true;
    await vi.advanceTimersByTimeAsync(2000);
    expect(onSubmit).not.toHaveBeenCalled();
    expect(voice.reviewing.value).toBe(false);
  });

  it('account or conversation changes abort upload and ignore the late transcript', async () => {
    let resolve;
    transcribe.mockImplementation(
      () =>
        new Promise(done => {
          resolve = done;
        })
    );
    await voice.start();
    await voice.start();
    const signal = transcribe.mock.calls[0][1];
    context.value = '2:8';
    expect(signal.aborted).toBe(true);
    resolve({ data: { text: 'Pedido da conta anterior' } });
    await vi.advanceTimersByTimeAsync(2000);
    expect(onTranscript).not.toHaveBeenCalled();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('changing context during review cancels its timer', async () => {
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    context.value = '1:15';
    await vi.advanceTimersByTimeAsync(2000);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('closing the voice scope cancels the pending review', async () => {
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    scope.stop();
    await vi.advanceTimersByTimeAsync(2000);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('rejects audio over 4 MB without uploading', async () => {
    await voice.start();
    recorder.ondataavailable({ data: new Blob([new Uint8Array(4194305)]) });
    expect(voice.error.value).toBe('too_large');
    expect(track.stop).toHaveBeenCalledOnce();
    expect(transcribe).not.toHaveBeenCalled();
  });

  it('ends capture at 60 seconds and sends the bounded recording for review', async () => {
    await voice.start();
    await vi.advanceTimersByTimeAsync(60000);
    expect(voice.listening.value).toBe(false);
    expect(transcribe).toHaveBeenCalledOnce();
    expect(voice.reviewing.value).toBe(true);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('does not submit when the planner is busy at the end of review', async () => {
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    canSubmit.value = false;
    await vi.advanceTimersByTimeAsync(2000);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('reports an empty transcript instead of sending an empty request', async () => {
    transcribe.mockResolvedValue({ data: { text: '   ' } });
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(2000);
    expect(voice.error.value).toBe('empty_transcript');
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('reports transcription failure and releases the microphone', async () => {
    transcribe.mockRejectedValue(new Error('unavailable'));
    await voice.start();
    await voice.start();
    await vi.advanceTimersByTimeAsync(0);
    expect(voice.error.value).toBe('transcription_failed');
    expect(voice.transcribing.value).toBe(false);
    expect(track.stop).toHaveBeenCalledOnce();
  });

  it('keeps spoken responses optional and exposes speaking and stop controls', async () => {
    voice.speak('Resposta');
    expect(window.speechSynthesis.speak).not.toHaveBeenCalled();
    voice.setSpeakingEnabled(true);
    voice.speak('Resposta');
    expect(voice.speaking.value).toBe(true);
    const previous = utterance;
    voice.stopSpeaking();
    expect(voice.speaking.value).toBe(false);
    voice.speak('Nova resposta');
    previous.onend();
    expect(voice.speaking.value).toBe(true);
    utterance.onend();
    expect(voice.speaking.value).toBe(false);
  });

  it('a new recording or call interrupts speech and prevents speech during calls', async () => {
    voice.setSpeakingEnabled(true);
    voice.speak('Resposta');
    await voice.start();
    expect(voice.speaking.value).toBe(false);
    voice.stop();
    voice.speak('Outra resposta');
    inCall.value = true;
    expect(voice.speaking.value).toBe(false);
    const count = window.speechSynthesis.speak.mock.calls.length;
    voice.speak('Não deve falar');
    expect(window.speechSynthesis.speak).toHaveBeenCalledTimes(count);
  });
});
