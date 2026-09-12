import { contourClosed, type SketchContour } from "../drawing";
/** A full ellipse uses two complementary half-arcs with one shared shape. */
export function ellipseShapeResiduals(path: SketchContour): number[] {
  if (
    path.type !== "path" ||
    !contourClosed(path) ||
    path.segments.length !== 2
  )
    throw Error("Ellipse shape requires a closed two-half ellipse.");
  const [a, b] = path.segments;
  if (a.type !== "ellipse" || b.type !== "ellipse" || a.sweep !== b.sweep)
    throw Error("Ellipse halves must have matching sweep.");
  const angle = (a.rotationDegrees * Math.PI) / 180,
    delta = ((b.rotationDegrees - a.rotationDegrees) * Math.PI) / 180;
  return [
    b.radiusX - a.radiusX,
    b.radiusY - a.radiusY,
    Math.atan2(Math.sin(delta), Math.cos(delta)),
    path.start[0] - a.end[0] - 2 * a.radiusX * Math.cos(angle),
    path.start[1] - a.end[1] - 2 * a.radiusX * Math.sin(angle),
  ];
}
