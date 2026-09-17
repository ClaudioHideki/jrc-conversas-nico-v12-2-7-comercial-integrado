<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import messages from './en.json';
import { NODE_TYPES, OPERATORS, ports } from './catalog';

const props = defineProps({
  node: { type: Object, default: null },
  graph: { type: Object, required: true },
  metadata: { type: Object, required: true },
  readonly: { type: Boolean, default: false },
});
const emit = defineEmits(['change', 'connect', 'remove']);
const { t } = useI18n({
  useScope: 'local',
  messages: { en: messages, pt_BR: messages, pt: messages },
});
const definition = computed(() =>
  NODE_TYPES.find(item => item.type === props.node?.type)
);
const terminalTargets = computed(() =>
  props.graph.nodes.filter(
    node => node.id !== props.node?.id && node.type !== 'start'
  )
);
const newId = () => crypto.randomUUID();
const variableHelp = '{{contact.name}} · {{contact.email}} · {{resposta}}';
function change(key, value) {
  emit('change', { ...props.node, data: { ...props.node.data, [key]: value } });
}
function options(type) {
  if (['agents', 'teams', 'stages'].includes(type))
    return props.metadata[type] || [];
  const lists = {
    operator: OPERATORS,
    operation: ['add', 'remove'],
    status: ['open', 'pending', 'resolved'],
    contact: ['name', 'email', 'phone_number'],
  };
  return (lists[type] || []).map(id => ({
    id,
    name: t(`${type === 'operator' ? 'OPERATORS' : 'OPTIONS'}.${id}`),
  }));
}
function changeCase(index, key, value) {
  change(
    'cases',
    props.node.data.cases.map((item, i) =>
      i === index ? { ...item, [key]: value } : item
    )
  );
}
function toggleArray(key, value, checked) {
  change(
    key,
    checked
      ? [...(props.node.data[key] || []), value]
      : (props.node.data[key] || []).filter(item => item !== value)
  );
}
function connection(port) {
  return (
    props.graph.edges.find(
      edge => edge.source === props.node.id && edge.port === port
    )?.target || ''
  );
}
</script>

