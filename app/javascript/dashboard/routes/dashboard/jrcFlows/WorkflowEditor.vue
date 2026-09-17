<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import FlowCanvas from './FlowCanvas.vue';
import messages from './en.json';
import { clone } from './catalog';

const props = defineProps({
  workflow: { type: Object, required: true },
  readonly: Boolean,
  flows: { type: Array, default: () => [] },
});
const emit = defineEmits(['change', 'invalid']);
const { t } = useI18n({
  useScope: 'local',
  messages: { en: messages, pt_BR: messages, pt: messages },
});
const selectedId = ref(props.workflow.nodes[0]?.id);
const search = ref('');
const parameterError = ref('');
const selected = computed(() =>
  props.workflow.nodes.find(n => n.id === selectedId.value)
);
const types = [
  'webhook',
  'code',
  'if',
  'switch',
  'redis',
  'httpRequest',
  'executeWorkflow',
  'respondToWebhook',
  'agent',
  'lmChatOpenAi',
  'set',
  'noOp',
  'stickyNote',
  'executeWorkflowTrigger',
];
const fullType = type =>
  ['agent', 'lmChatOpenAi'].includes(type)
    ? `@n8n/n8n-nodes-langchain.${type}`
    : `n8n-nodes-base.${type}`;
const shortType = node => node?.type.split('.').at(-1);
function nodePorts(node) {
  const type = shortType(node);
  if (type === 'lmChatOpenAi') return ['ai_languageModel:0'];
  if (['respondToWebhook', 'stickyNote'].includes(type)) return [];
  let count = 1;
  if (type === 'if') count = 2;
  if (type === 'switch')
    count =
      (node.parameters.rules?.values?.length || 1) +
      (node.parameters.options?.fallbackOutput === 'extra' ? 1 : 0);
  return Array.from({ length: count }, (_, i) => `main:${i}`);
}
const graph = computed(() => ({
  nodes: props.workflow.nodes.map(node => ({
    id: node.id,
    type: 'workflow',
    label: node.name,
    position: {
      x: (node.position?.[0] || 0) + 10000,
      y: (node.position?.[1] || 0) + 10000,
    },
    data: {
      ports: nodePorts(node),
      port_labels: Object.fromEntries(
        nodePorts(node).map(p => [
          p,
          p.startsWith('ai_')
            ? t('WF.MODEL')
            : `${t('WF.OUTPUT')} ${Number(p.split(':')[1]) + 1}`,
        ])
      ),
    },
  })),
  edges: Object.entries(props.workflow.connections).flatMap(
    ([source, groups]) =>
      Object.entries(groups).flatMap(([kind, outputs]) =>
        outputs.flatMap((targets, port) =>
          targets.map((edge, index) => ({
            id: `${source}:${kind}:${port}:${index}`,
            source: props.workflow.nodes.find(n => n.name === source)?.id,
            target: props.workflow.nodes.find(n => n.name === edge.node)?.id,
            port: `${kind}:${port}`,
          }))
        )
      )
  ),
}));
function update(fn) {
  const next = clone(props.workflow);
  fn(next);
  emit('change', next);
}
function param(key, value) {
  update(w => {
    w.nodes.find(n => n.id === selectedId.value).parameters[key] = value;
  });
}
function rename(name) {
  if (
    !name.trim() ||
    props.workflow.nodes.some(n => n.id !== selectedId.value && n.name === name)
  )
    return;
  update(w => {
    const node = w.nodes.find(n => n.id === selectedId.value);
    const old = node.name;
    node.name = name;
    if (w.connections[old]) {
      w.connections[name] = w.connections[old];
      delete w.connections[old];
    }
    Object.values(w.connections).forEach(g =>
      Object.values(g)
        .flat(2)
        .forEach(e => {
          if (e.node === old) e.node = name;
        })
    );
    // Name references inside JavaScript are deliberate user code and need review.
  });
}
function parameters(text) {
  try {
    const value = JSON.parse(text);
    if (!value || Array.isArray(value) || typeof value !== 'object')
      throw new Error();
    update(w => {
      w.nodes.find(n => n.id === selectedId.value).parameters = value;
    });
    parameterError.value = '';
    emit('invalid', false);
  } catch {
    parameterError.value = t('WF.JSON_ERROR');
    emit('invalid', true);
  }
}
function connect(edge) {
  update(w => {
    const source = w.nodes.find(n => n.id === edge.source);
    const target = w.nodes.find(n => n.id === edge.target);
    const [kind, number] = edge.port.split(':');
    w.connections[source.name] ||= {};
    w.connections[source.name][kind] ||= [];
    while (w.connections[source.name][kind].length <= Number(number))
      w.connections[source.name][kind].push([]);
    w.connections[source.name][kind][Number(number)] = target
      ? [{ node: target.name, type: kind, index: 0 }]
      : [];
  });
}
function move(id, position) {
  update(w => {
    w.nodes.find(n => n.id === id).position = [
      position.x - 10000,
      position.y - 10000,
    ];
  });
}
function removeEdge(id) {
  const edge = graph.value.edges.find(e => e.id === id);
  if (edge) connect({ ...edge, target: null });
}
function remove() {
  update(w => {
    const name = selected.value.name;
    w.nodes = w.nodes.filter(n => n.id !== selectedId.value);
    delete w.connections[name];
    Object.values(w.connections).forEach(g =>
      Object.keys(g).forEach(k => {
        g[k] = g[k].map(port => port.filter(e => e.node !== name));
      })
    );
  });
  selectedId.value = null;
}
function add(type) {
  const id = crypto.randomUUID();
  const defaults = {
    webhook: {
      httpMethod: 'POST',
      path: 'entrada-jrc',
      responseMode: 'responseNode',
    },
    code: { jsCode: 'return $input.all();' },
    if: {
      conditions: {
        conditions: [
          {
            leftValue: '={{ $json.mensagem }}',
            rightValue: 'oi',
            operator: { type: 'string', operation: 'equals' },
          },
        ],
        combinator: 'and',
      },
    },
    switch: {
      rules: {
        values: [
          {
            conditions: {
              conditions: [
                {
                  leftValue: '={{ $json.mensagem }}',
                  rightValue: '1',
                  operator: { type: 'string', operation: 'equals' },
                },
              ],
              combinator: 'and',
            },
          },
        ],
      },
      options: { fallbackOutput: 'extra' },
    },
    redis: {
      operation: 'get',
      key: '={{ $json.conversation_id }}',
      propertyName: 'context',
      ttl: 86400,
    },
    httpRequest: { method: 'GET', url: '', authentication: 'none' },
    executeWorkflow: { jrc_flow_id: '', options: { waitForSubWorkflow: true } },
    respondToWebhook: {
      respondWith: 'json',
      responseBody:
        '={{ { messages: ["Olá! Como posso ajudar?"], close: false } }}',
    },
    agent: {
      text: '={{ $json.mensagem }}',
      options: {
        systemMessage: 'Você é um assistente da JRC. Responda em português.',
      },
    },
    lmChatOpenAi: { model: 'gpt-4.1', options: { temperature: 0.1 } },
    set: {
      assignments: {
        assignments: [{ name: 'mensagem', value: 'Olá', type: 'string' }],
      },
    },
  };
  update(w => {
    const x = Math.max(0, ...w.nodes.map(n => n.position?.[0] || 0)) + 340;
    let name = t(`WF.TYPES.${type}`);
    let i = 1;
    const names = w.nodes.map(n => n.name);
    while (names.includes(name)) {
      name = `${t(`WF.TYPES.${type}`)} ${i}`;
      i += 1;
    }
    w.nodes.push({
      id,
      name,
      type: fullType(type),
      typeVersion: ['if', 'switch'].includes(type) ? 2 : 1,
      position: [x, 100],
      parameters: defaults[type] || {},
    });
  });
  selectedId.value = id;
}
</script>

