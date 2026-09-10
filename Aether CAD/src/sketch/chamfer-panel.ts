import {
  chamferSketchCorners,
  type ChamferCorner,
  chamferSketchLines,
  nearestSketchLine,
  type CornerLine,
  contourClosed,
  type SketchDrawing,
  type SketchPoint,
  type ChamferSize,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
interface Options {
  parent: HTMLElement;
  svg: SVGSVGElement;
  drawing: () => SketchDrawing;
  commit: (d: SketchDrawing) => void;
  report: (s: string) => void;
}
/** Chamfer controls own interaction only; Core owns geometry, dimensions and remapping. */
export function mountChamferPanel({
  parent,
  svg,
  drawing,
  commit,
  report,
}: Options) {
  const root = document.createElement("section");
  root.className = "sketch-modifications sketch-chamfer-controls";
  root.hidden = true;
  parent.append(root);
  const title = document.createElement("h3");
  title.textContent = "Chamfer";
  root.append(title);
  const hint = document.createElement("p");
  hint.textContent =
    "Click a straight corner or two lines. The first distance and angle follow the first selected line.";
  root.append(hint);
  const mode = document.createElement("select");
  mode.setAttribute("aria-label", "Chamfer mode");
  for (const [value, text] of [
    ["equal-distance", "Equal distance"],
    ["two-distances", "Two distances"],
    ["distance-angle", "Distance and angle"],
  ]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = text;
    mode.append(option);
  }
  root.append(mode);
  function number(name: string, value: number) {
    const label = document.createElement("label");
    label.textContent = name;
    const input = document.createElement("input");
    input.type = "number";
    input.step = "any";
    input.value = String(value);
    input.setAttribute("aria-label", name);
    label.append(input);
    root.append(label);
    input.oninput = preview;
    return { label, input };
  }
  const distance = number("Chamfer distance (mm)", 1),
    second = number("Second chamfer distance (mm)", 1),
    angle = number("Chamfer angle (degrees)", 45);
  const status = document.createElement("p");
  status.setAttribute("role", "status");
  root.append(status);
  const apply = document.createElement("button");
  apply.textContent = "Apply chamfer";
  root.append(apply);
  const cancel = document.createElement("button");
  cancel.textContent = "Cancel chamfer";
  root.append(cancel);
  let chosen: { contour: number; vertex: number } | undefined;
  let lines: CornerLine[] = [];
  let corners: ChamferCorner[] = [];
  const clear = () => svg.querySelector(".sketch-chamfer-preview")?.remove();
  function result() {
    if (!corners.length && lines.length !== 2)
      throw new Error(
        lines.length
          ? "First line selected. Select the second line."
          : "Select a straight corner or two lines.",
      );
    const value = Number(distance.input.value);
    if (!distance.input.value.trim())
      throw new Error("Enter a chamfer distance.");
    const size: ChamferSize =
      mode.value === "equal-distance"
        ? { mode: "equal-distance", distance: value }
        : mode.value === "two-distances"
          ? {
              mode: "two-distances",
              distance: value,
              secondDistance: Number(second.input.value),
            }
          : {
              mode: "distance-angle",
              distance: value,
              angleDegrees: Number(angle.input.value),
            };
    return lines.length === 2
      ? chamferSketchLines(drawing(), lines[0], lines[1], size)
      : chamferSketchCorners(drawing(), corners, size);
  }
  function preview() {
    clear();
    if (root.hidden) return;
    second.label.hidden = mode.value !== "two-distances";
    angle.label.hidden = mode.value !== "distance-angle";
    try {
      const next = result();
      const indices = corners.length
        ? [...new Set(corners.map((c) => c.contour))]
        : [Math.min(lines[0].contour, lines[1].contour)];
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.setAttribute("class", "sketch-chamfer-preview");
      group.setAttribute("aria-hidden", "true");
      for (const index of indices) {
        const path = next.contours[index];
        if (path.type === "path") {
          const shape = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "path",
          );
          shape.setAttribute("class", "sketch-preview");
          shape.setAttribute("d", contourPath(path));
          group.append(shape);
        }
      }
      svg.append(group);
      status.textContent =
        corners.length > 1
          ? `${corners.length} corners selected. Dimensions stay linked after Apply.`
          : "Preview only. Apply saves the chamfer.";
      apply.disabled = false;
    } catch (error) {
      status.textContent = (error as Error).message;
      apply.disabled = true;
    }
  }
  function close() {
    root.hidden = true;
    chosen = undefined;
    lines = [];
    corners = [];
    clear();
  }
  mode.onchange = preview;
  cancel.onclick = close;
  apply.onclick = () => {
    try {
      const next = result();
      close();
      commit(next);
      report("Sketch chamfer applied.");
    } catch (error) {
      status.textContent = (error as Error).message;
    }
  };
  return {
    close,
    refresh: preview,
    open() {
      root.hidden = false;
      chosen = undefined;
      lines = [];
      corners = [];
      preview();
    },
    pick(point: SketchPoint, tolerance: number) {
      if (root.hidden) return false;
      let best = tolerance;
      chosen = undefined;
      for (const [contour, path] of drawing().contours.entries()) {
        if (path.type !== "path") continue;
        for (
          let vertex = contourClosed(path) ? 0 : 1;
          vertex < path.segments.length;
          vertex++
        ) {
          const incoming = vertex === 0 ? path.segments.length - 1 : vertex - 1;
          if (
            path.segments[incoming].type !== "line" ||
            path.segments[vertex].type !== "line"
          )
            continue;
          const p = vertex === 0 ? path.start : path.segments[vertex - 1].end,
            dist = Math.hypot(p[0] - point[0], p[1] - point[1]);
          if (dist < best) {
            best = dist;
            chosen = { contour, vertex };
          }
        }
      }
      if (chosen) {
        lines = [];
        const corner = chosen;
        if (
          !corners.some(
            (c) => c.contour === corner.contour && c.vertex === corner.vertex,
          )
        )
          corners.push(corner);
      } else {
        try {
          const selected = nearestSketchLine(drawing(), point, tolerance);
          corners = [];
          if (lines.length === 2) lines = [];
          if (
            !lines.some(
              (line) =>
                line.contour === selected.contour &&
                line.segment === selected.segment,
            )
          )
            lines.push(selected);
        } catch (error) {
          status.textContent = (error as Error).message;
          return true;
        }
      }
      preview();
      return true;
    },
  };
}
