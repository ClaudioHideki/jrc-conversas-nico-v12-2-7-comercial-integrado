import { beforeEach, describe, expect, it, vi } from 'vitest';
import { Invitation, Inviter, SessionState } from 'sip.js';
import { SipClient } from './SipClient';

vi.mock('sip.js', () => {
  function MockInvitation() {
    this.state = 'Initial';
    this.reject = vi.fn().mockResolvedValue(undefined);
  }

  function MockInviter() {
    this.state = 'Initial';
    this.cancel = vi.fn().mockResolvedValue(undefined);
    this.bye = vi.fn().mockResolvedValue(undefined);
  }

  return {
    Invitation: MockInvitation,
    Inviter: MockInviter,
    Registerer: function Registerer() {},
    RegistererState: { Registered: 'Registered' },
    SessionState: {
      Initial: 'Initial',
      Establishing: 'Establishing',
      Established: 'Established',
      Terminating: 'Terminating',
      Terminated: 'Terminated',
    },
    UserAgent: function UserAgent() {},
  };
});

describe('SipClient call lifecycle', () => {
  let client;

  beforeEach(() => {
    client = new SipClient();
  });

  it('cancels an outgoing call that has not been established', async () => {
    const session = new Inviter();
    session.state = SessionState.Establishing;
    client.session = session;

    await client.hangup();

    expect(session.cancel).toHaveBeenCalledOnce();
    expect(session.bye).not.toHaveBeenCalled();
  });

  it('sends BYE only for an established call', async () => {
    const session = new Inviter();
    session.state = SessionState.Established;
    client.session = session;

    await client.hangup();

    expect(session.bye).toHaveBeenCalledOnce();
    expect(session.cancel).not.toHaveBeenCalled();
  });

  it('rejects an incoming call without unregistering the extension', async () => {
    const session = new Invitation();
    client.session = session;

    await client.hangup();

    expect(session.reject).toHaveBeenCalledWith({ statusCode: 480 });
    expect(client.session).toBe(session);
  });

  it('blocks a second call while the first call is being created', async () => {
    client.transportConnected = true;
    client.registerer = { state: 'Registered' };
    client.callStarting = true;

    await expect(client.call('100')).rejects.toThrow(
      'Já existe uma chamada ativa'
    );
  });
});
