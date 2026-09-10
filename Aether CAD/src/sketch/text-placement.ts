import type { SketchDrawing, SketchPoint } from "@aether/core/sketch";
import { snapSketchPoint } from "../sketch-snapping";

/** Preview-only baseline picking. Insertion remains the panel's explicit commit. */
export function mountTextPlacement(
  parent: HTMLElement,
  svg: SVGSVGElement,
  fields: { x: HTMLInputElement; y: HTMLInputElement },
  drawing: () => SketchDrawing,
  changed: () => void,
) {
  const button = document.createElement("button"),
    label = document.createElement("label"),
    snap = document.createElement("input"),
    status = document.createElement("span");
  button.type = "button";
  button.textContent = "Place text on canvas";
  button.disabled = true;
  button.setAttribute("aria-pressed", "false");
  snap.type = "checkbox";
  snap.checked = true;
  snap.setAttribute("aria-label", "Snap text placement");
  label.append(snap, " Snap text baseline to sketch geometry");
  status.setAttribute("role", "status");
  parent.append(button, label, status);
  let active = false,
    original: [string, string] = ["0", "0"];
  function stop(restore = false) {
    if (active && restore) {
      fields.x.value = original[0];
      fields.y.value = original[1];
    }
    const wasActive = active;
    active = false;
    button.setAttribute("aria-pressed", "false");
    status.textContent = "";
    if (wasActive && restore) changed();
  }
  button.onclick = () => {
    if (active) {
      stop(true);
      return;
    }
    window.dispatchEvent(
      new CustomEvent("aether-sketch-tool", { detail: "select" }),
    );
    original = [fields.x.value, fields.y.value];
    active = true;
    button.setAttribute("aria-pressed", "true");
    status.textContent =
      "Click the sketch to place the text baseline. Escape cancels placement.";
    svg.focus();
  };
  function move(event: Event) {
    if (!active) return false;
    event.stopImmediatePropagation();
    const matrix = svg.getScreenCTM?.();
    if (!matrix) return false;
    const point = svg.createSVGPoint(),
      mouse = event as MouseEvent;
    point.x = mouse.clientX;
    point.y = mouse.clientY;
    const world = point.matrixTransform(matrix.inverse());
    let target: SketchPoint = [world.x, -world.y];
    if (!target.every(Number.isFinite)) return false;
    if (snap.checked) {
      const result = snapSketchPoint(
        target,
        drawing(),
        undefined,
        6 / Math.max(Math.hypot(matrix.a, matrix.b), 1e-8),
        false,
      );
      target = result.point;
      status.textContent = result.label ? `Snap: ${result.label}` : "";
    } else status.textContent = "";
    fields.x.value = String(target[0]);
    fields.y.value = String(target[1]);
    changed();
    return true;
  }
  const click = (event: Event) => {
    if (!active || (event as MouseEvent).button !== 0) return;
    event.preventDefault();
    if (move(event)) stop();
  };
  const down = (event: Event) => {
    if (!active) return;
    event.preventDefault();
    event.stopImmediatePropagation();
  };
  const key = (event: KeyboardEvent) => {
    if (!active || event.key !== "Escape") return;
    event.preventDefault();
    event.stopImmediatePropagation();
    stop(true);
  };
  const toolChanged = () => stop(true);
  svg.addEventListener("pointermove", move, true);
  svg.addEventListener("pointerdown", down, true);
  svg.addEventListener("click", click, true);
  svg.addEventListener("keydown", key, true);
  window.addEventListener("aether-sketch-tool", toolChanged);
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
      svg.removeEventListener("pointermove", move, true);
      svg.removeEventListener("pointerdown", down, true);
      svg.removeEventListener("click", click, true);
      svg.removeEventListener("keydown", key, true);
      window.removeEventListener("aether-sketch-tool", toolChanged);
      button.remove();
      label.remove();
      status.remove();
    },
  };
}
