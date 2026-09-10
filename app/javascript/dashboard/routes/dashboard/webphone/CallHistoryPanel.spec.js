import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import CallHistoryAPI from 'dashboard/api/callHistory';
import CallHistoryPanel from './CallHistoryPanel.vue';

vi.mock('dashboard/api/callHistory', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/api/callQualityAnalyses', () => ({
  default: { analyze: vi.fn() },
}));

describe('CallHistoryPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CallHistoryAPI.get.mockResolvedValue({
      data: {
        count: 2,
        extension: '1110',
        fetched_at: '2026-08-19T12:00:00Z',
        summary: { total: 2, answered: 1, unanswered: 1 },
        calls: [
          {
            id: '1',
            direction: 'outbound',
            status: 'answered',
            external_number: '11999999999',
            started_at: '2026-08-19T10:00:00Z',
          },
          {
            id: '2',
            direction: 'inbound',
            status: 'unanswered',
            external_number: '11888888888',
            started_at: '2026-08-19T11:00:00Z',
          },
        ],
      },
    });
  });

  it('renders real summary values and distinct call statuses', async () => {
    const wrapper = mount(CallHistoryPanel);
    await flushPromises();

    expect(CallHistoryAPI.get).toHaveBeenCalled();
    expect(wrapper.text()).toContain('Total de chamadas');
    expect(wrapper.text()).toContain('Atendidas');
    expect(wrapper.text()).toContain('Não atendidas');
    expect(wrapper.find('.bg-n-teal-3').text()).toContain('1');
    expect(wrapper.find('.bg-n-ruby-3').text()).toContain('1');
    expect(wrapper.text()).toContain('Atendida');
    expect(wrapper.text()).toContain('Nao atendida');
    wrapper.unmount();
  });

  it('renders the newest call first', async () => {
    const wrapper = mount(CallHistoryPanel);
    await flushPromises();

    expect(wrapper.findAll('article')[0].text()).toContain('11888888888');
    wrapper.unmount();
  });
});
