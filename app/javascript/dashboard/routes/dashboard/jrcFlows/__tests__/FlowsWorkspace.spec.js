import { mount } from '@vue/test-utils';
import { ref, nextTick } from 'vue';
import { createStore } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';
import FlowsWorkspace from '../FlowsWorkspace.vue';

vi.mock('dashboard/composables/useAccount', () => ({ useAccount: vi.fn() }));
vi.mock('../FlowsPage.vue', () => ({
  default: { name: 'FlowsPage', template: '<div data-test="editor" />' },
}));
vi.mock('../AgentFlowsPage.vue', () => ({
  default: { name: 'AgentFlowsPage', template: '<div data-test="agent" />' },
}));

let wrapper;
let accountId;
let currentAccount;
let store;
beforeEach(() => {
  accountId = ref(1);
  currentAccount = ref({ features: { jrc_flows: true, jrc_broker: true } });
  useAccount.mockReturnValue({
    accountId,
    currentAccount,
    accountScopedRoute: name => ({ name }),
  });
  window.chatwootConfig = { jrcFlowsEnabled: true, jrcBrokerEnabled: true };
  store = createStore({
    state: () => ({ role: 'administrator', customRole: null }),
    getters: {
      getCurrentRole: state => state.role,
      getCurrentCustomRoleId: state => state.customRole,
    },
  });
});
afterEach(() => {
  wrapper?.unmount();
  delete window.chatwootConfig;
});

it('gives only administrators the editor and keeps the Broker route available', async () => {
  wrapper = mount(FlowsWorkspace, {
    global: { plugins: [store], stubs: { RouterLink: true } },
  });
  expect(wrapper.find('[data-test="editor"]').exists()).toBe(true);
  expect(
    wrapper.findComponent({ name: 'RouterLink' }).attributes('to')
  ).toBeDefined();
  store.state.role = 'agent';
  await nextTick();
  expect(wrapper.find('[data-test="editor"]').exists()).toBe(false);
  expect(wrapper.find('[data-test="agent"]').exists()).toBe(true);
});

it('hides the module when the account feature is removed', async () => {
  wrapper = mount(FlowsWorkspace, {
    global: { plugins: [store], stubs: { RouterLink: true } },
  });
  currentAccount.value = { features: { jrc_flows: false } };
  await nextTick();
  expect(wrapper.find('[data-test="editor"]').exists()).toBe(false);
  expect(wrapper.find('[data-test="agent"]').exists()).toBe(false);
});

it('remounts on account switch so prior account editor state cannot remain visible', async () => {
  wrapper = mount(FlowsWorkspace, {
    global: { plugins: [store], stubs: { RouterLink: true } },
  });
  const previous = wrapper.findComponent({ name: 'FlowsPage' }).vm;
  accountId.value = 2;
  await nextTick();
  expect(wrapper.findComponent({ name: 'FlowsPage' }).vm).not.toBe(previous);
});
