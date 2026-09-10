import {
  textFramePlacement,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
import { snapSketchPoint } from "../sketch-snapping";

/** Two-corner text layout gesture; font outlines remain cached by the panel. */
export function mountTextBoxPlacement(
  parent: HTMLElement,
  svg: SVGSVGElement,
  fields: {
    x: HTMLInputElement;
    y: HTMLInputElement;
    size: HTMLInputElement;
    width: HTMLInputElement;
    angle: HTMLInputElement;
    flipHorizontal: HTMLInputElement;
    flipVertical: HTMLInputElement;
    flipAboutFrame: HTMLInputElement;
  },
  drawing: () => SketchDrawing,
  changed: () => void,
  heightRatio: () => number = () => 1,
  placementReflected: () => boolean = () => false,
) {
  const button = document.createElement("button"),
    status = document.createElement("span");
  button.type = "button";
  button.textContent = "Draw text frame";
  button.disabled = true;
  button.setAttribute("aria-pressed", "false");
  status.setAttribute("role", "status");
  parent.append(button, status);
  const values = [fields.x, fields.y, fields.size, fields.width];
  let active = false,
    anchor: SketchPoint | undefined,
    valid = false,
    downAt: [number, number] | undefined,
    suppressClick = false,
    original: string[] = [];
  function stop(restore = false) {
    const wasActive = active;
    active = false;
    anchor = undefined;
    downAt = undefined;
    valid = false;
    button.setAttribute("aria-pressed", "false");
    status.textContent = "";
    if (wasActive && restore) {
      values.forEach((input, i) => {
        input.value = original[i];
      });
      changed();
    }
  }
  button.onclick = () => {
    if (active) {
      stop(true);
      return;
    }
    window.dispatchEvent(
      new CustomEvent("aether-sketch-tool", { detail: "select" }),
    );
    original = values.map((input) => input.value);
    active = true;
    suppressClick = false;
    button.setAttribute("aria-pressed", "true");
    status.textContent =
      "Drag a text frame, or click two opposite corners. Escape cancels.";
    svg.focus();
  };
  function target(event: MouseEvent): SketchPoint | undefined {
    const matrix = svg.getScreenCTM?.();
    if (!matrix) return;
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const world = point.matrixTransform(matrix.inverse());
    const raw: SketchPoint = [world.x, -world.y];
    if (!raw.every(Number.isFinite)) return;
    const snap = parent.querySelector<HTMLInputElement>(
      '[aria-label="Snap text placement"]',
    );
    if (snap && !snap.checked) return raw;
    const result = snapSketchPoint(
      raw,
      drawing(),
      undefined,
      6 / Math.max(Math.hypot(matrix.a, matrix.b), 1e-8),
      false,
    );
    status.textContent = result.label
      ? `Snap: ${result.label}`
      : "Select the opposite corner.";
    return result.point;
  }
  function update(point: SketchPoint) {
    if (!anchor) return;
    if (
      !fields.angle.value.trim() ||
      !Number.isFinite(Number(fields.angle.value))
    ) {
      valid = false;
      status.textContent =
        "Enter a finite text rotation before drawing the frame.";
      return;
    }
    const transform = textFramePlacement({
      originMillimeters: anchor,
      placementReflected: placementReflected(),
      rotationDegrees: Number(fields.angle.value),
      flipHorizontal: fields.flipHorizontal.checked,
      flipVertical: fields.flipVertical.checked,
      flipAboutFrame: fields.flipAboutFrame.checked,
    });
    const dx = point[0] - anchor[0],
      dy = point[1] - anchor[1],
      u = transform.a * dx + transform.c * dy,
      v = transform.b * dx + transform.d * dy;
    valid = Math.abs(u) > 1e-6 && Math.abs(v) > 1e-6;
    if (!valid) {
      status.textContent = "The frame needs nonzero width and height.";
      return;
    }
    const left = Math.min(0, u),
      bottom = Math.min(0, v);
    fields.x.value = String(
      anchor[0] + transform.a * left + transform.b * bottom,
    );
    fields.y.value = String(
      anchor[1] + transform.c * left + transform.d * bottom,
    );
    fields.width.value = String(Math.abs(u));
    fields.size.value = String(Math.abs(v) / heightRatio());
    changed();
  }
  function pointer(event: Event) {
    if (!active) return;
    const mouse = event as MouseEvent;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (event.type !== "pointermove" && mouse.button !== 0) return;
    const point = target(mouse);
    if (!point) return;
    if (event.type === "pointerdown") {
      downAt = [mouse.clientX, mouse.clientY];
      if (!anchor) anchor = point;
      else update(point);
    } else if (event.type === "pointermove") update(point);
    else if (
      downAt &&
      Math.hypot(mouse.clientX - downAt[0], mouse.clientY - downAt[1]) > 3
    ) {
      update(point);
      if (valid) {
        stop();
        suppressClick = true;
      }
    }
  }
  function click(event: Event) {
    if (suppressClick) {
      event.preventDefault();
      event.stopImmediatePropagation();
      suppressClick = false;
      return;
    }
    if (!active || (event as MouseEvent).button !== 0) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const point = target(event as MouseEvent);
    if (!point) return;
    if (!anchor) anchor = point;
    else {
      update(point);
      if (valid) stop();
    }
  }
  const key = (event: KeyboardEvent) => {
    if (!active || event.key !== "Escape") return;
    event.preventDefault();
    event.stopImmediatePropagation();
    stop(true);
  };
  const cancel = () => stop(true);
  for (const type of ["pointerdown", "pointermove", "pointerup"])
    svg.addEventListener(type, pointer, true);
  svg.addEventListener("click", click, true);
  svg.addEventListener("keydown", key, true);
  window.addEventListener("aether-sketch-tool", cancel);
  return {
    available(value: boolean) {
      button.disabled = !value;
      if (!value) stop();
    },
    reset() {
      stop();
    },
    dispose() {
      stop();
      for (const type of ["pointerdown", "pointermove", "pointerup"])
        svg.removeEventListener(type, pointer, true);
      svg.removeEventListener("click", click, true);
      svg.removeEventListener("keydown", key, true);
      window.removeEventListener("aether-sketch-tool", cancel);
      button.remove();
      status.remove();
    },
  };
}
