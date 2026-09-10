import {
  resizeSketchTextFrame,
  textFramePlacement,
  textFrameHeight,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";

/** Canvas handles project retained text; Core owns resizing and constraints. */
export function mountTextResize(
  svg: SVGSVGElement,
  drawing: () => SketchDrawing,
  selected: () => string,
  commit: (next: SketchDrawing) => void,
  report: (message: string) => void,
) {
  type Handle = "width" | "height" | "corner";
  let drag:
    | {
        before: SketchDrawing;
        snapshot: string;
        id: string;
        handle: Handle;
        pointerId: number;
        next?: SketchDrawing;
      }
    | undefined;
  let consumeClick = false;
  const ns = "http://www.w3.org/2000/svg";
  function render(source = drawing(), preview = false) {
    svg.querySelector(".sketch-text-resize")?.remove();
    const item = source.textItems?.find((item) => item.id === selected());
    if (!item?.frameContourId) return;
    const frame = source.contours.find((c) => c.id === item.frameContourId);
    if (frame?.type !== "path" || frame.segments.length !== 4) return;
    const group = document.createElementNS(ns, "g");
    group.classList.add("sketch-text-resize");
    if (preview)
      for (const contour of source.contours.filter(
        (c) => c.id && item.contourIds.includes(c.id),
      )) {
        if (contour.type !== "path") continue;
        const path = document.createElementNS(ns, "path");
        path.setAttribute("d", contourPath(contour));
        path.classList.add("sketch-preview");
        path.setAttribute("pointer-events", "none");
        group.append(path);
      }
    const corner = frame.segments[1].end,
      mid = (a: SketchPoint, b: SketchPoint): SketchPoint => [
        (a[0] + b[0]) / 2,
        (a[1] + b[1]) / 2,
      ];
    const points: [Handle, SketchPoint][] = [
      ["width", mid(frame.segments[0].end, corner)],
      ["height", mid(corner, frame.segments[2].end)],
      ["corner", corner],
    ];
    const matrix = svg.getScreenCTM?.(),
      scale = matrix ? Math.hypot(matrix.a, matrix.b) : 1;
    for (const [handle, point] of points) {
      const circle = document.createElementNS(ns, "circle");
      circle.dataset.textResize = handle;
      circle.setAttribute("cx", String(point[0]));
      circle.setAttribute("cy", String(-point[1]));
      circle.setAttribute("r", String(5 / Math.max(scale, 1e-8)));
      circle.setAttribute("fill", "var(--accent, #439aff)");
      circle.setAttribute("stroke", "var(--text, #edf3fa)");
      circle.setAttribute("vector-effect", "non-scaling-stroke");
      circle.setAttribute("aria-label", `Resize text ${handle}`);
      circle.style.cursor =
        handle === "corner"
          ? "nwse-resize"
          : handle === "width"
            ? "ew-resize"
            : "ns-resize";
      group.append(circle);
    }
    svg.append(group);
  }
  function release(pointerId: number) {
    if (svg.hasPointerCapture?.(pointerId))
      svg.releasePointerCapture(pointerId);
  }
  function cancel() {
    if (!drag) return;
    const pointerId = drag.pointerId;
    drag = undefined;
    release(pointerId);
    render();
  }
  function down(event: PointerEvent) {
    const element = (event.target as Element)?.closest?.("[data-text-resize]");
    if (!element || event.button !== 0) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const before = structuredClone(drawing());
    drag = {
      before,
      snapshot: JSON.stringify(before),
      id: selected(),
      handle: element.getAttribute("data-text-resize") as Handle,
      pointerId: event.pointerId,
    };
    svg.setPointerCapture?.(event.pointerId);
    svg.focus();
  }
  function move(event: PointerEvent) {
    if (!drag || drag.pointerId !== event.pointerId) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const item = drag.before.textItems!.find((item) => item.id === drag!.id)!;
    const matrix = svg.getScreenCTM?.();
    if (!matrix) return;
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const world = point.matrixTransform(matrix.inverse()),
      transform = textFramePlacement(item),
      dx = world.x - transform.tx,
      dy = -world.y - transform.ty,
      width =
        drag.handle === "height"
          ? item.frameWidthMillimeters!
          : transform.a * dx + transform.c * dy,
      height =
        drag.handle === "width"
          ? textFrameHeight(item)
          : transform.b * dx + transform.d * dy;
    try {
      drag.next = resizeSketchTextFrame(
        drag.before,
        drag.id,
        width,
        height / (item.fontAscenderRatio ?? 1),
      );
      render(drag.next, true);
      report("");
    } catch (error) {
      drag.next = undefined;
      render(drag.before);
      report((error as Error).message);
    }
  }
  function up(event: PointerEvent) {
    if (!drag || drag.pointerId !== event.pointerId) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const done = drag;
    drag = undefined;
    consumeClick = true;
    release(done.pointerId);
    if (done.next) {
      if (selected() !== done.id || JSON.stringify(drawing()) !== done.snapshot)
        report(
          "The sketch changed during text resizing. Try the resize again.",
        );
      else commit(done.next);
    }
    render();
  }
  function click(event: Event) {
    if (!consumeClick) return;
    consumeClick = false;
    event.preventDefault();
    event.stopImmediatePropagation();
  }
  function key(event: KeyboardEvent) {
    if (!drag || event.key !== "Escape") return;
    event.preventDefault();
    event.stopImmediatePropagation();
    cancel();
  }
  svg.addEventListener("pointerdown", down, true);
  svg.addEventListener("pointermove", move, true);
  svg.addEventListener("pointerup", up, true);
  svg.addEventListener("pointercancel", cancel, true);
  svg.addEventListener("lostpointercapture", cancel);
  svg.addEventListener("keydown", key, true);
  svg.addEventListener("click", click, true);
  window.addEventListener("aether-sketch-tool", cancel);
  return {
    render,
    clear() {
      cancel();
      svg.querySelector(".sketch-text-resize")?.remove();
    },
    dispose() {
      cancel();
      svg.querySelector(".sketch-text-resize")?.remove();
      svg.removeEventListener("pointerdown", down, true);
      svg.removeEventListener("pointermove", move, true);
      svg.removeEventListener("pointerup", up, true);
      svg.removeEventListener("pointercancel", cancel, true);
      svg.removeEventListener("lostpointercapture", cancel);
      svg.removeEventListener("keydown", key, true);
      svg.removeEventListener("click", click, true);
      window.removeEventListener("aether-sketch-tool", cancel);
    },
  };
}
