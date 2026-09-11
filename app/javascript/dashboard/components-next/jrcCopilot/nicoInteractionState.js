// Presentation only: completion always comes from the existing command snapshot.
export const nicoInteractionState = ({
  voice,
  busy,
  phase,
  error,
  command,
}) => {
  if (voice.error.value || error) return 'error';
  if (voice.requesting.value) return 'requesting';
  if (voice.listening.value) return 'listening';
  if (voice.transcribing.value) return 'transcribing';
  if (voice.reviewing.value) return 'reviewing';
  if (busy) return phase;
  if (voice.speaking.value) return 'speaking';
  // The planner also marks clarification replies as succeeded, without executing a tool.
  if (command?.status === 'succeeded' && !command.tool) return 'answered';
  const states = {
    planning: 'submitting',
    awaiting_confirmation: 'confirmation',
    browser_pending: 'confirmation',
    executing: 'working',
    unknown: 'unknown',
    failed: 'error',
    succeeded: 'success',
    cancelled: 'cancelled',
  };
  return states[command?.status] || 'idle';
};

export const nicoTimeline = state => {
  if (state === 'confirmation') return ['received', 'prepared', 'confirmation'];
  if (
    [
      'submitting',
      'working',
      'success',
      'answered',
      'error',
      'unknown',
      'cancelled',
    ].includes(state)
  )
    return ['received', state];
  return [];
};
