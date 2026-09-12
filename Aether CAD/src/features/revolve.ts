/** Revolve feature editor — window layout, controls, and serialization.
 *  Layout mirrors `core/ui/gallery/features/revolve.ts`: body/boolean tabs, a
 *  regions box, an axis box, then the Full-revolve toggle. */
import {
  bodyAndOperationTabs,
  entityChips,
  type Controls,
  type FeatureEditor,
  type FeatureEditorContext,
  requireSelections,
} from "./shared";

const operationValues = ["new", "add", "cut"] as const;

export const revolveEditor: FeatureEditor = {
  type: "revolve",

  controls({ field, reference, feature, doc }: FeatureEditorContext): Controls {
    return {
      source: reference("Sketch", ["sketch", "profile"], feature?.profileFeatureId),
      operation: field(
        "Operation",
        feature?.operation ??
          (doc.features.some((f) => ["extrude", "revolve"].includes(f.type)) ? "add" : "new"),
        [...operationValues],
      ),
      axis: field("Axis", feature?.axis ?? "Z", ["X", "Y", "Z"]),
      angle: field("Angle (degrees)", String(feature?.angleDegrees ?? 360)),
    };
  },

  layout({ win, form }: FeatureEditorContext, controls: Controls) {
    bodyAndOperationTabs(win, form, controls.operation, operationValues);
    entityChips(win, "Faces and sketch regions to revolve", controls.source, form);

    // The gallery shows the axis as its own entity box; this engine picks the
    // axis from a principal-axis list, so it is a row in the same position.
    controls.axis.closest("label")?.remove();
    controls.axis.setAttribute("form", form.id);
    win.row("Revolve axis", controls.axis);

    const full = document.createElement("input");
    full.type = "checkbox";
    full.setAttribute("aria-label", "Full revolve");
    win.row("Full revolve", full);

    controls.angle.closest("label")?.remove();
    controls.angle.setAttribute("form", form.id);
    const angleRow = win.row("Angle", controls.angle);
    full.checked = Math.abs(Number(controls.angle.value) - 360) < 1e-9;
    angleRow.hidden = full.checked;
    full.onchange = () => {
      angleRow.hidden = full.checked;
      if (full.checked) controls.angle.value = "360";
    };
  },

  validate(controls) {
    return requireSelections(controls, [
      { key: "source", noun: "a sketch region to revolve" },
      { key: "axis", noun: "a revolve axis" },
    ]);
  },

  serialize(values) {
    return {
      profileFeatureId: values.source,
      operation: values.operation,
      axis: values.axis,
      angleDegrees: Number(values.angle),
    };
  },
};
