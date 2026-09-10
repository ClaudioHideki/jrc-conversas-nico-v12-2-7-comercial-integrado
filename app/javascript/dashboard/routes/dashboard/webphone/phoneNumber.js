const BRAZIL_COUNTRY_CODE = '55';
const BRAZIL_NATIONAL_NUMBER_LENGTHS = [10, 11];

/**
 * Formats a phone number only for the value sent to the SIP client.
 * Brazilian numbers are dialed without 55; other country codes are preserved.
 */
export const normalizeSipDialNumber = phone => {
  const value = String(phone || '').trim();
  const hasInternationalPrefix = value.startsWith('+');
  const digits = value.replace(/\D/g, '');

  if (!digits) return '';

  const brazilianNationalNumber = digits.slice(BRAZIL_COUNTRY_CODE.length);
  const isBrazilianInternationalNumber =
    digits.startsWith(BRAZIL_COUNTRY_CODE) &&
    BRAZIL_NATIONAL_NUMBER_LENGTHS.includes(brazilianNationalNumber.length);

  if (isBrazilianInternationalNumber) return brazilianNationalNumber;

  return hasInternationalPrefix ? `+${digits}` : digits;
};

// Kept as an alias for callers outside the Ramal that may already import it.
export const normalizePhoneForDialing = normalizeSipDialNumber;
