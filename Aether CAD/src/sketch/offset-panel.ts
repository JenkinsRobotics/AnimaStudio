import {
  offsetSketch,
  offsetSketchEntities,
  pickCurve,
  type SketchDrawing,
  type SketchPoint,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
import { mountOffsetManipulator } from "./offset-manipulator";
interface Options {
  parent: HTMLElement;
  svg: SVGSVGElement;
  drawing: () => SketchDrawing;
  commit: (d: SketchDrawing) => void;
  report: (text: string) => void;
  finished: () => void;
}
/** Offset selection/preview lifecycle; all geometry and relationships remain in Core. */
export function mountOffsetPanel({
  parent,
  svg,
  drawing,
  commit,
  report,
  finished,
}: Options) {
  const root = document.createElement("section");
  root.className = "sketch-offset-panel";
  root.hidden = true;
  parent.append(root);
  const title = document.createElement("h3");
  title.textContent = "Offset";
  root.append(title);
  const mode = document.createElement("select");
  mode.setAttribute("aria-label", "Offset selection");
  for (const [value, label] of [
    ["contours", "Whole contours"],
    ["edges", "Individual edges"],
  ]) {
    const o = document.createElement("option");
    o.value = value;
    o.textContent = label;
    mode.append(o);
  }
  root.append(mode);
  const selection = document.createElement("select");
  selection.multiple = true;
  selection.size = 4;
  selection.setAttribute("aria-label", "Offset entities");
  root.append(selection);
  const label = document.createElement("label");
  label.textContent = "Offset distance (mm)";
  const input = document.createElement("input");
  input.type = "number";
  input.step = "any";
  input.setAttribute("aria-label", "Offset distance (mm)");
  label.append(input);
  root.append(label);
  const hint = document.createElement("p");
  hint.textContent =
    "Click a curve to select individual edges, or choose whole contours. Positive is left of paths and outward for circles. Selected offsets retain a shared distance and follow source edits.";
  root.append(hint);
  const errors = document.createElement("p");
  errors.setAttribute("role", "status");
  root.append(errors);
  const button = (text: string, run: () => void) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.onclick = run;
    root.append(b);
    return b;
  };
  button("Flip direction", () => {
    input.value = String(-Number(input.value));
    preview();
  });
  const apply = button("Apply modification", () => {
    try {
      const next = result();
      close();
      commit(next);
      finished();
      report("Sketch offset applied.");
    } catch (e) {
      errors.textContent = (e as Error).message;
    }
  });
  button("Cancel modification", () => {
    close();
    finished();
  });
  const manipulator = mountOffsetManipulator(
    svg,
    (v) => {
      input.value = String(v);
      preview();
    },
    (text) => {
      errors.textContent = text;
    },
  );
  let active = false;
  const clear = () => {
    svg.querySelector(".sketch-modification-preview")?.remove();
    svg.querySelector(".sketch-offset-handle")?.remove();
  };
  function result() {
    if (!input.value.trim()) throw Error("Enter an offset distance.");
    const values = [...selection.selectedOptions].map((o) => o.value);
    return mode.value === "edges"
      ? offsetSketchEntities(
          drawing(),
          values.map((v) => JSON.parse(v) as SketchEntityRef),
          Number(input.value),
        )
      : offsetSketch(drawing(), values.map(Number), Number(input.value));
  }
  function preview() {
    clear();
    if (!active) return;
    try {
      const before = drawing(),
        next = result();
      errors.textContent = "";
      apply.disabled = false;
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.classList.add("sketch-modification-preview");
      group.setAttribute("aria-hidden", "true");
      svg.append(group);
      for (const c of next.contours.slice(before.contours.length)) {
        const shape = document.createElementNS(
          "http://www.w3.org/2000/svg",
          c.type === "circle" ? "circle" : "path",
        );
        shape.classList.add("sketch-preview");
        if (c.type === "circle") {
          shape.setAttribute("cx", String(c.center[0]));
          shape.setAttribute("cy", String(-c.center[1]));
          shape.setAttribute("r", String(c.radius));
        } else shape.setAttribute("d", contourPath(c));
        group.append(shape);
      }
      const old = new Set(before.constraints?.map((c) => c.id));
      const dimension = next.constraints?.find(
        (c) => c.kind === "offset" && !old.has(c.id),
      );
      if (dimension) manipulator.render(next, dimension.id);
    } catch (e) {
      apply.disabled = true;
      errors.textContent = (e as Error).message;
    }
  }
  function populate() {
    selection.replaceChildren();
    const option = (value: string, text: string, selected = false) => {
      const o = document.createElement("option");
      o.value = value;
      o.textContent = text;
      o.selected = selected;
      selection.append(o);
    };
    drawing().contours.forEach((c, contour) => {
      if (mode.value === "contours")
        option(
          String(contour),
          `${contour + 1}. ${c.type}`,
          !c.construction && (c.type === "circle" || c.segments.length > 0),
        );
      else if (c.type === "circle")
        option(
          JSON.stringify({ contour, kind: "circle" }),
          `${contour + 1}: Circle`,
        );
      else
        c.segments.forEach((s, index) => {
          if (s.type === "line" || s.type === "arc")
            option(
              JSON.stringify({ contour, kind: s.type, index }),
              `${contour + 1}: ${s.type} ${index + 1}`,
            );
        });
    });
  }
  function close() {
    active = false;
    root.hidden = true;
    clear();
    manipulator.close();
  }
  input.oninput = preview;
  selection.onchange = preview;
  mode.onchange = () => {
    populate();
    preview();
  };
  input.onkeydown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      e.stopPropagation();
      if (!apply.disabled) apply.click();
    }
  };
  return {
    close,
    open() {
      active = true;
      root.hidden = false;
      mode.value = "contours";
      input.value = "1";
      populate();
      preview();
    },
    pick(point: SketchPoint, tolerance: number) {
      if (!active) return false;
      try {
        const hit = pickCurve(drawing(), point, tolerance),
          c = drawing().contours[hit.contour];
        let ref: SketchEntityRef;
        if (hit.circle) ref = { contour: hit.contour, kind: "circle" };
        else if (
          !hit.point &&
          c.type === "path" &&
          (c.segments[hit.segment].type === "line" ||
            c.segments[hit.segment].type === "arc")
        )
          ref = {
            contour: hit.contour,
            kind: c.segments[hit.segment].type as "line" | "arc",
            index: hit.segment,
          };
        else throw Error("Select a line, circular arc or circle.");
        if (mode.value !== "edges") {
          mode.value = "edges";
          populate();
        }
        const option = [...selection.options].find(
          (o) => o.value === JSON.stringify(ref),
        );
        if (option) option.selected = !option.selected;
        preview();
      } catch (e) {
        errors.textContent = (e as Error).message;
      }
      return true;
    },
  };
}
