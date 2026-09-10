import {
  editMirrorAxis,
  mirrorAxisConflicts,
  mirrorAxisPoints,
  sketchEntities,
  type DrawingConstraint,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Saved relation editor commits once; cancelled field edits never touch the drawing. */
export function mountMirrorRelationEditor(
  parent: HTMLElement,
  getDrawing: () => SketchDrawing,
  relation: DrawingConstraint,
  commit: (d: SketchDrawing) => void,
  report: (s: string) => void,
) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = "Edit mirror axis";
  parent.append(button);
  button.onclick = () => {
    try {
      if (parent.querySelector(".sketch-mirror-relation-editor")) return;
      const d = getDrawing(),
        current = d.constraints?.find((c) => c.id === relation.id);
      if (!current) throw Error("Mirror relation no longer exists.");
      const points = mirrorAxisPoints(d, current),
        section = document.createElement("section");
      section.className = "sketch-mirror-relation-editor";
      section.setAttribute("aria-label", "Edit mirror axis");
      parent.append(section);
      const axis = document.createElement("select");
      axis.setAttribute("aria-label", "Saved mirror axis");
      const fixed = document.createElement("option");
      fixed.value = "";
      fixed.textContent = "Fixed coordinates";
      axis.append(fixed);
      for (const e of sketchEntities(d).filter(
        (e) =>
          e.ref.kind === "line" &&
          !mirrorAxisConflicts(current.a, e.ref, current.b?.contour, d),
      )) {
        const o = document.createElement("option");
        o.value = JSON.stringify(e.ref);
        o.textContent = e.label;
        axis.append(o);
        if (
          current.axis &&
          mirrorAxisConflicts(current.axis, e.ref, undefined, d)
        )
          o.selected = true;
      }
      section.append(axis);
      const inputs = points.flatMap((p, i) =>
        p.map((v, k) => {
          const label = document.createElement("label"),
            input = document.createElement("input");
          const name = `Mirror ${i ? "end" : "start"} ${k ? "Y" : "X"} (mm)`;
          label.textContent = name;
          input.setAttribute("aria-label", name);
          input.type = "number";
          input.step = "any";
          input.value = String(v);
          label.append(input);
          section.append(label);
          return input;
        }),
      );
      const refresh = () =>
        inputs.forEach((input) => (input.disabled = !!axis.value));
      axis.onchange = refresh;
      refresh();
      const save = document.createElement("button");
      save.type = "button";
      save.textContent = "Update mirror axis";
      save.onclick = () => {
        try {
          if (axis.value)
            commit(
              editMirrorAxis(getDrawing(), relation.id, {
                axis: JSON.parse(axis.value),
              }),
            );
          else {
            if (
              inputs.some(
                (input) =>
                  !input.value.trim() || !Number.isFinite(Number(input.value)),
              )
            )
              throw Error("Enter finite mirror-axis coordinates.");
            const v = inputs.map((i) => Number(i.value));
            commit(
              editMirrorAxis(getDrawing(), relation.id, {
                start: [v[0], v[1]],
                end: [v[2], v[3]],
              }),
            );
          }
        } catch (error) {
          report((error as Error).message);
        }
      };
      const cancel = document.createElement("button");
      cancel.type = "button";
      cancel.textContent = "Cancel axis edit";
      cancel.onclick = () => section.remove();
      section.append(save, cancel);
      axis.focus();
    } catch (error) {
      report((error as Error).message);
    }
  };
}
