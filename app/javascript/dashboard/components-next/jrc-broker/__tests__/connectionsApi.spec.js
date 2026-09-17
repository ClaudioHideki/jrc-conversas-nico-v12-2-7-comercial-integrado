import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';

afterEach(() => vi.unstubAllGlobals());

it('loads inboxes from the authenticated Rails origin and retains the captured account', async () => {
  const request = vi.fn().mockResolvedValue({ data: { payload: [] } });
  vi.stubGlobal('axios', request);
  const first = createJrcBrokerApi(1);
  const second = createJrcBrokerApi(2);
  const signal = new AbortController().signal;
  await second.inboxes(signal);
  await first.inboxes(signal);
  expect(request.mock.calls.map(([value]) => value.url)).toEqual([
    '/api/v1/accounts/2/inboxes',
    '/api/v1/accounts/1/inboxes',
  ]);
  expect(request).toHaveBeenLastCalledWith({
    method: 'get',
    url: '/api/v1/accounts/1/inboxes',
    signal,
  });
});
