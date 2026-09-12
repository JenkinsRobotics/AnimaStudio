import type { SketchDrawing, SketchPoint } from "@aether/core/sketch";
import { isDimensionConstraint, sketchConstraintEntry } from "./constraint-catalog";

/** Onshape-style constraint badges on committed geometry: each applied
 *  relationship gets a small glyph beside the entity it constrains, so you can
 *  see WHY the sketch is holding its shape. Dimensions are drawn separately by
 *  dimension-annotations; these are the non-dimensional relationships. */
/** Midpoint of the segment a constraint refers to, in sketch coordinates.
 *  Returns null when the reference does not resolve to drawn geometry. */
function anchorFor(drawing: SketchDrawing, reference: any): SketchPoint | null {
  if (!reference || typeof reference.contour !== "number") return null;
  const contour = drawing.contours[reference.contour];
  if (!contour) return null;
  if (contour.type === "circle") return contour.center;
  if (contour.type !== "path") return null;
  if (reference.kind === "point")
    return reference.index === 0 ? contour.start : contour.segments[reference.index - 1]?.end ?? null;
  const index = reference.index ?? 0;
  const segment = contour.segments[index];
  if (!segment) return null;
  const start = index === 0 ? contour.start : contour.segments[index - 1].end;
  return [(start[0] + segment.end[0]) / 2, (start[1] + segment.end[1]) / 2];
}

export function renderConstraintMarks(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
  bounds: { x: number; y: number; width: number; height: number },
) {
  const constraints = drawing.constraints ?? [];
  if (!constraints.length) return;
  const size = bounds.width / 70;
  // Stack marks that land on the same anchor so they do not overprint.
  const used = new Map<string, number>();
  for (const constraint of constraints as any[]) {
    if (isDimensionConstraint(constraint.kind)) continue; // drawn as annotations
    const entry = sketchConstraintEntry(constraint.kind);
    if (!entry) continue;
    const glyph = entry.glyph;
    const anchor = anchorFor(drawing, constraint.a) ?? anchorFor(drawing, constraint.b);
    if (!anchor) continue;
    const key = `${anchor[0].toFixed(3)}:${anchor[1].toFixed(3)}`;
    const stack = used.get(key) ?? 0;
    used.set(key, stack + 1);

    const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
    group.setAttribute("class", "sketch-constraint-mark");
    // NOT data-constraint-kind / -id: the constraint PANEL rows already own
    // those, and a canvas mark must not answer a query meant for a row.
    group.setAttribute("data-constraint-mark", constraint.kind);
    if (constraint.id) group.setAttribute("data-mark-for", String(constraint.id));
    const x = anchor[0] + size * 0.6;
    const y = -anchor[1] - size * 0.6 - stack * size * 1.25;

    const box = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    box.setAttribute("x", String(x));
    box.setAttribute("y", String(y - size * 0.8));
    box.setAttribute("width", String(size));
    box.setAttribute("height", String(size));
    box.setAttribute("rx", String(size / 6));
    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", String(x + size / 2));
    text.setAttribute("y", String(y - size * 0.28));
    text.setAttribute("font-size", String(size * 0.7));
    text.setAttribute("text-anchor", "middle");
    text.textContent = glyph;
    text.setAttribute("aria-label", entry.label);
    group.append(box, text);
    svg.append(group);
  }
}

/** Every constraint that references this entity, as catalog entries. Used by
 *  the hover readout: Onshape shows what is holding a line or point the moment
 *  you point at it, whether or not constraint display is switched on. */
export function constraintsForEntity(drawing: SketchDrawing, entity: any) {
  if (!entity) return [];
  const matches = (reference: any) =>
    reference &&
    reference.contour === entity.contour &&
    (entity.kind === "point"
      ? reference.kind === "point" && reference.index === entity.index
      : reference.kind !== "point" &&
        (reference.index === undefined || entity.index === undefined || reference.index === entity.index));
  return ((drawing.constraints ?? []) as any[])
    .filter((constraint) => matches(constraint.a) || matches(constraint.b))
    .map((constraint) => sketchConstraintEntry(constraint.kind))
    .filter((entry): entry is NonNullable<typeof entry> => Boolean(entry));
}

/** A row of glyphs beside the hovered entity, naming what constrains it. */
export function renderHoveredConstraints(
  svg: SVGSVGElement,
  drawing: SketchDrawing,
  entity: any,
  at: SketchPoint,
  bounds: { x: number; y: number; width: number; height: number },
) {
  const entries = constraintsForEntity(drawing, entity);
  if (!entries.length) return;
  const size = bounds.width / 60;
  const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
  group.setAttribute("class", "sketch-hovered-constraints");
  group.setAttribute("data-constraint-count", String(entries.length));
  entries.forEach((entry, index) => {
    const x = at[0] + size * 0.6 + index * size * 1.2;
    const y = -at[1] - size * 1.4;
    const box = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    box.setAttribute("x", String(x));
    box.setAttribute("y", String(y - size * 0.8));
    box.setAttribute("width", String(size));
    box.setAttribute("height", String(size));
    box.setAttribute("rx", String(size / 6));
    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", String(x + size / 2));
    text.setAttribute("y", String(y - size * 0.28));
    text.setAttribute("font-size", String(size * 0.7));
    text.setAttribute("text-anchor", "middle");
    text.textContent = entry.glyph;
    const title = document.createElementNS("http://www.w3.org/2000/svg", "title");
    title.textContent = entry.label;
    text.append(title);
    group.append(box, text);
  });
  svg.append(group);
}
