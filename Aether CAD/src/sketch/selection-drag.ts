import {
  dragSketchEntity,
  type SketchDrawing,
  type SketchPoint,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { pickSelectableSketchEntity } from "./projected-picking";
interface Options {
  svg: SVGSVGElement;
  enabled: () => boolean;
  point: (e: MouseEvent) => SketchPoint | null;
  drawing: () => SketchDrawing;
  tolerance: () => number;
  preview: (d: SketchDrawing) => void;
  commit: (before: SketchDrawing, after: SketchDrawing) => void;
  select: (ref: SketchEntityRef) => void;
  report: (s: string) => void;
}
export function bindSelectionDrag(o: Options) {
  let drag:
      | {
          id: number;
          screen: SketchPoint;
          start: SketchPoint;
          ref: SketchEntityRef;
          before: SketchDrawing;
          after: SketchDrawing;
          moved: boolean;
        }
      | undefined,
    consume = false;
  o.svg.addEventListener("pointerdown", (e) => {
    if (e.button !== 0 || !o.enabled()) return;
    const p = o.point(e);
    if (!p) return;
    const pick = pickSelectableSketchEntity(o.drawing(), p);
    if (!pick || pick.d > o.tolerance() || pick.ref.projectedContourId!==undefined) return;
    const before = structuredClone(o.drawing());
    drag = {
      id: e.pointerId,
      screen: [e.clientX, e.clientY],
      start: p,
      ref: pick.ref,
      before,
      after: before,
      moved: false,
    };
  });
  o.svg.addEventListener("pointermove", (e) => {
    if (!drag || drag.id !== e.pointerId) return;
    if (
      !drag.moved &&
      Math.hypot(e.clientX - drag.screen[0], e.clientY - drag.screen[1]) < 3
    )
      return;
    const p = o.point(e);
    if (!p) return;
    drag.moved = true;
    o.svg.setPointerCapture?.(e.pointerId);
    o.select(drag.ref);
    try {
      drag.after = dragSketchEntity(drag.before, drag.ref, [
        p[0] - drag.start[0],
        p[1] - drag.start[1],
      ]);
      o.preview(drag.after);
    } catch (error) {
      o.report((error as Error).message);
    }
  });
  o.svg.addEventListener("pointerup", (e) => {
    if (!drag || drag.id !== e.pointerId) return;
    const done = drag;
    drag = undefined;
    if (done.moved) {
      consume = true;
      o.commit(done.before, done.after);
    }
    if (o.svg.hasPointerCapture?.(e.pointerId))
      o.svg.releasePointerCapture(e.pointerId);
  });
  const cancel = () => {
    if (drag) {
      const before = drag.before;
      drag = undefined;
      o.preview(before);
    }
  };
  o.svg.addEventListener("pointercancel", cancel);
  o.svg.addEventListener("lostpointercapture", cancel);
  return {
    cancel,
    active: () => !!drag?.moved,
    consumeClick() {
      const result = consume;
      consume = false;
      return result;
    },
  };
}
