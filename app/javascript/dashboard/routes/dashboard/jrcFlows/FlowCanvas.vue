<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import messages from './en.json';
import { ports } from './catalog';

const props = defineProps({
  graph: { type: Object, required: true },
  selected: { type: String, default: '' },
  readonly: { type: Boolean, default: false },
  visited: { type: Array, default: () => [] },
});
const emit = defineEmits(['select', 'move', 'connect', 'removeEdge']);
const { t } = useI18n({
  useScope: 'local',
  messages: { en: messages, pt_BR: messages, pt: messages },
});
const svg = ref(null);
const connection = ref(null);
const drag = ref(null);
const view = ref({ x: 0, y: 0, width: 1200, height: 760 });
const viewBox = computed(() => Object.values(view.value).join(' '));
const position = node => node.position || { x: 60, y: 60 };
const height = node => Math.max(120, 105 + ports(node).length * 28);
const label = node => node.label || t(`NODES.${node.type}`);
const portLabel = (node, port) =>
  node.data.port_labels?.[port] ||
  node.data.cases?.find(item => item.id === port)?.label ||
  t(`PORTS.${port}`);
const point = event =>
  new DOMPoint(event.clientX, event.clientY).matrixTransform(
    svg.value.getScreenCTM().inverse()
  );

function edgePath(edge) {
  const source = props.graph.nodes.find(node => node.id === edge.source);
  const target = props.graph.nodes.find(node => node.id === edge.target);
  if (!source || !target) return '';
  const start = position(source);
  const end = position(target);
  const x = start.x + 240;
  const y = start.y + 90 + Math.max(0, ports(source).indexOf(edge.port)) * 28;
  const bend = Math.max(70, Math.abs(end.x - x) / 2);
  return `M ${x} ${y} C ${x + bend} ${y}, ${end.x - bend} ${end.y + 40}, ${end.x} ${end.y + 40}`;
}

function selectNode(event, node) {
  emit('select', node.id);
  if (props.readonly) return;
  const p = point(event);
  drag.value = {
    id: node.id,
    x: p.x - position(node).x,
    y: p.y - position(node).y,
  };
  svg.value.setPointerCapture(event.pointerId);
}

function startPan(event) {
  if (event.target !== svg.value && !event.target.dataset.background) return;
  drag.value = {
    pan: true,
    x: event.clientX,
    y: event.clientY,
    origin: { ...view.value },
  };
  svg.value.setPointerCapture(event.pointerId);
}

function pointerMove(event) {
  if (!drag.value) return;
  if (drag.value.pan) {
    const scale = view.value.width / svg.value.getBoundingClientRect().width;
    view.value.x = drag.value.origin.x - (event.clientX - drag.value.x) * scale;
    view.value.y = drag.value.origin.y - (event.clientY - drag.value.y) * scale;
    return;
  }
  const p = point(event);
  emit('move', drag.value.id, {
    x: Math.max(0, Math.round(p.x - drag.value.x)),
    y: Math.max(0, Math.round(p.y - drag.value.y)),
  });
}

function connectTo(node) {
  if (
    !props.readonly &&
    connection.value &&
    connection.value.source !== node.id &&
    node.type !== 'start'
  ) {
    emit('connect', { ...connection.value, target: node.id });
    connection.value = null;
  }
}

function keyMove(event, node) {
  emit('select', node.id);
  if (props.readonly) return;
  const offsets = {
    ArrowUp: [0, -20],
    ArrowDown: [0, 20],
    ArrowLeft: [-20, 0],
    ArrowRight: [20, 0],
  };
  const offset = offsets[event.key];
  if (!offset) return;
  event.preventDefault();
  emit('move', node.id, {
    x: Math.max(0, position(node).x + offset[0]),
    y: Math.max(0, position(node).y + offset[1]),
  });
}

function zoom(factor) {
  const width = Math.min(100000, Math.max(500, view.value.width * factor));
  const nextHeight = (width * 760) / 1200;
  view.value = {
    x: view.value.x + (view.value.width - width) / 2,
    y: view.value.y + (view.value.height - nextHeight) / 2,
    width,
    height: nextHeight,
  };
}

function fit() {
  const nodes = props.graph.nodes;
  if (!nodes.length) return;
  const minX = Math.min(...nodes.map(n => position(n).x)) - 60;
  const minY = Math.min(...nodes.map(n => position(n).y)) - 80;
  const maxX = Math.max(...nodes.map(n => position(n).x + 300));
  const maxY = Math.max(...nodes.map(n => position(n).y + height(n) + 80));
  const width = Math.max(900, maxX - minX, ((maxY - minY) * 1200) / 760);
  view.value = { x: minX, y: minY, width, height: (width * 760) / 1200 };
}
onMounted(fit);
watch(
  () => props.selected,
  id => {
    const node = props.graph.nodes.find(n => n.id === id);
    if (!node) return;
    const p = position(node);
    if (
      view.value.width > 2500 ||
      p.x < view.value.x ||
      p.x + 240 > view.value.x + view.value.width ||
      p.y < view.value.y ||
      p.y + height(node) > view.value.y + view.value.height
    ) {
      view.value = {
        x: p.x - 600,
        y: p.y - 320,
        width: 1600,
        height: (1600 * 760) / 1200,
      };
    }
  },
  { flush: 'post' }
);
</script>

