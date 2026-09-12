/** Extrude feature editor — window layout, controls, and serialization.
 *  Layout mirrors `core/ui/gallery/features/extrude.ts` exactly. */
import {
  bodyAndOperationTabs,
  entityChips,
  plannedCheckbox,
  planned,
  rowIn,
  textInput,
  unitSuffix,
  type Controls,
  type FeatureEditor,
  type FeatureEditorContext,
  requireSelections,
} from "./shared";

const operationValues = ["new", "add", "cut"] as const;

export const extrudeEditor: FeatureEditor = {
  type: "extrude",

  controls({ field, reference, feature, doc }: FeatureEditorContext): Controls {
    return {
      source: reference("Sketch", ["sketch", "profile"], feature?.profileFeatureId),
      operation: field(
        "Operation",
        feature?.operation ??
          (doc.features.some((f) => ["extrude", "revolve"].includes(f.type)) ? "add" : "new"),
        [...operationValues],
      ),
      distance: field("Distance (mm)", String(feature?.distanceMillimeters ?? 10)),
    };
  },

  layout({ win, form, lengthUnitLabel, angleUnitLabel }: FeatureEditorContext, controls: Controls) {
    // Onshape order: body type, boolean, selection, end type, then options.
    bodyAndOperationTabs(win, form, controls.operation, operationValues);
    entityChips(win, "Faces and sketch regions to extrude", controls.source, form);

    // End type drives which sub-settings exist — Blind wants a depth, the
    // "up to" types want a reference instead, Through all wants neither.
    // Only Blind evaluates today; the rest are the gallery's target shape.
    const endType = win.picker(
      ["Blind", "Symmetric", "Up to next", "Up to face", "Up to vertex", "Through all"],
      { ariaLabel: "End type", onChange: () => syncEndType() },
    );
    win.body.append(endType.element);

    controls.distance.closest("label")?.remove();
    controls.distance.setAttribute("form", form.id);
    const depth = win.row("Depth", controls.distance, unitSuffix(lengthUnitLabel));

    const upTo = win.entitiesBox("Up to entity");
    upTo.render([]);

    const draft = win.subsection("Draft", { kind: "checkbox" });
    draft.body.append(rowIn("Draft angle", planned(textInput("3")), unitSuffix(angleUnitLabel)));

    const direction = win.subsection("Direction", { kind: "disclosure" });
    direction.body.append(rowIn("Flip direction", plannedCheckbox()));
    direction.body.append(
      rowIn(
        "Direction reference",
        win.picker(["Normal to sketch", "Custom"], { ariaLabel: "Direction reference" }).element,
      ),
    );

    const startOffset = win.subsection("Starting offset", { kind: "checkbox" });
    startOffset.body.append(rowIn("Offset distance", planned(textInput("0")), unitSuffix(lengthUnitLabel)));
    startOffset.body.append(rowIn("Opposite direction", plannedCheckbox()));

    const secondEnd = win.subsection("Second end position", { kind: "checkbox" });
    secondEnd.body.append(
      rowIn(
        "Second end type",
        win.picker(["Blind", "Up to face", "Through all"], { ariaLabel: "Second end type" }).element,
      ),
    );
    secondEnd.body.append(rowIn("Second depth", planned(textInput("10")), unitSuffix(lengthUnitLabel)));

    function syncEndType() {
      const value = endType.value();
      depth.hidden = !(value === "Blind" || value === "Symmetric");
      upTo.element.hidden = !value.startsWith("Up to ") || value === "Up to next";
      // A symmetric extrude has no separate direction or second end.
      direction.element.hidden = value === "Symmetric";
      secondEnd.element.hidden = value === "Symmetric" || value === "Through all";
    }
    syncEndType();
  },

  validate(controls) {
    return requireSelections(controls, [{ key: "source", noun: "a sketch region to extrude" }]);
  },

  serialize(values) {
    return {
      profileFeatureId: values.source,
      operation: values.operation,
      distanceMillimeters: Number(values.distance),
    };
  },
};