<template>
  <aside
    class="w-full shrink-0 overflow-y-auto border-l border-n-weak bg-n-solid-2 p-4 xl:w-80"
  >
    <h3 class="mb-4 text-sm font-semibold text-n-slate-12">
      {{ t('INSPECTOR') }}
    </h3>
    <p v-if="!node" class="text-sm text-n-slate-11">
      {{ t('SELECT_BLOCK') }}
    </p>
    <fieldset v-else :disabled="readonly" class="space-y-4">
      <label class="block text-sm text-n-slate-11">
        {{ t('BLOCK_NAME') }}
        <input
          :value="node.label"
          class="mt-1 w-full"
          :placeholder="t(`NODES.${node.type}`)"
          maxlength="80"
          @input="emit('change', { ...node, label: $event.target.value })"
        />
      </label>
      <p
        v-if="
          definition?.capability &&
          !metadata.capabilities?.[definition.capability]
        "
        class="rounded-lg bg-n-amber-3 p-3 text-sm text-n-amber-11"
      >
        {{ t('CAPABILITY_NOTICE') }}
      </p>
      <p v-if="node.type === 'start'" class="text-sm text-n-slate-11">
        {{ t('INBOX_HELP') }}
      </p>
      <p v-if="node.type === 'media'" class="text-sm text-n-slate-11">
        {{ t('MEDIA_HELP') }}
      </p>
      <p v-if="node.type === 'webhook'" class="text-sm text-n-slate-11">
        {{ t('WEBHOOK_HELP') }}
      </p>
      <p v-if="node.type === 'nico'" class="text-sm text-n-slate-11">
        {{ t('NICO_HELP') }}
      </p>
      <div v-for="[key, type] in definition?.fields || []" :key="key">
        <label
          v-if="['text', 'url', 'number', 'textarea'].includes(type)"
          class="block text-sm text-n-slate-11"
        >
          {{ t(`FIELDS.${key}`) }}
          <textarea
            v-if="type === 'textarea'"
            :value="node.data[key] || ''"
            rows="5"
            class="mt-1 w-full"
            maxlength="10000"
            @input="change(key, $event.target.value)"
          />
          <input
            v-else
            :value="node.data[key] ?? ''"
            :type="type"
            :min="type === 'number' ? 1 : undefined"
            class="mt-1 w-full"
            @input="
              change(
                key,
                type === 'number'
                  ? Number($event.target.value)
                  : $event.target.value
              )
            "
          />
        </label>
        <fieldset
          v-else-if="['labels', 'permissions'].includes(type)"
          class="space-y-2"
        >
          <legend class="mb-2 text-sm text-n-slate-11">
            {{ t(`FIELDS.${key}`) }}
          </legend>
          <label
            v-for="option in type === 'labels'
              ? metadata.labels
              : ['contacts', 'leads', 'proposals', 'meetings', 'calls']"
            :key="option"
            class="flex items-center gap-2 text-sm"
          >
            <input
              type="checkbox"
              :checked="(node.data[key] || []).includes(option)"
              @change="toggleArray(key, option, $event.target.checked)"
            />
            {{ type === 'labels' ? option : t(`PERMISSIONS.${option}`) }}
          </label>
        </fieldset>
        <label v-else class="block text-sm text-n-slate-11">
          {{ t(`FIELDS.${key}`) }}
          <select
            :value="node.data[key] || ''"
            class="mt-1 w-full"
            @change="
              change(
                key,
                ['agents', 'teams', 'stages'].includes(type) &&
                  $event.target.value
                  ? Number($event.target.value)
                  : $event.target.value
              )
            "
          >
            <option value="">
              {{ t('SELECT') }}
            </option>
            <option
              v-for="option in options(type)"
              :key="option.id"
              :value="option.id"
            >
              {{ option.name }}
            </option>
          </select>
        </label>
      </div>
      <template v-if="node.type === 'switch'">
        <p class="text-xs text-n-slate-11">
          {{ t('RULES_HELP') }}
        </p>
        <div
          v-for="(item, index) in node.data.cases"
          :key="item.id"
          class="space-y-2 rounded-lg border border-n-weak p-3"
        >
          <label class="block text-sm">
            {{ t('CASE') }}
            <input
              :value="item.label"
              class="w-full"
              @input="changeCase(index, 'label', $event.target.value)"
            />
          </label>
          <label class="block text-sm">
            {{ t('FIELD') }}
            <input
              :value="item.field"
              class="w-full"
              @input="changeCase(index, 'field', $event.target.value)"
            />
          </label>
          <label class="block text-sm">
            {{ t('FIELDS.operator') }}
            <select
              :value="item.operator"
              class="w-full"
              @change="changeCase(index, 'operator', $event.target.value)"
            >
              <option
                v-for="operator in OPERATORS"
                :key="operator"
                :value="operator"
              >
                {{ t(`OPERATORS.${operator}`) }}
              </option>
            </select>
          </label>
          <label class="block text-sm">
            {{ t('VALUE') }}
            <input
              :value="item.value"
              class="w-full"
              @input="changeCase(index, 'value', $event.target.value)"
            />
          </label>
          <Button
            :label="t('REMOVE_CASE')"
            variant="ghost"
            color="ruby"
            size="sm"
            @click="
              change(
                'cases',
                node.data.cases.filter(c => c.id !== item.id)
              )
            "
          />
        </div>
        <Button
          v-if="node.data.cases.length < 10"
          :label="t('ADD_CASE')"
          icon="i-lucide-plus"
          variant="outline"
          size="sm"
          @click="
            change('cases', [
              ...node.data.cases,
              {
                id: newId(),
                label: t('CASE'),
                field: 'message',
                operator: 'equals',
                value: '',
              },
            ])
          "
        />
      </template>
      <div
        v-if="ports(node).length"
        class="space-y-3 border-t border-n-weak pt-4"
      >
        <h4 class="text-sm font-semibold">
          {{ t('CONNECTIONS') }}
        </h4>
        <label
          v-for="port in ports(node)"
          :key="port"
          class="block text-sm text-n-slate-11"
        >
          {{
            node.data.cases?.find(item => item.id === port)?.label ||
            t(`PORTS.${port}`)
          }}
          <select
            :value="connection(port)"
            class="mt-1 w-full"
            @change="
              emit('connect', {
                source: node.id,
                port,
                target: $event.target.value,
              })
            "
          >
            <option value="">
              {{ t('DISCONNECT') }}
            </option>
            <option
              v-for="target in terminalTargets"
              :key="target.id"
              :value="target.id"
            >
              {{ target.label || t(`NODES.${target.type}`) }}
            </option>
          </select>
        </label>
      </div>
      <div class="rounded-lg bg-n-alpha-2 p-3 text-xs text-n-slate-11">
        <p>
          {{ t('VARIABLE_HELP') }}
        </p>
        <code class="break-all">
          {{ variableHelp }}
        </code>
      </div>
      <Button
        v-if="node.type !== 'start'"
        :label="t('REMOVE_BLOCK')"
        icon="i-lucide-trash-2"
        variant="ghost"
        color="ruby"
        size="sm"
        @click="emit('remove', node.id)"
      />
    </fieldset>
  </aside>
</template>