<template>
  <div class="flex min-h-0 flex-1 overflow-auto">
    <aside
      class="w-52 shrink-0 overflow-auto border-r border-n-weak bg-n-solid-2 p-3"
    >
      <label class="mb-4 block text-sm"
        >{{ t('WF.JUMP_NODE')
        }}<select
          v-model="selectedId"
          :aria-label="t('WF.JUMP_NODE')"
          class="mt-1 w-full"
        >
          <option
            v-for="node in workflow.nodes"
            :key="node.id"
            :value="node.id"
          >
            {{ node.name }}
          </option>
        </select></label
      >
      <h2 class="text-sm font-semibold">{{ t('BLOCKS') }}</h2>
      <input
        v-model="search"
        :placeholder="t('SEARCH_BLOCK')"
        class="w-full text-sm"
      />
      <button
        v-for="type in types.filter(v =>
          t(`WF.TYPES.${v}`).toLowerCase().includes(search.toLowerCase())
        )"
        :key="type"
        type="button"
        :disabled="readonly || workflow.nodes.length >= 150"
        class="flex w-full items-center gap-2 rounded-lg px-2 py-3 text-left text-sm hover:bg-n-alpha-2 disabled:opacity-40"
        @click="add(type)"
      >
        <span class="i-lucide-box size-4 text-n-blue-9" />{{
          t(`WF.TYPES.${type}`)
        }}
      </button>
      <p class="mt-5 text-xs text-n-slate-11">{{ t('WF.INTERNAL_HELP') }}</p>
    </aside>
    <FlowCanvas
      :graph="graph"
      :selected="selectedId || ''"
      :readonly="readonly"
      @select="selectedId = $event"
      @move="move"
      @connect="connect"
      @remove-edge="removeEdge"
    />
    <aside
      class="w-80 shrink-0 overflow-auto border-l border-n-weak bg-n-solid-2 p-4"
    >
      <p v-if="!selected" class="text-sm">{{ t('WF.SELECT_NODE') }}</p>
      <fieldset v-else :disabled="readonly" class="space-y-4">
        <h2 class="text-sm font-semibold">{{ t('INSPECTOR') }}</h2>
        <label class="block text-sm"
          >{{ t('NAME')
          }}<input
            :value="selected.name"
            maxlength="120"
            :aria-label="t('BLOCK_NAME')"
            class="mt-1 w-full"
            @change="rename($event.target.value)"
        /></label>
        <p class="break-words text-xs text-n-slate-11">{{ selected.type }}</p>
        <p
          v-if="
            ['webhook', 'executeWorkflowTrigger'].includes(shortType(selected))
          "
          class="rounded-lg bg-n-blue-3 p-3 text-sm"
        >
          {{ t('WF.ENTRY_HELP') }}
        </p>
        <label
          v-if="shortType(selected) === 'code'"
          class="block text-sm font-medium text-n-slate-12"
          >{{ t('WF.CODE')
          }}<textarea
            :value="selected.parameters.jsCode"
            rows="18"
            class="mt-2 w-full font-mono text-xs"
            @change="param('jsCode', $event.target.value)"
          />
        </label>
        <template v-if="shortType(selected) === 'httpRequest'">
          <label class="block text-sm"
            >{{ t('WF.URL')
            }}<input
              :value="selected.parameters.url"
              type="url"
              class="mt-1 w-full"
              @change="param('url', $event.target.value)"
          /></label>
          <label class="block text-sm"
            >{{ t('WF.METHOD')
            }}<select
              :value="selected.parameters.method || 'GET'"
              class="mt-1 w-full"
              @change="param('method', $event.target.value)"
            >
              <option
                v-for="m in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']"
                :key="m"
              >
                {{ m }}
              </option>
            </select></label
          >
          <label class="flex items-center gap-2 text-sm"
            ><input
              type="checkbox"
              :checked="selected.parameters.jrc_use_credential"
              @change="param('jrc_use_credential', $event.target.checked)"
            />{{ t('WF.USE_CREDENTIAL') }}</label
          >
        </template>
        <template v-if="shortType(selected) === 'redis'">
          <label class="block text-sm"
            >{{ t('WF.OPERATION')
            }}<select
              :value="selected.parameters.operation"
              class="mt-1 w-full"
              @change="param('operation', $event.target.value)"
            >
              <option v-for="v in ['get', 'set', 'delete']" :key="v">
                {{ v }}
              </option>
            </select></label
          >
          <label class="block text-sm"
            >{{ t('WF.KEY')
            }}<input
              :value="selected.parameters.key"
              class="mt-1 w-full"
              @change="param('key', $event.target.value)"
          /></label>
        </template>
        <template v-if="shortType(selected) === 'agent'">
          <label class="block text-sm"
            >{{ t('WF.SYSTEM_PROMPT')
            }}<textarea
              :value="selected.parameters.options?.systemMessage"
              rows="9"
              class="mt-1 w-full"
              @change="
                param('options', {
                  ...selected.parameters.options,
                  systemMessage: $event.target.value,
                })
              "
            />
          </label>
          <label class="block text-sm"
            >{{ t('WF.PROMPT')
            }}<textarea
              :value="selected.parameters.text"
              rows="3"
              class="mt-1 w-full"
              @change="param('text', $event.target.value)"
            />
          </label>
        </template>
        <label
          v-if="shortType(selected) === 'lmChatOpenAi'"
          class="block text-sm"
          >{{ t('WF.MODEL')
          }}<input
            :value="
              selected.parameters.model?.value || selected.parameters.model
            "
            class="mt-1 w-full"
            @change="param('model', $event.target.value)"
        /></label>
        <template v-if="shortType(selected) === 'executeWorkflow'">
          <p class="text-xs text-n-slate-11">
            {{
              selected.parameters.workflowId?.cachedResultName ||
              selected.parameters.workflowId?.value ||
              t('WF.CHILD_HELP')
            }}
          </p>
          <label class="block text-sm"
            >{{ t('WF.CHILD')
            }}<select
              :value="selected.parameters.jrc_flow_id || ''"
              class="mt-1 w-full"
              @change="param('jrc_flow_id', Number($event.target.value))"
            >
              <option value="">{{ t('SELECT') }}</option>
              <option v-for="f in flows" :key="f.id" :value="f.id">
                {{ f.name }}
              </option>
            </select></label
          >
        </template>
        <details
          :key="selected.id"
          :open="!['code', 'agent'].includes(shortType(selected))"
        >
          <summary class="cursor-pointer text-sm font-medium">
            {{ t('WF.PARAMETERS') }}
          </summary>
          <textarea
            :value="JSON.stringify(selected.parameters, null, 2)"
            rows="14"
            :aria-label="t('WF.PARAMETERS')"
            class="mt-2 w-full font-mono text-xs"
            @change="parameters($event.target.value)"
          />
        </details>
        <p v-if="parameterError" role="alert" class="text-sm text-n-ruby-11">
          {{ parameterError }}
        </p>
        <h3 class="text-sm font-semibold">{{ t('CONNECTIONS') }}</h3>
        <label
          v-for="port in nodePorts(selected)"
          :key="port"
          class="block text-sm"
          >{{ port
          }}<select
            :value="
              graph.edges.find(e => e.source === selected.id && e.port === port)
                ?.target || ''
            "
            class="mt-1 w-full"
            @change="
              connect({
                source: selected.id,
                port,
                target: $event.target.value,
              })
            "
          >
            <option value="">{{ t('DISCONNECT') }}</option>
            <option
              v-for="n in workflow.nodes.filter(v => v.id !== selected.id)"
              :key="n.id"
              :value="n.id"
            >
              {{ n.name }}
            </option>
          </select></label
        >
        <Button
          :label="t('REMOVE_BLOCK')"
          variant="ghost"
          color="ruby"
          icon="i-lucide-trash-2"
          @click="remove"
        />
      </fieldset>
    </aside>
  </div>
</template>
