import {
  setAuthCredentials,
  throwErrorMessage,
  clearLocalStorageOnLogout,
  parseAPIErrorResponse,
} from 'dashboard/store/utils/api';
import wootAPI from './apiClient';
import {
  getLoginRedirectURL,
  getCredentialsFromEmail,
} from '../helpers/AuthHelper';
import SessionStorage from 'shared/helpers/sessionStorage';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';

const getSafeSuperAdminPath = path => {
  if (!path || typeof path !== 'string') return '/super_admin';
  if (!path.startsWith('/super_admin')) return '/super_admin';
  if (path.startsWith('//') || path.includes('\\')) return '/super_admin';
  return path;
};

const persistImpersonationContext = () => {
  const urlParams = new URLSearchParams(window.location.search);
  if (!urlParams.get('impersonation')) return;

  SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
  SessionStorage.set(
    SESSION_STORAGE_KEYS.IMPERSONATION_ACCOUNT_ID,
    urlParams.get('super_admin_account_id') || ''
  );
  SessionStorage.set(
    SESSION_STORAGE_KEYS.IMPERSONATION_RETURN_TO,
    getSafeSuperAdminPath(urlParams.get('super_admin_return_to'))
  );
};

export const login = async ({
  ssoAccountId,
  ssoConversationId,
  target,
  ...credentials
}) => {
  try {
    const response = await wootAPI.post('auth/sign_in', credentials);

    // Check if MFA is required
    if (response.status === 206 && response.data.mfa_required) {
      // Return MFA data instead of throwing error
      return {
        mfaRequired: true,
        mfaToken: response.data.mfa_token,
      };
    }

    setAuthCredentials(response);
    persistImpersonationContext();
    clearLocalStorageOnLogout();
    window.location = getLoginRedirectURL({
      ssoAccountId,
      ssoConversationId,
      target,
      user: response.data.data,
    });
    return null;
  } catch (error) {
    // Check if it's an MFA required response
    if (error.response?.status === 206 && error.response?.data?.mfa_required) {
      return {
        mfaRequired: true,
        mfaToken: error.response.data.mfa_token,
      };
    }
    if (
      error.response?.status === 409 &&
      error.response?.data?.sessions_limit_reached
    ) {
      return {
        sessionsLimitReached: true,
        sessions: error.response.data.sessions,
      };
    }
    const loginError = new Error(parseAPIErrorResponse(error));
    loginError.errorCode = error.response?.data?.error_code;
    throw loginError;
  }
};

export const register = async creds => {
  try {
    const { fullName, accountName } = getCredentialsFromEmail(creds.email);
    const response = await wootAPI.post('api/v1/accounts.json', {
      account_name: accountName,
      user_full_name: fullName,
      email: creds.email,
      password: creds.password,
      h_captcha_client_response: creds.hCaptchaClientResponse,
    });
    return response.data;
  } catch (error) {
    throwErrorMessage(error);
  }
  return null;
};

export const resendConfirmation = async ({ email, hCaptchaClientResponse }) => {
  return wootAPI.post('resend_confirmation', {
    email,
    h_captcha_client_response: hCaptchaClientResponse,
  });
};

export const verifyPasswordToken = async ({ confirmationToken }) => {
  try {
    const response = await wootAPI.post('auth/confirmation', {
      confirmation_token: confirmationToken,
    });
    setAuthCredentials(response);
  } catch (error) {
    throwErrorMessage(error);
  }
};

export const setNewPassword = async ({
  resetPasswordToken,
  password,
  confirmPassword,
}) => {
  try {
    const response = await wootAPI.put('auth/password', {
      reset_password_token: resetPasswordToken,
      password_confirmation: confirmPassword,
      password,
    });
    setAuthCredentials(response);
  } catch (error) {
    throwErrorMessage(error);
  }
};

export const resetPassword = async ({ email }) =>
  wootAPI.post('auth/password', { email });
