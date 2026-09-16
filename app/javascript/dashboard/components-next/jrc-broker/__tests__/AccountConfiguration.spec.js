import { mount, flushPromises } from '@vue/test-utils';
import AccountConfiguration from '../AccountConfiguration.vue';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';

vi.mock('dashboard/api/jrcBroker', () => ({ createJrcBrokerApi: vi.fn() }));

it('clears the input after saving and never receives a stored credential back', async () => {
  const api = {
    configuration: vi.fn().mockResolvedValue({
      configured: false,
      allowedOrigins: ['https://broker.example.test'],
    }),
    configure: vi.fn().mockResolvedValue({
      configured: true,
      has_credential: true,
      allowedOrigins: ['https://broker.example.test'],
    }),
  };
  createJrcBrokerApi.mockReturnValue(api);
  const wrapper = mount(AccountConfiguration, { props: { accountId: 1 } });
  await flushPromises();
  await wrapper.get('input[type="password"]').setValue('synthetic-ui-secret');
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(api.configure.mock.calls[0][0].controlKey).toBe('synthetic-ui-secret');
  expect(wrapper.find('input[type="password"]').exists()).toBe(false);
  await wrapper.get('button').trigger('click');
  expect(wrapper.get('input[type="password"]').element.value).toBe('');
  expect(wrapper.html()).not.toContain('synthetic-ui-secret');
  wrapper.unmount();
});
