import { formatDimensionLabel } from "./dimension-label-units";
import type { SketchDrawing, SketchPoint } from "@aether/core/sketch";
/** Presentation-only drag state. Applying the panel remains the single document commit. */
export function mountDimensionManipulator<H extends { position: SketchPoint }>(
  svg: SVGSVGElement,
  setValue: (value: number) => void,
  report: (message: string) => void,
  getHandle: (drawing: SketchDrawing, id: string) => H | undefined,
  className: string,
  label: string,
  behavior: {
    value: (handle: H) => number;
    project: (handle: H, point: SketchPoint) => number;
    step: (value: number, direction: number) => number;
    minimum?: number;
  },
) {
  let drag: { id: number; handle: H } | undefined,
    suppressClick = false;
  const point = (e: MouseEvent): SketchPoint | null => {
    const matrix = svg.getScreenCTM?.();
    if (!matrix) return null;
    const p = svg.createSVGPoint();
    p.x = e.clientX;
    p.y = e.clientY;
    const local = p.matrixTransform(matrix.inverse());
    return [local.x, -local.y];
  };
  svg.addEventListener("pointermove", (e) => {
    if (!drag || drag.id !== e.pointerId) return;
    const p = point(e);
    if (!p) return;
    try {
      setValue(behavior.project(drag.handle, p));
    } catch (error) {
      report((error as Error).message);
    }
  });
  svg.addEventListener("pointerup", (e) => {
    if (drag && drag.id === e.pointerId) {
      drag = undefined;
      suppressClick = true;
      if (svg.hasPointerCapture?.(e.pointerId))
        svg.releasePointerCapture(e.pointerId);
    }
  });
  const cancel = () => {
    if (drag) {
      const value = behavior.value(drag.handle),
        id = drag.id;
      drag = undefined;
      if (svg.hasPointerCapture?.(id)) svg.releasePointerCapture(id);
      setValue(value);
    }
  };
  svg.addEventListener(
    "pointerdown",
    () => {
      suppressClick = false;
    },
    true,
  );
  svg.addEventListener("pointercancel", cancel);
  svg.addEventListener("lostpointercapture", cancel);
  svg.addEventListener(
    "keydown",
    (e) => {
      if (e.key === "Escape" && drag) {
        e.stopImmediatePropagation();
        cancel();
      }
    },
    true,
  );
  svg.addEventListener(
    "click",
    (e) => {
      if (suppressClick) {
        suppressClick = false;
        e.stopImmediatePropagation();
      }
    },
    true,
  );
  return {
    close() {
      const id = drag?.id;
      drag = undefined;
      suppressClick = false;
      if (id !== undefined && svg.hasPointerCapture?.(id))
        svg.releasePointerCapture(id);
      svg.querySelector(`.${className}`)?.remove();
    },
    render(drawing: SketchDrawing, id: string) {
      svg.querySelector(`.${className}`)?.remove();
      const handle = getHandle(drawing, id);
      if (!handle) return;
      const circle = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "circle",
      );
      circle.classList.add(className);
      circle.setAttribute("cx", String(handle.position[0]));
      circle.setAttribute("cy", String(-handle.position[1]));
      const matrix = svg.getScreenCTM?.(),
        scale = matrix ? Math.hypot(matrix.a, matrix.b) : NaN;
      circle.setAttribute(
        "r",
        String(Number.isFinite(scale) && scale > 0 ? 6 / scale : 0.8),
      );
      circle.setAttribute("role", "slider");
      circle.setAttribute("aria-label", label);
      circle.setAttribute("aria-valuenow", String(behavior.value(handle)));
      circle.setAttribute(
        "aria-valuetext",
        formatDimensionLabel(behavior.value(handle)),
      );
      if (behavior.minimum !== undefined)
        circle.setAttribute("aria-valuemin", String(behavior.minimum));
      circle.setAttribute("tabindex", "0");
      circle.addEventListener("pointerdown", (e) => {
        if (e.button !== 0) return;
        e.preventDefault();
        e.stopPropagation();
        drag = { id: e.pointerId, handle };
        suppressClick = false;
        svg.focus();
        svg.setPointerCapture?.(e.pointerId);
      });
      circle.addEventListener("keydown", (e) => {
        if (
          e.key === "ArrowUp" ||
          e.key === "ArrowRight" ||
          e.key === "ArrowDown" ||
          e.key === "ArrowLeft"
        ) {
          e.preventDefault();
          e.stopPropagation();
          setValue(
            behavior.step(
              behavior.value(handle),
              e.key === "ArrowUp" || e.key === "ArrowRight" ? 1 : -1,
            ),
          );
          (svg.querySelector(`.${className}`) as SVGElement | null)?.focus();
        }
      });
      svg.append(circle);
    },
  };
}
