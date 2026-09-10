<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import VideoConferenceSettingsAPI from 'dashboard/api/videoConferenceSettings';
import {
  isValidVideoConferenceUrl,
  openVideoConferencePopup,
} from 'dashboard/helper/videoConference';

const { t } = useI18n();

const isLoading = ref(true);
const moderatorUrl = ref(null);
const spectatorUrl = ref(null);
const moderatorPassword = ref(null);
const spectatorPassword = ref(null);
const fallbackMessage = ref(null);
const visiblePasswords = ref({ moderator: false, spectator: false });
const copiedField = ref(null);

const isConfigured = computed(() =>
  Boolean(moderatorUrl.value || spectatorUrl.value)
);
const hasModeratorUrl = computed(() =>
  isValidVideoConferenceUrl(moderatorUrl.value)
);
const hasSpectatorUrl = computed(() =>
  isValidVideoConferenceUrl(spectatorUrl.value)
);

const loadConfiguration = async () => {
  isLoading.value = true;
  fallbackMessage.value = null;
  try {
    const { data } = await VideoConferenceSettingsAPI.getMine();
    moderatorUrl.value = data.moderator_url || null;
    spectatorUrl.value = data.spectator_url || null;
    moderatorPassword.value = data.moderator_password || null;
    spectatorPassword.value = data.spectator_password || null;
  } catch {
    moderatorUrl.value = null;
    spectatorUrl.value = null;
    moderatorPassword.value = null;
    spectatorPassword.value = null;
  } finally {
    isLoading.value = false;
  }
};

const getFreshVideoConferenceSetting = async () => {
  const { data } = await VideoConferenceSettingsAPI.getFreshMine();
  return data;
};

const togglePassword = role => {
  visiblePasswords.value[role] = !visiblePasswords.value[role];
};

const setFallbackMessage = message => {
  fallbackMessage.value = message;
};

const copyWithTextareaFallback = value => {
  const textarea = document.createElement('textarea');
  textarea.value = value;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  document.body.appendChild(textarea);
  textarea.select();

  try {
    return document.execCommand('copy');
  } finally {
    document.body.removeChild(textarea);
  }
};

const enterConference = role => {
  fallbackMessage.value = null;
  openVideoConferencePopup({
    getSetting: getFreshVideoConferenceSetting,
    preferredRole: role,
    onBlocked: () => setFallbackMessage(t('VIDEO_CONFERENCE.POPUP_BLOCKED')),
    onUnavailable: () => setFallbackMessage(t('VIDEO_CONFERENCE.UNAVAILABLE')),
    onInvalidUrl: () => setFallbackMessage(t('VIDEO_CONFERENCE.INVALID_URL')),
    onError: () => setFallbackMessage(t('VIDEO_CONFERENCE.OPEN_ERROR')),
  });
};

const openNewTab = url => {
  fallbackMessage.value = null;

  if (!isValidVideoConferenceUrl(url)) {
    fallbackMessage.value = t('VIDEO_CONFERENCE.INVALID_URL');
    return;
  }

  const tab = window.open(url, '_blank', 'noopener,noreferrer');
  if (!tab) fallbackMessage.value = t('VIDEO_CONFERENCE.POPUP_BLOCKED');
};

const copyValue = async (field, value) => {
  if (!value) return;

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(value);
    } else if (!copyWithTextareaFallback(value)) {
      throw new Error('copy_failed');
    }

    copiedField.value = field;
    window.setTimeout(() => {
      if (copiedField.value === field) copiedField.value = null;
    }, 2000);
  } catch {
    fallbackMessage.value = t('VIDEO_CONFERENCE.COPY_FAILED');
  }
};

onMounted(loadConfiguration);
</script>

