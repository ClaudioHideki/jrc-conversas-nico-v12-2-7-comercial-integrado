import { computed } from 'vue';
import SessionStorage from 'shared/helpers/sessionStorage';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';

export function useImpersonation() {
  const isImpersonating = computed(() => {
    return SessionStorage.get(SESSION_STORAGE_KEYS.IMPERSONATION_USER);
  });
  const impersonationAccountId = computed(() => {
    return SessionStorage.get(SESSION_STORAGE_KEYS.IMPERSONATION_ACCOUNT_ID);
  });
  const impersonationReturnTo = computed(() => {
    return (
      SessionStorage.get(SESSION_STORAGE_KEYS.IMPERSONATION_RETURN_TO) ||
      '/super_admin'
    );
  });

  return { isImpersonating, impersonationAccountId, impersonationReturnTo };
}
