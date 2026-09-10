<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';
import AnalyticsHelper from 'dashboard/helper/AnalyticsHelper';
import { SESSION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const SUPER_ADMIN_ACCOUNT_ID_SEARCH_KEY = 'super_admin_account_id';
const SUPER_ADMIN_RETURN_TO_SEARCH_KEY = 'super_admin_return_to';

const getSafeSuperAdminPath = path => {
  if (!path || typeof path !== 'string') return '/super_admin';
  if (!path.startsWith('/super_admin')) return '/super_admin';
  if (path.startsWith('//') || path.includes('\\')) return '/super_admin';
  return path;
};
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';
const JRC_LOGO_URL = '/brand-assets/logo-jrc-thumbnail.png';
const JRC_LOGIN_TEXT = Object.freeze({
  brandName: 'JRC Conversas',
  relationshipCenter: 'Central de relacionamento',
  connectedService: 'Atendimento conectado',
  headline: 'Conversas que aproximam pessoas e negócios.',
  description:
    'Reúna seus canais, organize atendimentos e acompanhe sua equipe em um único lugar.',
  conversations: 'Conversas',
  contacts: 'Contatos',
  results: 'Resultados',
  loginDescription: 'Entre com suas credenciais para acessar o JRC Conversas.',
  footer: 'Grupo JRC · Conectando pessoas, impulsionando negócios.',
});

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    SessionLimitOverlay,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    target: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      jrcText: JRC_LOGIN_TEXT,
      jrcLogoUrl: JRC_LOGO_URL,
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
      sessionsLimitReached: false,
      limitedSessions: [],
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
        SessionStorage.set(
          SESSION_STORAGE_KEYS.IMPERSONATION_ACCOUNT_ID,
          urlParams.get(SUPER_ADMIN_ACCOUNT_ID_SEARCH_KEY) || ''
        );
        SessionStorage.set(
          SESSION_STORAGE_KEYS.IMPERSONATION_RETURN_TO,
          getSafeSuperAdminPath(urlParams.get(SUPER_ADMIN_RETURN_TO_SEARCH_KEY))
        );
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        target: this.target,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          // Check if sessions limit reached
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (response?.errorCode === USER_NOT_CONFIRMED_ERROR_CODE) {
            this.loginApi.showLoading = false;
            this.$router.push({
              name: 'auth_verify_email',
              state: { email: credentials.email },
            });
            return;
          }

          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
    retryLoginWithParams(extraParams) {
      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        target: this.target,
        ...extraParams,
      };

      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.loginApi.showLoading = true;
      login(credentials)
        .then(result => {
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleSessionRevoke(sessionId) {
      this.retryLoginWithParams({ revoke_session_id: sessionId });
    },
    handleSessionRevokeAll() {
      this.retryLoginWithParams({ revoke_all_sessions: true });
    },
    handleSessionLimitCancel() {
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main class="flex w-full min-h-screen bg-white dark:bg-n-background">
    <aside
      class="relative hidden w-[44%] min-h-screen overflow-hidden bg-[#062f57] lg:flex lg:flex-col lg:justify-between"
    >
      <div
        class="absolute inset-0 bg-[url('/brand-assets/jrc-background.jpeg')] bg-cover bg-center opacity-25"
      />
      <div
        class="absolute inset-0 bg-gradient-to-br from-[#062f57]/95 via-[#063f73]/90 to-[#0877da]/75"
      />

      <div class="relative z-10 flex items-center gap-4 px-12 pt-12">
        <img
          :src="jrcLogoUrl"
          alt="JRC"
          class="object-cover w-16 h-16 shadow-xl rounded-2xl ring-1 ring-white/20"
        />
        <div>
          <p class="text-2xl font-semibold tracking-tight text-white">
            {{ jrcText.brandName }}
          </p>
          <p class="mt-1 text-sm font-medium text-white/70">
            {{ jrcText.relationshipCenter }}
          </p>
        </div>
      </div>

      <div class="relative z-10 max-w-xl px-12 pb-16">
        <div
          class="inline-flex items-center gap-2 px-3 py-1.5 mb-7 text-sm font-medium text-white/85 border rounded-full border-white/25 bg-white/10"
        >
          <span class="w-2 h-2 bg-emerald-400 rounded-full" />
          {{ jrcText.connectedService }}
        </div>
        <h1 class="text-4xl font-semibold leading-tight text-white xl:text-5xl">
          {{ jrcText.headline }}
        </h1>
        <p class="mt-6 text-lg font-medium leading-8 text-white/75">
          {{ jrcText.description }}
        </p>
        <div class="grid grid-cols-3 gap-3 mt-10">
          <div class="p-4 border rounded-2xl border-white/15 bg-white/10">
            <Icon icon="i-lucide-messages-square" class="text-white size-6" />
            <p class="mt-3 text-sm font-medium text-white">
              {{ jrcText.conversations }}
            </p>
          </div>
          <div class="p-4 border rounded-2xl border-white/15 bg-white/10">
            <Icon icon="i-lucide-users" class="text-white size-6" />
            <p class="mt-3 text-sm font-medium text-white">
              {{ jrcText.contacts }}
            </p>
          </div>
          <div class="p-4 border rounded-2xl border-white/15 bg-white/10">
            <Icon
              icon="i-lucide-chart-no-axes-combined"
              class="text-white size-6"
            />
            <p class="mt-3 text-sm font-medium text-white">
              {{ jrcText.results }}
            </p>
          </div>
        </div>
      </div>
    </aside>

    <section
      class="flex flex-1 min-h-screen px-6 py-10 bg-gradient-to-br from-white via-white to-blue-50/70 sm:px-12 lg:px-16"
    >
      <div class="w-full max-w-md m-auto">
        <div class="flex items-center gap-3 mb-10 lg:hidden">
          <img
            :src="jrcLogoUrl"
            alt="JRC"
            class="object-cover w-12 h-12 rounded-xl"
          />
          <span class="text-xl font-semibold text-n-slate-12">
            {{ jrcText.brandName }}
          </span>
        </div>

        <div class="mb-9">
          <div class="mb-7 flex justify-center">
            <img
              :src="jrcLogoUrl"
              alt="JRC Conversas"
              class="size-32 rounded-[2rem] object-cover shadow-[0_18px_48px_rgba(8,43,82,0.2)] ring-1 ring-[#dce7f2]"
            />
          </div>
          <p
            class="text-center text-base font-medium text-[#526b85] dark:text-n-slate-11"
          >
            {{ jrcText.loginDescription }}
          </p>
          <p v-if="showSignupLink" class="mt-3 text-sm text-n-slate-11">
            {{ $t('COMMON.OR') }}
            <router-link
              to="auth/signup"
              class="lowercase text-link text-n-brand"
            >
              {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
            </router-link>
          </p>
        </div>

        <div
          class="p-7 bg-white border shadow-xl shadow-blue-950/5 border-slate-200/80 rounded-2xl sm:p-9 dark:bg-n-solid-2 dark:border-n-strong"
          :class="{ 'animate-wiggle': loginApi.hasErrored }"
        >
          <SessionLimitOverlay
            v-if="sessionsLimitReached"
            :sessions="limitedSessions"
            @revoke="handleSessionRevoke"
            @revoke-all="handleSessionRevokeAll"
            @cancel="handleSessionLimitCancel"
          />

          <MfaVerification
            v-else-if="mfaRequired"
            :mfa-token="mfaToken"
            @verified="handleMfaVerified"
            @cancel="handleMfaCancel"
          />

          <div v-else-if="!email">
            <div class="flex flex-col gap-4">
              <GoogleOAuthButton v-if="showGoogleOAuth" />
              <div v-if="showSamlLogin" class="text-center">
                <router-link
                  to="/app/login/sso"
                  class="inline-flex items-center justify-center w-full px-4 py-3 rounded-xl bg-n-background ring-1 ring-inset ring-n-container hover:bg-n-alpha-2"
                >
                  <Icon
                    icon="i-lucide-lock-keyhole"
                    class="size-5 text-n-slate-11"
                  />
                  <span class="ml-2 text-base font-medium text-n-slate-12">
                    {{ $t('LOGIN.SAML.LABEL') }}
                  </span>
                </router-link>
              </div>
              <SimpleDivider
                v-if="showGoogleOAuth || showSamlLogin"
                :label="$t('COMMON.OR')"
                class="uppercase"
              />
            </div>
            <form class="space-y-5" @submit.prevent="submitFormLogin">
              <FormInput
                v-model="credentials.email"
                name="email_address"
                type="text"
                data-testid="email_input"
                :tabindex="1"
                required
                :label="$t('LOGIN.EMAIL.LABEL')"
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                :has-error="v$.credentials.email.$error"
                @input="v$.credentials.email.$touch"
              />
              <FormInput
                v-model="credentials.password"
                type="password"
                name="password"
                data-testid="password_input"
                required
                :tabindex="2"
                :label="$t('LOGIN.PASSWORD.LABEL')"
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                :has-error="v$.credentials.password.$error"
                @input="v$.credentials.password.$touch"
              >
                <p v-if="!globalConfig.disableUserProfileUpdate">
                  <router-link
                    to="auth/reset/password"
                    class="text-sm text-link"
                    tabindex="4"
                  >
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </p>
              </FormInput>
              <NextButton
                lg
                type="submit"
                data-testid="submit_button"
                class="w-full"
                :tabindex="3"
                :label="$t('LOGIN.SUBMIT')"
                :disabled="loginApi.showLoading"
                :is-loading="loginApi.showLoading"
              />
            </form>
          </div>
          <div v-else class="flex items-center justify-center py-10">
            <Spinner color-scheme="primary" size="" />
          </div>
        </div>

        <p
          class="mt-8 text-sm font-medium text-center text-[#60758c] dark:text-n-slate-10"
        >
          {{ jrcText.footer }}
        </p>
      </div>
    </section>
  </main>
</template>
