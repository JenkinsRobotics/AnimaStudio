/** Fillet and chamfer share one editor: both are edge finishes differing only
 *  in name and in how Core evaluates them. One definition, two registrations —
 *  a second file would be the same 30 lines with a different string. */
import type { Controls, FeatureEditor, FeatureEditorContext } from "./shared";

const edgeFinishEditor = (type: "fillet" | "chamfer"): FeatureEditor => ({
  type,

  controls({ field, feature }: FeatureEditorContext): Controls {
    return {
      radius: field("All-edge size (mm)", String(feature?.radiusMillimeters ?? 0.5)),
      edgeScope: field("Edges", feature?.edgePlane ? "plane" : "all", ["all", "plane"]),
      edgePlane: field("Edge plane", feature?.edgePlane?.plane ?? "XY", ["XY", "XZ", "YZ"]),
      edgeOffset: field(
        "Edge plane offset (mm)",
        String(feature?.edgePlane?.offsetMillimeters ?? 0),
      ),
    };
  },

  serialize(values) {
    return {
      radiusMillimeters: Number(values.radius),
      // Scoping to a plane is optional; "all" leaves the field off entirely so
      // the stored feature stays the shape Core validates.
      ...(values.edgeScope === "plane"
        ? {
            edgePlane: {
              plane: values.edgePlane,
              offsetMillimeters: Number(values.edgeOffset),
            },
          }
        : {}),
    };
  },
});

export const filletEditor = edgeFinishEditor("fillet");
export const chamferEditor = edgeFinishEditor("chamfer");
