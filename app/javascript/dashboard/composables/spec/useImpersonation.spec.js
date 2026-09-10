import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useImpersonation } from '../useImpersonation';

vi.mock('shared/helpers/sessionStorage', () => ({
  __esModule: true,
  default: {
    get: vi.fn(),
    set: vi.fn(),
  },
}));

import SessionStorage from 'shared/helpers/sessionStorage';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';

describe('useImpersonation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should return true if impersonation flag is set in session storage', () => {
    SessionStorage.get.mockImplementation(key => {
      if (key === SESSION_STORAGE_KEYS.IMPERSONATION_USER) return true;
      return null;
    });
    const { isImpersonating, impersonationReturnTo } = useImpersonation();
    expect(isImpersonating.value).toBe(true);
    expect(impersonationReturnTo.value).toBe('/super_admin');
    expect(SessionStorage.get).toHaveBeenCalledWith(
      SESSION_STORAGE_KEYS.IMPERSONATION_USER
    );
  });

  it('should return false if impersonation flag is not set in session storage', () => {
    SessionStorage.get.mockReturnValue(false);
    const { isImpersonating } = useImpersonation();
    expect(isImpersonating.value).toBe(false);
    expect(SessionStorage.get).toHaveBeenCalledWith(
      SESSION_STORAGE_KEYS.IMPERSONATION_USER
    );
  });

  it('should return saved super admin context while impersonating', () => {
    SessionStorage.get.mockImplementation(key => {
      if (key === SESSION_STORAGE_KEYS.IMPERSONATION_USER) return true;
      if (key === SESSION_STORAGE_KEYS.IMPERSONATION_ACCOUNT_ID) return '3';
      if (key === SESSION_STORAGE_KEYS.IMPERSONATION_RETURN_TO) {
        return '/super_admin?account_id=3';
      }
      return null;
    });

    const {
      isImpersonating,
      impersonationAccountId,
      impersonationReturnTo,
    } = useImpersonation();

    expect(isImpersonating.value).toBe(true);
    expect(impersonationAccountId.value).toBe('3');
    expect(impersonationReturnTo.value).toBe('/super_admin?account_id=3');
  });
});
