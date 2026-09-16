import { mount, flushPromises } from '@vue/test-utils';
import GrantsPanel from '../GrantsPanel.vue';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';

vi.mock('dashboard/api/jrcBroker', () => ({ createJrcBrokerApi: vi.fn() }));

it('sends only selected inbox member IDs and keeps grant editing out of the connection panel', async () => {
  const members = [{ user_id: 7, name: 'Synthetic agent', can_pair: true }];
  const api = {
    grants: vi.fn().mockResolvedValue({ data: members }),
    updateGrants: vi.fn().mockResolvedValue({ data: members }),
  };
  createJrcBrokerApi.mockReturnValue(api);
  const wrapper = mount(GrantsPanel, { props: { accountId: 1, inboxId: 2 } });
  await flushPromises();
  await wrapper.get('input[type="checkbox"]').setValue(false);
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(api.updateGrants).toHaveBeenCalledWith(2, [], expect.any(AbortSignal));
  expect(wrapper.find('input[type="password"]').exists()).toBe(false);
  wrapper.unmount();
});
