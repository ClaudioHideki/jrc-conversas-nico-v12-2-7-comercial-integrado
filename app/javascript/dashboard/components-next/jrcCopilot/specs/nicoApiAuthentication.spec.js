import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import runs from '../../../api/jrcNico';
import knowledge from '../../../api/jrcNicoKnowledge';
import proposals from '../../../api/jrcNicoProposals';

// The package singleton has no JRC session. Only the application's client does.
vi.mock('axios', () => ({
  default: {
    get: () => Promise.reject(new Error('Unauthenticated client')),
    post: () => Promise.reject(new Error('Unauthenticated client')),
  },
}));

describe('NICO authenticated transport', () => {
  let client;
  beforeEach(() => {
    client = {
      get: vi.fn().mockResolvedValue({ data: [] }),
      post: vi.fn().mockResolvedValue({ data: { id: 1 } }),
    };
    vi.stubGlobal('axios', client);
  });
  afterEach(() => vi.unstubAllGlobals());

  it('loads conversation runs through the signed-in JRC client', async () => {
    const signal = new AbortController().signal;
    await runs.index(42, 7, signal);
    expect(client.get).toHaveBeenCalledWith(
      '/api/v1/accounts/42/jrc_nico/runs',
      {
        params: { conversation_id: 7 },
        signal,
      }
    );
  });

  it('loads account knowledge through the signed-in JRC client', async () => {
    await knowledge.index(42);
    expect(client.get).toHaveBeenCalledWith(
      '/api/v1/accounts/42/jrc_nico/knowledge_documents',
      { signal: undefined }
    );
  });

  it('approves proposals through the signed-in JRC client', async () => {
    await proposals.approve(42, 9, 'reviewed-digest');
    expect(client.post).toHaveBeenCalledWith(
      '/api/v1/accounts/42/jrc_nico/proposals/9/approve',
      { digest: 'reviewed-digest' },
      { signal: undefined }
    );
  });
});
