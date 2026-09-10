<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/jrcNicoOperations';
import videoSettings from 'dashboard/api/videoConferenceSettings';
import { openVideoConferencePopup } from 'dashboard/helper/videoConference';
import { useCallsStore } from 'dashboard/stores/calls';
import { useSipWebphone } from 'dashboard/routes/dashboard/webphone/useSipWebphone';
import { useJrcCopilot } from './useJrcCopilot';
import { useNicoVoice } from './useNicoVoice';
import NicoKnowledgePanel from './NicoKnowledgePanel.vue';
import NicoConversationPanel from './NicoConversationPanel.vue';
import { runNicoBrowserAction } from './nicoBrowserActions';
import { runNicoModuleAction } from './nicoModuleActions';
import { nextNicoAutomaticCall } from './nicoAutomaticCalls';
import { useWhatsappCallSession } from 'dashboard/composables/useWhatsappCallSession';

const props = defineProps({ embedded: { type: Boolean, default: false } });
const { t } = useI18n();
const label = key => t(`JRC_NICO.OPERATOR.${key}`);
const avatarUrl = '/brand-assets/jrc-copilot-avatar.png';
const route = useRoute();
const router = useRouter();
const {
  isOpen,
  close,
  pendingPrompt,
  consumePrompt,
  suggestionCount,
  notices,
  focusedNoticeId,
  openNotice,
} = useJrcCopilot();
const accountId = computed(() => Number(route.params.accountId));
const conversationId = computed(
  () =>
    Number(route.params.conversation_id || route.params.conversationId) ||
    undefined
);
const visible = computed(() => props.embedded || isOpen.value);
const input = ref('');
const busy = ref(false);
const error = ref('');
const emptyState = () => ({
  messages: [],
  commands: [],
  delegations: [],
  suggestions: [],
  tools: [],
});
const state = ref(emptyState());
const scroller = ref(null);
const panelRoot = ref(null);
const delegateForm = ref(false);
const knowledgeOpen = ref(false);
const choices = ref([]);
const selected = ref([]);
const objective = ref('');
const hours = ref(2);
const allowCrm = ref(false);
const allowedActions = ref([]);
const automaticAttempts = new Set();
const actionOptions = computed(() =>
  [
    ['contacts', 'update_contact'],
    ['proposals', 'create_proposal'],
    ['meetings', 'create_activity'],
    ['calls', 'call_contact'],
  ].filter(([, toolName]) =>
    state.value.tools.some(tool => tool.name === toolName)
  )
);
const expandedHistory = ref(false);
const sip = useSipWebphone();
const whatsapp = useWhatsappCallSession();
const calls = useCallsStore();
const inCall = computed(
  () => sip.hasCall.value || calls.hasActiveCall || calls.hasIncomingCall
);
const voice = useNicoVoice({
  transcribe: (audio, signal) => api.transcribe(accountId.value, audio, signal),
  onTranscript: text => {
    input.value = text;
  },
  inCall,
});
const pending = computed(() =>
  state.value.commands.filter(
    c =>
      (!focusedNoticeId.value ||
        c.source_notice_id === focusedNoticeId.value) &&
      [
        'awaiting_confirmation',
        'browser_pending',
        'executing',
        'unknown',
      ].includes(c.status)
  )
);
const messages = computed(() =>
  expandedHistory.value ? state.value.messages : state.value.messages.slice(-8)
);
const latest = computed(() => state.value.commands[0]);
const receipts = computed(() =>
  state.value.commands
    .filter(c => c.status === 'succeeded' && c.result?.record?.id)
    .slice(0, 4)
);
let version = 0;
let poll;
let abort;
const apply = data => {
  state.value = data;
  suggestionCount.value =
    data.suggestions.length +
    data.delegations.filter(d => d.status === 'needs_human').length;
};
const load = async () => {
  if (!accountId.value || busy.value) return;
  const current = version;
  abort?.abort();
  abort = new AbortController();
  try {
    const { data } = await api.show(accountId.value, abort.signal);
    if (current === version) apply(data);
  } catch (e) {
    if (current === version && e.code !== 'ERR_CANCELED')
      error.value = label('LOAD_ERROR');
  }
};
const perform = async action => {
  if (busy.value) return;
  const current = version;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await action();
    if (current !== version) return;
    apply(data);
    voice.speak(data.messages.at(-1)?.content);
    await nextTick();
    scroller.value?.scrollTo({ top: scroller.value.scrollHeight });
    return data;
  } catch {
    if (current === version) {
      error.value = label('ACTION_ERROR');
      busy.value = false;
      await load();
    }
  } finally {
    if (current === version) busy.value = false;
  }
};
const ask = async prompt => {
  const message = String(prompt ?? input.value).trim();
  if (!message || busy.value) return;
  focusedNoticeId.value = null;
  input.value = '';
  voice.stop();
  await perform(() =>
    api.ask(accountId.value, {
      message,
      request_id: crypto.randomUUID(),
      conversation_id: conversationId.value,
    })
  );
};
const navigate = async result => {
  if (!result?.route_name || !router.hasRoute(result.route_name)) return;
  const record = result.record;
  const name =
    result.resource_type === 'Contact' && record?.id
      ? 'contacts_edit'
      : result.route_name;
  const params = { accountId: accountId.value };
  const query = {};
  if (result.resource_type === 'Contact' && record?.id)
    params.contactId = record.id;
  if (result.resource_type === 'JrcCrm::Lead' && record?.id)
    query.leadId = record.id;
  if (result.resource_type === 'JrcCrm::Deal' && record?.id)
    query.dealId = record.id;
  await router.push({
    name,
    params,
    query,
  });
  if (window.innerWidth < 640) close();
};
const openConversation = async id => {
  await router.push(`/app/accounts/${accountId.value}/conversations/${id}`);
  if (window.innerWidth < 640) close();
};
const prepareDelegation = async () => {
  delegateForm.value = true;
  objective.value ||= label('DEFAULT_OBJECTIVE');
  if (conversationId.value) selected.value = [conversationId.value];
  try {
    choices.value = (await api.conversations(accountId.value)).data;
  } catch {
    error.value = label('LOAD_ERROR');
  }
};
const submitDelegation = async () => {
  await perform(() =>
    api.prepare(accountId.value, {
      message: `${label('DELEGATE')}: ${selected.value.join(', ')}`,
      request_id: crypto.randomUUID(),
      tool: 'delegate_conversations',
      arguments: {
        conversation_ids: selected.value,
        objective: objective.value,
        hours: Number(hours.value),
        allow_crm: allowCrm.value,
        allowed_actions: allowedActions.value,
      },
    })
  );
  delegateForm.value = false;
};
const browserAction = async command => {
  if (busy.value) return;
  const current = version;
  const account = accountId.value;
  busy.value = true;
  error.value = '';
  let claimed = false;
  let status = 'unknown';
  let detail = label('BROWSER_UNKNOWN');
  try {
    const { data } = await api.command(account, command.id, 'claim');
    claimed = true;
    if (current !== version) throw new Error(label('ACCOUNT_CHANGED'));
    detail =
      data.result.browser_action === 'module_action'
        ? await runNicoModuleAction(account, data.result, { whatsapp })
        : await runNicoBrowserAction(data.result, {
            sip,
            openVideo: () =>
              openVideoConferencePopup({
                getSetting: async () =>
                  (await videoSettings.getFreshMine()).data,
              }),
          });
    status = 'succeeded';
  } catch (e) {
    detail = e.message || label('ACTION_ERROR');
    status =
      e.isAxiosError && (!e.response || e.response.status >= 500)
        ? 'unknown'
        : 'failed';
  } finally {
    try {
      if (claimed) {
        const { data } = await api.command(account, command.id, 'receipt', {
          status,
          detail,
        });
        if (current === version) apply(data);
      } else if (current === version)
        error.value = label('BROWSER_CLAIM_ERROR');
    } catch {
      if (current === version) error.value = label('BROWSER_UNKNOWN');
    }
    if (current === version) busy.value = false;
  }
};
const confirmAndExecute = async command => {
  const data = await perform(() =>
    api.command(accountId.value, command.id, 'confirm')
  );
  const confirmed = data?.commands.find(item => item.id === command.id);
  if (confirmed?.status === 'browser_pending') await browserAction(confirmed);
};
watch(
  () => [state.value.commands, busy.value, sip.registered.value, inCall.value],
  () => {
    if (props.embedded || busy.value) return;
    const command = nextNicoAutomaticCall(state.value.commands, {
      registered: sip.registered.value,
      inCall: inCall.value,
      attempted: automaticAttempts,
    });
    if (!command) return;
    automaticAttempts.add(command.id);
    browserAction(command);
  }
);
const formatValue = (value, field) => {
  if (field === 'allowed_actions')
    return value
      .map(action => t(`JRC_NICO.OPERATOR.ACTIONS.${action}`))
      .join(', ');
  if (typeof value === 'boolean') return label(value ? 'YES' : 'NO');
  return Array.isArray(value) ? value.join(', ') : String(value);
};
const toolLabel = command =>
  state.value.tools.find(tool => tool.name === command.tool)?.description ||
  command.reply;
