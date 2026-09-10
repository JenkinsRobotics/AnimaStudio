import type { SketchPoint } from "@aether/core/sketch";
interface Options {
  svg: SVGSVGElement;
  enabled(): boolean;
  hasPending(): boolean;
  point(e: MouseEvent): SketchPoint | null;
  begin(p: SketchPoint): SketchPoint | null;
  preview(start: SketchPoint, end: SketchPoint): void;
  commit(start: SketchPoint, end: SketchPoint): void;
  clear(): void;
  report(message: string): void;
}

/** Drag-release placement shares the two-click tool's geometry and transaction. */
export function bindEndpointDragGesture(o: Options) {
  let gesture:
    | { id: number; start: SketchPoint; screen: SketchPoint; dragged: boolean }
    | undefined;
  let suppressClick = false;
  const release = (id: number) => {
    if (o.svg.hasPointerCapture?.(id)) o.svg.releasePointerCapture(id);
  };
  const cancel = () => {
    const current = gesture;
    gesture = undefined;
    if (!current) return;
    suppressClick = true;
    if (current.dragged) o.clear();
    release(current.id);
  };
  o.svg.addEventListener("pointerdown", (e) => {
    if (!gesture) suppressClick = false;
    if (gesture || e.button !== 0 || !o.enabled() || o.hasPending()) return;
    const point = o.point(e);
    if (!point) return;
    try {
      const start = o.begin(point);
      if (!start) return;
      gesture = {
        id: e.pointerId,
        start,
        screen: [e.clientX, e.clientY],
        dragged: false,
      };
      o.svg.focus();
      o.svg.setPointerCapture?.(e.pointerId);
    } catch (error) {
      o.report((error as Error).message);
    }
  });
  const advance = (e: PointerEvent) => {
    if (!gesture || e.pointerId !== gesture.id) return null;
    if (!o.enabled()) {
      cancel();
      return null;
    }
    if (
      !gesture.dragged &&
      Math.hypot(e.clientX - gesture.screen[0], e.clientY - gesture.screen[1]) <
        3
    )
      return null;
    const point = o.point(e);
    if (!point) return null;
    gesture.dragged = true;
    o.preview(gesture.start, point);
    return point;
  };
  o.svg.addEventListener("pointermove", advance);
  o.svg.addEventListener("pointerup", (e) => {
    const end = advance(e);
    if (!gesture || e.pointerId !== gesture.id) return;
    const current = gesture;
    gesture = undefined;
    suppressClick = current.dragged;
    if (current.dragged) {
      o.clear();
      if (end) {
        try {
          o.commit(current.start, end);
        } catch (error) {
          o.report((error as Error).message);
        }
      }
    }
    release(current.id);
  });
  o.svg.addEventListener("pointercancel", cancel);
  o.svg.addEventListener("lostpointercapture", cancel);
  return {
    cancel,
    active: () => Boolean(gesture?.dragged),
    consumeClick() {
      const value = suppressClick;
      suppressClick = false;
      return value;
    },
  };
}