<template>
  <section class="min-h-0 flex-1 overflow-y-auto bg-n-background">
    <div class="mx-auto w-full max-w-[1500px] p-4 lg:p-6">
      <header
        class="relative overflow-hidden rounded-3xl border border-n-blue-5 bg-gradient-to-br from-n-blue-2 via-n-solid-2 to-n-blue-3 p-6 shadow-sm lg:p-10"
      >
        <div class="relative z-10 max-w-3xl">
          <p class="text-sm font-semibold text-n-blue-11">
            {{ t('VIDEO_CONFERENCE.PRODUCT') }}
          </p>
          <h1 class="mt-2 text-3xl font-bold text-n-slate-12 lg:text-4xl">
            {{ t('VIDEO_CONFERENCE.TITLE') }}
          </h1>
          <p class="mt-3 text-sm text-n-slate-11 lg:text-base">
            {{ t('VIDEO_CONFERENCE.DESCRIPTION') }}
          </p>
          <span
            v-if="!isLoading && isConfigured"
            class="mt-5 inline-flex items-center gap-2 rounded-full border border-n-teal-7 bg-n-teal-3 px-4 py-2 text-sm font-semibold text-n-teal-11"
          >
            <span class="size-2 rounded-full bg-n-teal-9" />
            {{ t('VIDEO_CONFERENCE.ROOM_AVAILABLE') }}
          </span>
        </div>
        <div
          class="absolute -bottom-16 -right-12 grid size-64 place-items-center rounded-full bg-n-blue-4/60 text-n-blue-10 lg:right-8"
        >
          <span class="i-lucide-video size-24" />
        </div>
      </header>

      <p
        v-if="fallbackMessage"
        class="mt-5 rounded-xl border border-n-amber-7 bg-n-amber-3 px-4 py-3 text-sm text-n-amber-11"
        data-testid="video-conference-message"
      >
        {{ fallbackMessage }}
      </p>

      <div
        v-if="isLoading"
        class="mt-5 flex items-center gap-2 rounded-2xl border border-n-weak bg-n-solid-2 p-6 text-sm text-n-slate-11"
      >
        <span class="i-lucide-loader-2 size-5 animate-spin" />
        {{ t('VIDEO_CONFERENCE.LOADING') }}
      </div>

      <template v-else-if="isConfigured">
        <div class="mt-5 grid gap-5 lg:grid-cols-2">
          <article
            class="flex flex-col rounded-2xl border border-n-blue-7 bg-n-blue-2 p-6 shadow-sm"
          >
            <div class="flex items-start gap-4">
              <span
                class="grid size-14 shrink-0 place-items-center rounded-2xl bg-n-blue-9 text-white shadow-sm"
              >
                <span class="i-lucide-shield-check size-7" />
              </span>
              <div>
                <span
                  class="rounded-full bg-n-blue-4 px-2.5 py-1 text-[10px] font-bold tracking-wide text-n-blue-11"
                >
                  {{ t('VIDEO_CONFERENCE.MODERATOR') }}
                </span>
                <h2 class="mt-3 text-xl font-semibold text-n-slate-12">
                  {{ t('VIDEO_CONFERENCE.ENTER_MODERATOR') }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{ t('VIDEO_CONFERENCE.MODERATOR_DESCRIPTION') }}
                </p>
              </div>
            </div>
            <ul class="mt-5 grid gap-2 text-sm text-n-slate-11">
              <li class="flex items-center gap-2">
                <span class="i-lucide-circle-check size-4 text-n-blue-10" />
                {{ t('VIDEO_CONFERENCE.MODERATOR_FEATURE_1') }}
              </li>
              <li class="flex items-center gap-2">
                <span class="i-lucide-circle-check size-4 text-n-blue-10" />
                {{ t('VIDEO_CONFERENCE.MODERATOR_FEATURE_2') }}
              </li>
              <li class="flex items-center gap-2">
                <span class="i-lucide-circle-check size-4 text-n-blue-10" />
                {{ t('VIDEO_CONFERENCE.MODERATOR_FEATURE_3') }}
              </li>
            </ul>
            <button
              type="button"
              class="mt-6 w-full rounded-xl bg-n-blue-9 px-4 py-3 text-sm font-semibold text-white transition hover:bg-n-blue-10 disabled:cursor-not-allowed disabled:opacity-60"
              data-testid="enter-moderator"
              :disabled="!hasModeratorUrl"
              @click="enterConference('moderator')"
            >
              {{ t('VIDEO_CONFERENCE.ENTER_MODERATOR') }}
            </button>
            <button
              type="button"
              class="mt-2 w-full rounded-xl border border-n-blue-7 px-4 py-2.5 text-sm font-semibold text-n-blue-11 transition hover:bg-n-blue-3 disabled:cursor-not-allowed disabled:opacity-60"
              data-testid="open-moderator-new-tab"
              :disabled="!hasModeratorUrl"
              @click="openNewTab(moderatorUrl)"
            >
              {{ t('VIDEO_CONFERENCE.OPEN_NEW_TAB') }}
            </button>
          </article>

          <article
            class="flex flex-col rounded-2xl border border-n-weak bg-n-solid-2 p-6 shadow-sm"
          >
            <div class="flex items-start gap-4">
              <span
                class="grid size-14 shrink-0 place-items-center rounded-2xl bg-n-alpha-3 text-n-slate-11 shadow-sm"
              >
                <span class="i-lucide-eye size-7" />
              </span>
              <div>
                <span
                  class="rounded-full bg-n-alpha-3 px-2.5 py-1 text-[10px] font-bold tracking-wide text-n-slate-11"
                >
                  {{ t('VIDEO_CONFERENCE.SPECTATOR') }}
                </span>
                <h2 class="mt-3 text-xl font-semibold text-n-slate-12">
                  {{ t('VIDEO_CONFERENCE.ENTER_SPECTATOR') }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{ t('VIDEO_CONFERENCE.SPECTATOR_DESCRIPTION') }}
                </p>
              </div>
            </div>
            <ul class="mt-5 grid gap-2 text-sm text-n-slate-11">
              <li class="flex items-center gap-2">
                <span class="i-lucide-circle-check size-4 text-n-slate-10" />
                {{ t('VIDEO_CONFERENCE.SPECTATOR_FEATURE_1') }}
              </li>
              <li class="flex items-center gap-2">
                <span class="i-lucide-circle-check size-4 text-n-slate-10" />
                {{ t('VIDEO_CONFERENCE.SPECTATOR_FEATURE_2') }}
              </li>
              <li class="flex items-center gap-2">
                <span class="i-lucide-circle-check size-4 text-n-slate-10" />
                {{ t('VIDEO_CONFERENCE.SPECTATOR_FEATURE_3') }}
              </li>
            </ul>
            <button
              type="button"
              class="mt-6 w-full rounded-xl border border-n-blue-8 bg-n-solid-2 px-4 py-3 text-sm font-semibold text-n-blue-11 transition hover:bg-n-blue-2 disabled:cursor-not-allowed disabled:opacity-60"
              data-testid="enter-spectator"
              :disabled="!hasSpectatorUrl"
              @click="enterConference('spectator')"
            >
              {{ t('VIDEO_CONFERENCE.ENTER_SPECTATOR') }}
            </button>
            <button
              type="button"
              class="mt-2 w-full rounded-xl border border-n-weak px-4 py-2.5 text-sm font-semibold text-n-slate-11 transition hover:bg-n-alpha-2 disabled:cursor-not-allowed disabled:opacity-60"
              data-testid="open-spectator-new-tab"
              :disabled="!hasSpectatorUrl"
              @click="openNewTab(spectatorUrl)"
            >
              {{ t('VIDEO_CONFERENCE.OPEN_NEW_TAB') }}
            </button>
          </article>
        </div>

        <section
          class="mt-5 rounded-2xl border border-n-weak bg-n-solid-2 p-5 shadow-sm lg:p-6"
        >
          <div class="flex items-center gap-3">
            <span
              class="grid size-10 place-items-center rounded-xl bg-n-blue-3 text-n-blue-11"
            >
              <span class="i-lucide-lock-keyhole size-5" />
            </span>
            <div>
              <h2 class="font-semibold text-n-slate-12">
                {{ t('VIDEO_CONFERENCE.ACCESS_DATA') }}
              </h2>
              <p class="text-xs text-n-slate-10">
                {{ t('VIDEO_CONFERENCE.ACCESS_DATA_DESCRIPTION') }}
              </p>
            </div>
          </div>

          <div class="mt-5 grid gap-5 lg:grid-cols-2">
            <div class="rounded-xl border border-n-blue-6 bg-n-blue-2 p-4">
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('VIDEO_CONFERENCE.MODERATOR') }}
              </p>
              <label class="mt-3 grid gap-1.5">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('VIDEO_CONFERENCE.ROOM_URL') }}
                </span>
                <span class="flex gap-2">
                  <input
                    :value="moderatorUrl || t('VIDEO_CONFERENCE.URL_NOT_SET')"
                    type="text"
                    readonly
                    class="h-10 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs text-n-slate-12"
                    data-testid="moderator-url"
                  />
                  <button
                    type="button"
                    class="rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-60"
                    data-testid="copy-moderator-url"
                    :disabled="!hasModeratorUrl"
                    @click="copyValue('moderator-url', moderatorUrl)"
                  >
                    {{
                      copiedField === 'moderator-url'
                        ? t('VIDEO_CONFERENCE.URL_COPIED')
                        : t('VIDEO_CONFERENCE.COPY_URL')
                    }}
                  </button>
                </span>
              </label>
              <label class="mt-3 grid gap-1.5">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('VIDEO_CONFERENCE.ROOM_PASSWORD') }}
                </span>
                <template v-if="moderatorPassword">
                  <input
                    :value="moderatorPassword"
                    :type="visiblePasswords.moderator ? 'text' : 'password'"
                    readonly
                    class="h-10 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs text-n-slate-12"
                    data-testid="moderator-password"
                  />
                  <span class="grid grid-cols-2 gap-2">
                    <button
                      type="button"
                      class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
                      data-testid="toggle-moderator-password"
                      @click="togglePassword('moderator')"
                    >
                      {{
                        visiblePasswords.moderator
                          ? t('VIDEO_CONFERENCE.HIDE_PASSWORD')
                          : t('VIDEO_CONFERENCE.SHOW_PASSWORD')
                      }}
                    </button>
                    <button
                      type="button"
                      class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
                      data-testid="copy-moderator-password"
                      @click="
                        copyValue('moderator-password', moderatorPassword)
                      "
                    >
                      {{
                        copiedField === 'moderator-password'
                          ? t('VIDEO_CONFERENCE.PASSWORD_COPIED')
                          : t('VIDEO_CONFERENCE.COPY_PASSWORD')
                      }}
                    </button>
                  </span>
                </template>
                <span v-else class="text-xs text-n-slate-10">
                  {{ t('VIDEO_CONFERENCE.PASSWORD_NOT_SET') }}
                </span>
              </label>
            </div>

            <div class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('VIDEO_CONFERENCE.SPECTATOR') }}
              </p>
              <label class="mt-3 grid gap-1.5">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('VIDEO_CONFERENCE.ROOM_URL') }}
                </span>
                <span class="flex gap-2">
                  <input
                    :value="spectatorUrl || t('VIDEO_CONFERENCE.URL_NOT_SET')"
                    type="text"
                    readonly
                    class="h-10 min-w-0 flex-1 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs text-n-slate-12"
                    data-testid="spectator-url"
                  />
                  <button
                    type="button"
                    class="rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-60"
                    data-testid="copy-spectator-url"
                    :disabled="!hasSpectatorUrl"
                    @click="copyValue('spectator-url', spectatorUrl)"
                  >
                    {{
                      copiedField === 'spectator-url'
                        ? t('VIDEO_CONFERENCE.URL_COPIED')
                        : t('VIDEO_CONFERENCE.COPY_URL')
                    }}
                  </button>
                </span>
              </label>
              <label class="mt-3 grid gap-1.5">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('VIDEO_CONFERENCE.ROOM_PASSWORD') }}
                </span>
                <template v-if="spectatorPassword">
                  <input
                    :value="spectatorPassword"
                    :type="visiblePasswords.spectator ? 'text' : 'password'"
                    readonly
                    class="h-10 rounded-lg border border-n-weak bg-n-solid-2 px-3 text-xs text-n-slate-12"
                    data-testid="spectator-password"
                  />
                  <span class="grid grid-cols-2 gap-2">
                    <button
                      type="button"
                      class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
                      data-testid="toggle-spectator-password"
                      @click="togglePassword('spectator')"
                    >
                      {{
                        visiblePasswords.spectator
                          ? t('VIDEO_CONFERENCE.HIDE_PASSWORD')
                          : t('VIDEO_CONFERENCE.SHOW_PASSWORD')
                      }}
                    </button>
                    <button
                      type="button"
                      class="rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
                      data-testid="copy-spectator-password"
                      @click="
                        copyValue('spectator-password', spectatorPassword)
                      "
                    >
                      {{
                        copiedField === 'spectator-password'
                          ? t('VIDEO_CONFERENCE.PASSWORD_COPIED')
                          : t('VIDEO_CONFERENCE.COPY_PASSWORD')
                      }}
                    </button>
                  </span>
                </template>
                <span v-else class="text-xs text-n-slate-10">
                  {{ t('VIDEO_CONFERENCE.PASSWORD_NOT_SET') }}
                </span>
              </label>
            </div>
          </div>
        </section>
      </template>

      <p
        v-else
        class="mt-5 rounded-xl border border-n-weak bg-n-solid-2 px-4 py-5 text-sm text-n-slate-11"
      >
        {{ t('VIDEO_CONFERENCE.UNAVAILABLE') }}
      </p>
    </div>
  </section>
</template>
