import { sketchRegionGroups } from "../sketch/regions/groups";
import { resolveProfileDrawing } from "../document/profile-projection";
import { principalFrame } from "../document/construction-planes";
import { sketchRegionOrder } from "../sketch/regions/order";
import { solveDrawingConstraints } from "../sketch/drawing-constraints";
import { contourClosed } from "../sketch/drawing";
import {
  draw,
  Plane,
  isShape3D,
  drawCircle,
  drawRectangle,
  type Drawing,
  type Shape3D,
  type EdgeFinder,
} from "replicad";
import type { ImportedModelData } from "../contracts/index";
import { buildPartGeometry } from "./part-geometry";
import {
  availableBodies,
  bodyIDForFeature,
  rollbackPosition,
  validatePartDocument,
  type PartDocument,
} from "../document/index";
import { rectangleSketchRevision } from "../sketch/index";
function release(value: unknown) {
  try {
    (value as { delete?: () => void }).delete?.();
  } catch {
    /* OCCT may transfer ownership. */
  }
}
/** Evaluates persisted features into an exact OCCT solid; meshes are disposable. */
export function evaluatePartDocument(
  document: PartDocument,
): ImportedModelData {
  validatePartDocument(document);
  const started = performance.now();
  const owned: unknown[] = [];
  const profiles = new Map<
    string,
    { drawing: Drawing; plane: "XY" | "XZ" | "YZ" | Plane; offset: number }
  >();
  const tools = new Map<string, Shape3D>();
  const bodies = new Map<string, Shape3D>();
  let currentBodyID: string | undefined;
  const own = <T>(shape: T): T => {
    owned.push(shape);
    return shape;
  };
  const combine = (
    tool: Shape3D,
    operation: "new" | "add" | "cut",
    feature: import("../document/index").PartFeature,
  ) => {
    if (operation === "new") {
      const id = bodyIDForFeature(document, feature);
      bodies.set(id, own(tool.clone()));
      currentBodyID = id;
    } else {
      const id =
        ("targetBodyId" in feature && feature.targetBodyId) || currentBodyID;
      const body = id && bodies.get(id);
      if (!body || !id) throw new Error("Select an existing target body.");
      bodies.set(
        id,
        own(operation === "add" ? body.fuse(tool) : body.cut(tool)),
      );
    }
  };
  try {
    for (const feature of document.features.slice(
      0,
      rollbackPosition(document),
    )) {
      if (feature.suppressed || feature.type === "plane") continue;
      try {
        if (feature.type === "sketch") {
          const state = rectangleSketchRevision(feature);
          const drawing = own(
            drawRectangle(
              state.widthMillimeters,
              state.heightMillimeters,
            ).translate(
              feature.profile.centerXMillimeters,
              feature.profile.centerYMillimeters,
            ),
          );
          profiles.set(feature.id, { drawing, plane: state.plane, offset: 0 });
          continue;
        }
        if (feature.type === "profile") {
          let drawing: Drawing;
          const profile = feature.profile.type === "projection" ? resolveProfileDrawing(document.features.slice(0,rollbackPosition(document)),feature.id) : feature.profile;
          if (profile.type === "drawing") {
            const closed = solveDrawingConstraints(profile).contours.filter(c=>!c.construction&&contourClosed(c));
            let combined: Drawing | undefined;
            const regionFor = (index: number): Drawing => {
              const contour = closed[index];
              let region: Drawing;
              if (contour.type === "circle") region = own(drawCircle(contour.radius).translate(contour.center));
              else {
                const pen=draw(contour.start);
                for(const segment of contour.segments) {
                  if(segment.type==='arc') pen.threePointsArcTo(segment.end,segment.middle);
                  else if(segment.type==='ellipse')pen.ellipseTo(segment.end,segment.radiusX,segment.radiusY,segment.rotationDegrees,segment.largeArc,segment.sweep);
                  else if(segment.type==='bezier')pen.bezierCurveTo(segment.end,segment.controls);
                  else pen.lineTo(segment.end);
                }
                region=own(pen.done());
              }
              return region;
            };
            const groups = sketchRegionGroups(closed);
            if (groups) {
              for (const group of groups) {
                let region = regionFor(group.solid);
                for (const hole of group.holes) region = own(region.cut(regionFor(hole)));
                combined = combined ? own(combined.fuse(region)) : region;
              }
              if (!combined && closed.some(c => c.hole)) throw new Error("A hole needs an outer closed profile.");
            } else {
              for (const index of sketchRegionOrder(closed)) {
                const contour = closed[index], region = regionFor(index);
                if(contour.hole && !combined) throw new Error("A hole needs an outer closed profile.");
                combined=combined ? own(contour.hole ? combined.cut(region) : combined.fuse(region)) : region;
              }
            }
            // Open contours remain saved and editable, but cannot create a solid.
            if(!combined) continue;
            drawing=combined;
          } else if (profile.type === "circle")
            drawing = drawCircle(profile.radiusMillimeters).translate(
              profile.centerMillimeters,
            );
          else {
            const points = profile.pointsMillimeters;
            const pen = draw(points[0]);
            for (const point of points.slice(1)) pen.lineTo(point);
            drawing = pen.close();
          }
          profiles.set(feature.id, {
            drawing: own(drawing),
            // Always sketch on an explicit principalFrame plane: replicad's
            // named-plane table disagrees with the engine's frame authority
            // (XZ mirrored, YZ rotated), so plane strings must never reach
            // the kernel — what the UI displays is what gets built.
            plane: own(
              feature.frame
                ? new Plane(feature.frame.originMillimeters, feature.frame.xDirection, feature.frame.normal)
                : (() => {
                    const resolved = principalFrame(feature.plane, feature.offsetMillimeters);
                    return new Plane(resolved.originMillimeters, resolved.xDirection, resolved.normal);
                  })(),
            ),
            offset: 0,
          });
          continue;
        }
        if (feature.type === "fillet" || feature.type === "chamfer") {
          const id = feature.targetBodyId ?? currentBodyID;
          const body = id && bodies.get(id);
          if (!body || !id)
            throw new Error("Create a solid before finishing edges.");
          const filter = feature.edgePlane
            ? (edges: EdgeFinder) =>
                edges.inPlane(
                  feature.edgePlane!.plane,
                  feature.edgePlane!.offsetMillimeters,
                )
            : undefined;
          bodies.set(
            id,
            own(
              feature.type === "fillet"
                ? body.fillet(feature.radiusMillimeters, filter)
                : body.chamfer(feature.radiusMillimeters, filter),
            ),
          );
          continue;
        }
        let tool: Shape3D;
        if (feature.type === "mirror") {
          const source = tools.get(feature.sourceFeatureId);
          if (!source) throw new Error("Mirror source is unavailable.");
          const origin: [number, number, number] =
            feature.plane === "XY"
              ? [0, 0, feature.offsetMillimeters]
              : feature.plane === "XZ"
                ? [0, feature.offsetMillimeters, 0]
                : [feature.offsetMillimeters, 0, 0];
          tool = own(source.clone().mirror(feature.plane, origin));
        } else {
          const profile = profiles.get(feature.profileFeatureId);
          if (!profile) throw new Error("Sketch needs a closed profile before creating a solid.");
          const planarDrawing = own(profile.drawing.clone());
          const sketch = own(typeof profile.plane === "string"
            ? planarDrawing.sketchOnPlane(profile.plane, profile.offset)
            : planarDrawing.sketchOnPlane(profile.plane));
          const result = own(
            feature.type === "extrude"
              ? sketch.extrude(feature.distanceMillimeters)
              : sketch.revolve(
                  feature.axis === "X"
                    ? [1, 0, 0]
                    : feature.axis === "Y"
                      ? [0, 1, 0]
                      : [0, 0, 1],
                  { origin: [0, 0, 0], angle: feature.angleDegrees },
                ),
          );
          if (!isShape3D(result))
            throw new Error("Feature did not produce a solid.");
          tool = result;
        }
        tools.set(feature.id, tool);
        combine(tool, feature.operation, feature);
      } catch (error) {
        throw new Error(
          `${feature.name}: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
    return {
      sourceName: document.name + ".acpart",
      parts: [...bodies].map(([id, body], index) =>
        buildPartGeometry(
          body,
          document.documentId,
          document.name + ".acpart",
          index,
          {
            id,
            name:
              availableBodies(document).find((b) => b.id === id)?.name ??
              `Body ${index + 1}`,
          },
        ),
      ),
      parseMilliseconds: performance.now() - started,
    };
  } finally {
    for (const shape of owned.reverse()) release(shape);
  }
}
