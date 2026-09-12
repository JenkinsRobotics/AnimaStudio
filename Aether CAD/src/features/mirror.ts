/** Mirror feature editor — controls and serialization. The gallery has no
 *  mirror demo; layout follows the same anatomy: selection first, then the
 *  mirror plane and its offset. */
import {
  entityChips,
  requireSelections,
  type Controls,
  type FeatureEditor,
  type FeatureEditorContext,
} from "./shared";

export const mirrorEditor: FeatureEditor = {
  type: "mirror",

  controls({ field, reference, feature }: FeatureEditorContext): Controls {
    return {
      source: reference("Feature", ["extrude", "revolve", "mirror"], feature?.sourceFeatureId),
      plane: field("Mirror plane", feature?.plane ?? "YZ", ["XY", "XZ", "YZ"]),
      offset: field("Plane offset (mm)", String(feature?.offsetMillimeters ?? 0)),
      operation: field("Operation", feature?.operation ?? "add", ["add", "cut"]),
    };
  },

  layout({ win, form }: FeatureEditorContext, controls: Controls) {
    entityChips(win, "Features to mirror", controls.source, form);
  },

  validate(controls) {
    return requireSelections(controls, [
      { key: "source", noun: "a feature to mirror" },
      { key: "plane", noun: "a mirror plane" },
    ]);
  },

  serialize(values) {
    return {
      sourceFeatureId: values.source,
      plane: values.plane,
      offsetMillimeters: Number(values.offset),
      operation: values.operation,
    };
  },
};
