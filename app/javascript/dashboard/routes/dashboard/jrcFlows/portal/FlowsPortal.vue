<script setup>
import { computed, ref, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import FlowsPage from '../FlowsPage.vue';
import messages from './en.json';
import { makeClient, flowsClient } from './client';

const { t } = useI18n({
  useScope: 'local',
  messages: { en: messages, pt_BR: messages, pt: messages },
});
const config = JSON.parse(
  document.getElementById('flows-portal').dataset.config || '{}'
);
const email = ref('');
const password = ref('');
const otp = ref('');
const mfaToken = ref('');
const user = ref(null);
const accountId = ref(config.accountId || null);
const connections = ref([]);
const editing = ref(null);
const selected = ref(null);
const editor = ref(null);
const busy = ref(false);
const error = ref('');
const notice = ref('');
const contextId = ref(null);
const embedded = window.parent !== window;
const portalPath = window.location.pathname;
const headers = {};
const request = makeClient(headers);
const base = computed(
  () => `/api/v1/accounts/${accountId.value}/jrc_flow_connections`
);
const editorApi = computed(() =>
  selected.value
    ? flowsClient(request, accountId.value, selected.value.id)
    : null
);
const accounts = computed(() =>
  (user.value?.accounts || []).filter(a => a.role === 'administrator')
);
const blankSecrets = () => ({
  api_token: '',
  openai_api_key: '',
  http_api_key: '',
});

async function run(fn) {
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    return await fn();
  } catch (e) {
    error.value = e.message || t('ERROR');
    if (e.response?.status === 401) user.value = null;
    return null;
  } finally {
    busy.value = false;
  }
}
async function load() {
  selected.value = null;
  connections.value = (await request(base.value)).data;
}
async function login() {
  await run(async () => {
    const body = mfaToken.value
      ? { mfa_token: mfaToken.value, otp_code: otp.value }
      : { email: email.value, password: password.value };
    const result = await request('/auth/sign_in', 'POST', body);
    password.value = '';
    if (result.data.mfa_required) {
      mfaToken.value = result.data.mfa_token;
      return;
    }
    const identity = result.data.data;
    const allowed = (identity?.accounts || []).filter(
      a => a.role === 'administrator'
    );
    if (
      !allowed.length ||
      (config.accountId && !allowed.some(a => a.id === config.accountId))
    )
      throw new Error(t('NO_ACCOUNT'));
    user.value = identity;
    accountId.value = config.accountId || allowed[0].id;
    mfaToken.value = '';
    if (config.connectionId) {
      selected.value = (
        await request(`${base.value}/${config.connectionId}`)
      ).data;
    } else {
      await load();
    }
  });
}
async function logout() {
  if (editor.value && !editor.value.canLeave()) return;
  await run(() => request('/auth/sign_out', 'DELETE'));
  Object.keys(headers).forEach(key => delete headers[key]);
  user.value = null;
  selected.value = null;
  editing.value = null;
}
async function showConnections() {
  if (editor.value && !editor.value.canLeave()) return;
  editing.value = null;
  await run(load);
}
async function changeAccount(event) {
  if (editor.value && !editor.value.canLeave()) {
    event.target.value = accountId.value;
    return;
  }
  accountId.value = Number(event.target.value);
  editing.value = null;
  await run(load);
}
function edit(connection) {
  selected.value = null;
  editing.value = connection
    ? { ...structuredClone(connection), secrets: blankSecrets() }
    : {
        name: '',
        base_url: '',
        remote_account_id: 1,
        inbox_ids: [],
        catalog: {},
        secrets: blankSecrets(),
        credential_configured: [],
      };
  error.value = '';
  notice.value = '';
}
async function persist() {
  const value = editing.value;
  const body = {
    connection: {
      name: value.name,
      base_url: value.base_url,
      remote_account_id: Number(value.remote_account_id),
      inbox_ids: value.inbox_ids,
      secrets: value.secrets,
    },
  };
  const result = await request(
    value.id ? `${base.value}/${value.id}` : base.value,
    value.id ? 'PATCH' : 'POST',
    body
  );
  editing.value = { ...result.data, secrets: blankSecrets() };
  return result.data;
}
async function save() {
  await run(async () => {
    await persist();
    notice.value = t('SAVED');
  });
}
async function action(name) {
  await run(async () => {
    if (name === 'disconnect') {
      // eslint-disable-next-line no-alert
      if (!window.confirm(t('DISCONNECT_CONFIRM'))) return;
    } else if (!editing.value.enabled) {
      await persist();
    }
    const result = await request(
      `${base.value}/${editing.value.id}/${name}`,
      'POST',
      {}
    );
    editing.value = { ...result.data, secrets: blankSecrets() };
    notice.value = t(
      { verify: 'VERIFIED', install: 'INSTALLED', disconnect: 'DISCONNECTED' }[
        name
      ]
    );
  });
}
function open(connection) {
  editing.value = null;
  selected.value = connection;
  error.value = '';
  notice.value = '';
}
function receiveContext(event) {
  if (
    !config.origin ||
    event.origin !== config.origin ||
    event.source !== window.parent
  )
    return;
  let data = event.data;
  try {
    if (typeof data === 'string') data = JSON.parse(data);
  } catch {
    return;
  }
  // Context is display-only. It never authenticates a user or selects another tenant.
  const id = data?.data?.conversation?.id;
  if (Number.isInteger(id) && id > 0) contextId.value = id;
}
onMounted(() => {
  window.addEventListener('message', receiveContext);
  if (config.origin && window.parent !== window)
    window.parent.postMessage(
      'chatwoot-dashboard-app:fetch-info',
      config.origin
    );
});
onBeforeUnmount(() => window.removeEventListener('message', receiveContext));
</script>

