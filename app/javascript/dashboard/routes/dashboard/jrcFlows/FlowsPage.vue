<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { onBeforeRouteLeave, useRoute } from 'vue-router';
import { useEventListener } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WorkflowEditor from './WorkflowEditor.vue';
import { workflowTemplate } from './workflowTemplate';
import Button from 'dashboard/components-next/button/Button.vue';
import defaultApi from 'dashboard/api/jrcFlows';
import FlowCanvas from './FlowCanvas.vue';
import FlowInspector from './FlowInspector.vue';
import messages from './en.json';
import {
  NODE_TYPES,
  KINDS,
  clone,
  makeTemplate,
  nodeDefaults,
  ports,
  templateIds,
} from './catalog';

const props = defineProps({ apiClient: { type: Object, default: null } });
const api = props.apiClient || defaultApi;
const { t } = useI18n({
  useScope: 'local',
  messages: { en: messages, pt_BR: messages, pt: messages },
});
const route = useRoute();
const flows = ref([]);
const metadata = ref({
  inboxes: [],
  agents: [],
  teams: [],
  labels: [],
  stages: [],
  capabilities: {},
  triggers: [],
});
const loading = ref(false);
const busy = ref(false);
const error = ref('');
const notice = ref('');
const validation = ref([]);
const search = ref('');
const typeFilter = ref('');
const statusFilter = ref('');
const flow = ref(null);
const saved = ref('');
const selectedId = ref('');
const tab = ref('CANVAS');
const blockSearch = ref('');
const createDialog = ref(null);
const importContent = ref('');
const openaiKey = ref('');
const httpKey = ref('');
const invalidParameters = ref(false);
const newName = ref('');
const template = ref('welcome');
const newInboxes = ref([]);
const importFile = ref(null);
const imported = ref(null);
const pendingDelete = ref(null);
const responses = ref('');
const simulationEvent = ref('MESSAGE');
const simulation = ref(null);
const executions = ref([]);
const expandedRun = ref(null);
const manualConversation = ref('');
const dirty = computed(
  () =>
    flow.value &&
    (JSON.stringify(flow.value) !== saved.value ||
      openaiKey.value ||
      httpKey.value)
);
const readonly = computed(() => flow.value?.status === 'active');
const selected = computed(() =>
  flow.value?.graph.nodes.find(node => node.id === selectedId.value)
);
const visibleFlows = computed(() =>
  flows.value.filter(
    item =>
      (!typeFilter.value || item.kind === typeFilter.value) &&
      (!statusFilter.value || item.status === statusFilter.value) &&
      `${item.name} ${item.description || ''}`
        .toLocaleLowerCase()
        .includes(search.value.toLocaleLowerCase())
  )
);
const palette = computed(() =>
  NODE_TYPES.filter(
    node =>
      node.type !== 'start' &&
      (!metadata.value.capabilities.remote ||
        ![
          'media',
          'contact',
          'webhook',
          'create_lead',
          'move_deal',
          'activity',
          'nico',
        ].includes(node.type)) &&
      t(`NODES.${node.type}`)
        .toLocaleLowerCase()
        .includes(blockSearch.value.toLocaleLowerCase())
  )
);
const groups = computed(() =>
  ['messages', 'logic', 'service', 'crm', 'integrations'].filter(group =>
    palette.value.some(node => node.group === group)
  )
);
const availableTemplates = computed(() =>
  props.apiClient ? ['welcome', 'triage'] : templateIds
);
const visited = computed(
  () => simulation.value?.trace.map(item => item.node_id) || []
);
const scheduleConversationIds = computed({
  get: () => (flow.value?.settings.conversation_ids || []).join(', '),
  set: value => {
    flow.value.settings.conversation_ids = [
      ...new Set(
        value
          .split(/[\s,;]+/)
          .filter(Boolean)
          .map(Number)
      ),
    ];
  },
});
const availableTriggers = computed(() =>
  flow.value?.kind === 'chatbot' ? ['message_created'] : metadata.value.triggers
);

