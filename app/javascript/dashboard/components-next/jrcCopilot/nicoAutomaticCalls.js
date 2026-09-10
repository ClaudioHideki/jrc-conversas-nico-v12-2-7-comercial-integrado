export const nextNicoAutomaticCall = (
  commands,
  { registered, inCall, attempted }
) => {
  if (!registered || inCall) return undefined;
  return [...commands]
    .reverse()
    .find(
      command =>
        command.status === 'browser_pending' &&
        command.authorization?.source === 'delegation' &&
        command.tool === 'call_contact' &&
        command.result?.browser_action === 'sip_call' &&
        !attempted.has(command.id)
    );
};
