import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mockRoute } from 'vue-router';
import { mockSipState } from './useSipWebphone';
import SipCallWidget from './SipCallWidget.vue';

vi.mock('vue-router', async () => {
  const { reactive } = await import('vue');
  const routeState = reactive({ name: 'ramal_index' });
  return { useRoute: () => routeState, mockRoute: routeState };
});

vi.mock('./useSipWebphone', async () => {
  const { ref, shallowRef } = await import('vue');
  const sipState = {
    status: ref('Chamada recebida'),
    incoming: ref(false),
    established: ref(false),
    remoteNumber: ref('11999999999'),
    remoteStream: shallowRef(null),
    errorMessage: ref(''),
    answer: vi.fn(),
    reject: vi.fn(),
    hangup: vi.fn(),
  };
  return { useSipWebphone: () => sipState, mockSipState: sipState };
});

describe('SipCallWidget', () => {
  beforeEach(() => {
    mockRoute.name = 'ramal_index';
    mockSipState.incoming.value = false;
    mockSipState.established.value = false;
    mockSipState.answer.mockClear();
    mockSipState.reject.mockClear();
    vi.stubGlobal(
      'Audio',
      vi.fn(() => ({
        pause: vi.fn(),
        play: vi.fn().mockResolvedValue(undefined),
        currentTime: 0,
        loop: false,
        volume: 1,
      }))
    );
  });

  it('shows answer and reject actions for an incoming call on the Ramal page', async () => {
    mockSipState.incoming.value = true;
    const wrapper = mount(SipCallWidget);
    await flushPromises();

    expect(wrapper.text()).toContain('Chamada recebida');
    expect(wrapper.text()).toContain('11999999999');

    const buttons = wrapper.findAll('button');
    await buttons.find(button => button.text() === 'Atender').trigger('click');
    await buttons.find(button => button.text() === 'Recusar').trigger('click');

    expect(mockSipState.answer).toHaveBeenCalledOnce();
    expect(mockSipState.reject).toHaveBeenCalledOnce();
  });

  it('closes when the call is no longer incoming', async () => {
    mockSipState.incoming.value = true;
    const wrapper = mount(SipCallWidget);
    expect(wrapper.find('aside').exists()).toBe(true);

    mockSipState.incoming.value = false;
    await wrapper.vm.$nextTick();

    expect(wrapper.find('aside').exists()).toBe(false);
  });
});
