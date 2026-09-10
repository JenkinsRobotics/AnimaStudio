import type { SketchPoint } from "@aether/core/sketch";
import { updateDimensionLabelLeader } from "./dimension-label-leader";

/** Delegated SVG drag behavior; preview changes only text position. Commit is
 * one presentation edit on release, never a geometry move. */
export function mountDimensionLabelDrag(
  svg: SVGSVGElement,
  commit: (id: string, point: SketchPoint) => void,
) {
  let drag: {
    id: string;
    label: SVGTextElement;
    start: [number, number];
    original: [string, string];
    point: SketchPoint | null;
    pointerId: number;
    hadLeader: boolean;
  } | null = null;
  let swallowClick = false;
  const stop = (e: Event) => {
    e.preventDefault();
    e.stopImmediatePropagation();
  };
  const position = (e: PointerEvent): SketchPoint | null => {
    const matrix = svg.getScreenCTM();
    if (!matrix) return null;
    const p = svg.createSVGPoint();
    p.x = e.clientX;
    p.y = e.clientY;
    const local = p.matrixTransform(matrix.inverse());
    return [local.x, -local.y];
  };
  const down = (event: Event) => {
    const e = event as PointerEvent;
    swallowClick = false;
    if (e.button !== 0) return;
    const label = (e.target as Element)?.closest<SVGTextElement>(
      ".sketch-dimension text",
    );
    const id = label?.parentElement?.getAttribute("data-constraint-id");
    if (!label || !id) return;
    stop(e);
    svg.focus();
    drag = {
      id,
      label,
      start: [e.clientX, e.clientY],
      original: [label.getAttribute("x")!, label.getAttribute("y")!],
      point: null,
      pointerId: e.pointerId,
      hadLeader: !!label.parentElement?.querySelector(
        "[data-dimension-leader]",
      ),
    };
    svg.setPointerCapture?.(e.pointerId);
  };
  const move = (event: Event) => {
    if (!drag) return;
    const e = event as PointerEvent;
    stop(e);
    if (
      Math.hypot(e.clientX - drag.start[0], e.clientY - drag.start[1]) < 3 &&
      !drag.point
    )
      return;
    const p = position(e);
    if (!p) return;
    drag.point = p;
    drag.label.setAttribute("x", String(p[0]));
    drag.label.setAttribute("y", String(-p[1]));
    updateDimensionLabelLeader(drag.label);
  };
  const up = (event: Event) => {
    if (!drag) return;
    stop(event);
    const current = drag;
    drag = null;
    svg.releasePointerCapture?.(current.pointerId);
    if (current.point) {
      swallowClick = true;
      commit(current.id, current.point);
    }
  };
  const cancel = (event: Event) => {
    if (!drag) return;
    stop(event);
    const current = drag;
    drag = null;
    current.label.setAttribute("x", current.original[0]);
    current.label.setAttribute("y", current.original[1]);
    updateDimensionLabelLeader(current.label, current.hadLeader);
    svg.releasePointerCapture?.(current.pointerId);
  };
  const key = (event: Event) => {
    if ((event as KeyboardEvent).key === "Escape") cancel(event);
  };
  const click = (event: Event) => {
    if (swallowClick) {
      swallowClick = false;
      stop(event);
    }
  };
  const bindings: [string, EventListener][] = [
    ["pointerdown", down],
    ["pointermove", move],
    ["pointerup", up],
    ["pointercancel", cancel],
    ["keydown", key],
    ["click", click],
  ];
  bindings.forEach(([name, handler]) =>
    svg.addEventListener(name, handler, true),
  );
  return {
    dispose: () =>
      bindings.forEach(([name, handler]) =>
        svg.removeEventListener(name, handler, true),
      ),
  };
}
