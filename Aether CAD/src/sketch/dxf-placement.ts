import { snapSketchPoint } from "../sketch-snapping";
import { dxfAnchorChoices } from "./dxf-anchor";
import {
  similarityTransform,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
/** Import positioning is preview-only until the parent commits insertion. */
export function mountDxfPlacement(
  parent: HTMLElement,
  svg: SVGSVGElement,
  changed: () => void,
  drawing: () => SketchDrawing,
) {
  const fields = (label: string, value: string) => {
    const l = document.createElement("label");
    l.textContent = label;
    const input = document.createElement("input");
    input.type = "number";
    input.step = "any";
    input.value = value;
    input.setAttribute("aria-label", label);
    l.append(input);
    parent.append(l);
    input.oninput = changed;
    return input;
  };
  const x = fields("DXF X (mm)", "0"),
    y = fields("DXF Y (mm)", "0"),
    rotation = fields("DXF rotation (degrees)", "0"),
    scale = fields("DXF scale", "1");
  scale.min = "0";
  const anchorX = fields("DXF anchor X (mm)", "0"),
    anchorY = fields("DXF anchor Y (mm)", "0"),
    anchors = document.createElement("select");
  anchors.setAttribute("aria-label", "DXF source anchor");
  parent.append(anchors);
  anchors.onchange = () => {
    if (!anchors.value) return;
    const point = JSON.parse(anchors.value) as SketchPoint;
    anchorX.value = String(point[0]);
    anchorY.value = String(point[1]);
    changed();
  };
  for (const field of [anchorX, anchorY])
    field.oninput = () => {
      anchors.value = "";
      changed();
    };
  const snapLabel = document.createElement("label"),
    snap = document.createElement("input"),
    snapStatus = document.createElement("span");
  snap.type = "checkbox";
  snap.checked = true;
  snap.setAttribute("aria-label", "Snap DXF placement");
  snapLabel.append(snap, " Snap placement to sketch geometry");
  parent.append(snapLabel, snapStatus);
  snapStatus.setAttribute("role", "status");
  const hint = document.createElement("p");
  hint.textContent =
    "The source anchor lands at DXF X/Y. Rotation and scale act around that anchor.";
  parent.append(hint);
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = "Place DXF on canvas";
  button.disabled = true;
  parent.append(button);
  let active = false,
    original: [string, string] = ["0", "0"];
  const stop = (restore = false) => {
    if (restore) {
      x.value = original[0];
      y.value = original[1];
    }
    active = false;
    snapStatus.textContent = "";
    button.setAttribute("aria-pressed", "false");
    if (restore) changed();
  };
  button.onclick = () => {
    if (active) {
      stop(true);
      return;
    }
    original = [x.value, y.value];
    active = true;
    button.setAttribute("aria-pressed", "true");
    svg.focus();
  };
  const point = (e: MouseEvent): SketchPoint | undefined => {
    const matrix = svg.getScreenCTM?.();
    if (!matrix) return;
    const p = svg.createSVGPoint();
    p.x = e.clientX;
    p.y = e.clientY;
    const q = p.matrixTransform(matrix.inverse());
    return [q.x, -q.y];
  };
  const move = (event: Event) => {
    if (!active) return;
    event.stopImmediatePropagation();
    let p = point(event as MouseEvent);
    if (p) {
      if (snap.checked) {
        const matrix = svg.getScreenCTM?.(),
          scale = matrix ? Math.hypot(matrix.a, matrix.b) : 1;
        const result = snapSketchPoint(
          p,
          drawing(),
          undefined,
          6 / Math.max(scale, 1e-8),
          false,
        );
        p = result.point;
        snapStatus.textContent = result.label ? `Snap: ${result.label}` : "";
      } else snapStatus.textContent = "";
      x.value = String(p[0]);
      y.value = String(p[1]);
      changed();
    }
  };
  const click = (event: Event) => {
    if (!active) return;
    event.preventDefault();
    move(event);
    stop();
  };
  const down = (event: Event) => {
    if (active) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  };
  const key = (event: KeyboardEvent) => {
    if (active && event.key === "Escape") {
      event.preventDefault();
      event.stopImmediatePropagation();
      stop(true);
    }
  };
  svg.addEventListener("pointermove", move, true);
  svg.addEventListener("pointerdown", down, true);
  svg.addEventListener("click", click, true);
  svg.addEventListener("keydown", key, true);
  return {
    transform() {
      const values = [x, y, rotation, scale, anchorX, anchorY].map((f) => {
        if (!f.value.trim()) throw Error("Enter all DXF placement values.");
        return Number(f.value);
      });
      return similarityTransform(
        [values[4], values[5]],
        [values[0] - values[4], values[1] - values[5]],
        values[2],
        values[3],
      );
    },
    source(source: SketchDrawing | undefined) {
      anchors.replaceChildren();
      const custom = document.createElement("option");
      custom.value = "";
      custom.textContent = "Custom coordinates";
      anchors.append(custom);
      for (const choice of dxfAnchorChoices(
        source ?? { type: "drawing", contours: [] },
      )) {
        const option = document.createElement("option");
        option.value = JSON.stringify(choice.point);
        option.textContent = choice.label;
        anchors.append(option);
      }
      anchorX.value = anchorY.value = "0";
      anchors.value = "[0,0]";
    },
    available(value: boolean) {
      button.disabled = !value;
      if (!value) stop();
    },
    reset() {
      stop();
      x.value = y.value = rotation.value = "0";
      scale.value = "1";
      anchorX.value = anchorY.value = "0";
      anchors.value = "[0,0]";
    },
    dispose() {
      stop();
      svg.removeEventListener("pointermove", move, true);
      svg.removeEventListener("pointerdown", down, true);
      svg.removeEventListener("click", click, true);
      svg.removeEventListener("keydown", key, true);
    },
  };
}
