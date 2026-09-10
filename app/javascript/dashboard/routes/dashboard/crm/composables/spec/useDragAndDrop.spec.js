import { describe, expect, it, vi } from 'vitest';
import { useDragAndDrop } from '../useDragAndDrop';

describe('useDragAndDrop', () => {
  it('moves a dragged deal to a different stage and resets its state', () => {
    const onMove = vi.fn();
    const dataTransfer = { setData: vi.fn() };
    const drag = useDragAndDrop({ onMove });

    drag.onDragStart(
      { dataTransfer, target: { classList: { add: vi.fn() } } },
      { id: 12, stage_id: 3 }
    );
    drag.onDrop({ preventDefault: vi.fn() }, 4);

    expect(dataTransfer.effectAllowed).toBe('move');
    expect(dataTransfer.setData).toHaveBeenCalledWith('text/plain', '12');
    expect(onMove).toHaveBeenCalledWith({
      dealId: 12,
      fromStageId: 3,
      toStageId: 4,
    });
    expect(drag.isDragging.value).toBe(false);
  });

  it('does not persist a move when dropped in the original stage', () => {
    const onMove = vi.fn();
    const drag = useDragAndDrop({ onMove });

    drag.onDragStart({}, { id: 12, stage_id: 3 });
    drag.onDrop({ preventDefault: vi.fn() }, 3);

    expect(onMove).not.toHaveBeenCalled();
  });
});