function showError(e) {
  const data = e.response?.data;
  if (Array.isArray(data?.errors)) validation.value = data.errors;
  error.value = data?.error || data?.message || e.message || t('ERROR');
}
async function request(action) {
  busy.value = true;
  error.value = '';
  notice.value = '';
  validation.value = [];
  try {
    return await action();
  } catch (e) {
    showError(e);
    return null;
  } finally {
    busy.value = false;
  }
}
async function load() {
  const account = route.params.accountId;
  loading.value = true;
  error.value = '';
  try {
    const [list, meta] = await Promise.all([api.get(), api.metadata()]);
    if (account !== route.params.accountId) return;
    flows.value = list.data;
    metadata.value = meta.data;
  } catch (e) {
    showError(e);
  } finally {
    loading.value = false;
  }
}
function setFlow(value) {
  flow.value = clone(value);
  openaiKey.value = '';
  httpKey.value = '';
  invalidParameters.value = false;
  saved.value = JSON.stringify(flow.value);
  selectedId.value = flow.value.graph.nodes[0]?.id || '';
  simulation.value = null;
  executions.value = [];
  expandedRun.value = null;
  tab.value = 'CANVAS';
}
function canLeave() {
  // eslint-disable-next-line no-alert
  return !dirty.value || window.confirm(t('UNSAVED'));
}
defineExpose({ canLeave });
onBeforeRouteLeave(canLeave);
useEventListener(window, 'beforeunload', event => {
  if (dirty.value) {
    event.preventDefault();
    event.returnValue = '';
  }
});
function back() {
  if (!canLeave()) return;
  flow.value = null;
  validation.value = [];
  error.value = '';
  load();
}
function openConnections() {
  window.open('/flows/portal', '_blank', 'noopener');
}
async function open(item) {
  const result = await request(() => api.show(item.id));
  if (result) setFlow(result.data);
}
function prepareCreate(id = 'welcome') {
  template.value = id;
  newName.value = t(`TEMPLATES.${id}`);
  imported.value = null;
  newInboxes.value = [];
  createDialog.value.open();
}
async function create() {
  if (imported.value || template.value === 'workflow') {
    const result = await request(() =>
      api.importDefinition({
        content: imported.value
          ? importContent.value
          : JSON.stringify(workflowTemplate(newName.value)),
        name: newName.value,
        inbox_ids: newInboxes.value,
      })
    );
    if (result) {
      createDialog.value.close();
      setFlow(result.data);
    }
    return;
  }
  const body = imported.value
    ? {
        ...clone(imported.value),
        name: newName.value,
        settings: { ...imported.value.settings, inbox_ids: newInboxes.value },
      }
    : makeTemplate(template.value, newName.value, newInboxes.value);
  body.graph.nodes.forEach(node => {
    node.label ||= t(`NODES.${node.type}`);
  });
  const result = await request(() => api.create({ flow: body }));
  if (result) {
    createDialog.value.close();
    setFlow(result.data);
  }
}
function payload() {
  const { name, description, kind, graph, settings, lock_version } = flow.value;
  return {
    name,
    description,
    kind,
    graph,
    settings,
    lock_version,
    ...(flow.value.engine === 'workflow'
      ? {
          workflow_json: JSON.stringify(flow.value.workflow),
          connection_secrets: {
            openai_api_key: openaiKey.value,
            http_api_key: httpKey.value,
          },
        }
      : {}),
  };
}
async function save() {
  const result = await request(() =>
    api.update(flow.value.id, { flow: payload() })
  );
  if (result) {
    flow.value = result.data;
    openaiKey.value = '';
    httpKey.value = '';
    saved.value = JSON.stringify(flow.value);
    notice.value = t('SAVED');
  }
}
async function validate() {
  const result = await request(() =>
    api.action(flow.value.id, 'validate_definition', { flow: payload() })
  );
  if (result) {
    validation.value = result.data.errors;
    if (!validation.value.length) notice.value = t('VALID');
  }
}
async function toggle() {
  if (!readonly.value && dirty.value) {
    error.value = t('SAVE_FIRST');
    return;
  }
  const action = readonly.value ? 'pause' : 'activate';
  const result = await request(() => api.action(flow.value.id, action));
  if (result) {
    flow.value = result.data;
    saved.value = JSON.stringify(flow.value);
    notice.value = t(action === 'pause' ? 'FLOW_DISABLED' : 'FLOW_ACTIVE');
  }
}
async function duplicate(item) {
  const result = await request(() => api.action(item.id, 'duplicate'));
  if (result) setFlow(result.data);
}
async function removeFlow(item) {
  if (pendingDelete.value !== item.id) {
    pendingDelete.value = item.id;
    return;
  }
  const result = await request(() => api.delete(item.id));
  if (result) {
    pendingDelete.value = null;
    await load();
  }
}
function addNode(definition) {
  if (readonly.value) return;
  if (flow.value.graph.nodes.length >= 150) {
    error.value = t('LIMIT');
    return;
  }
  const origin = selected.value?.position || { x: 0, y: 80 };
  const node = {
    id: crypto.randomUUID(),
    type: definition.type,
    label: t(`NODES.${definition.type}`),
    position: { x: origin.x + 320, y: origin.y },
    data: nodeDefaults(definition.type),
  };
  while (
    flow.value.graph.nodes.some(
      n =>
        Math.abs(n.position.x - node.position.x) < 270 &&
        Math.abs(n.position.y - node.position.y) < 200
    )
  )
    node.position.y += 220;
  flow.value.graph.nodes.push(node);
  selectedId.value = node.id;
  simulation.value = null;
}
function moveNode(id, position) {
  if (!readonly.value)
    flow.value.graph.nodes.find(node => node.id === id).position = position;
}
function changeNode(value) {
  const index = flow.value.graph.nodes.findIndex(node => node.id === value.id);
  flow.value.graph.nodes[index] = value;
  flow.value.graph.edges = flow.value.graph.edges.filter(
    edge => edge.source !== value.id || ports(value).includes(edge.port)
  );
  simulation.value = null;
}
function connect(edge) {
  if (readonly.value) return;
  flow.value.graph.edges = flow.value.graph.edges.filter(
    item => item.source !== edge.source || item.port !== edge.port
  );
  if (edge.target)
    flow.value.graph.edges.push({ ...edge, id: crypto.randomUUID() });
  simulation.value = null;
}
function removeNode(id) {
  flow.value.graph.nodes = flow.value.graph.nodes.filter(
    node => node.id !== id
  );
  flow.value.graph.edges = flow.value.graph.edges.filter(
    edge => edge.source !== id && edge.target !== id
  );
  selectedId.value = '';
  simulation.value = null;
}
function removeEdge(id) {
  flow.value.graph.edges = flow.value.graph.edges.filter(
    edge => edge.id !== id
  );
  simulation.value = null;
}
async function simulate() {
  const result = await request(() =>
    api.action(flow.value.id, 'simulate', {
      flow: payload(),
      event_type: simulationEvent.value,
      responses: responses.value ? responses.value.split('\n') : [],
    })
  );
  if (result) simulation.value = result.data;
}
async function loadRuns(more = false) {
  const result = await request(() =>
    api.runs(flow.value.id, more ? executions.value.at(-1)?.id : undefined)
  );
  if (result)
    executions.value = more
      ? [...executions.value, ...result.data]
      : result.data;
}
async function stopRun(run) {
  const result = await request(() =>
    api.action(flow.value.id, 'stop_run', { run_id: run.id })
  );
  if (result)
    executions.value = executions.value.map(item =>
      item.id === run.id ? result.data : item
    );
}
async function selectTab(value) {
  tab.value = value;
  if (value === 'RUNS') await loadRuns();
}
async function startManual() {
  const result = await request(() =>
    api.action(flow.value.id, 'start', {
      conversation_id: Number(manualConversation.value),
    })
  );
  if (result) {
    notice.value = t('STARTED');
    await loadRuns();
    notice.value = t('STARTED');
  }
}
async function exportFlow(original = false) {
  if (dirty.value) {
    error.value = t('SAVE_FIRST');
    return;
  }
  const result = await request(() =>
    api.exportDefinition(flow.value.id, original)
  );
  if (!result) return;
  const url = URL.createObjectURL(
    new Blob([JSON.stringify(result.data, null, 2)], {
      type: 'application/json;charset=utf-8',
    })
  );
  const link = document.createElement('a');
  link.href = url;
  link.download =
    (flow.value.name.replace(/[^\p{L}\p{N}_-]+/gu, '-') || 'jrc-flow') +
    (original ? '-n8n' : '') +
    '.json';
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
async function importFlow(event) {
  const file = event.target.files?.[0];
  if (!file) return;
  if (file.size > 2 * 1024 * 1024) {
    error.value = t('WF.FILE_LIMIT');
    event.target.value = '';
    return;
  }
  importContent.value = (await file.text()).replace(/^\uFEFF/, '');
  const result = await request(() =>
    api.importPreview({ content: importContent.value })
  );
  if (result) {
    imported.value = result.data;
    newName.value = result.data.name || t('TITLE');
    newInboxes.value = [];
    createDialog.value.open();
  }
  event.target.value = '';
}
function changeKind() {
  if (flow.value.kind === 'chatbot')
    flow.value.settings.trigger = 'message_created';
}
function toggleDay(day, checked) {
  const days = flow.value.settings.days || [];
  flow.value.settings.days = checked
    ? [...days, day]
    : days.filter(value => value !== day);
}
const date = value => (value ? new Date(value).toLocaleString('pt-BR') : '—');
onMounted(load);
watch(
  () => route.params.accountId,
  () => {
    flow.value = null;
    load();
  }
);
</script>

<template>
  <section
    class="flex h-full min-w-0 flex-1 flex-col overflow-hidden bg-n-background text-n-slate-12"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak bg-n-solid-2 px-6 py-4"
    >
      <div class="flex min-w-0 items-center gap-3">
        <Button
          v-if="flow"
          :aria-label="t('BACK')"
          icon="i-lucide-arrow-left"
          variant="ghost"
          @click="back"
        />
        <span v-else class="i-lucide-workflow size-8 text-n-blue-9" />
        <div class="min-w-0">
          <h1 class="m-0 truncate text-xl font-semibold">
            {{ flow?.name || t('TITLE') }}
          </h1>
          <p class="m-0 mt-1 text-sm text-n-slate-11">
            {{ flow ? t(`KINDS.${flow.kind}`) : t('SUBTITLE') }}
          </p>
        </div>
        <span v-if="flow" class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs">
          {{ t(`STATUSES.${flow.status}`) }}
        </span>
        <span v-if="dirty" class="text-xs text-n-amber-11">
          {{ t('DIRTY') }}
        </span>
      </div>
      <div class="flex flex-wrap gap-2">
        <template v-if="flow">
          <Button
            :label="t('EXPORT')"
            icon="i-lucide-download"
            variant="ghost"
            @click="exportFlow(false)"
          />
          <Button
            v-if="flow.engine === 'workflow'"
            :label="t('WF.EXPORT_N8N')"
            variant="ghost"
            @click="exportFlow(true)"
          />
          <Button
            :label="t('VALIDATE')"
            variant="outline"
            :disabled="busy"
            @click="validate"
          />
          <Button
            v-if="!readonly"
            :label="t('SAVE')"
            icon="i-lucide-save"
            variant="outline"
            :disabled="busy || !dirty || invalidParameters"
            @click="save"
          />
          <Button
            :label="readonly ? t('PAUSE') : t('ACTIVATE')"
            :icon="readonly ? 'i-lucide-pause' : 'i-lucide-play'"
            :disabled="busy || (!readonly && (dirty || flow.kind === 'voice'))"
            @click="toggle"
          />
        </template>
        <template v-else>
          <Button
            v-if="!props.apiClient"
            :label="t('REMOTE_CONNECTIONS')"
            variant="outline"
            @click="openConnections"
          />
          <input
            ref="importFile"
            class="hidden"
            type="file"
            accept=".json,.txt,application/json,text/plain"
            @change="importFlow"
          />
          <Button
            :label="t('IMPORT')"
            icon="i-lucide-upload"
            variant="outline"
            :disabled="loading || busy"
            @click="importFile.click()"
          />
          <Button
            :label="t('NEW')"
            icon="i-lucide-plus"
            :disabled="loading || busy"
            @click="prepareCreate()"
          />
        </template>
      </div>
    </header>

    <Dialog
      ref="createDialog"
      :title="imported ? t('WF.IMPORT_TITLE') : t('CREATE')"
      :confirm-button-label="t('CREATE')"
      :cancel-button-label="t('CANCEL')"
      :disable-confirm-button="busy || !newName.trim()"
      :is-loading="busy"
      @confirm="create"
    >
      <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
        {{ error }}
      </p>
      <p v-if="imported" class="rounded-lg bg-n-blue-3 p-3 text-sm">
        {{
          imported.engine === 'workflow'
            ? t('WF.DETECTED_N8N', { count: imported.external.node_count })
            : t('WF.DETECTED_JRC')
        }}
      </p>
      <label class="block text-sm"
        >{{ t('NAME')
        }}<input
          v-model="newName"
          autofocus
          required
          maxlength="120"
          class="mt-1 w-full"
      /></label>
      <label
        v-if="!imported"
        class="block text-sm font-medium text-n-slate-12 leading-relaxed tracking-normal"
        >{{ t('TEMPLATE')
        }}<select
          v-model="template"
          :aria-label="t('TEMPLATE')"
          class="mt-1 w-full"
        >
          <option v-for="id in availableTemplates" :key="id" :value="id">
            {{ t(`TEMPLATES.${id}`) }}
          </option>
          <option value="workflow">{{ t('WF.NEW_TEMPLATE') }}</option>
        </select></label
      >
      <fieldset>
        <legend class="mb-2 text-sm">{{ t('INBOXES') }}</legend>
        <label
          v-for="inbox in metadata.inboxes"
          :key="inbox.id"
          class="mb-2 flex items-center gap-2 text-sm"
          ><input v-model="newInboxes" type="checkbox" :value="inbox.id" />{{
            inbox.name
          }}</label
        >
      </fieldset>
      <p class="text-xs text-n-slate-11">{{ t('WF.IMPORT_HELP') }}</p>
    </Dialog>

    <div
      v-if="error || notice || validation.length"
      class="space-y-2 px-6 pt-3"
      aria-live="polite"
    >
      <p
        v-if="error"
        role="alert"
        class="rounded-lg bg-n-ruby-3 px-4 py-3 text-sm text-n-ruby-11"
      >
        {{ error }}
      </p>
      <p
        v-if="notice"
        role="status"
        class="rounded-lg bg-n-teal-3 px-4 py-3 text-sm text-n-teal-11"
      >
        {{ notice }}
      </p>
      <div
        v-if="validation.length"
        class="max-h-40 overflow-auto rounded-lg bg-n-amber-3 px-4 py-3 text-sm text-n-amber-11"
      >
        <strong>
          {{ t('VALIDATION_TITLE') }}
        </strong>
        <ul class="m-0 mt-2 list-disc pl-5">
          <li v-for="(item, i) in validation" :key="i">
            {{ item }}
          </li>
        </ul>
      </div>
    </div>

    <div v-if="loading && !flow" class="p-8 text-sm text-n-slate-11">
      {{ t('LOADING') }}
    </div>
    <div v-else-if="!flow" class="flex-1 overflow-y-auto p-6">
      <div class="mb-6 grid gap-4 sm:grid-cols-3">
        <div
          v-for="(value, key) in {
            TOTAL: flows.length,
            AUTOMATIC: flows.filter(f => f.status === 'active').length,
            DRAFTS: flows.filter(f => f.status !== 'active').length,
          }"
          :key="key"
          class="rounded-xl border border-n-weak bg-n-solid-2 p-5"
        >
          <p class="m-0 text-sm text-n-slate-11">
            {{ t(key) }}
          </p>
          <p class="m-0 mt-2 text-3xl font-semibold">
            {{ value }}
          </p>
        </div>
      </div>
      <div class="mb-4 flex flex-wrap gap-3">
        <input
          v-model="search"
          type="search"
          :placeholder="t('SEARCH')"
          :aria-label="t('SEARCH')"
          class="min-w-52 flex-1"
        />
        <select v-model="typeFilter" :aria-label="t('KIND')">
          <option value="">
            {{ t('ALL_TYPES') }}
          </option>
          <option v-for="kind in KINDS" :key="kind" :value="kind">
            {{ t(`KINDS.${kind}`) }}
          </option>
        </select>
        <select v-model="statusFilter" :aria-label="t('ALL')">
          <option value="">
            {{ t('ALL') }}
          </option>
          <option
            v-for="status in ['active', 'draft', 'paused']"
            :key="status"
            :value="status"
          >
            {{ t(`STATUSES.${status}`) }}
          </option>
        </select>
      </div>
      <div
        v-if="!flows.length"
        class="mb-6 rounded-xl border border-dashed border-n-strong p-8 text-center"
      >
        <span
          class="i-lucide-git-branch mx-auto mb-3 block size-10 text-n-blue-9"
        />
        <h2 class="text-lg font-semibold">
          {{ t('EMPTY') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('EMPTY_HELP') }}
        </p>
      </div>
      <p
        v-else-if="!visibleFlows.length"
        class="p-6 text-center text-sm text-n-slate-11"
      >
        {{ t('NO_MATCH') }}
      </p>
      <div class="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
        <article
          v-for="item in visibleFlows"
          :key="item.id"
          class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-2 p-5"
        >
          <div class="flex items-start justify-between gap-3">
            <span class="i-lucide-workflow size-6 text-n-blue-9" /><span
              class="rounded-full px-3 py-1 text-xs"
              :class="
                item.status === 'active'
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              {{ t(`STATUSES.${item.status}`) }}
            </span>
          </div>
          <h3 class="m-0 text-base font-semibold">
            {{ item.name }}
          </h3>
          <p class="m-0 line-clamp-2 text-sm text-n-slate-11">
            {{ item.description || t(`KINDS.${item.kind}`) }}
          </p>
          <p class="m-0 text-xs text-n-slate-10">
            {{ item.run_count }} {{ t('RUN_COUNT') }}
          </p>
          <div class="mt-auto flex flex-wrap gap-2 border-t border-n-weak pt-3">
            <Button
              :label="t('EDIT')"
              size="sm"
              variant="outline"
              :disabled="busy"
              @click="open(item)"
            />
            <Button
              :aria-label="t('DUPLICATE')"
              icon="i-lucide-copy"
              size="sm"
              variant="ghost"
              :disabled="busy"
              @click="duplicate(item)"
            />
            <Button
              v-if="item.status !== 'active'"
              :label="pendingDelete === item.id ? t('CONFIRM_DELETE') : ''"
              :aria-label="t('DELETE')"
              icon="i-lucide-trash-2"
              color="ruby"
              size="sm"
              variant="ghost"
              :disabled="busy"
              @click="removeFlow(item)"
            />
            <Button
              v-if="pendingDelete === item.id"
              :label="t('CANCEL')"
              size="sm"
              variant="ghost"
              @click="pendingDelete = null"
            />
          </div>
          <p
            v-if="pendingDelete === item.id"
            class="m-0 text-xs text-n-ruby-11"
          >
            {{ t('DELETE_HELP') }}
          </p>
        </article>
      </div>
      <div class="mb-4 mt-10">
        <h2 class="text-lg font-semibold">
          {{ t('LIBRARY') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('LIBRARY_HELP') }}
        </p>
      </div>
      <div class="grid gap-3 md:grid-cols-2 2xl:grid-cols-3">
        <button
          v-for="id in availableTemplates"
          :key="id"
          type="button"
          class="rounded-xl border border-n-weak bg-n-solid-2 p-5 text-left transition hover:border-n-blue-9 focus-visible:ring-2 focus-visible:ring-n-blue-9"
          @click="prepareCreate(id)"
        >
          <span class="block text-sm font-semibold">
            {{ t(`TEMPLATES.${id}`) }} </span
          ><span class="mt-2 block text-sm text-n-slate-11">
            {{ t(`TEMPLATE_HELP.${id}`) }}
          </span>
        </button>
      </div>
    </div>

    <template v-else>
      <nav
        class="flex gap-1 border-b border-n-weak bg-n-solid-2 px-6"
        :aria-label="t('TITLE')"
      >
        <button
          v-for="value in ['CANVAS', 'SETTINGS', 'PLAYGROUND', 'RUNS']"
          :key="value"
          type="button"
          class="border-b-2 px-4 py-3 text-sm font-medium"
          :class="
            tab === value
              ? 'border-n-blue-9 text-n-blue-11'
              : 'border-transparent text-n-slate-11'
          "
          :aria-current="tab === value ? 'page' : undefined"
          @click="selectTab(value)"
        >
          {{ t(value) }}
        </button>
      </nav>
      <p
        v-if="flow.kind === 'voice'"
        class="m-0 bg-n-amber-3 px-6 py-3 text-sm text-n-amber-11"
      >
        {{ t('VOICE_NOTICE') }}
      </p>
      <p
        v-else-if="readonly && ['CANVAS', 'SETTINGS'].includes(tab)"
        class="m-0 bg-n-blue-3 px-6 py-2 text-xs text-n-blue-11"
      >
        {{ t('READ_ONLY') }}
      </p>

      <div
        v-if="tab === 'CANVAS' && flow.engine !== 'workflow'"
        class="flex min-h-0 flex-1 flex-col overflow-auto xl:flex-row"
      >
        <aside
          class="w-full shrink-0 overflow-y-auto border-r border-n-weak bg-n-solid-2 p-3 xl:w-56"
        >
          <h2 class="text-sm font-semibold">
            {{ t('BLOCKS') }}
          </h2>
          <input
            v-model="blockSearch"
            type="search"
            :placeholder="t('SEARCH_BLOCK')"
            :aria-label="t('SEARCH_BLOCK')"
            class="w-full text-sm"
          />
          <div class="flex flex-wrap gap-x-4 xl:block">
            <div v-for="group in groups" :key="group" class="mt-4">
              <h3
                class="mb-2 text-xs font-semibold uppercase tracking-wider text-n-slate-10"
              >
                {{ t(`GROUPS.${group}`) }}
              </h3>
              <button
                v-for="definition in palette.filter(
                  item => item.group === group
                )"
                :key="definition.type"
                type="button"
                class="flex w-full items-center gap-2 rounded-lg px-2 py-2 text-left text-sm text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-40"
                :disabled="readonly"
                @click="addNode(definition)"
              >
                <span
                  class="size-4 shrink-0 text-n-blue-9"
                  :class="definition.icon"
                />
                {{ t(`NODES.${definition.type}`) }}
              </button>
            </div>
          </div>
        </aside>
        <FlowCanvas
          :graph="flow.graph"
          :selected="selectedId"
          :readonly="readonly"
          :visited="visited"
          @select="selectedId = $event"
          @move="moveNode"
          @connect="connect"
          @remove-edge="removeEdge"
        />
        <FlowInspector
          :node="selected"
          :graph="flow.graph"
          :metadata="metadata"
          :readonly="readonly"
          @change="changeNode"
          @connect="connect"
          @remove="removeNode"
        />
      </div>

      <WorkflowEditor
        v-else-if="tab === 'CANVAS' && flow.engine === 'workflow'"
        :key="flow.id"
        :workflow="flow.workflow"
        :readonly="readonly"
        :flows="flows.filter(f => f.engine === 'workflow' && f.id !== flow.id)"
        @change="flow.workflow = $event"
        @invalid="invalidParameters = $event"
      />
      <div v-else-if="tab === 'SETTINGS'" class="flex-1 overflow-auto p-6">
        <fieldset :disabled="readonly" class="mx-auto max-w-4xl space-y-6">
          <section
            v-if="flow.engine === 'workflow'"
            class="space-y-4 rounded-xl border border-n-blue-7 bg-n-solid-2 p-5"
          >
            <h2 class="text-base font-semibold">
              {{ t('WF.INTERNAL_TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">{{ t('WF.INTERNAL_HELP') }}</p>
            <div class="grid gap-4 md:grid-cols-2">
              <label class="text-sm"
                >{{ t('WF.OPENAI_KEY')
                }}<input
                  v-model="openaiKey"
                  type="password"
                  autocomplete="new-password"
                  :placeholder="
                    flow.credential_configured?.includes('openai_api_key')
                      ? t('WF.CONFIGURED')
                      : t('WF.NOT_CONFIGURED')
                  "
                  class="mt-1 w-full"
              /></label>
              <label class="text-sm"
                >{{ t('WF.HTTP_KEY')
                }}<input
                  v-model="httpKey"
                  type="password"
                  autocomplete="new-password"
                  :placeholder="
                    flow.credential_configured?.includes('http_api_key')
                      ? t('WF.CONFIGURED')
                      : t('WF.NOT_CONFIGURED')
                  "
                  class="mt-1 w-full"
              /></label>
              <label
                v-for="key in [
                  'workflow_team_id',
                  'workflow_support_team_id',
                  'workflow_financial_team_id',
                  'workflow_commercial_team_id',
                ]"
                :key="key"
                class="text-sm"
                >{{ t(`WF.${key}`)
                }}<select v-model="flow.settings[key]" class="mt-1 w-full">
                  <option value="">{{ t('SELECT') }}</option>
                  <option
                    v-for="team in metadata.teams"
                    :key="team.id"
                    :value="team.id"
                  >
                    {{ team.name }}
                  </option>
                </select></label
              >
            </div>
            <p class="text-xs text-n-slate-11">{{ t('WF.SECRETS_HELP') }}</p>
          </section>
          <div class="grid gap-5 md:grid-cols-2">
            <label class="text-sm">
              {{ t('NAME') }}
              <input
                v-model="flow.name"
                type="text"
                maxlength="120"
                class="mt-1 w-full"
            /></label>
            <label class="text-sm">
              {{ t('KIND') }}
              <select
                v-model="flow.kind"
                class="mt-1 w-full"
                @change="changeKind"
              >
                <option v-for="kind in KINDS" :key="kind" :value="kind">
                  {{ t(`KINDS.${kind}`) }}
                </option>
              </select></label
            >
          </div>
          <label class="block text-sm">
            {{ t('DESCRIPTION') }}
            <textarea v-model="flow.description" rows="2" class="mt-1 w-full" />
          </label>
          <fieldset class="rounded-xl border border-n-weak bg-n-solid-2 p-5">
            <legend class="px-2 text-sm font-semibold">
              {{ t('INBOXES') }}
            </legend>
            <div class="flex flex-wrap gap-4">
              <label
                v-for="inbox in metadata.inboxes"
                :key="inbox.id"
                class="flex items-center gap-2 text-sm"
                ><input
                  v-model="flow.settings.inbox_ids"
                  type="checkbox"
                  :value="inbox.id"
                />
                {{ inbox.name }}
              </label>
            </div>
            <p class="mb-0 mt-3 text-xs text-n-slate-11">
              {{ t('INBOX_HELP') }}
            </p>
          </fieldset>
          <div class="grid gap-5 md:grid-cols-2">
            <label class="text-sm">
              {{ t('TRIGGER') }}
              <select v-model="flow.settings.trigger" class="mt-1 w-full">
                <option
                  v-for="trigger in availableTriggers"
                  :key="trigger"
                  :value="trigger"
                >
                  {{ t(`TRIGGERS.${trigger}`) }}
                </option>
              </select></label
            >
            <label
              v-if="flow.settings.trigger === 'message_created'"
              class="text-sm"
            >
              {{ t('KEYWORD') }}
              <input
                v-model="flow.settings.keyword"
                type="text"
                class="mt-1 w-full"
            /></label>
            <label
              v-if="flow.settings.trigger === 'label_added'"
              class="text-sm"
            >
              {{ t('LABEL_TRIGGER') }}
              <select v-model="flow.settings.label" class="mt-1 w-full">
                <option
                  v-for="label in metadata.labels"
                  :key="label"
                  :value="label"
                >
                  {{ label }}
                </option>
              </select></label
            >
          </div>
          <label
            v-if="flow.settings.trigger === 'stage_changed'"
            class="block text-sm"
          >
            {{ t('STAGE_TRIGGER') }}
            <select v-model="flow.settings.stage_id" class="mt-1 w-full">
              <option
                v-for="stage in metadata.stages"
                :key="stage.id"
                :value="stage.id"
              >
                {{ stage.name }}
              </option>
            </select>
            <span class="mt-2 block text-xs text-n-slate-11">
              {{ t('STAGE_HELP') }}
            </span>
          </label>
          <div
            v-if="flow.settings.trigger === 'schedule'"
            class="grid gap-4 md:grid-cols-2"
          >
            <label class="text-sm">
              {{ t('INTERVAL') }}
              <input
                v-model.number="flow.settings.interval_minutes"
                type="number"
                min="1"
                max="10080"
                class="mt-1 w-full"
            /></label>
            <label class="text-sm">
              {{ t('SCHEDULE_CONVERSATIONS') }}
              <input
                v-model="scheduleConversationIds"
                type="text"
                class="mt-1 w-full"
            /></label>
            <p class="text-xs text-n-slate-11 md:col-span-2">
              {{ t('SCHEDULE_HELP') }}
            </p>
          </div>
          <div
            class="space-y-3 rounded-xl border border-n-weak bg-n-solid-2 p-5"
          >
            <label
              v-for="[key, text] in [
                ['pause_on_agent', 'PAUSE_AGENT'],
                ['pause_on_team', 'PAUSE_TEAM'],
                ['restart_on_resolve', 'RESTART'],
                ['stop_on_reply', 'STOP_REPLY'],
                ['business_hours', 'BUSINESS_HOURS'],
              ]"
              :key="key"
              class="flex items-center gap-3 text-sm"
              ><input v-model="flow.settings[key]" type="checkbox" />
              {{ t(text) }}
            </label>
          </div>
          <div v-if="flow.settings.business_hours" class="space-y-4">
            <div class="grid gap-4 md:grid-cols-3">
              <label class="text-sm">
                {{ t('TIMEZONE') }}
                <input
                  v-model="flow.settings.timezone"
                  type="text"
                  class="mt-1 w-full"
              /></label>
              <label class="text-sm">
                {{ t('OPEN') }}
                <input
                  v-model="flow.settings.opens_at"
                  type="time"
                  class="mt-1 w-full"
              /></label>
              <label class="text-sm">
                {{ t('CLOSE') }}
                <input
                  v-model="flow.settings.closes_at"
                  type="time"
                  class="mt-1 w-full"
              /></label>
            </div>
            <fieldset>
              <legend class="mb-2 text-sm">
                {{ t('DAYS') }}
              </legend>
              <div class="flex flex-wrap gap-4">
                <label
                  v-for="day in 7"
                  :key="day"
                  class="flex items-center gap-2 text-sm"
                  ><input
                    type="checkbox"
                    :checked="flow.settings.days?.includes(day - 1)"
                    @change="toggleDay(day - 1, $event.target.checked)"
                  />
                  {{ t(`WEEKDAYS.${day - 1}`) }}
                </label>
              </div>
            </fieldset>
          </div>
          <p
            v-if="flow.settings.trigger === 'manual'"
            class="text-sm text-n-slate-11"
          >
            {{ t('MANUAL_SETTINGS') }}
          </p>
        </fieldset>
      </div>

      <div
        v-else-if="tab === 'PLAYGROUND'"
        class="grid min-h-0 flex-1 gap-6 overflow-auto p-6 lg:grid-cols-2"
      >
        <div>
          <h2 class="text-lg font-semibold">
            {{ t('PLAYGROUND') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('SIMULATION_HELP') }}
          </p>
          <label
            v-if="flow.engine === 'workflow'"
            class="mb-4 block text-sm font-medium text-n-slate-12 leading-relaxed"
            >{{ t('WF.TEST_EVENT')
            }}<select
              v-model="simulationEvent"
              :aria-label="t('WF.TEST_EVENT')"
              class="mt-1 w-full"
            >
              <option value="MESSAGE">{{ t('WF.EVENT_MESSAGE') }}</option>
              <option value="START">{{ t('WF.EVENT_START') }}</option>
            </select></label
          >
          <label class="block text-sm">
            {{ t('RESPONSES') }}
            <textarea
              v-model="responses"
              rows="8"
              class="mt-2 w-full"
              maxlength="20000"
            />
          </label>
          <p class="text-xs text-n-slate-11">
            {{ t('RESPONSE_HELP') }}
          </p>
          <div class="flex gap-2">
            <Button
              :label="t('SIMULATE')"
              icon="i-lucide-play"
              :disabled="busy"
              @click="simulate"
            /><Button
              :label="t('RESET')"
              variant="ghost"
              @click="
                simulation = null;
                responses = '';
              "
            />
          </div>
        </div>
        <div class="rounded-xl border border-n-weak bg-n-solid-2 p-5">
          <h3 class="text-sm font-semibold">
            {{ t('TRACE') }}
          </h3>
          <p v-if="!simulation" class="text-sm text-n-slate-11">
            {{ t('NO_SIMULATION') }}
          </p>
          <template v-else>
            <div
              v-if="simulation.output"
              class="mb-4 rounded-lg bg-n-teal-3 p-3"
            >
              <h4 class="text-sm font-semibold">{{ t('WF.RESULT') }}</h4>
              <pre
                class="m-0 max-h-72 overflow-auto whitespace-pre-wrap break-words text-xs"
                >{{ JSON.stringify(simulation.output, null, 2) }}
</pre
              >
            </div>
            <span
              class="mb-4 inline-block rounded-full bg-n-blue-3 px-3 py-1 text-xs text-n-blue-11"
            >
              {{ t(`STATUSES.${simulation.status}`) }}
            </span>
            <ol class="m-0 space-y-3 p-0">
              <li
                v-for="(step, index) in simulation.trace"
                :key="index"
                class="list-none rounded-lg border border-n-weak p-3"
              >
                <div class="flex items-center justify-between gap-3">
                  <strong class="text-sm">
                    {{ step.label || t(`NODES.${step.type}`) }} </strong
                  ><span class="text-xs text-n-slate-10">
                    {{ t('SIMULATED') }}
                  </span>
                </div>
                <p
                  v-if="step.content"
                  class="mb-0 mt-2 whitespace-pre-wrap break-words text-sm text-n-slate-11"
                >
                  {{ step.content }}
                </p>
              </li>
            </ol>
          </template>
        </div>
      </div>

      <div v-else-if="tab === 'RUNS'" class="flex-1 overflow-auto p-6">
        <form
          v-if="flow.settings.trigger === 'manual' && readonly"
          class="mb-5 flex flex-wrap items-end gap-3 rounded-xl border border-n-weak bg-n-solid-2 p-4"
          @submit.prevent="startManual"
        >
          <label class="text-sm">
            {{ t('CONVERSATION_ID') }}
            <input
              v-model="manualConversation"
              type="number"
              min="1"
              required
              class="mt-1 block"
          /></label>
          <Button type="submit" :label="t('START_MANUAL')" :disabled="busy" />
          <p class="m-0 text-xs text-n-slate-11">
            {{ t('NUMBER_HELP') }}
          </p>
        </form>
        <div class="mb-4 flex items-center justify-between">
          <h2 class="m-0 text-lg font-semibold">
            {{ t('RUNS') }}
          </h2>
          <Button
            :label="t('REFRESH')"
            icon="i-lucide-refresh-cw"
            variant="outline"
            :disabled="busy"
            @click="loadRuns()"
          />
        </div>
        <p
          v-if="!executions.length"
          class="rounded-xl border border-dashed border-n-strong p-8 text-center text-sm text-n-slate-11"
        >
          {{ t('NO_RUNS') }}
        </p>
        <div v-else class="space-y-3">
          <article
            v-for="run in executions"
            :key="run.id"
            class="rounded-xl border border-n-weak bg-n-solid-2 p-4"
          >
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <a
                  v-if="run.remote"
                  :href="run.conversation_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-sm font-semibold text-n-blue-11"
                >
                  {{ run.contact_name }} · #{{ run.conversation_id }}
                </a>
                <RouterLink
                  v-else
                  :to="{
                    name: 'inbox_conversation',
                    params: {
                      accountId: route.params.accountId,
                      conversation_id: run.conversation_id,
                    },
                  }"
                  class="text-sm font-semibold text-n-blue-11"
                >
                  {{ run.contact_name }} · #{{ run.conversation_id }}
                </RouterLink>
                <p class="m-0 mt-1 text-xs text-n-slate-10">
                  {{ date(run.created_at) }}
                </p>
              </div>
              <span class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs">
                {{ t(`STATUSES.${run.status}`) }}
              </span>
              <Button
                v-if="['running', 'waiting', 'delayed'].includes(run.status)"
                :label="t('STOP_RUN')"
                size="sm"
                variant="outline"
                :disabled="busy"
                @click="stopRun(run)"
              />
              <Button
                :label="
                  expandedRun === run.id ? t('CLOSE_DETAILS') : t('DETAILS')
                "
                size="sm"
                variant="ghost"
                @click="expandedRun = expandedRun === run.id ? null : run.id"
              />
            </div>
            <p v-if="run.error" class="mb-0 mt-3 text-sm text-n-ruby-11">
              {{ run.error }}
            </p>
            <ol
              v-if="expandedRun === run.id"
              class="mb-0 mt-4 space-y-2 border-t border-n-weak pt-4"
            >
              <li
                v-for="(step, index) in run.trace"
                :key="index"
                class="text-sm"
              >
                {{ step.label || t(`NODES.${step.type}`) }} ·
                {{ date(step.at) }}
              </li>
            </ol>
          </article>
          <Button
            v-if="executions.length >= 30"
            :label="t('MORE')"
            variant="outline"
            :disabled="busy"
            @click="loadRuns(true)"
          />
        </div>
      </div>
    </template>
  </section>
</template>
