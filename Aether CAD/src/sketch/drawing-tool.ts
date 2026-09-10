import { placeTangentArc } from "./tangent-arc-tool";
import {
  inferSketchSemicircle,
  contourClosed,
  fitSketchSpline,
  constrainFitSpline,
  constrainSketchRectangle,
  constrainSketchEllipse,
  constrainSketchPolygon,
  addSketchLineMidpoint,
  constrainThreePointCircle,
  addSketchArcCenter,
  addSketchEllipseCenter,
  constrainEllipseEndpointQuadrants,
  setSketchEllipseDiameter,
  sketchVariantTools,
  sketchVariantPointCounts,
  sketchVariantContour,
  validateSketchDrawing,
  type SketchVariantTool,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
export interface DrawingGesture {
  drawing: SketchDrawing;
  pending: SketchPoint[];
  activePath: number;
}
interface Settings {
  tool: string;
  sides: number;
  inferQuadrants?: boolean;
  inferSemicircles?: boolean;
  clockwise?: boolean;
  secondaryRadiusMillimeters?: number;
  rememberedRadiusMillimeters?: number;
  construction: boolean;
  closeTolerance: number;
}
/** Pure placement state machine. Unfinished gestures never mutate the document or undo history. */
export function placeDrawingPoint(
  state: DrawingGesture,
  p: SketchPoint,
  settings: Settings,
): DrawingGesture & { committed: boolean } {
  const { tool, sides, construction, closeTolerance } = settings;
  if (tool === "tangent-arc")
    return placeTangentArc(
      state.drawing,
      state.pending,
      p,
      closeTolerance,
      construction,
    );
  const wait = (pending: SketchPoint[]) => ({
    ...state,
    pending,
    committed: false,
  });
  if (tool === "fit-spline") {
    if (
      state.pending.length >= 3 &&
      Math.hypot(p[0] - state.pending[0][0], p[1] - state.pending[0][1]) <
        closeTolerance
    ) {
      const drawing = structuredClone(state.drawing);
      const contour = fitSketchSpline(state.pending, { closed: true });
      if (construction) contour.construction = true;
      drawing.contours.push(contour);
      validateSketchDrawing(drawing);
      return {
        drawing: constrainFitSpline(drawing, drawing.contours.length - 1),
        pending: [],
        activePath: -1,
        committed: true,
      };
    }
    const last = state.pending.at(-1);
    if (last && Math.hypot(last[0] - p[0], last[1] - p[1]) < 1e-8)
      throw Error("Choose a distinct fit point, then Finish spline.");
    if (state.pending.length >= 1001)
      throw Error("Spline fit point limit reached.");
    return wait([...state.pending, [...p]]);
  }
  let drawing = structuredClone(state.drawing);
  let { pending, activePath } = state;
  const commit = () => {
    validateSketchDrawing(drawing);
    return { drawing, pending: [], activePath, committed: true };
  };
  if (sketchVariantTools.includes(tool as SketchVariantTool)) {
    const points = [...pending, p];
    if (points.length < sketchVariantPointCounts[tool as SketchVariantTool])
      return wait(points);
    const contour = sketchVariantContour(
      tool as SketchVariantTool,
      points,
      sides,
      {
        clockwise: settings.clockwise,
        secondaryRadiusMillimeters: settings.secondaryRadiusMillimeters,
        rememberedRadiusMillimeters: settings.rememberedRadiusMillimeters,
      },
    );
    if (construction) contour.construction = true;
    drawing.contours.push(contour);
    activePath = contourClosed(contour) ? -1 : drawing.contours.length - 1;
    if (tool === "elliptical-arc" && settings.inferQuadrants)
      constrainEllipseEndpointQuadrants(drawing, activePath);
    if (tool === "ellipse")
      drawing = constrainSketchEllipse(drawing, drawing.contours.length - 1);
    if (tool === "elliptical-arc")
      drawing = addSketchEllipseCenter(drawing, {
        contour: activePath,
        kind: "ellipse",
        index: 0,
      });
    if (
      tool === "elliptical-arc" &&
      settings.secondaryRadiusMillimeters !== undefined
    )
      drawing = setSketchEllipseDiameter(
        drawing,
        { contour: activePath, kind: "ellipse", index: 0 },
        "y",
        settings.secondaryRadiusMillimeters * 2,
      );
    if (tool === "center-arc")
      drawing = addSketchArcCenter(drawing, {
        contour: activePath,
        kind: "arc",
        index: 0,
      });
    if (tool === "three-point-circle")
      drawing = constrainThreePointCircle(
        drawing,
        drawing.contours.length - 1,
        points,
      );
    if (tool === "midpoint-line")
      drawing = addSketchLineMidpoint(drawing, {
        contour: activePath,
        kind: "line",
        index: 0,
      });
    if (tool === "center-rectangle" || tool === "aligned-rectangle")
      drawing = constrainSketchRectangle(
        drawing,
        drawing.contours.length - 1,
        tool,
      );
    if (tool === "inscribed-polygon" || tool === "circumscribed-polygon")
      drawing = constrainSketchPolygon(
        drawing,
        drawing.contours.length - 1,
        points[0],
        tool === "circumscribed-polygon",
      );
    return commit();
  }
  if (tool === "circle" || tool === "rectangle") {
    if (!pending.length) return wait([p]);
    const a = pending[0];
    if (tool === "circle")
      drawing.contours.push({
        type: "circle",
        ...(construction ? { construction: true } : {}),
        center: a,
        radius: Math.hypot(a[0] - p[0], a[1] - p[1]),
      });
    else {
      if (a[0] === p[0] || a[1] === p[1])
        throw new Error("Rectangle needs width and height.");
      drawing.contours.push({
        type: "path",
        ...(construction ? { construction: true } : {}),
        start: a,
        segments: [
          { type: "line", end: [p[0], a[1]] },
          { type: "line", end: p },
          { type: "line", end: [a[0], p[1]] },
          { type: "line", end: a },
        ],
      });
      drawing = constrainSketchRectangle(
        drawing,
        drawing.contours.length - 1,
        "rectangle",
      );
    }
    activePath = -1;
    return commit();
  }
  if (tool !== "line" && tool !== "arc")
    throw new Error("Choose a drawing tool.");
  let c = drawing.contours[activePath];
  if (!c || c.type !== "path" || contourClosed(c)) {
    if (!pending.length) return wait([p]);
    if (tool === "arc" && pending.length === 1) {
      if (Math.hypot(pending[0][0] - p[0], pending[0][1] - p[1]) < 1e-8)
        throw new Error("Arc endpoints must be distinct.");
      return wait([...pending, p]);
    }
    c = {
      type: "path",
      ...(construction ? { construction: true } : {}),
      start: pending[0],
      segments: [],
    };
    drawing.contours.push(c);
    activePath = drawing.contours.length - 1;
  } else if (tool === "arc" && !pending.length) {
    const start = c.segments.at(-1)?.end ?? c.start;
    if (Math.hypot(start[0] - p[0], start[1] - p[1]) < 1e-8)
      throw new Error("Arc endpoints must be distinct.");
    return wait([start, p]);
  }
  if (c.type === "path") {
    let end = tool === "arc" ? pending[1] : p;
    if (Math.hypot(c.start[0] - end[0], c.start[1] - end[1]) < closeTolerance)
      end = [...c.start];
    c.segments.push(
      tool === "arc" ? { type: "arc", middle: p, end } : { type: "line", end },
    );
    if (tool === "arc" && settings.inferSemicircles)
      drawing = inferSketchSemicircle(
        drawing,
        activePath,
        c.segments.length - 1,
      );
  }
  return commit();
}
