import { normalizeSipDialNumber } from './phoneNumber';

describe('normalizeSipDialNumber', () => {
  it.each([
    ['+55 11 95298-5670', '11952985670'],
    ['5511952985670', '11952985670'],
    ['+55 16 3600-8130', '1636008130'],
    ['(11) 95298-5670', '11952985670'],
    ['11952985670', '11952985670'],
  ])('normalizes Brazilian number %s', (phone, expected) => {
    expect(normalizeSipDialNumber(phone)).toBe(expected);
  });

  it.each([
    ['+1 305 555 1234', '+13055551234'],
    ['+351 912 345 678', '+351912345678'],
  ])(
    'preserves the country code in international number %s',
    (phone, expected) => {
      expect(normalizeSipDialNumber(phone)).toBe(expected);
    }
  );

  it('does not mistake a short extension starting with 55 for Brazil', () => {
    expect(normalizeSipDialNumber('5512')).toBe('5512');
  });

  it('returns an empty string when there are no digits', () => {
    expect(normalizeSipDialNumber('')).toBe('');
  });
});
