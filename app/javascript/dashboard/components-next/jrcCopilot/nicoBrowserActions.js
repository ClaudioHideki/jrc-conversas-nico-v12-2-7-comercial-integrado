// Only actions emitted by the authenticated, reviewed command endpoint reach this bridge.
export const runNicoBrowserAction = async (action, { sip, openVideo }) => {
  if (action.browser_action === 'video') {
    const result = await openVideo();
    if (result.status !== 'opened')
      throw new Error(
        'Não foi possível abrir a sala. Verifique a configuração e o bloqueio de pop-ups.'
      );
    return 'Sala aberta nesta aba.';
  }
  if (action.browser_action === 'sip_call') {
    if (!sip.registered.value)
      throw new Error(
        'O ramal não está registrado. A ligação não foi iniciada.'
      );
    if (sip.hasCall.value)
      throw new Error('Já existe uma chamada em andamento.');
    sip.destination.value = action.phone_number;
    await sip.call();
    if (sip.errorMessage.value) throw new Error(sip.errorMessage.value);
    return 'Discagem solicitada. Acompanhe o estado da chamada no ramal.';
  }
  if (action.browser_action !== 'sip_control')
    throw new Error('Ação de navegador desconhecida.');
  const controls = {
    answer: () => sip.answer(),
    reject: () => sip.reject(),
    hangup: () => sip.hangup(),
    mute: () => sip.setMuted(true),
    unmute: () => sip.setMuted(false),
    hold: () => sip.setHold(true),
    unhold: () => sip.setHold(false),
    transfer: () => sip.transferCall('blind', action.destination),
  };
  if (!controls[action.action])
    throw new Error('Controle de chamada desconhecido.');
  if (!sip.hasCall.value)
    throw new Error('Não há chamada ativa para controlar.');
  await controls[action.action]();
  if (sip.errorMessage.value) throw new Error(sip.errorMessage.value);
  return 'Comando enviado ao ramal. Acompanhe o estado no controle de chamadas.';
};
