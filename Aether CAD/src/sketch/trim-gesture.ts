import {
  trimSketchSweep,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
interface Callbacks {
  enabled(): boolean;
  point(event: MouseEvent): SketchPoint | null;
  drawing(): SketchDrawing;
  pointTolerance(): number;
  preview(drawing: SketchDrawing): void;
  commit(original: SketchDrawing, drawing: SketchDrawing): void;
  error(message: string): void;
}
/** Pointer capture and a single undo transaction for an entire trim stroke. */
export function bindTrimGesture(svg: SVGSVGElement, callbacks: Callbacks) {
  let gesture:
    | {
        id: number;
        original: SketchDrawing;
        draft: SketchDrawing;
        last: SketchPoint;
        screen: SketchPoint;
        dragged: boolean;
      }
    | undefined;
  let suppressClick = false;
  const cancel = () => {
    if (gesture) {
      callbacks.preview(gesture.original);
      gesture = undefined;
    }
  };
  svg.addEventListener("pointerdown", (e) => {
    if (gesture || e.button !== 0 || !callbacks.enabled()) return;
    const point = callbacks.point(e);
    if (!point) return;
    const drawing = callbacks.drawing();
    gesture = {
      id: e.pointerId,
      original: drawing,
      draft: drawing,
      last: point,
      screen: [e.clientX, e.clientY],
      dragged: false,
    };
    suppressClick = false;
    svg.focus();
    svg.setPointerCapture?.(e.pointerId);
  });
  const advance = (e: PointerEvent) => {
    if (!gesture || e.pointerId !== gesture.id) return;
    if (!callbacks.enabled()) {
      cancel();
      return;
    }
    const point = callbacks.point(e);
    if (!point) return;
    if (
      !gesture.dragged &&
      Math.hypot(e.clientX - gesture.screen[0], e.clientY - gesture.screen[1]) <
        3
    )
      return;
    gesture.dragged = true;
    try {
      gesture.draft = trimSketchSweep(
        gesture.draft,
        gesture.last,
        point,
        callbacks.pointTolerance(),
      );
      gesture.last = point;
      callbacks.preview(gesture.draft);
    } catch (error) {
      callbacks.error((error as Error).message);
      gesture.last = point;
    }
  };
  svg.addEventListener("pointermove", advance);
  svg.addEventListener("pointerup", (e) => {
    advance(e);
    if (!gesture || e.pointerId !== gesture.id) return;
    const finished = gesture;
    gesture = undefined;
    suppressClick = finished.dragged;
    if (finished.dragged) callbacks.commit(finished.original, finished.draft);
    if (svg.hasPointerCapture?.(e.pointerId))
      svg.releasePointerCapture(e.pointerId);
  });
  svg.addEventListener("pointercancel", cancel);
  svg.addEventListener("lostpointercapture", cancel);
  svg.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      suppressClick = !!gesture?.dragged;
      cancel();
    }
  });
  return {
    active: () => !!gesture?.dragged,
    consumeClick: () => {
      const value = suppressClick;
      suppressClick = false;
      return value;
    },
  };
}
