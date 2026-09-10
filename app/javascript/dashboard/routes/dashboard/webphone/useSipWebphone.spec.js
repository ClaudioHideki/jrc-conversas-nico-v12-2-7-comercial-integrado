import { describe, expect, it, vi } from 'vitest';

vi.mock('dashboard/api/sipCredentials', () => ({
  default: { getMine: vi.fn() },
}));
vi.mock('./SipClient', () => ({
  SipClient: class {},
}));

import { formatCallDuration } from './useSipWebphone';

describe('formatCallDuration', () => {
  it.each([
    [0, '00:00'],
    [65, '01:05'],
    [3600, '01:00:00'],
    [3661, '01:01:01'],
  ])('formats %i seconds as %s', (seconds, expected) => {
    expect(formatCallDuration(seconds)).toBe(expected);
  });
});
