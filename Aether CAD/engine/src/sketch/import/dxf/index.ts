import { legacyPolyline } from "./polyline";
import { expandedDxfEntities } from "./blocks";
import { mapSketchDrawing } from "../../projection/drawing";
import { transformContour } from "../../curves/similarity";
export { dxfLayers } from "./layers";
import { classifyImportedRegions } from "../classify-regions";
import { joinImportedContours } from "../join-contours";
import { validateSketchDrawing, type SketchDrawing } from "../../drawing";
import { dxfTags, numberTag } from "./tags";
import { dxfEntity } from "./entities";
const units: Record<number, number> = {
  1: 25.4,
  2: 304.8,
  3: 1609344,
  4: 1,
  5: 10,
  6: 1000,
  7: 1e6,
  8: 0.0000254,
  9: 0.0254,
  10: 914.4,
  11: 1e-7,
  12: 1e-6,
  13: 0.001,
  14: 100,
  15: 10000,
  16: 100000,
};
export interface DxfImport {
  drawing: SketchDrawing;
  millimetersPerUnit: number;
  entityCount: number;
}
/** Model-space ASCII DXF. Unsupported entities reject atomically rather than disappear. */
export function importDxfSketch(
  text: string,
  millimetersPerUnit?: number,
  options: {
    joinConnected?: boolean;
    toleranceMillimeters?: number;
    classifyHoles?: boolean;
    includedLayers?: readonly string[];
  } = {},
): DxfImport {
  const tags = dxfTags(text);
  let section = "",
    scale = millimetersPerUnit;
  if (scale !== undefined && (!Number.isFinite(scale) || scale <= 0))
    throw Error("DXF unit scale must be positive.");
  // Header is read before geometry even when sections appear out of order.
  for (let i = 0; i < tags.length; i++) {
    if (tags[i].code === 0 && tags[i].value === "SECTION")
      section = tags[i + 1]?.value ?? "";
    if (
      section === "HEADER" &&
      tags[i].code === 9 &&
      tags[i].value === "$INSUNITS" &&
      scale === undefined
    ) {
      const id = numberTag(tags.slice(i + 1, i + 2), 70);
      scale = units[id];
    }
    if (tags[i].code === 0 && tags[i].value === "ENDSEC") section = "";
  }
  if (scale === undefined)
    throw Error(
      "DXF units are unspecified or unsupported. Choose the source units.",
    );
  const drawing: SketchDrawing = { type: "drawing", contours: [] };
  if (
    options.includedLayers !== undefined &&
    (!Array.isArray(options.includedLayers) ||
      options.includedLayers.some((name) => typeof name !== "string"))
  )
    throw Error("DXF layer selection must be a list of layer names.");
  const selected =
    options.includedLayers === undefined
      ? undefined
      : new Set(options.includedLayers);
  for (const record of expandedDxfEntities(tags)) {
    if (selected && !selected.has(record.layer)) continue;
    const type = record.vertexStart === undefined ? record.type : "LWPOLYLINE";
    const body =
      record.vertexStart === undefined
        ? record.body
        : legacyPolyline(record.tags, record.vertexStart, record.body).body;
    if (!record.transforms.length) {
      drawing.contours.push({
        ...dxfEntity(type, body, scale),
        sourceLayer: record.layer,
      });
      continue;
    }
    let geometry: SketchDrawing = {
      type: "drawing",
      contours: [dxfEntity(type, body, 1)],
    };
    for (const map of record.transforms)
      geometry = mapSketchDrawing(geometry, map);
    drawing.contours.push(
      ...geometry.contours.map((c) => ({
        ...transformContour(c, {
          a: scale!,
          b: 0,
          c: 0,
          d: scale!,
          tx: 0,
          ty: 0,
        }),
        sourceLayer: record.layer,
      })),
    );
  }
  if (!drawing.contours.length)
    throw Error("DXF has no geometry in the selected model-space layers.");
  validateSketchDrawing(drawing);
  const joined =
    options.joinConnected === false
      ? drawing
      : joinImportedContours(drawing, options.toleranceMillimeters);
  return {
    drawing:
      options.classifyHoles === false
        ? joined
        : classifyImportedRegions(joined),
    millimetersPerUnit: scale,
    entityCount: drawing.contours.length,
  };
}
