import { effectScope, ref, nextTick } from 'vue';
import { useNicoVoice } from '../useNicoVoice';

describe('NICO push-to-talk lifecycle', () => {
  let scope;
  let recorder;
  let track;
  let transcript;
  let transcribe;
  let inCall;
  let voice;
  beforeEach(() => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
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
        this.ondataavailable({ data: new Blob(['test recording data']) });
        this.onstop();
      }
    }
    vi.stubGlobal('MediaRecorder', Recorder);
    vi.stubGlobal('window', {
      MediaRecorder: Recorder,
      speechSynthesis: { cancel: vi.fn() },
    });
    vi.stubGlobal('navigator', {
      mediaDevices: {
        getUserMedia: vi.fn().mockResolvedValue({ getTracks: () => [track] }),
      },
    });
    transcript = vi.fn();
    transcribe = vi
      .fn()
      .mockResolvedValue({ data: { text: 'Crie um contato' } });
    inCall = ref(false);
    scope = effectScope();
    scope.run(() => {
      voice = useNicoVoice({ onTranscript: transcript, transcribe, inCall });
    });
  });
  afterEach(() => {
    voice.stop();
    scope.stop();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });
  it('uploads only on explicit stop and only returns editable text', async () => {
    await voice.start();
    expect(transcribe).not.toHaveBeenCalled();
    await voice.start();
    await nextTick();
    expect(transcribe).toHaveBeenCalledOnce();
    expect(transcript).toHaveBeenCalledWith('Crie um contato');
    expect(track.stop).toHaveBeenCalled();
  });
  it('cancels a recording without uploading it', async () => {
    await voice.start();
    voice.stop();
    expect(transcribe).not.toHaveBeenCalled();
    expect(track.stop).toHaveBeenCalled();
  });
  it('stops capture for a call and rejects late transcription after cancellation', async () => {
    let complete;
    transcribe.mockImplementation(
      () =>
        new Promise(resolve => {
          complete = resolve;
        })
    );
    await voice.start();
    await voice.start();
    inCall.value = true;
    await nextTick();
    complete({ data: { text: 'Comando atrasado' } });
    await nextTick();
    expect(transcript).not.toHaveBeenCalled();
    expect(voice.transcribing.value).toBe(false);
    await voice.start();
    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledOnce();
  });
});
