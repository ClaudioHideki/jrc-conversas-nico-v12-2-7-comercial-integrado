import { describe, expect, it } from 'vitest';
import { nextNicoAutomaticCall } from '../nicoAutomaticCalls';

const call = {
  id: 1,
  tool: 'call_contact',
  status: 'browser_pending',
  authorization: { source: 'delegation' },
  result: { browser_action: 'sip_call' },
};
const ready = { registered: true, inCall: false, attempted: new Set() };

describe('delegated Nico calls', () => {
  it('requires a registered idle ramal', () => {
    expect(
      nextNicoAutomaticCall([call], { ...ready, registered: false })
    ).toBeUndefined();
    expect(
      nextNicoAutomaticCall([call], { ...ready, inCall: true })
    ).toBeUndefined();
    expect(nextNicoAutomaticCall([call], ready)).toEqual(call);
  });
  it('does not start manual commands or other browser operations automatically', () => {
    expect(
      nextNicoAutomaticCall(
        [{ ...call, authorization: { source: 'operator' } }],
        ready
      )
    ).toBeUndefined();
    expect(
      nextNicoAutomaticCall([{ ...call, tool: 'whatsapp_call' }], ready)
    ).toBeUndefined();
  });
  it('does not retry an attempted or cancelled call', () => {
    expect(
      nextNicoAutomaticCall([call], { ...ready, attempted: new Set([1]) })
    ).toBeUndefined();
    expect(
      nextNicoAutomaticCall([{ ...call, status: 'cancelled' }], ready)
    ).toBeUndefined();
  });
  it('starts the oldest eligible call first', () => {
    expect(nextNicoAutomaticCall([{ ...call, id: 2 }, call], ready)?.id).toBe(
      1
    );
  });
});