<template>
  <main class="flex h-screen min-h-0 flex-col bg-n-background text-n-slate-12">
    <header
      class="flex shrink-0 flex-wrap items-center justify-between gap-3 border-b border-n-weak bg-n-solid-2 px-5 py-3"
    >
      <div class="flex items-center gap-3">
        <span class="i-lucide-workflow size-6 text-n-brand" />
        <strong>{{ config.name || t('TITLE') }}</strong>
        <span v-if="contextId" class="text-xs text-n-slate-11">
          {{ t('CONTEXT') }} #{{ contextId }}
        </span>
      </div>
      <a
        v-if="embedded"
        :href="portalPath"
        target="_blank"
        rel="noopener noreferrer"
        class="text-sm text-n-blue-11"
      >
        {{ t('EXPAND') }}
      </a>
      <div v-if="user" class="flex items-center gap-3">
        <select
          v-if="!config.connectionId"
          :value="accountId"
          :aria-label="t('ACCOUNT')"
          class="max-w-60"
          @change="changeAccount"
        >
          <option
            v-for="account in accounts"
            :key="account.id"
            :value="account.id"
          >
            {{ account.name }}
          </option>
        </select>
        <Button
          v-if="!config.connectionId && (selected || editing)"
          :label="t('CONNECTIONS')"
          variant="ghost"
          @click="showConnections"
        />
        <Button :label="t('EXIT')" variant="ghost" @click="logout" />
      </div>
    </header>
    <div
      v-if="error"
      role="alert"
      class="m-4 rounded-lg bg-n-ruby-3 p-3 text-n-ruby-11"
    >
      {{ error }}
    </div>
    <div
      v-if="notice"
      role="status"
      class="m-4 rounded-lg bg-n-teal-3 p-3 text-n-teal-11"
    >
      {{ notice }}
    </div>
    <form
      v-if="!user"
      class="m-auto w-full max-w-md space-y-5 rounded-2xl border border-n-weak bg-n-solid-2 p-8 shadow-sm"
      @submit.prevent="login"
    >
      <h1 class="text-xl font-semibold">{{ t('LOGIN_TITLE') }}</h1>
      <p class="text-sm text-n-slate-11">{{ t('LOGIN_HELP') }}</p>
      <template v-if="!mfaToken">
        <label class="block text-sm"
          >{{ t('EMAIL')
          }}<input
            v-model="email"
            required
            type="email"
            autocomplete="username"
            class="mt-1 w-full" /></label
        ><label class="block text-sm"
          >{{ t('PASSWORD')
          }}<input
            v-model="password"
            required
            type="password"
            autocomplete="current-password"
            class="mt-1 w-full"
        /></label>
      </template>
      <label v-else class="block text-sm">
        {{ t('OTP') }}
        <input
          v-model="otp"
          required
          autocomplete="one-time-code"
          class="mt-1 w-full"
        />
      </label>
      <Button
        :label="t('ENTER')"
        type="submit"
        :disabled="busy"
        class="w-full"
      />
    </form>
    <FlowsPage
      v-else-if="selected"
      ref="editor"
      :key="selected.id"
      :api-client="editorApi"
    />
    <div v-else-if="editing" class="min-h-0 overflow-auto p-6">
      <div
        class="mx-auto max-w-4xl space-y-5 rounded-xl border border-n-weak bg-n-solid-2 p-6"
      >
        <h1 class="text-xl font-semibold">
          {{ editing.id ? t('EDIT') : t('NEW') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('INSTALL_HELP') }}</p>
        <div class="grid gap-5 md:grid-cols-2">
          <label class="text-sm"
            >{{ t('NAME')
            }}<input
              v-model="editing.name"
              :disabled="editing.enabled"
              class="mt-1 w-full"
              maxlength="120"
          /></label>
          <label class="text-sm"
            >{{ t('URL')
            }}<input
              v-model="editing.base_url"
              :disabled="!!editing.id"
              class="mt-1 w-full"
              :placeholder="t('URL_EXAMPLE')"
          /></label>
          <label class="text-sm"
            >{{ t('REMOTE_ACCOUNT')
            }}<input
              v-model.number="editing.remote_account_id"
              :disabled="!!editing.id"
              type="number"
              min="1"
              class="mt-1 w-full"
          /></label>
          <label
            v-for="[key, label] in [
              ['api_token', 'TOKEN'],
              ['openai_api_key', 'OPENAI'],
              ['http_api_key', 'HTTP'],
            ]"
            :key="key"
            class="text-sm"
            >{{ t(label)
            }}<input
              v-model="editing.secrets[key]"
              :disabled="editing.enabled"
              type="password"
              autocomplete="new-password"
              class="mt-1 w-full"
              :placeholder="
                t(
                  editing.credential_configured.includes(key)
                    ? 'CONFIGURED'
                    : 'EMPTY'
                )
              "
          /></label>
        </div>
        <p class="text-xs text-n-slate-11">{{ t('INHERIT_HELP') }}</p>
        <fieldset class="rounded-lg border border-n-weak p-4">
          <legend class="px-2 text-sm">{{ t('INBOXES') }}</legend>
          <div class="flex flex-wrap gap-4">
            <label
              v-for="inbox in editing.catalog.inboxes || []"
              :key="inbox.id"
              class="flex items-center gap-2 text-sm"
              ><input
                v-model="editing.inbox_ids"
                :disabled="editing.enabled"
                type="checkbox"
                :value="inbox.id"
              />{{ inbox.name }}</label
            >
            <p
              v-if="!editing.catalog.inboxes?.length"
              class="text-sm text-n-slate-11"
            >
              {{ t('NO_INBOX') }}
            </p>
          </div>
        </fieldset>
        <p v-if="editing.enabled" class="text-sm text-n-slate-11">
          {{ t('EDIT_HELP') }}
        </p>
        <div class="flex flex-wrap gap-3">
          <Button
            :label="t('SAVE')"
            :disabled="busy || editing.enabled"
            @click="save"
          /><Button
            :label="t('VERIFY')"
            variant="outline"
            :disabled="busy"
            @click="action('verify')"
          /><Button
            v-if="!editing.enabled"
            :label="t('INSTALL')"
            :disabled="
              busy || !editing.verified_at || !editing.inbox_ids.length
            "
            @click="action('install')"
          /><Button
            v-else
            :label="t('DISCONNECT')"
            variant="outline"
            color="ruby"
            :disabled="busy"
            @click="action('disconnect')"
          /><Button
            v-if="editing.id"
            :label="t('OPEN')"
            variant="outline"
            @click="open(editing)"
          />
        </div>
        <div
          v-if="editing.portal_url"
          class="space-y-3 rounded-lg bg-n-alpha-1 p-4 text-xs"
        >
          <p class="mb-1 font-medium">{{ t('EMBED_URL') }}</p>
          <code class="break-all">{{ editing.portal_url }}</code>
          <p class="mb-1 font-medium">{{ t('EVENT_URL') }}</p>
          <code class="break-all">{{ editing.webhook_url }}</code>
        </div>
      </div>
    </div>
    <section v-else class="min-h-0 overflow-auto p-6">
      <div class="mx-auto max-w-5xl">
        <div class="mb-6 flex items-center justify-between">
          <h1 class="text-xl font-semibold">{{ t('CONNECTIONS') }}</h1>
          <Button :label="t('NEW')" icon="i-lucide-plus" @click="edit(null)" />
        </div>
        <p v-if="!connections.length" class="text-n-slate-11">
          {{ t('EMPTY_LIST') }}
        </p>
        <div class="grid gap-5 md:grid-cols-2">
          <article
            v-for="connection in connections"
            :key="connection.id"
            class="space-y-4 rounded-xl border border-n-weak bg-n-solid-2 p-5"
          >
            <div class="flex items-start justify-between gap-3">
              <h2 class="text-lg font-semibold">{{ connection.name }}</h2>
              <span class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs">{{
                t(connection.enabled ? 'READY' : 'DRAFT')
              }}</span>
            </div>
            <p class="break-all text-sm text-n-slate-11">
              {{ connection.base_url }}
            </p>
            <div class="flex gap-3">
              <Button :label="t('OPEN')" @click="open(connection)" /><Button
                :label="t('EDIT')"
                variant="outline"
                @click="edit(connection)"
              />
            </div>
          </article>
        </div>
      </div>
    </section>
  </main>
</template>
