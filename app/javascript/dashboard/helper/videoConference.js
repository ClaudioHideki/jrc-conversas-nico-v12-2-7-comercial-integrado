export const hasVideoConferenceUrls = setting =>
  Boolean(setting?.moderator_url || setting?.spectator_url);

const POPUP_NAME = 'jrc_meet';
const POPUP_MARGIN = 8;
const SIDEBAR_WIDTH = 190;
const MIN_POPUP_SIZE = 320;

let videoConferencePopup = null;

const getScreenMetric = (metric, fallback) => {
  if (typeof window === 'undefined') return fallback;

  return window.screen?.[metric] || fallback;
};

export const getVideoConferencePopupFeatures = () => {
  const availableWidth = getScreenMetric('availWidth', 1200);
  const availableHeight = getScreenMetric('availHeight', 800);
  const screenLeft = getScreenMetric('availLeft', 0);
  const screenTop = getScreenMetric('availTop', 0);
  const width = Math.max(
    MIN_POPUP_SIZE,
    availableWidth - SIDEBAR_WIDTH - POPUP_MARGIN * 2
  );
  const height = Math.max(
    MIN_POPUP_SIZE,
    availableHeight - POPUP_MARGIN * 2
  );
  const left = Math.max(0, screenLeft + SIDEBAR_WIDTH + POPUP_MARGIN);
  const top = Math.max(0, screenTop + POPUP_MARGIN);

  return [
    `width=${width}`,
    `height=${height}`,
    `left=${left}`,
    `top=${top}`,
    'resizable=yes',
    'scrollbars=yes',
    'status=yes',
  ].join(',');
};

export const isValidVideoConferenceUrl = url => {
  if (!url) return false;

  try {
    const parsedUrl = new URL(url);
    return parsedUrl.protocol === 'https:' && Boolean(parsedUrl.host);
  } catch {
    return false;
  }
};

export const resolveVideoConferenceUrl = (setting, preferredRole = null) => {
  if (preferredRole === 'spectator') {
    return isValidVideoConferenceUrl(setting?.spectator_url)
      ? setting.spectator_url
      : null;
  }

  if (preferredRole === 'moderator') {
    return isValidVideoConferenceUrl(setting?.moderator_url)
      ? setting.moderator_url
      : null;
  }

  return [setting?.moderator_url, setting?.spectator_url].find(
    isValidVideoConferenceUrl
  ) || null;
};

const writeLoadingState = popup => {
  try {
    popup.document.title = 'JRC Meet';
    popup.document.body.innerHTML = [
      '<main style="font-family: system-ui, -apple-system,',
      'BlinkMacSystemFont, Segoe UI, sans-serif;',
      'display: grid; min-height: 100vh; place-items: center; margin: 0;',
      'color: #0f172a; background: #f8fafc;">',
      '<p style="font-size: 16px;">Abrindo JRC Meet...</p></main>',
    ].join(' ');
  } catch {
    // Ignore cross-window access issues; the popup can still be redirected.
  }
};

const detachOpener = popup => {
  try {
    popup.opener = null;
  } catch {
    // Ignore browsers that do not allow changing opener.
  }
};

export const openVideoConferencePopup = async ({
  getSetting,
  preferredRole = 'moderator',
  onBlocked,
  onUnavailable,
  onInvalidUrl,
  onError,
} = {}) => {
  if (videoConferencePopup && !videoConferencePopup.closed) {
    writeLoadingState(videoConferencePopup);
    videoConferencePopup.focus();
  } else {
    videoConferencePopup = window.open(
      '',
      POPUP_NAME,
      getVideoConferencePopupFeatures()
    );

    if (!videoConferencePopup) {
      onBlocked?.();
      return { status: 'blocked' };
    }

    writeLoadingState(videoConferencePopup);
  }

  try {
    const setting = await getSetting();
    const url = resolveVideoConferenceUrl(setting, preferredRole);

    if (!url) {
      videoConferencePopup.close();
      videoConferencePopup = null;

      if (hasVideoConferenceUrls(setting)) {
        onInvalidUrl?.();
        return { status: 'invalid_url' };
      }

      onUnavailable?.();
      return { status: 'unavailable' };
    }

    videoConferencePopup.location.href = url;
    detachOpener(videoConferencePopup);
    videoConferencePopup.focus();
    return { status: 'opened', url };
  } catch (error) {
    videoConferencePopup.close();
    videoConferencePopup = null;
    onError?.(error);
    return { status: 'error', error };
  }
};

export const resetVideoConferencePopupForTests = () => {
  videoConferencePopup = null;
};
