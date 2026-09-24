import { mount, flushPromises } from '@vue/test-utils';
import OnboardingFlow from '../OnboardingFlow.vue';
import { createJrcBrokerApi } from 'dashboard/api/jrcBroker';

vi.mock('dashboard/api/jrcBroker', () => ({ createJrcBrokerApi: vi.fn() }));
let api;
let wrapper;
beforeEach(() => {
  api = {
    resources: vi
      .fn()
      .mockResolvedValue({ providers: [], instances: [], agents: [] }),
    operations: vi.fn().mockResolvedValue({ data: [] }),
    create: vi.fn(),
    operation: vi.fn(),
  };
  createJrcBrokerApi.mockReturnValue(api);
});
afterEach(() => wrapper?.unmount());

it('adopts an existing connection without creating an onboarding', async () => {
  api.resources.mockResolvedValue({
    providers: [],
    instances: [],
    agents: [],
    connections: [
      { integrationId: 'existing', name: 'Existing inbox', inboxId: 2 },
    ],
  });
  api.adopt = vi.fn().mockResolvedValue({ inboxId: 2 });
  wrapper = mount(OnboardingFlow, {
    props: { accountId: 1 },
    global: { stubs: { ConnectionPanel: true, RouterLink: true } },
  });
  await flushPromises();
  await wrapper
    .findAll('button')
    .find(button => button.text().includes('Existing inbox'))
    .trigger('click');
  await flushPromises();
  expect(api.adopt).toHaveBeenCalledWith('existing', expect.any(AbortSignal));
  expect(api.create).not.toHaveBeenCalled();
  expect(wrapper.find('connection-panel-stub').exists()).toBe(true);
});

it('waits for the Rails binding check before displaying a previously completed connection', async () => {
  const completed = {
    operationId: 'synthetic-operation',
    state: 'SUCCEEDED',
    stage: 'DONE',
    inboxId: 2,
  };
  api.operations.mockResolvedValue({ data: [completed] });
  let finish;
  api.operation.mockImplementation(
    () =>
      new Promise(resolve => {
        finish = resolve;
      })
  );
  wrapper = mount(OnboardingFlow, {
    props: { accountId: 1 },
    global: { stubs: { RouterLink: true, ConnectionPanel: true } },
  });
  await flushPromises();
  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Resume')
    .trigger('click');
  await flushPromises();
  expect(wrapper.find('connection-panel-stub').exists()).toBe(false);
  finish(completed);
  await flushPromises();
  expect(wrapper.find('connection-panel-stub').exists()).toBe(true);
});

it('allows correcting a rejected request instead of permanently retrying the invalid body', async () => {
  api.create.mockRejectedValue({ response: { status: 400 } });
  wrapper = mount(OnboardingFlow, {
    props: { accountId: 1 },
    global: { stubs: { RouterLink: true } },
  });
  await flushPromises();
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(wrapper.get('fieldset').attributes('disabled')).toBeUndefined();
});

it('keeps a single intent during double submit and retries the same intent after uncertainty', async () => {
  let fail;
  api.create.mockImplementation(
    () =>
      new Promise((_, reject) => {
        fail = reject;
      })
  );
  wrapper = mount(OnboardingFlow, {
    props: { accountId: 1 },
    global: { stubs: { RouterLink: true } },
  });
  await flushPromises();
  await wrapper.get('form').trigger('submit');
  await wrapper.get('form').trigger('submit');
  expect(api.create).toHaveBeenCalledTimes(1);
  const [body, key] = api.create.mock.calls[0];
  fail(new Error('timeout'));
  await flushPromises();
  await wrapper.get('form').trigger('submit');
  expect(api.create).toHaveBeenCalledTimes(2);
  expect(api.create.mock.calls[1].slice(0, 2)).toEqual([body, key]);
  fail(new Error('timeout'));
  await flushPromises();
});

it('resumes a persisted operation through GET and does not create a second inbox', async () => {
  const operation = {
    operationId: 'synthetic-operation',
    state: 'UNKNOWN',
    stage: 'LINK_INBOX',
  };
  api.operations.mockResolvedValue({ data: [operation] });
  api.operation.mockResolvedValue(operation);
  wrapper = mount(OnboardingFlow, {
    props: { accountId: 1 },
    global: { stubs: { RouterLink: true } },
  });
  await flushPromises();
  const resume = wrapper
    .findAll('button')
    .find(button => button.text() === 'Resume');
  await resume.trigger('click');
  await flushPromises();
  expect(api.operation).toHaveBeenCalledWith(
    operation.operationId,
    expect.any(AbortSignal)
  );
  expect(api.create).not.toHaveBeenCalled();
  expect(wrapper.text()).toContain('Needs reconciliation');
});
