import { mount, flushPromises } from '@vue/test-utils';
import { defineComponent, h, ref } from 'vue';
import ConnectionButton from '../ConnectionButton.vue';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';

vi.mock('dashboard/api/jrcBroker', () => ({ createJrcBrokerApi: vi.fn() }));
const DialogStub = defineComponent({
  setup(_, { slots, expose }) {
    const open = ref(false);
    expose({
      open: () => {
        open.value = true;
      },
      close: () => {
        open.value = false;
      },
    });
    return () => h('div', open.value ? slots.default?.() : []);
  },
});
let wrapper;
afterEach(() => {
  wrapper?.unmount();
  delete window.chatwootConfig;
});

it('requires a confirmed server binding rather than a name or arbitrary attribute', async () => {
  window.chatwootConfig = { jrcBrokerEnabled: true };
  const api = {
    status: vi.fn().mockResolvedValue({
      allowedActions: ['status', 'pair'],
      instanceStatus: 'DISCONNECTED',
    }),
  };
  createJrcBrokerApi.mockReturnValue(api);
  wrapper = mount(ConnectionButton, {
    props: {
      accountId: 1,
      inbox: {
        id: 2,
        name: 'JRC',
        additional_attributes: { jrc_broker: true },
      },
    },
    global: { stubs: { Dialog: DialogStub, ConnectionPanel: true } },
  });
  await flushPromises();
  expect(wrapper.find('button').exists()).toBe(false);
  expect(api.status).not.toHaveBeenCalled();
  await wrapper.setProps({ inbox: { id: 2, jrc_broker_bound: true } });
  await flushPromises();
  await wrapper.get('button').trigger('click');
  expect(wrapper.find('connection-panel-stub').exists()).toBe(true);
  await wrapper.setProps({
    accountId: 3,
    inbox: { id: 4, jrc_broker_bound: true },
  });
  await flushPromises();
  expect(wrapper.find('connection-panel-stub').exists()).toBe(false);
  expect(api.status).toHaveBeenCalledWith(4, expect.any(AbortSignal));
});
