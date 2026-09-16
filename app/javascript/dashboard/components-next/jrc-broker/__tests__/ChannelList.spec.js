import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import ChannelList from 'dashboard/routes/dashboard/settings/inbox/ChannelList.vue';
import { useAccount } from 'dashboard/composables/useAccount';

vi.mock('dashboard/composables/useAccount', () => ({ useAccount: vi.fn() }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('dashboard/composables/store', () => ({ useMapGetter: () => ref({}) }));

it('shows the native channel only when both installation and account flags are enabled', () => {
  const previous = window.chatwootConfig;
  [
    [false, true],
    [true, false],
    [true, true],
  ].forEach(([installation, account]) => {
    window.chatwootConfig = { jrcBrokerEnabled: installation };
    useAccount.mockReturnValue({
      accountId: ref(1),
      currentAccount: ref({ features: { jrc_broker: account } }),
    });
    const wrapper = mount(ChannelList, {
      global: { stubs: { ChannelItem: true } },
    });
    const card = wrapper
      .findAllComponents({ name: 'ChannelItem' })
      .find(value => value.props('channel').key === 'jrc_broker');
    expect(Boolean(card)).toBe(installation && account);
    wrapper.unmount();
  });
  window.chatwootConfig = previous;
});
