import { mountModificationSourceControl } from "./source-control";
import { mountMirrorAxisControl } from "./mirror-axis-control";
import { mountSlotPanel } from "./slot-panel";
import { mountOffsetPanel } from "./offset-panel";
import { mountChamferPanel } from "./chamfer-panel";
import { pickSketchEntity } from "./picking";
import { mountFilletManipulator } from "./fillet-manipulator";
import {
  editFilletRadius,
  findFilletRadiusDimension,
  dimensionValue,
  filletSketchCorners,
  filletSketchCurves,
  pickCurve,
  type FilletLine,
  type FilletCorner,
  circularPattern,
  linearPattern,
  mirrorSketch,
  mirrorSketchEntities,
  moveSketchContours,
  copySketchContours,
  similarityTransform,
  contourClosed,
  type SketchEntityRef,
  type SketchPoint,
  type SketchDrawing,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
import { type ModificationTool } from "./tool-instructions";
interface Options {
  parent: HTMLElement;
  svg: SVGSVGElement;
  drawing: () => SketchDrawing;
  commit: (next: SketchDrawing) => void;
  report: (message: string) => void;
  finished: () => void;
}
/** Owns only modification controls and preview. Core owns the actual operation. */
export function mountModificationPanel({
  parent,
  svg,
  drawing,
  commit,
  report,
  finished,
}: Options) {
  const root = document.createElement("section");
  root.className = "sketch-modifications";
  root.hidden = true;
  parent.append(root);
  const chamfer = mountChamferPanel({ parent, svg, drawing, commit, report });
  const offset = mountOffsetPanel({
    parent,
    svg,
    drawing,
    commit,
    report,
    finished,
  });
  const slot = mountSlotPanel({
    parent,
    svg,
    drawing,
    commit,
    report,
    finished,
  });
  const title = document.createElement("h3");
  root.append(title);
  const label = document.createElement("label");
  label.textContent = "Contours";
  const selection = document.createElement("select");
  selection.multiple = true;
  selection.size = 4;
  selection.setAttribute("aria-label", "Modification contours");
  label.append(selection);
  root.append(label);
  let copyTransform: HTMLInputElement | undefined;
  const hint = document.createElement("p");
  hint.textContent =
    "Copies are independent geometry. Original constraints remain unchanged.";
  root.append(hint);
  const fields = document.createElement("div");
  root.append(fields);
  const errors = document.createElement("p");
  errors.setAttribute("role", "status");
  root.append(errors);
  const apply = document.createElement("button");
  apply.type = "button";
  apply.textContent = "Apply modification";
  root.append(apply);
  const cancel = document.createElement("button");
  cancel.type = "button";
  cancel.textContent = "Cancel modification";
  root.append(cancel);
  let sourceSelection:
    ReturnType<typeof mountModificationSourceControl> | undefined;
  let liveMirrorAxis: (() => SketchEntityRef | undefined) | undefined;
  let active: ModificationTool | null = null;
  let editingRadius: string | undefined;
  let corners: FilletCorner[] = [];
  let lines: FilletLine[] = [];
  const inputs = new Map<string, HTMLInputElement>();
  const number = (name: string, value: number) => {
    const label = document.createElement("label");
    label.textContent = name;
    const input = document.createElement("input");
    input.type = "number";
    input.step = "any";
    input.value = String(value);
    input.setAttribute("aria-label", name);
    input.oninput = () => {
      if (name === "Corner vertex") {
        corners = [];
        lines = [];
        editingRadius = undefined;
      }
      preview();
    };
    inputs.set(name, input);
    label.append(input);
    fields.append(label);
  };
  const manipulator = mountFilletManipulator(
    svg,
    (radius) => {
      const input = inputs.get("Fillet radius (mm)");
      if (input) {
        input.value = String(radius);
        preview();
      }
    },
    (text) => {
      errors.textContent = text;
    },
  );
  const n = (name: string) => {
    const value = inputs.get(name)?.value ?? "";
    if (!value.trim()) throw new Error(`Enter ${name}.`);
    return Number(value);
  };
  const chosen = () =>
    [...selection.selectedOptions].map((o) => Number(o.value));
  const result = () => {
    const d = drawing(),
      indices = chosen();
    if (active === "fillet") {
      if (editingRadius)
        return editFilletRadius(d, editingRadius, n("Fillet radius (mm)"));
      if (lines.length) {
        if (lines.length !== 2) throw new Error("Select the second curve.");
        return filletSketchCurves(
          d,
          lines[0],
          lines[1],
          n("Fillet radius (mm)"),
        );
      }
      if (!corners.length && indices.length !== 1)
        throw new Error("Choose one path contour or click corners.");
      return filletSketchCorners(
        d,
        corners.length
          ? corners
          : [{ contour: indices[0], vertex: n("Corner vertex") }],
        n("Fillet radius (mm)"),
      );
    }
    if (active === "mirror" && sourceSelection?.selected())
      return mirrorSketchEntities(
        d,
        sourceSelection.selected()!,
        [n("Axis start X (mm)"), n("Axis start Y (mm)")],
        [n("Axis end X (mm)"), n("Axis end Y (mm)")],
        liveMirrorAxis?.(),
      );
    if (active === "mirror")
      return mirrorSketch(
        d,
        indices,
        [n("Axis start X (mm)"), n("Axis start Y (mm)")],
        [n("Axis end X (mm)"), n("Axis end Y (mm)")],
        liveMirrorAxis?.(),
      );
    if (active === "linear-pattern")
      return linearPattern(
        d,
        sourceSelection?.selected() ?? indices,
        [n("Spacing X (mm)"), n("Spacing Y (mm)")],
        n("Count"),
        [n("Second spacing X (mm)"), n("Second spacing Y (mm)")],
        n("Second count"),
      );
    if (active === "circular-pattern")
      return circularPattern(
        d,
        sourceSelection?.selected() ?? indices,
        [n("Center X (mm)"), n("Center Y (mm)")],
        n("Count"),
        n("Step angle (degrees)"),
      );
    if (active === "transform") {
      const transform = similarityTransform(
        [n("Center X (mm)"), n("Center Y (mm)")],
        [n("Move X (mm)"), n("Move Y (mm)")],
        n("Rotation (degrees)"), n("Scale"));
      return copyTransform?.checked ? copySketchContours(d, indices, [transform]) : moveSketchContours(d, indices, transform);
    }
    throw new Error("Choose a modification tool.");
  };
  const clearPreview = () =>
    svg.querySelector(".sketch-modification-preview")?.remove();
  function preview() {
    clearPreview();
    if (
      active === "mirror" ||
      active === "linear-pattern" ||
      active === "circular-pattern"
    )
      sourceSelection?.render();
    svg.querySelector(".sketch-fillet-handle")?.remove();
    svg.querySelector(".sketch-offset-handle")?.remove();
    if (!active) return;
    try {
      const next = result();
      errors.textContent = "";
      apply.disabled = false;
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.setAttribute("class", "sketch-modification-preview");
      group.setAttribute("aria-hidden", "true");
      svg.append(group);
      const contours = editingRadius
        ? next.contours
        : active === "fillet" && lines.length === 2
          ? [next.contours[Math.min(lines[0].contour, lines[1].contour)]]
          : (active === "transform" && !copyTransform?.checked) || active === "fillet"
            ? chosen().map((i) => next.contours[i])
            : next.contours.slice(drawing().contours.length);
      for (const c of contours) {
        const shape = document.createElementNS(
          "http://www.w3.org/2000/svg",
          c.type === "circle" ? "circle" : "path",
        );
        shape.setAttribute("class", "sketch-preview");
        if (c.type === "circle") {
          shape.setAttribute("cx", String(c.center[0]));
          shape.setAttribute("cy", String(-c.center[1]));
          shape.setAttribute("r", String(c.radius));
        } else shape.setAttribute("d", contourPath(c));
        group.append(shape);
      }
      if (active === "fillet") {
        const original = new Set(drawing().constraints?.map((c) => c.id));
        const dimension = next.constraints?.find(
          (c) =>
            c.kind === "radius" &&
            (editingRadius ? c.id === editingRadius : !original.has(c.id)),
        );
        if (dimension) manipulator.render(next, dimension.id);
      }
    } catch (error) {
      apply.disabled = true;
      errors.textContent = (error as Error).message;
    }
  }
  function close() {
    sourceSelection?.dispose();
    sourceSelection = undefined;
    chamfer.close();
    manipulator.close();
    offset.close();
    slot.close();
    active = null;
    root.hidden = true;
    clearPreview();
  }
  selection.onchange = () => {
    corners = [];
    lines = [];
    editingRadius = undefined;
    preview();
  };
  cancel.onclick = () => {
    close();
    finished();
  };
  apply.onclick = () => {
    try {
      const next = result();
      close();
      commit(next);
      finished();
      report("Sketch modification applied.");
    } catch (error) {
      errors.textContent = (error as Error).message;
    }
  };
  return {
    close,
    pickCorner(point: SketchPoint, tolerance: number) {
      if (slot.pick(point, tolerance)) return true;
      if (offset.pick(point, tolerance)) return true;
      if (chamfer.pick(point, tolerance)) return true;
      if (
        active === "mirror" ||
        active === "linear-pattern" ||
        active === "circular-pattern"
      )
        return sourceSelection?.pick(point, tolerance) ?? true;
      if (active !== "fillet") return false;
      const picked = pickSketchEntity(drawing(), point);
      const dimension =
        picked && picked.d < tolerance
          ? findFilletRadiusDimension(drawing(), picked.ref)
          : undefined;
      if (dimension) {
        editingRadius = dimension;
        corners = [];
        lines = [];
        inputs.get("Fillet radius (mm)")!.value = String(
          dimensionValue(drawing(), drawing().constraints!.find((c) => c.id === dimension)!),
        );
        hint.textContent =
          "Editing an existing fillet radius. Linked fillets update together. Apply saves the change.";
        preview();
        return true;
      }
      editingRadius = undefined;
      let best = tolerance,
        chosenContour = -1,
        chosenVertex = -1;
      drawing().contours.forEach((c, contour) => {
        if (c.type !== "path") return;
        for (
          let vertex = contourClosed(c) ? 0 : 1;
          vertex < c.segments.length;
          vertex++
        ) {
          const p = vertex === 0 ? c.start : c.segments[vertex - 1].end;
          const distance = Math.hypot(p[0] - point[0], p[1] - point[1]);
          if (distance < best) {
            best = distance;
            chosenContour = contour;
            chosenVertex = vertex;
          }
        }
      });
      if (chosenContour < 0) {
        try {
          const selected = pickCurve(drawing(), point, tolerance);
          if (selected.circle || selected.point)
            throw new Error("Select a finite sketch curve.");
          if (lines.length === 2) lines = [];
          if (
            !lines.some(
              (l) =>
                l.contour === selected.contour &&
                l.segment === selected.segment,
            )
          )
            lines.push({
              contour: selected.contour,
              segment: selected.segment,
              parameter: selected.parameter,
            });
          corners = [];
          hint.textContent =
            lines.length === 1
              ? "First curve selected. Click the second curve; pick the side to keep."
              : "Two curves selected. Adjust the fillet radius and Apply.";
          preview();
        } catch (error) {
          report((error as Error).message);
        }
        return true;
      }
      lines = [];
      if (
        !corners.some(
          (c) => c.contour === chosenContour && c.vertex === chosenVertex,
        )
      )
        corners.push({ contour: chosenContour, vertex: chosenVertex });
      for (const option of selection.options)
        option.selected = corners.some(
          (c) => c.contour === Number(option.value),
        );
      hint.textContent = `${corners.length} corner${corners.length === 1 ? "" : "s"} selected. One radius controls the batch. Click more corners to include them.`;
      inputs.get("Corner vertex")!.value = String(chosenVertex);
      preview();
      return true;
    },
    refresh() {
      preview();
      chamfer.refresh();
    },
    open(tool: ModificationTool) {
      close();
      if (tool === "chamfer") return chamfer.open();
      if (tool === "offset") return offset.open();
      if (tool === "slot") return slot.open();
      active = tool;
      liveMirrorAxis = undefined;
      sourceSelection = undefined;
      editingRadius = undefined;
      corners = [];
      lines = [];
      root.hidden = false;
      title.textContent = tool.replaceAll("-", " ");
      fields.replaceChildren();
      copyTransform = undefined;
      inputs.clear();
      selection.replaceChildren();
      drawing().contours.forEach((c, i) => {
        const option = document.createElement("option");
        option.value = String(i);
        option.textContent = `${i + 1}. ${c.type}`;
        option.selected = tool !== "fillet" || i === 0;
        selection.append(option);
      });
      hint.hidden = tool === "transform";
      hint.textContent =
        tool === "fillet"
          ? "Click a corner in the sketch, then set its radius. A construction point preserves the original sharp corner."
          : tool === "linear-pattern" || tool === "circular-pattern"
            ? "Pattern instances stay linked to their source geometry. Remove an instance’s pattern constraint to detach it."
            : "Mirrored geometry stays linked. Choose a live sketch line or a fixed numeric axis. Exclude the axis contour in contour mode, or only the axis itself in edge mode.";
      if (tool === "fillet") {
        number("Corner vertex", 1);
        number("Fillet radius (mm)", 1);
      }
      if (tool === "mirror") {
        number("Axis start X (mm)", 0);
        number("Axis start Y (mm)", 0);
        number("Axis end X (mm)", 0);
        number("Axis end Y (mm)", 10);
        liveMirrorAxis = mountMirrorAxisControl(fields, drawing(), () => {
          const axis = liveMirrorAxis?.();
          for (const [name, input] of inputs)
            if (name.startsWith("Axis ")) input.disabled = !!axis;
          sourceSelection?.syncAxis();
          preview();
        });
        sourceSelection = mountModificationSourceControl(
          fields,
          svg,
          selection,
          drawing,
          () => liveMirrorAxis?.(),
          preview,
        );
      }
      if (tool === "linear-pattern") {
        number("Spacing X (mm)", 20);
        number("Spacing Y (mm)", 0);
        number("Count", 3);
        number("Second spacing X (mm)", 0);
        number("Second spacing Y (mm)", 20);
        number("Second count", 1);
      }
      if (tool === "circular-pattern" || tool === "transform") {
        number("Center X (mm)", 0);
        number("Center Y (mm)", 0);
      }
      if (tool === "circular-pattern") {
        number("Count", 4);
        number("Step angle (degrees)", 90);
      }
      if (tool === "transform") {
        const row = document.createElement("label");
        copyTransform = document.createElement("input");
        copyTransform.type = "checkbox";
        copyTransform.setAttribute("aria-label", "Copy selected geometry");
        copyTransform.onchange = () => {
          hint.hidden = !copyTransform?.checked;
          hint.textContent = "Copies retain compatible internal constraints. Relations to unselected geometry and unsupported axis directions are omitted.";
          preview();
        };
        row.append(copyTransform, "Copy selected geometry with internal constraints");
        fields.append(row);

        number("Move X (mm)", 10);
        number("Move Y (mm)", 0);
        number("Rotation (degrees)", 0);
        number("Scale", 1);
      }
      if (tool === "linear-pattern" || tool === "circular-pattern")
        sourceSelection = mountModificationSourceControl(
          fields,
          svg,
          selection,
          drawing,
          () => undefined,
          preview,
          "Pattern individual edges",
        );
      preview();
      root.scrollIntoView?.({ block: "nearest" });
    },
  };
}
