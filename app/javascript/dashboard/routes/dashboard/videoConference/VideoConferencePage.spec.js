import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import VideoConferenceSettingsAPI from 'dashboard/api/videoConferenceSettings';
import { resetVideoConferencePopupForTests } from 'dashboard/helper/videoConference';
import VideoConferencePage from './VideoConferencePage.vue';

vi.mock('dashboard/api/videoConferenceSettings', () => ({
  default: {
    getMine: vi.fn(),
    getFreshMine: vi.fn(),
  },
}));

describe('VideoConferencePage', () => {
  let popup;

  beforeEach(() => {
    vi.restoreAllMocks();
    vi.clearAllMocks();
    resetVideoConferencePopupForTests();
    popup = {
      closed: false,
      close: vi.fn(),
      focus: vi.fn(),
      document: {
        title: '',
        body: { innerHTML: '' },
      },
      location: { href: '' },
    };
    vi.spyOn(window, 'open').mockReturnValue(popup);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText: vi.fn().mockResolvedValue(undefined) },
    });
  });

  const mountPage = async data => {
    VideoConferenceSettingsAPI.getMine.mockResolvedValue({ data });
    VideoConferenceSettingsAPI.getFreshMine.mockResolvedValue({ data });
    const wrapper = mount(VideoConferencePage);
    await flushPromises();
    return wrapper;
  };

  it('shows the moderator URL and disables the missing spectator action', async () => {
    const moderatorUrl = 'https://meet.example.com/moderator/room?token=exact';
    const wrapper = await mountPage({
      configured: true,
      moderator_url: moderatorUrl,
      spectator_url: null,
      moderator_password: 'moderator-secret',
      spectator_password: null,
    });

    expect(wrapper.find('[data-testid="enter-moderator"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="enter-spectator"]').exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="enter-spectator"]').attributes('disabled')
    ).toBeDefined();
    expect(window.open).not.toHaveBeenCalled();

    await wrapper.find('[data-testid="enter-moderator"]').trigger('click');
    await flushPromises();

    expect(VideoConferenceSettingsAPI.getFreshMine).toHaveBeenCalled();
    expect(window.open).toHaveBeenCalledWith(
      '',
      'jrc_meet',
      expect.stringContaining('width=')
    );
    expect(popup.location.href).toBe(moderatorUrl);
  });

  it('shows the spectator URL and disables the missing moderator action', async () => {
    const spectatorUrl = 'https://meet.example.com/spectator/room?token=exact';
    const wrapper = await mountPage({
      configured: true,
      moderator_url: null,
      spectator_url: spectatorUrl,
      moderator_password: null,
      spectator_password: 'spectator-secret',
    });

    expect(wrapper.find('[data-testid="enter-moderator"]').exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="enter-moderator"]').attributes('disabled')
    ).toBeDefined();
    expect(wrapper.find('[data-testid="enter-spectator"]').exists()).toBe(true);
    expect(window.open).not.toHaveBeenCalled();

    await wrapper.find('[data-testid="enter-spectator"]').trigger('click');
    await flushPromises();

    expect(VideoConferenceSettingsAPI.getFreshMine).toHaveBeenCalled();
    expect(popup.location.href).toBe(spectatorUrl);
  });

  it('shows and copies the URL and room password for each available role', async () => {
    const wrapper = await mountPage({
      configured: true,
      moderator_url: 'https://meet.example.com/moderator/room',
      spectator_url: 'https://meet.example.com/spectator/room',
      moderator_password: 'moderator-secret',
      spectator_password: 'spectator-secret',
    });

    expect(wrapper.find('[data-testid="moderator-url"]').element.value).toBe(
      'https://meet.example.com/moderator/room'
    );
    expect(wrapper.find('[data-testid="spectator-url"]').element.value).toBe(
      'https://meet.example.com/spectator/room'
    );
    expect(
      wrapper.find('[data-testid="moderator-password"]').attributes('type')
    ).toBe('password');
    expect(
      wrapper.find('[data-testid="spectator-password"]').attributes('type')
    ).toBe('password');

    await wrapper.find('[data-testid="copy-moderator-url"]').trigger('click');
    await wrapper.find('[data-testid="copy-spectator-url"]').trigger('click');

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
      'https://meet.example.com/moderator/room'
    );
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith(
      'https://meet.example.com/spectator/room'
    );

    await wrapper
      .find('[data-testid="toggle-moderator-password"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="moderator-password"]').attributes('type')
    ).toBe('text');
  });

  it('keeps the access screen visible after opening the meeting popup', async () => {
    const moderatorUrl = 'https://meet.example.com/moderator/room';
    const wrapper = await mountPage({
      configured: true,
      moderator_url: moderatorUrl,
      spectator_url: null,
      moderator_password: 'moderator-secret',
      spectator_password: null,
    });

    await wrapper.find('[data-testid="enter-moderator"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="conference-frame"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-testid="moderator-url"]').element.value).toBe(
      moderatorUrl
    );
    expect(
      wrapper.find('[data-testid="moderator-password"]').element.value
    ).toBe('moderator-secret');
    expect(popup.location.href).toBe(moderatorUrl);
  });

  it('shows both actions when both URLs exist', async () => {
    const wrapper = await mountPage({
      configured: true,
      moderator_url: 'https://meet.example.com/moderator/room',
      spectator_url: 'https://meet.example.com/spectator/room',
    });

    expect(wrapper.find('[data-testid="enter-moderator"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="enter-spectator"]').exists()).toBe(true);
  });

  it('shows an unavailable message when no URL exists', async () => {
    const wrapper = await mountPage({
      configured: false,
      moderator_url: null,
      spectator_url: null,
    });

    expect(wrapper.find('[data-testid="enter-moderator"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-testid="enter-spectator"]').exists()).toBe(
      false
    );
    expect(wrapper.text()).toContain(
      'Vídeo Conferência não configurada para este agente.'
    );
  });

  it('shows a clear fallback message when the popup is blocked', async () => {
    window.open.mockReturnValue(null);
    const wrapper = await mountPage({
      configured: true,
      moderator_url: 'https://meet.example.com/moderator/room',
      spectator_url: null,
    });

    await wrapper.find('[data-testid="enter-moderator"]').trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="video-conference-message"]').text()
    ).toContain('Permita pop-ups');
  });
});
