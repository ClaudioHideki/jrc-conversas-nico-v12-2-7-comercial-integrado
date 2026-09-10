import { createNicoRunSession } from '../nicoRunSession';

describe('NICO run session', () => {
  afterEach(() => vi.useRealTimers());

  it('sends the chosen specialist and does not reuse another specialist request', async () => {
    const api = { create: vi.fn().mockRejectedValue(new Error('Network')) };
    const session = createNicoRunSession(api, 7, 12, vi.fn());
    await session.start('Analise', 'comercial');
    await session.start('Analise', 'financeiro');
    expect(api.create.mock.calls[0][1].agent_key).toBe('comercial');
    expect(api.create.mock.calls[1][1].agent_key).toBe('financeiro');
    expect(api.create.mock.calls[0][1].request_id).not.toBe(
      api.create.mock.calls[1][1].request_id
    );
    session.dispose();
  });

  it('does not render a late response after account or conversation disposal', async () => {
    let resolve;
    const api = {
      create: vi.fn(
        () =>
          new Promise(done => {
            resolve = done;
          })
      ),
    };
    const update = vi.fn();
    const session = createNicoRunSession(api, 7, 12, update);
    const pending = session.start('Resumo');
    session.dispose();
    update.mockClear();
    resolve({
      data: { id: 3, status: 'completed', result: { summary: 'Private' } },
    });
    await pending;
    expect(update).not.toHaveBeenCalled();
  });

  it('keeps the original account when polling and stops after completion', async () => {
    vi.useFakeTimers();
    const api = {
      create: vi.fn().mockResolvedValue({ data: { id: 3, status: 'queued' } }),
      show: vi.fn().mockResolvedValue({ data: { id: 3, status: 'completed' } }),
    };
    const session = createNicoRunSession(api, 7, 12, vi.fn());
    await session.start('Resumo');
    await vi.advanceTimersByTimeAsync(1000);
    expect(api.show.mock.calls[0].slice(0, 2)).toEqual([7, 3]);
    await vi.advanceTimersByTimeAsync(10000);
    expect(api.show).toHaveBeenCalledTimes(1);
    session.dispose();
  });

  it('reuses the request id after a lost create response', async () => {
    const api = {
      create: vi
        .fn()
        .mockRejectedValueOnce(new Error('Network'))
        .mockResolvedValueOnce({ data: { id: 3, status: 'completed' } }),
    };
    const session = createNicoRunSession(api, 7, 12, vi.fn());
    await session.start('Resumo');
    await session.start('Resumo');
    expect(api.create.mock.calls[0][1].request_id).toBe(
      api.create.mock.calls[1][1].request_id
    );
    session.dispose();
  });
});
