export const pairingImage = action => {
  if (
    action?.type !== 'QR_CODE' ||
    typeof action.value !== 'string' ||
    action.value.length > 2000000
  )
    return null;
  let encoded = action.value;
  if (action.encoding === 'DATA_URL') {
    if (!encoded.startsWith('data:image/png;base64,')) return null;
    encoded = encoded.slice('data:image/png;base64,'.length);
  } else if (action.encoding !== 'BASE64') return null;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded) || encoded.length % 4 !== 0)
    return null;
  try {
    if (!atob(encoded).startsWith('\x89PNG\r\n\x1a\n')) return null;
  } catch {
    return null;
  }
  return `data:image/png;base64,${encoded}`;
};

export const isPairingActionUsable = (action, nowMs) => {
  if (
    !Number.isFinite(Date.parse(action?.expiresAt)) ||
    Date.parse(action.expiresAt) <= nowMs
  )
    return false;
  if (action.type === 'QR_CODE') return Boolean(pairingImage(action));
  return (
    action.type === 'PAIRING_CODE' && /^[A-Za-z0-9-]{1,64}$/.test(action.code)
  );
};

export const visibleConnectionActions = actions =>
  (Array.isArray(actions) ? actions : []).filter(action =>
    ['status', 'pair', 'disconnect', 'manage'].includes(action)
  );
