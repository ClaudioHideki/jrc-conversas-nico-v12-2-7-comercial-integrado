import { runNicoBrowserAction } from '../nicoBrowserActions';

describe('NICO browser actions', () => {
  const makeSip = () => ({
    registered: { value: true },
    hasCall: { value: false },
    destination: { value: '' },
    errorMessage: { value: '' },
    call: vi.fn(),
    hangup: vi.fn(),
  });
  it('does not dial when the extension is disconnected', async () => {
    const sip = makeSip();
    sip.registered.value = false;
    await expect(
      runNicoBrowserAction(
        { browser_action: 'sip_call', phone_number: '+5511991234567' },
        { sip }
      )
    ).rejects.toThrow('não está registrado');
    expect(sip.call).not.toHaveBeenCalled();
  });
  it('does not start another call while a call exists', async () => {
    const sip = makeSip();
    sip.hasCall.value = true;
    await expect(
      runNicoBrowserAction(
        { browser_action: 'sip_call', phone_number: '+5511991234567' },
        { sip }
      )
    ).rejects.toThrow('em andamento');
    expect(sip.call).not.toHaveBeenCalled();
  });
  it('uses the reviewed destination and propagates softphone errors', async () => {
    const sip = makeSip();
    sip.call.mockImplementation(() => {
      sip.errorMessage.value = 'Microfone negado';
    });
    await expect(
      runNicoBrowserAction(
        { browser_action: 'sip_call', phone_number: '+5511991234567' },
        { sip }
      )
    ).rejects.toThrow('Microfone negado');
    expect(sip.destination.value).toBe('+5511991234567');
  });
  it('does not report an unavailable video room as opened', async () => {
    await expect(
      runNicoBrowserAction(
        { browser_action: 'video' },
        { openVideo: async () => ({ status: 'unavailable' }) }
      )
    ).rejects.toThrow('Não foi possível');
  });
});
