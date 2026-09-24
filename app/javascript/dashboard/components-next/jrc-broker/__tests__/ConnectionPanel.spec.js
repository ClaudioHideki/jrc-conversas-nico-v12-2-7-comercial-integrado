import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConnectionPanel from '../ConnectionPanel.vue';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';

vi.mock('dashboard/api/jrcBroker', () => ({ createJrcBrokerApi: vi.fn() }));
const health = {
  instanceStatus: 'DISCONNECTED',
  integrationStatus: 'READY',
  transportStatus: 'UNVERIFIED',
  identityStatus: 'UNVERIFIED',
  allowedActions: ['status', 'pair'],
};
let api;
let wrapper;

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2030-01-01T00:00:00Z'));
  api = {
    status: vi.fn().mockResolvedValue({ ...health }),
    pair: vi.fn().mockResolvedValue({
      action: {
        type: 'PAIRING_CODE',
        code: 'ABCD-1234',
        expiresAt: '2030-01-01T00:00:10Z',
      },
    }),
  };
  createJrcBrokerApi.mockReturnValue(api);
});
afterEach(() => {
  wrapper?.unmount();
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe('native pairing lifecycle', () => {
  it('retrieves an asynchronous QR using the same intent and stops after receiving it', async () => {
    api.pair.mockResolvedValueOnce({
      action: { type: 'NONE', reason: 'CONNECTION_PENDING' },
    });
    wrapper = mount(ConnectionPanel, { props: { accountId: 1, inboxId: 2 } });
    await flushPromises();
    await wrapper.get('[data-testid="pair"]').trigger('click');
    await flushPromises();
    await vi.advanceTimersByTimeAsync(3000);
    expect(api.pair).toHaveBeenCalledTimes(2);
    expect(api.pair.mock.calls[1][1]).toBe(api.pair.mock.calls[0][1]);
    expect(wrapper.text()).toContain('ABCD-1234');
    await vi.advanceTimersByTimeAsync(3000);
    expect(api.pair).toHaveBeenCalledTimes(2);
  });
  it('suspends polling while hidden and clears the code on logout', async () => {
    const store = createStore({ mutations: { LOGOUT: () => {} } });
    wrapper = mount(ConnectionPanel, {
      props: { accountId: 1, inboxId: 2 },
      global: { plugins: [store] },
    });
    await flushPromises();
    await wrapper.get('[data-testid="pair"]').trigger('click');
    await flushPromises();
    vi.spyOn(document, 'hidden', 'get').mockReturnValue(true);
    document.dispatchEvent(new Event('visibilitychange'));
    const calls = api.status.mock.calls.length;
    await vi.advanceTimersByTimeAsync(5000);
    expect(api.status).toHaveBeenCalledTimes(calls);
    store.commit('LOGOUT');
    await flushPromises();
    expect(wrapper.text()).not.toContain('ABCD-1234');
    wrapper.unmount();
    await vi.advanceTimersByTimeAsync(15000);
    expect(api.status).toHaveBeenCalledTimes(calls);
  });

  it('requires fresh confirmation if the observed business identity changes while the dialog is open', async () => {
    api.status.mockResolvedValue({
      ...health,
      allowedActions: ['status', 'manage'],
      identityStatus: 'CONFIRMATION_REQUIRED',
      identityRevision: 2,
      observedNumberSuffix: '1111',
    });
    wrapper = mount(ConnectionPanel, { props: { accountId: 1, inboxId: 2 } });
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Confirm business number')
      .trigger('click');
    await wrapper.get('input[type="checkbox"]').setValue(true);
    api.status.mockResolvedValue({
      ...health,
      allowedActions: ['status', 'manage'],
      identityStatus: 'CONFIRMATION_REQUIRED',
      identityRevision: 3,
      observedNumberSuffix: '2222',
    });
    await vi.advanceTimersByTimeAsync(3000);
    expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);
  });

  it('removes a displayed code when the next status no longer grants pair', async () => {
    wrapper = mount(ConnectionPanel, { props: { accountId: 1, inboxId: 2 } });
    await flushPromises();
    await wrapper.get('[data-testid="pair"]').trigger('click');
    await flushPromises();
    api.status.mockResolvedValue({ ...health, allowedActions: ['status'] });
    await vi.advanceTimersByTimeAsync(3000);
    expect(wrapper.text()).not.toContain('ABCD-1234');
    expect(wrapper.find('[data-testid="pair"]').exists()).toBe(false);
  });

  it('polls only GET, requires an explicit click and removes an expired code', async () => {
    wrapper = mount(ConnectionPanel, { props: { accountId: 1, inboxId: 2 } });
    await flushPromises();
    expect(api.pair).not.toHaveBeenCalled();
    await wrapper.get('[data-testid="pair"]').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('ABCD-1234');
    await vi.advanceTimersByTimeAsync(11000);
    expect(wrapper.text()).not.toContain('ABCD-1234');
    expect(api.pair).toHaveBeenCalledTimes(1);
    expect(api.status.mock.calls.length).toBeGreaterThan(1);
  });

  it('discards a late pair response after changing account or inbox', async () => {
    let finish;
    api.pair.mockImplementation(
      () =>
        new Promise(resolve => {
          finish = resolve;
        })
    );
    wrapper = mount(ConnectionPanel, { props: { accountId: 1, inboxId: 2 } });
    await flushPromises();
    await wrapper.get('[data-testid="pair"]').trigger('click');
    await wrapper.setProps({ accountId: 3, inboxId: 4 });
    await flushPromises();
    finish({
      action: {
        type: 'PAIRING_CODE',
        code: 'STALE',
        expiresAt: '2030-01-01T00:00:30Z',
      },
    });
    await flushPromises();
    expect(wrapper.text()).not.toContain('STALE');
  });

  it('clears codes on connection, denied permission and unmount, and stops polling on forbidden', async () => {
    wrapper = mount(ConnectionPanel, { props: { accountId: 1, inboxId: 2 } });
    await flushPromises();
    await wrapper.get('[data-testid="pair"]').trigger('click');
    await flushPromises();
    api.status.mockResolvedValue({ ...health, instanceStatus: 'CONNECTED' });
    await vi.advanceTimersByTimeAsync(3000);
    expect(wrapper.text()).not.toContain('ABCD-1234');
    api.status.mockRejectedValue({ response: { status: 403 } });
    await vi.advanceTimersByTimeAsync(3000);
    const calls = api.status.mock.calls.length;
    await vi.advanceTimersByTimeAsync(15000);
    expect(api.status).toHaveBeenCalledTimes(calls);
    expect(wrapper.find('[data-testid="pair"]').exists()).toBe(false);
    wrapper.unmount();
    await vi.advanceTimersByTimeAsync(15000);
    expect(api.status).toHaveBeenCalledTimes(calls);
  });
});
