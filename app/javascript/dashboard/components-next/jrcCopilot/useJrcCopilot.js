import { computed, ref } from 'vue';

const mode = ref('closed');
const isOpen = computed(() => mode.value !== 'closed');
const isFull = computed(() => mode.value === 'full');
const pendingPrompt = ref('');
const suggestionCount = ref(0);
const notices = ref([]);
const focusedNoticeId = ref(null);

export const useJrcCopilot = () => {
  const open = () => {
    mode.value = 'full';
  };
  const openQuick = () => {
    mode.value = 'quick';
  };
  const close = () => {
    mode.value = 'closed';
  };
  const openNotice = id => {
    focusedNoticeId.value = id;
    open();
  };
  const toggle = () => {
    if (isOpen.value) close();
    else openQuick();
  };
  const openWithPrompt = prompt => {
    pendingPrompt.value = String(prompt || '').trim();
    open();
  };
  const consumePrompt = () => {
    const value = pendingPrompt.value;
    pendingPrompt.value = '';
    return value;
  };

  return {
    mode,
    isOpen,
    isFull,
    pendingPrompt,
    suggestionCount,
    notices,
    focusedNoticeId,
    openNotice,
    open,
    openQuick,
    close,
    toggle,
    openWithPrompt,
    consumePrompt,
  };
};
