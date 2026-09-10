import { computed, ref } from 'vue';

export function useDragAndDrop({ onMove }) {
  const draggingDealId = ref(null);
  const draggingFromStageId = ref(null);

  const onDragStart = (event, deal) => {
    draggingDealId.value = deal.id;
    draggingFromStageId.value = deal.stage_id;

    // Set visual drag effect
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', deal.id.toString());

      // Optional: add a class to the element being dragged
      setTimeout(() => {
        if (event.target && event.target.classList) {
          event.target.classList.add('opacity-50');
        }
      }, 0);
    }
  };

  const onDragOver = event => {
    // Prevent default to allow drop
    event.preventDefault();
    if (event.dataTransfer) {
      event.dataTransfer.dropEffect = 'move';
    }
  };

  const onDrop = (event, toStageId) => {
    event.preventDefault();

    // Clean up any visual drag effects on drop targets (if implemented)

    if (draggingDealId.value && draggingFromStageId.value !== toStageId) {
      onMove({
        dealId: draggingDealId.value,
        fromStageId: draggingFromStageId.value,
        toStageId,
      });
    }

    // Reset state
    draggingDealId.value = null;
    draggingFromStageId.value = null;
  };

  const onDragEnd = event => {
    if (event.target && event.target.classList) {
      event.target.classList.remove('opacity-50');
    }
    draggingDealId.value = null;
    draggingFromStageId.value = null;
  };

  return {
    isDragging: computed(() => !!draggingDealId.value),
    draggingDealId,
    onDragStart,
    onDragOver,
    onDrop,
    onDragEnd,
  };
}