<template>
  <div
    class="relative flex min-h-[520px] min-w-0 flex-1 flex-col overflow-hidden bg-n-background"
  >
    <div class="absolute left-3 top-3 z-10 flex flex-wrap gap-2">
      <Button
        :label="t('FIT')"
        icon="i-lucide-maximize"
        variant="outline"
        size="sm"
        @click="fit"
      />
      <Button
        :aria-label="t('ZOOM_IN')"
        icon="i-lucide-plus"
        variant="outline"
        size="sm"
        @click="zoom(0.8)"
      />
      <Button
        :aria-label="t('ZOOM_OUT')"
        icon="i-lucide-minus"
        variant="outline"
        size="sm"
        @click="zoom(1.25)"
      />
      <Button
        v-if="connection"
        :label="t('CANCEL')"
        variant="outline"
        size="sm"
        @click="connection = null"
      />
    </div>
    <svg
      ref="svg"
      class="h-full min-h-[520px] w-full flex-1 touch-none select-none"
      :viewBox="viewBox"
      role="group"
      :aria-label="t('CANVAS')"
      @pointerdown="startPan"
      @pointermove="pointerMove"
      @pointerup="drag = null"
      @pointercancel="drag = null"
      @keydown.esc="connection = null"
    >
      <defs>
        <pattern
          id="flow-grid"
          width="24"
          height="24"
          patternUnits="userSpaceOnUse"
        >
          <circle cx="1" cy="1" r="1" class="fill-n-slate-5" />
        </pattern>
        <marker
          id="flow-arrow"
          viewBox="0 0 10 10"
          refX="9"
          refY="5"
          markerWidth="6"
          markerHeight="6"
          orient="auto-start-reverse"
        >
          <path d="M 0 0 L 10 5 L 0 10 z" class="fill-n-slate-9" />
        </marker>
      </defs>
      <rect
        :x="view.x"
        :y="view.y"
        :width="view.width"
        :height="view.height"
        fill="url(#flow-grid)"
        data-background="true"
      />
      <g v-for="edge in graph.edges" :key="edge.id">
        <path
          :d="edgePath(edge)"
          fill="none"
          stroke-width="2"
          class="stroke-n-slate-8"
          marker-end="url(#flow-arrow)"
        />
        <path
          v-if="!readonly"
          :d="edgePath(edge)"
          fill="none"
          stroke="transparent"
          stroke-width="16"
          class="cursor-pointer"
          role="button"
          tabindex="0"
          :aria-label="t('DELETE_EDGE')"
          @dblclick.stop="emit('removeEdge', edge.id)"
          @keydown.delete.prevent="emit('removeEdge', edge.id)"
        >
          <title>{{ t('DELETE_EDGE') }}</title>
        </path>
      </g>
      <g
        v-for="node in graph.nodes"
        :key="node.id"
        :transform="`translate(${position(node).x}, ${position(node).y})`"
        class="cursor-grab outline-none focus:ring-2"
        role="button"
        tabindex="0"
        :aria-label="label(node)"
        @pointerdown.stop="selectNode($event, node)"
        @keydown="keyMove($event, node)"
        @keydown.enter="emit('select', node.id)"
      >
        <rect
          width="240"
          :height="height(node)"
          rx="12"
          stroke-width="2"
          class="fill-n-solid-2"
          :class="
            selected === node.id
              ? 'stroke-n-blue-9'
              : visited.includes(node.id)
                ? 'stroke-n-teal-9'
                : 'stroke-n-weak'
          "
        />
        <rect
          x="0"
          y="15"
          width="4"
          height="30"
          rx="2"
          :class="node.type === 'start' ? 'fill-n-teal-9' : 'fill-n-blue-9'"
        />
        <text x="18" y="30" class="fill-n-slate-12 text-sm font-semibold">
          {{ label(node).slice(0, 27) }}
        </text>
        <text x="18" y="55" class="fill-n-slate-11 text-xs">
          {{ t(`NODES.${node.type}`) }}
        </text>
        <g
          v-if="node.type !== 'start'"
          role="button"
          tabindex="0"
          :aria-label="t('SELECT_BLOCK') + ' ' + label(node)"
          @pointerdown.stop
          @click.stop="connectTo(node)"
          @keydown.enter.stop="connectTo(node)"
        >
          <circle
            cx="0"
            cy="40"
            r="8"
            class="fill-n-solid-2 stroke-n-blue-9"
            stroke-width="2"
          />
        </g>
        <g
          v-for="(port, index) in ports(node)"
          :key="port"
          role="button"
          tabindex="0"
          :aria-label="label(node) + ': ' + portLabel(node, port)"
          @pointerdown.stop
          @click.stop="!readonly && (connection = { source: node.id, port })"
          @keydown.enter.stop="
            !readonly && (connection = { source: node.id, port })
          "
        >
          <text
            x="219"
            :y="94 + index * 28"
            text-anchor="end"
            class="fill-n-slate-11 text-xs"
          >
            {{ portLabel(node, port).slice(0, 22) }}
          </text>
          <circle
            cx="240"
            :cy="90 + index * 28"
            r="8"
            :class="
              connection?.source === node.id && connection?.port === port
                ? 'fill-n-blue-9'
                : 'fill-n-solid-2'
            "
            class="stroke-n-blue-9"
            stroke-width="2"
          />
        </g>
      </g>
    </svg>
    <p
      class="absolute bottom-3 left-3 right-3 m-0 rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-xs text-n-slate-11"
      role="status"
    >
      {{ connection ? t('CONNECTING') : t('MOVE_HELP') }}
    </p>
  </div>
</template>
