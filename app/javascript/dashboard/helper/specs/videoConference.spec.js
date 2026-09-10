import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getVideoConferencePopupFeatures,
  hasVideoConferenceUrls,
  isValidVideoConferenceUrl,
  openVideoConferencePopup,
  resetVideoConferencePopupForTests,
  resolveVideoConferenceUrl,
} from '../videoConference';

describe('hasVideoConferenceUrls', () => {
  it.each([
    [
      {
        moderator_url: 'https://meet.example.com/moderator',
        spectator_url: null,
      },
      true,
    ],
    [
      {
        moderator_url: null,
        spectator_url: 'https://meet.example.com/spectator',
      },
      true,
    ],
    [
      {
        moderator_url: 'https://meet.example.com/moderator',
        spectator_url: 'https://meet.example.com/spectator',
      },
      true,
    ],
    [{ moderator_url: null, spectator_url: null }, false],
  ])('returns the menu visibility for %o', (setting, expected) => {
    expect(hasVideoConferenceUrls(setting)).toBe(expected);
  });
});

describe('video conference URL helpers', () => {
  it('only accepts HTTPS meeting URLs', () => {
    expect(isValidVideoConferenceUrl('https://meet.example.com/room')).toBe(
      true
    );
    expect(isValidVideoConferenceUrl('http://meet.example.com/room')).toBe(
      false
    );
    expect(isValidVideoConferenceUrl('javascript:alert(1)')).toBe(false);
  });

  it('resolves only the preferred role URL', () => {
    const setting = {
      moderator_url: 'https://meet.example.com/moderator',
      spectator_url: 'https://meet.example.com/spectator',
    };

    expect(resolveVideoConferenceUrl(setting, 'moderator')).toBe(
      setting.moderator_url
    );
    expect(resolveVideoConferenceUrl(setting, 'spectator')).toBe(
      setting.spectator_url
    );
    expect(
      resolveVideoConferenceUrl(
        { moderator_url: null, spectator_url: setting.spectator_url },
        'moderator'
      )
    ).toBeNull();
    expect(resolveVideoConferenceUrl(setting)).toBe(setting.moderator_url);
  });

  it('builds popup features that preserve the left sidebar area', () => {
    const features = getVideoConferencePopupFeatures();

    expect(features).toContain('left=198');
    expect(features).toContain('top=8');
    expect(features).toContain('resizable=yes');
  });
});

describe('openVideoConferencePopup', () => {
  let popup;

  beforeEach(() => {
    vi.restoreAllMocks();
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
  });

  it('opens a blank named popup before awaiting the URL and then redirects it', async () => {
    const result = await openVideoConferencePopup({
      getSetting: vi.fn().mockResolvedValue({
        moderator_url: 'https://meet.example.com/moderator',
      }),
    });

    expect(window.open).toHaveBeenCalledWith(
      '',
      'jrc_meet',
      expect.stringContaining('width=')
    );
    expect(popup.location.href).toBe('https://meet.example.com/moderator');
    expect(result.status).toBe('opened');
  });

  it('reuses the existing popup and updates its URL', async () => {
    await openVideoConferencePopup({
      getSetting: vi.fn().mockResolvedValue({
        moderator_url: 'https://meet.example.com/moderator',
      }),
    });

    window.open.mockClear();
    const result = await openVideoConferencePopup({
      preferredRole: 'spectator',
      getSetting: vi.fn().mockResolvedValue({
        spectator_url: 'https://meet.example.com/spectator',
      }),
    });

    expect(window.open).not.toHaveBeenCalled();
    expect(popup.focus).toHaveBeenCalled();
    expect(popup.location.href).toBe('https://meet.example.com/spectator');
    expect(result.status).toBe('opened');
  });

  it('reports blocked popups', async () => {
    const onBlocked = vi.fn();
    window.open.mockReturnValue(null);

    const result = await openVideoConferencePopup({
      getSetting: vi.fn(),
      onBlocked,
    });

    expect(onBlocked).toHaveBeenCalled();
    expect(result.status).toBe('blocked');
  });
});
