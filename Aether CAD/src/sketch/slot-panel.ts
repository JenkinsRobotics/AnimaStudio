import { mountSlotManipulator } from "./slot-manipulator";
import {
  slotSketchEntities,
  contourClosed,
  pickCurve,
  type SketchDrawing,
  type SketchPoint,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
interface Options {
  parent: HTMLElement;
  svg: SVGSVGElement;
  drawing: () => SketchDrawing;
  commit: (d: SketchDrawing) => void;
  report: (text: string) => void;
  finished: () => void;
}
/** Slot centerline selection and preview; Core owns geometry and width relations. */
export function mountSlotPanel({
  parent,
  svg,
  drawing,
  commit,
  report,
  finished,
}: Options) {
  const root = document.createElement("section");
  root.hidden = true;
  root.className = "sketch-slot-panel";
  parent.append(root);
  const heading = document.createElement("h3");
  heading.textContent = "Slot";
  root.append(heading);
  const mode = document.createElement("select");
  mode.setAttribute("aria-label", "Slot selection");
  for (const [value, text] of [
    ["edges", "Individual edges"],
    ["chains", "Line/arc chains"],
  ]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = text;
    mode.append(option);
  }
  root.append(mode);
  const select = document.createElement("select");
  select.multiple = true;
  select.size = 4;
  select.setAttribute("aria-label", "Slot centerlines");
  root.append(select);
  const label = document.createElement("label");
  label.textContent = "Slot width (mm)";
  const input = document.createElement("input");
  input.type = "number";
  input.step = "any";
  input.min = "0";
  input.setAttribute("aria-label", "Slot width (mm)");
  label.append(input);
  root.append(label);
  const hint = document.createElement("p");
  hint.textContent =
    "Select line/arc edges, circular centerlines or open/closed chains. Slots share one width. Selected chains and standalone centerlines become construction geometry. Smooth chain joins retain tangency.";
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
  const apply = button("Apply slot", () => {
    try {
      const next = result();
      close();
      commit(next);
      finished();
      report("Slot created.");
    } catch (e) {
      errors.textContent = (e as Error).message;
    }
  });
  button("Cancel slot", () => {
    close();
    finished();
  });
  const manipulator = mountSlotManipulator(
    svg,
    (value) => {
      input.value = String(value);
      preview();
    },
    (text) => {
      errors.textContent = text;
    },
  );
  let active = false;
  const clear = () => {
    svg.querySelector(".sketch-slot-preview")?.remove();
    svg.querySelector(".sketch-slot-handle")?.remove();
  };
  function result() {
    if (!input.value.trim()) throw Error("Enter slot width.");
    return slotSketchEntities(
      drawing(),
      [...select.selectedOptions].map((o) => JSON.parse(o.value)),
      Number(input.value),
    );
  }
  function preview() {
    clear();
    if (!active) return;
    try {
      const next = result();
      errors.textContent = "";
      apply.disabled = false;
      const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
      g.classList.add("sketch-slot-preview");
      g.setAttribute("aria-hidden", "true");
      svg.append(g);
      for (const c of next.contours.slice(drawing().contours.length)) {
        const path = document.createElementNS(
          "http://www.w3.org/2000/svg",
          c.type === "circle" ? "circle" : "path",
        );
        path.classList.add("sketch-preview");
        if (c.type === "circle") {
          path.setAttribute("cx", String(c.center[0]));
          path.setAttribute("cy", String(-c.center[1]));
          path.setAttribute("r", String(c.radius));
          path.style.fill = "none";
        } else path.setAttribute("d", contourPath(c));
        g.append(path);
      }
      const old = new Set(drawing().constraints?.map((c) => c.id));
      const dimension = next.constraints?.find(
        (c) => c.kind === "slot" && !old.has(c.id),
      );
      if (dimension) manipulator.render(next, dimension.id);
    } catch (e) {
      apply.disabled = true;
      errors.textContent = (e as Error).message;
    }
  }
  function close() {
    active = false;
    root.hidden = true;
    manipulator.close();
    clear();
  }
  function populate() {
    select.replaceChildren();
    drawing().contours.forEach((c, contour) => {
      if (mode.value === "chains") {
        if (
          c.type === "path" &&
          c.segments.length &&
          c.segments.every((s) => s.type === "line" || s.type === "arc")
        ) {
          const o = document.createElement("option");
          o.value = JSON.stringify({ contour, kind: "contour" });
          o.textContent = `${contour + 1}: ${contourClosed(c) ? "closed" : "open"} chain`;
          select.append(o);
        }
        return;
      }
      if (c.type === "circle") {
        const o = document.createElement("option");
        o.value = JSON.stringify({ contour, kind: "circle" });
        o.textContent = `${contour + 1}: circular centerline`;
        select.append(o);
      }
      if (c.type === "path")
        c.segments.forEach((s, index) => {
          if (s.type === "line" || s.type === "arc") {
            const o = document.createElement("option");
            o.value = JSON.stringify({ contour, kind: s.type, index });
            o.textContent = `${contour + 1}: ${s.type} ${index + 1}`;
            select.append(o);
          }
        });
    });
  }
  mode.onchange = () => {
    populate();
    preview();
  };
  select.onchange = preview;
  input.oninput = preview;
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
      input.value = "2";
      mode.value = "edges";
      populate();
      preview();
    },
    pick(point: SketchPoint, tolerance: number) {
      if (!active) return false;
      try {
        const hit = pickCurve(drawing(), point, tolerance),
          c = drawing().contours[hit.contour];
        if (
          hit.point ||
          (!hit.circle &&
            (c.type !== "path" ||
              !["line", "arc"].includes(c.segments[hit.segment].type)))
        )
          throw Error("Select a line, circular arc or circle.");
        const ref: SketchEntityRef = hit.circle
          ? { contour: hit.contour, kind: "circle" }
          : mode.value === "chains"
            ? { contour: hit.contour, kind: "contour" }
            : {
                contour: hit.contour,
                kind: (c.type === "path"
                  ? c.segments[hit.segment].type
                  : "circle") as "line" | "arc",
                index: hit.segment,
              };
        const option = [...select.options].find(
          (o) => o.value === JSON.stringify(ref),
        );
        if (!option)
          throw Error(
            "Select a chain containing only lines and circular arcs.",
          );
        option.selected = !option.selected;
        preview();
      } catch (e) {
        errors.textContent = (e as Error).message;
      }
      return true;
    },
  };
}
