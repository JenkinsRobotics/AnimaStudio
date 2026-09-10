import { isDirectModificationTool } from "./tool-instructions";
import { directModification } from "./direct-modification";
import { previewTangentArc } from "./tangent-arc-tool";

import {
  pickCurve,
  contourClosed,
  fitSketchSpline,
  sketchVariantTools,
  sketchVariantPointCounts,
  sketchVariantContour,
  ellipticalArcGuide,
  type SketchVariantTool,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
import { arcPath, contourPath } from "./svg-geometry";
export interface PreviewState {
  started: boolean;
  busy: boolean;
  cursor: SketchPoint | null;
  tool: string;
  drawing: SketchDrawing;
  activePath: number;
  pending: SketchPoint[];
  bounds: { width: number };
  snapLabel: string;
  sides: number;
  clockwise?: boolean;
  secondaryRadiusMillimeters?: number;
  rememberedRadiusMillimeters?: number;
  effectivePoint: (point: SketchPoint) => SketchPoint;
}
export function renderSketchPreview(svg: SVGSVGElement, state: PreviewState) {
  const {
    started,
    busy,
    cursor,
    tool,
    drawing,
    activePath,
    pending,
    bounds,
    snapLabel,
    sides,
    effectivePoint,
  } = state;
  const ns = "http://www.w3.org/2000/svg";
  const el = (tag: string, attrs: Record<string, string | number>) => {
    const node = document.createElementNS(ns, tag);
    for (const [key, value] of Object.entries(attrs))
      node.setAttribute(key, String(value));
    return node;
  };
  const isVariant = () =>
    sketchVariantTools.includes(tool as SketchVariantTool);
  svg.querySelector(".sketch-preview-layer")?.remove();
  if (
    !started ||
    busy ||
    (!cursor && tool !== "fit-spline") ||
    tool === "select"
  )
    return;
  const previewCursor = cursor ?? pending.at(-1);
  if (!previewCursor) return;
  if (isDirectModificationTool(tool)) {
    try {
      const result = directModification(
        drawing,
        tool,
        previewCursor,
        pending,
        bounds.width / 60,
      );
      if (!result.drawing) return;
      const next = result.drawing;
      const group = document.createElementNS(ns, "g");
      group.setAttribute("class", "sketch-preview-layer");
      group.setAttribute("aria-hidden", "true");
      svg.append(group);
      for (const contour of next.contours) {
        const node =
          contour.type === "circle"
            ? el("circle", {
                cx: contour.center[0],
                cy: -contour.center[1],
                r: contour.radius,
                class: "sketch-preview",
              })
            : el("path", { d: contourPath(contour), class: "sketch-preview" });
        group.append(node);
      }
      if (tool === "insert-spline-point") {
        const target = pickCurve(drawing, previewCursor, bounds.width / 60);
        const contour = next.contours[target.contour];
        if (contour?.type === "path") {
          const point = contour.segments[target.segment].end;
          group.append(
            el("circle", {
              cx: point[0],
              cy: -point[1],
              r: bounds.width / 180,
              class: "sketch-preview",
              "data-spline-insertion-point": "true",
            }),
          );
        }
      }
    } catch {
      /* Only committed clicks report errors; hovering must not mutate the drawing. */
    }
    return;
  }
  if (tool === "fit-spline") {
    const closing =
      pending.length >= 3 &&
      Math.hypot(
        previewCursor[0] - pending[0][0],
        previewCursor[1] - pending[0][1],
      ) <
        bounds.width / 100;
    const points = [...pending];
    const p = effectivePoint(previewCursor),
      last = points.at(-1);
    if (
      !closing &&
      (!last || Math.hypot(last[0] - p[0], last[1] - p[1]) > 1e-8)
    )
      points.push(p);
    if (points.length >= 2) {
      try {
        const contour = fitSketchSpline(points, { closed: closing });
        if (contour.type === "path")
          svg.append(
            el("path", {
              d: contourPath(contour),
              class: "sketch-preview-layer sketch-preview",
            }),
          );
      } catch {
        /* A preview never changes saved geometry. */
      }
    }
    return;
  }
  if (!cursor) return;
  const c = drawing.contours[activePath];
  const a =
    pending[0] ??
    ((tool === "line" || tool === "arc") &&
    c?.type === "path" &&
    !contourClosed(c)
      ? c.segments.at(-1)?.end
      : undefined);
  if (tool === "point") {
    const point = document.createElementNS(ns, "circle");
    point.setAttribute("class", "sketch-preview-layer sketch-preview-point");
    point.setAttribute("cx", String(cursor[0]));
    point.setAttribute("cy", String(-cursor[1]));
    point.setAttribute("r", String(bounds.width / 180));
    svg.append(point);
    return;
  }
  if (!a) return;
  const p = effectivePoint(cursor),
    length = Math.hypot(p[0] - a[0], p[1] - a[1]);
  if (length < 1e-8) return;
  const group = document.createElementNS(ns, "g");
  group.setAttribute("class", "sketch-preview-layer");
  group.setAttribute("aria-hidden", "true");
  svg.append(group);
  const add = (tag: string, attrs: Record<string, string | number>) => {
    const node = el(tag, attrs);
    group.append(node);
    return node;
  };
  const style = { class: "sketch-preview" };
  let label = "";
  if (tool === "tangent-arc") {
    try {
      const contour = previewTangentArc(drawing, a, p, bounds.width / 100);
      add("path", { d: contourPath(contour), ...style });
      label = "Tangent arc";
    } catch (error) {
      label = (error as Error).message;
    }
  } else if (isVariant()) {
    const points = [...pending, p];
    if (tool === "elliptical-arc" && points.length >= 3) {
      try {
        add("path", {
          d: contourPath(
            ellipticalArcGuide(
              points.slice(0, 3),
              state.secondaryRadiusMillimeters,
              state.rememberedRadiusMillimeters,
            ),
          ),
          class: "sketch-preview sketch-ellipse-guide",
          "stroke-dasharray": "3 3",
        });
      } catch (error) {
        label = (error as Error).message;
      }
    }
    if (points.length === sketchVariantPointCounts[tool as SketchVariantTool]) {
      try {
        const contour = sketchVariantContour(
          tool as SketchVariantTool,
          points,
          sides,
          {
            clockwise: state.clockwise,
            secondaryRadiusMillimeters: state.secondaryRadiusMillimeters,
            rememberedRadiusMillimeters: state.rememberedRadiusMillimeters,
          },
        );
        if (contour.type === "circle") {
          add("circle", {
            cx: contour.center[0],
            cy: -contour.center[1],
            r: contour.radius,
            ...style,
          });
          label = `R ${contour.radius.toFixed(2)} mm`;
        } else {
          add("path", { d: contourPath(contour), ...style });
          label = tool.replaceAll("-", " ");
        }
      } catch (error) {
        label = (error as Error).message;
      }
    } else {
      add("line", {
        x1: a[0],
        y1: -a[1],
        x2: p[0],
        y2: -p[1],
        class: "sketch-preview-guide",
      });
      label = "Choose the next point";
    }
  } else if (tool === "circle") {
    add("circle", { cx: a[0], cy: -a[1], r: length, ...style });
    add("line", {
      x1: a[0],
      y1: -a[1],
      x2: p[0],
      y2: -p[1],
      class: "sketch-preview-guide",
    });
    label = `R ${length.toFixed(2)} mm · Ø ${(length * 2).toFixed(2)} mm`;
  } else if (tool === "rectangle") {
    add("rect", {
      x: Math.min(a[0], p[0]),
      y: -Math.max(a[1], p[1]),
      width: Math.abs(p[0] - a[0]),
      height: Math.abs(p[1] - a[1]),
      ...style,
    });
    label = `${Math.abs(p[0] - a[0]).toFixed(2)} × ${Math.abs(p[1] - a[1]).toFixed(2)} mm`;
  } else if (tool === "arc" && pending.length === 2) {
    const d = arcPath(
      [a[0], -a[1]],
      [p[0], -p[1]],
      [pending[1][0], -pending[1][1]],
    );
    add("path", { d: `M${a[0]},${-a[1]}${d}`, ...style });
    label = d.startsWith("A")
      ? `Arc · chord ${Math.hypot(pending[1][0] - a[0], pending[1][1] - a[1]).toFixed(2)} mm · click to set curvature`
      : "Move away from the line to form an arc";
  } else {
    add("line", { x1: a[0], y1: -a[1], x2: p[0], y2: -p[1], ...style });
    label =
      tool === "arc"
        ? `Arc guide · ${length.toFixed(2)} mm`
        : `${length.toFixed(2)} mm · ${((Math.atan2(p[1] - a[1], p[0] - a[0]) * 180) / Math.PI).toFixed(1)}°`;
  }
  add("circle", {
    cx: p[0],
    cy: -p[1],
    r: bounds.width / 240,
    class: "sketch-preview-point",
  });
  const text = add("text", {
    x: p[0] + bounds.width / 80,
    y: -p[1] - bounds.width / 80,
    "font-size": bounds.width / 85,
    class: "sketch-preview-dimension",
  });
  text.textContent = label + (snapLabel ? ` · ${snapLabel}` : "");
}
