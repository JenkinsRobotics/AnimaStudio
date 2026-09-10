import {
  referenceProfileContour,
  identifyProfileContours,
  resolveProfileDrawing,
  type PartDocument,
} from "@aether/core/document";

/** Selector values are indices into the immutable editing snapshot; persisted
 * references are stable contour IDs, never these temporary menu indices. */
export function populateProjectionGeometry(
  select: HTMLSelectElement,
  source: PartDocument,
  featureId: string,
  selectedId?: string,
) {
  select.replaceChildren();
  const option = (value: string, label: string, disabled = false) => {
    const o = document.createElement("option");
    o.value = value;
    o.textContent = label;
    o.disabled = disabled;
    select.append(o);
  };
  option("all", "Entire sketch");
  let selected = "all";
  try {
    const drawing = resolveProfileDrawing(source.features, featureId);
    drawing.contours.forEach((c, index) => {
      const value = `contour:${index}`;
      option(value, `Contour ${index + 1} (${c.type})`);
      if (selectedId !== undefined && c.id === selectedId) selected = value;
    });
  } catch {
    /* Preview presents the resolver's actionable error. */
  }
  if (selectedId !== undefined && selected === "all") {
    selected = `missing:${selectedId}`;
    option(selected, "Missing contour — choose a replacement");
  }
  select.value = selected;
}

export function projectionGeometryReference(
  source: PartDocument,
  featureId: string,
  value: string,
): {
  document: PartDocument;
  reference: { sourceFeatureId: string; sourceContourId?: string };
} {
  if (value === "all")
    return {
      document: identifyProfileContours(source, featureId),
      reference: { sourceFeatureId: featureId },
    };
  if (value.startsWith("missing:"))
    return {
      document: source,
      reference: {
        sourceFeatureId: featureId,
        sourceContourId: value.slice(8),
      },
    };
  const index = Number(value.slice("contour:".length));
  if (!value.startsWith("contour:") || !Number.isInteger(index) || index < 0)
    throw Error("Select source geometry.");
  const drawing = resolveProfileDrawing(source.features, featureId),
    contour = drawing.contours[index];
  if (!contour) throw Error("Select an existing source contour.");
  return referenceProfileContour(source, featureId, index);
}
