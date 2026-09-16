import { isPairingActionUsable, pairingImage } from '../pairingState';

const png =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z3aQAAAAASUVORK5CYII=';
const action = {
  type: 'QR_CODE',
  encoding: 'BASE64',
  value: png,
  expiresAt: '2030-01-01T00:00:30Z',
};

describe('temporary pairing action', () => {
  it('allows only future, valid PNG or pairing codes', () => {
    const now = Date.parse('2030-01-01T00:00:00Z');
    expect(isPairingActionUsable(action, now)).toBe(true);
    expect(pairingImage(action)).toBe(`data:image/png;base64,${png}`);
    expect(isPairingActionUsable(action, now + 30000)).toBe(false);
    expect(
      isPairingActionUsable({ ...action, expiresAt: 'invalid' }, now)
    ).toBe(false);
    expect(isPairingActionUsable({ ...action, value: '<svg />' }, now)).toBe(
      false
    );
    expect(
      isPairingActionUsable(
        { ...action, encoding: 'DATA_URL', value: 'https://elsewhere.test/qr' },
        now
      )
    ).toBe(false);
    expect(
      isPairingActionUsable(
        {
          type: 'PAIRING_CODE',
          code: 'ABCD-1234',
          expiresAt: action.expiresAt,
        },
        now
      )
    ).toBe(true);
  });
});
