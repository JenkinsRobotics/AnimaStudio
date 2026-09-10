import {
  sketchConstraintStates,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
/** Per-entity presentation; Core owns all mobility classification. No saved geometry is changed. */
export function renderGeometryConstraintColors(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
) {
  const refs: SketchEntityRef[] = [],
    keys = new Map<string, number>();
  const register = (ref: SketchEntityRef) => {
    const key = JSON.stringify(ref);
    if (!keys.has(key)) {
      keys.set(key, refs.length);
      refs.push(ref);
    }
    return keys.get(key)!;
  };
  const entries: { node: Element; indices: number[] }[] = [];
  const vertices = [...svg.querySelectorAll(".sketch-vertex")];
  const controls = [...svg.querySelectorAll(".sketch-point")];
  let vertex = 0, controlPoint = 0;
  const bind = (node: Element | null, entityRefs: SketchEntityRef[]) => {
    if (node) entries.push({ node, indices: entityRefs.map(register) });
  };
  drawing.contours.forEach((c, contour) => {
    const shape = svg.querySelector(`[data-contour-index="${contour}"]`);
    if (c.type === "circle") {
      bind(shape, [{ contour, kind: "circle" }]);
      bind(vertices[vertex++], [{ contour, kind: "point", index: 0 }]);
      return;
    }
    for (let index = 0; index <= c.segments.length; index++)
      bind(vertices[vertex++], [{ contour, kind: "point", index }]);
    if (!c.segments.length) {
      bind(shape, [{ contour, kind: "point", index: 0 }]);
      return;
    }
    shape?.classList.add("sketch-region-fill");
    let start = c.start;
    c.segments.forEach((segment, index) => {
      const path = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "path",
      );
      path.setAttribute(
        "d",
        contourPath({ type: "path", start, segments: [segment] }),
      );
      path.setAttribute(
        "class",
        `sketch-entity-edge${c.construction ? " construction" : ""}`,
      );
      path.setAttribute("data-entity-contour", String(contour));
      path.setAttribute("data-entity-segment", String(index));
      svg.append(path);
      const entityRefs: SketchEntityRef[] =
        segment.type === "bezier"
          ? [
              { contour, kind: "point", index },
              { contour, kind: "point", index: index + 1 },
              { contour, kind: "point", index, control: 0 },
              { contour, kind: "point", index, control: 1 },
            ]
          : [
              {
                contour,
                kind:
                  segment.type === "line"
                    ? "line"
                    : segment.type === "arc"
                      ? "arc"
                      : "ellipse",
                index,
              },
            ];
      bind(path, entityRefs);
      if(segment.type === "bezier") for(const control of [0,1] as const) bind(controls[controlPoint++], [{contour,kind:"point",index,control}]);
      start = segment.end;
    });
  });
  const states = sketchConstraintStates(drawing, refs);
  for (const { node, indices } of entries) {
    const values = indices.map((i) => states[i].state);
    const state = values.includes("invalid")
      ? "invalid"
      : values.includes("over-constrained")
        ? "over-constrained"
        : values.every((s) => s === "fully-constrained")
          ? "fully-constrained"
          : "under-constrained";
    node.setAttribute("data-entity-constraint-state", state);
    node.setAttribute("aria-label", state === "invalid" ? "Constraint analysis unavailable" : state === "over-constrained" ? "Sketch has conflicting or redundant constraints" : state.replaceAll("-", " "));
  }
}