watch(
  () => accountId.value,
  async () => {
    version += 1;
    abort?.abort();
    voice.stop();
    window.speechSynthesis?.cancel();
    input.value = '';
    busy.value = false;
    error.value = '';
    selected.value = [];
    allowCrm.value = false;
    allowedActions.value = [];
    automaticAttempts.clear();
    delegateForm.value = false;
    knowledgeOpen.value = false;
    state.value = emptyState();
    suggestionCount.value = 0;
    await load();
  }
);
watch(pendingPrompt, value => {
  if (value) ask(consumePrompt());
});
watch(visible, async value => {
  if (value) {
    load();
    await nextTick();
    if (!props.embedded) panelRoot.value?.focus({ preventScroll: true });
  }
  if (!value) {
    voice.stop();
    window.speechSynthesis?.cancel();
  }
});
watch(focusedNoticeId, () => load());
onMounted(async () => {
  await load();
  if (pendingPrompt.value) await ask(consumePrompt());
  poll = setInterval(load, 5000);
});
onBeforeUnmount(() => {
  version += 1;
  abort?.abort();
  clearInterval(poll);
});
</script>

<template>
  <aside
    v-if="visible"
    ref="panelRoot"
    tabindex="-1"
    :id="embedded ? undefined : 'nico-operator-panel'"
    :aria-label="label('TITLE')"
    class="flex min-h-0 shrink-0 flex-col overflow-hidden border-t border-n-weak bg-n-solid-2 shadow-sm min-[1920px]:border-l"
    :class="
      embedded
        ? 'h-full w-full'
        : 'h-full sm:h-[42vh] w-full min-[1920px]:h-full min-[1920px]:w-[380px]'
    "
  >
    <header
      class="flex shrink-0 items-center gap-2 border-b border-n-weak bg-n-alpha-2 px-3 py-2"
    >
      <img :src="avatarUrl" alt="" class="size-9 rounded-full" />
      <div class="min-w-0 flex-1">
        <h2 class="text-sm font-semibold">{{ label('TITLE') }}</h2>
        <p class="truncate text-xs text-n-slate-11">
          {{
            conversationId
              ? t('JRC_NICO.OPERATOR.CONTEXT', { id: conversationId })
              : label('PRIVATE')
          }}
        </p>
      </div>
      <button
        type="button"
        class="rounded p-2 hover:bg-n-alpha-3"
        :aria-label="label('DELEGATE')"
        @click="prepareDelegation"
      >
        <span class="i-lucide-bot size-5" />
      </button>
      <button
        v-if="state.can_manage_knowledge"
        type="button"
        class="rounded p-2 hover:bg-n-alpha-3"
        :aria-label="label('KNOWLEDGE')"
        @click="knowledgeOpen = !knowledgeOpen"
      >
        <span class="i-lucide-book-open size-5" />
      </button>
      <button
        v-if="!embedded"
        type="button"
        class="rounded p-2 hover:bg-n-alpha-3"
        :aria-label="label('MINIMIZE')"
        @click="close"
      >
        <span class="i-lucide-chevron-down size-5" />
      </button>
    </header>
    <div
      ref="scroller"
      class="min-h-0 flex-1 space-y-3 overflow-y-auto px-3 py-3"
    >
      <p
        v-if="error"
        role="alert"
        class="rounded bg-n-ruby-3 p-2 text-sm text-n-ruby-11"
      >
        {{ error }}
      </p>
      <form
        v-if="delegateForm"
        class="space-y-3 rounded border border-n-weak p-3"
        @submit.prevent="submitDelegation"
      >
        <h3 class="text-sm font-semibold">{{ label('DELEGATE') }}</h3>
        <div class="max-h-40 space-y-2 overflow-auto">
          <label
            v-for="choice in choices"
            :key="choice.id"
            class="flex items-center gap-2 text-sm"
            ><input
              v-model="selected"
              type="checkbox"
              :value="choice.id"
            /><span
              >{{ choice.name }} · {{ choice.id }} · {{ choice.inbox }}</span
            ></label
          >
        </div>
        <label class="block text-xs"
          >{{ label('OBJECTIVE')
          }}<textarea
            v-model="objective"
            required
            maxlength="2000"
            rows="3"
            class="mt-1 w-full rounded border border-n-weak bg-n-solid-2 p-2 text-sm"
          />
        </label>
        <label class="flex items-center gap-2 text-xs"
          >{{ label('HOURS')
          }}<input
            v-model="hours"
            type="number"
            min="1"
            max="8"
            required
            class="w-16 rounded border border-n-weak bg-n-solid-2 p-1"
        /></label>
        <label
          v-if="state.tools.some(tool => tool.name === 'create_lead')"
          class="flex items-center gap-2 text-xs"
          ><input v-model="allowCrm" type="checkbox" />{{
            label('ALLOW_CRM')
          }}</label
        >
        <p class="text-xs text-n-slate-11">{{ label('DELEGATION_SCOPE') }}</p>
        <fieldset class="space-y-2 rounded border border-n-weak p-2 text-xs">
          <legend class="px-1 font-medium">
            {{ label('AUTOMATIC_ACTIONS') }}
          </legend>
          <label
            v-for="[action] in actionOptions"
            :key="action"
            class="flex items-start gap-2"
          >
            <input v-model="allowedActions" type="checkbox" :value="action" />
            <span>{{ t(`JRC_NICO.OPERATOR.ACTIONS.${action}`) }}</span>
          </label>
          <p class="text-n-slate-11">{{ label('AUTOMATIC_SCOPE') }}</p>
        </fieldset>
        <div class="flex gap-2">
          <button
            type="submit"
            :disabled="busy || !selected.length || selected.length > 20"
            class="rounded bg-n-blue-10 px-3 py-2 text-xs text-white disabled:opacity-40"
          >
            {{ label('REVIEW') }}
          </button>
          <button
            type="button"
            class="rounded border border-n-weak px-3 py-2 text-xs"
            @click="delegateForm = false"
          >
            {{ label('CANCEL') }}
          </button>
        </div>
      </form>
      <NicoKnowledgePanel
        v-if="knowledgeOpen && state.can_manage_knowledge"
        :account-id="accountId"
      />
      <section
        v-if="notices.length"
        class="space-y-2 rounded border border-n-weak p-2"
      >
        <div class="flex items-center justify-between gap-2">
          <h3 class="text-xs font-semibold">{{ label('NOTICES') }}</h3>
          <button
            v-if="focusedNoticeId"
            type="button"
            class="text-xs text-n-blue-11"
            @click="focusedNoticeId = null"
          >
            {{ label('ALL_ACTIONS') }}
          </button>
        </div>
        <article
          v-for="notice in notices.slice(0, 8)"
          :key="notice.id"
          class="border-t border-n-weak pt-2 text-xs"
        >
          <button
            type="button"
            class="font-semibold text-n-blue-11"
            @click="openNotice(notice.id)"
          >
            {{ notice.contact_name || label('TITLE') }}
          </button>
          <p class="mt-1 whitespace-pre-wrap">{{ notice.body }}</p>
          <div class="mt-2 flex flex-wrap gap-2">
            <button
              v-if="notice.kind === 'action' && notice.status === 'failed'"
              type="button"
              :disabled="busy"
              class="rounded border border-n-weak px-2 py-1 text-n-blue-11"
              @click="perform(() => api.retryNotice(accountId, notice.id))"
            >
              {{ label('RETRY_REQUEST') }}
            </button>
            <button
              v-if="notice.kind === 'action'"
              type="button"
              class="rounded border border-n-weak px-2 py-1"
              @click="openNotice(notice.id)"
            >
              {{ label('REVIEW_ACTIONS') }}
            </button>
            <button
              v-if="notice.conversation_id"
              type="button"
              class="text-n-blue-11"
              @click="openConversation(notice.conversation_id)"
            >
              {{ label('OPEN_CONVERSATION') }}
            </button>
          </div>
        </article>
      </section>
      <details v-if="conversationId" class="rounded border border-n-weak p-2">
        <summary class="cursor-pointer text-xs font-medium">
          {{ label('SPECIALISTS') }}
        </summary>
        <NicoConversationPanel
          :account-id="accountId"
          :conversation-id="conversationId"
          :can-manage="state.can_manage_knowledge"
        />
      </details>
      <details
        v-if="state.delegations.length"
        class="rounded border border-n-weak p-2"
        :open="
          state.delegations.some(d =>
            ['active', 'needs_human'].includes(d.status)
          )
        "
      >
        <summary class="cursor-pointer text-xs font-medium">
          {{ label('DELEGATIONS') }}
        </summary>
        <div
          v-for="delegation in state.delegations"
          :key="delegation.id"
          class="mt-2 border-t border-n-weak pt-2 text-xs"
        >
          <button
            class="font-medium text-n-blue-11"
            type="button"
            @click="openConversation(delegation.conversation_id)"
          >
            {{ delegation.contact_name }} · {{ delegation.conversation_id }}
          </button>
          <p>{{ t(`JRC_NICO.OPERATOR.STATES.${delegation.status}`) }}</p>
          <p
            v-if="delegation.summary"
            class="mt-1 line-clamp-2 whitespace-pre-wrap"
            :title="delegation.summary"
          >
            {{ delegation.summary }}
          </p>
          <button
            v-if="['active', 'needs_human'].includes(delegation.status)"
            :disabled="busy"
            type="button"
            class="mt-2 rounded border border-n-weak px-2 py-1"
            @click="
              perform(() => api.takeover(accountId, delegation.conversation_id))
            "
          >
            {{ label('TAKEOVER') }}
          </button>
        </div>
      </details>
      <details
        v-if="state.suggestions.length"
        class="rounded border border-n-weak p-2"
      >
        <summary class="cursor-pointer text-xs">
          {{
            t('JRC_NICO.OPERATOR.SUGGESTIONS', {
              count: state.suggestions.length,
            })
          }}
        </summary>
        <button
          v-for="suggestion in state.suggestions"
          :key="suggestion.conversation_id"
          type="button"
          class="mt-2 block text-left text-xs text-n-blue-11"
          @click="openConversation(suggestion.conversation_id)"
        >
          {{
            t('JRC_NICO.OPERATOR.SUGGESTION', {
              name: suggestion.name,
              id: suggestion.conversation_id,
            })
          }}
        </button>
      </details>
      <p v-if="!state.messages.length" class="text-sm text-n-slate-11">
        {{ label('GREETING') }}
      </p>
      <button
        v-if="state.messages.length > 8"
        type="button"
        class="text-xs text-n-blue-11"
        @click="expandedHistory = !expandedHistory"
      >
        {{ label('HISTORY') }}
      </button>
      <div
        v-for="(message, index) in messages"
        :key="`${message.at}-${index}`"
        class="flex"
        :class="message.role === 'user' ? 'justify-end' : ''"
      >
        <p
          class="max-w-full whitespace-pre-wrap break-words rounded-xl px-3 py-2 text-sm"
          :class="message.role === 'user' ? 'bg-n-blue-3' : 'bg-n-alpha-2'"
        >
          {{ message.content }}
        </p>
      </div>
      <article
        v-for="command in pending"
        :key="command.id"
        class="space-y-2 rounded-xl border border-n-weak p-3"
      >
        <button
          v-if="command.source_conversation_id"
          type="button"
          class="text-xs font-semibold text-n-blue-11"
          @click="openConversation(command.source_conversation_id)"
        >
          {{ command.source_contact }} · #{{ command.source_conversation_id }}
        </button>
        <p class="text-xs font-semibold">
          {{ t(`JRC_NICO.OPERATOR.STATES.${command.status}`) }}
        </p>
        <p class="text-sm">{{ toolLabel(command) }}</p>
        <p
          v-if="command.authorization?.source === 'delegation'"
          class="text-xs text-n-teal-11"
        >
          {{ label('DELEGATED_AUTHORIZATION') }}
        </p>
        <dl class="space-y-1 text-xs">
          <div
            v-for="(value, field) in command.arguments"
            :key="field"
            class="flex flex-wrap gap-x-2"
          >
            <dt class="text-n-slate-11">
              {{ t(`JRC_NICO.OPERATOR.FIELDS.${field}`) }}
            </dt>
            <dd class="break-words">{{ formatValue(value, field) }}</dd>
          </div>
        </dl>
        <div class="flex flex-wrap gap-2">
          <button
            v-if="command.status === 'awaiting_confirmation'"
            type="button"
            :disabled="busy"
            class="rounded bg-n-blue-10 px-3 py-2 text-xs text-white disabled:opacity-40"
            @click="confirmAndExecute(command)"
          >
            {{ label('CONFIRM') }}
          </button>
          <button
            v-if="command.status === 'browser_pending'"
            type="button"
            :disabled="busy"
            class="rounded bg-n-blue-10 px-3 py-2 text-xs text-white disabled:opacity-40"
            @click="browserAction(command)"
          >
            {{ label('RUN_HERE') }}
          </button>
          <button
            v-if="
              ['awaiting_confirmation', 'browser_pending'].includes(
                command.status
              )
            "
            type="button"
            :disabled="busy"
            class="rounded border border-n-weak px-3 py-2 text-xs"
            @click="perform(() => api.command(accountId, command.id, 'cancel'))"
          >
            {{ label('CANCEL') }}
          </button>
        </div>
      </article>
      <button
        v-if="latest?.status === 'succeeded' && latest.result?.route_name"
        type="button"
        class="rounded border border-n-weak px-3 py-2 text-xs text-n-blue-11"
        @click="navigate(latest.result)"
      >
        {{ label('OPEN_RESULT') }}
      </button>
      <details v-if="receipts.length" class="rounded border border-n-weak p-2">
        <summary class="cursor-pointer text-xs font-medium">
          {{ label('RECEIPTS') }}
        </summary>
        <article
          v-for="receipt in receipts"
          :key="receipt.id"
          class="mt-2 space-y-1 border-t border-n-weak pt-2 text-xs"
        >
          <p class="font-medium">{{ receipt.result.message }}</p>
          <p>
            {{
              t('JRC_NICO.OPERATOR.RECORD', {
                id: receipt.result.record.id,
                name: receipt.result.record.name || receipt.result.record.title,
              })
            }}
          </p>
          <button
            type="button"
            class="text-n-blue-11"
            @click="navigate(receipt.result)"
          >
            {{ label('OPEN_RESULT') }}
          </button>
        </article>
      </details>
      <p v-if="busy" role="status" class="text-xs text-n-slate-11">
        {{ label('WORKING') }}
      </p>
    </div>
    <footer class="shrink-0 space-y-1 border-t border-n-weak px-3 py-2">
      <form class="flex items-end gap-2" @submit.prevent="ask()">
        <textarea
          v-model="input"
          :aria-label="label('INPUT')"
          :placeholder="label('INPUT')"
          maxlength="4000"
          rows="2"
          class="min-w-0 flex-1 resize-none rounded border border-n-weak bg-n-solid-2 p-2 text-sm"
          @keydown.enter.exact.prevent="ask()"
        />
        <button
          type="button"
          :disabled="
            !voice.supported || inCall || busy || voice.transcribing.value
          "
          class="rounded border border-n-weak p-2 disabled:opacity-40"
          :aria-label="
            voice.listening.value ? label('STOP_VOICE') : label('VOICE')
          "
          :aria-pressed="voice.listening.value"
          @click="voice.start"
        >
          <span
            :class="voice.listening.value ? 'i-lucide-square' : 'i-lucide-mic'"
            class="size-5"
          />
        </button>
        <button
          type="submit"
          :disabled="busy || !input.trim()"
          class="rounded bg-n-blue-10 p-2 text-white disabled:opacity-40"
          :aria-label="label('SEND')"
        >
          <span class="i-lucide-send size-5" />
        </button>
      </form>
      <div
        class="flex flex-wrap items-center justify-between gap-2 text-xs text-n-slate-11"
      >
        <span>{{
          voice.transcribing.value
            ? label('TRANSCRIBING')
            : voice.listening.value
              ? label('LISTENING')
              : voice.supported
                ? label('VOICE_REVIEW')
                : label('VOICE_UNAVAILABLE')
        }}</span
        ><label class="flex items-center gap-1"
          ><input
            v-model="voice.speakingEnabled.value"
            type="checkbox"
            :disabled="inCall"
          />{{ label('SPEAK') }}</label
        >
      </div>
      <p v-if="voice.error.value" role="alert" class="text-xs text-n-ruby-11">
        {{ label('VOICE_ERROR') }}
      </p>
      <button
        v-if="voice.listening.value || voice.transcribing.value"
        type="button"
        class="text-xs text-n-blue-11"
        @click="voice.stop"
      >
        {{ label('CANCEL') }}
      </button>
    </footer>
  </aside>
</template>
