import { ref } from 'vue';

const isOpen = ref(false);
const pendingPrompt = ref('');
const suggestionCount = ref(0);
const notices = ref([]);
const focusedNoticeId = ref(null);

export const useJrcCopilot = () => {
  const open = () => {
    isOpen.value = true;
  };
  const close = () => {
    isOpen.value = false;
  };
  const openNotice = id => {
    focusedNoticeId.value = id;
    isOpen.value = true;
  };
  const toggle = () => {
    isOpen.value = !isOpen.value;
  };
  const openWithPrompt = prompt => {
    pendingPrompt.value = String(prompt || '').trim();
    isOpen.value = true;
  };
  const consumePrompt = () => {
    const value = pendingPrompt.value;
    pendingPrompt.value = '';
    return value;
  };

  return {
    isOpen,
    pendingPrompt,
    suggestionCount,
    notices,
    focusedNoticeId,
    openNotice,
    open,
    close,
    toggle,
    openWithPrompt,
    consumePrompt,
  };
};
