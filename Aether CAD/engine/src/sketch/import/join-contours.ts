import {
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchContour,
  type SketchPoint,
} from "../drawing";
type Path = Extract<SketchContour, { type: "path" }>;
function reversed(path: Path): Path {
  const points = [path.start, ...path.segments.map((s) => s.end)];
  return {
    ...path,
    start: points.at(-1)!,
    segments: path.segments.map((_, j) => {
      const i = path.segments.length - 1 - j,
        s = path.segments[i];
      return {
        ...s,
        end: points[i],
        ...(s.type === "bezier"
          ? {
              controls: [s.controls[1], s.controls[0]] as [
                SketchPoint,
                SketchPoint,
              ],
            }
          : {}),
        ...(s.type === "ellipse" ? { sweep: !s.sweep } : {}),
      };
    }),
  };
}
/** Join endpoint-connected import paths without crossing branch nodes. Interior
 * crossings are not split. Matching endpoints move by at most the stated tolerance.
 * Call before adding constraints: topology references would otherwise need remapping.
 */
export function joinImportedContours(
  source: SketchDrawing,
  toleranceMillimeters = 1e-7,
): SketchDrawing {
  if (!Number.isFinite(toleranceMillimeters) || toleranceMillimeters < 0)
    throw Error("Join tolerance must be finite and nonnegative.");
  if (source.constraints?.length)
    throw Error("Join imported geometry before adding constraints.");
  validateSketchDrawing(source);
  const next = structuredClone(source),
    nodes: { point: SketchPoint; group: string; edges: number[] }[] = [],
    edges: { path: Path; nodes: [number, number]; index: number }[] = [],
    output: { index: number; contour: SketchContour }[] = [];
  function node(point: SketchPoint, group: string) {
    const found = nodes.findIndex(
      (n) =>
        n.group === group &&
        Math.hypot(n.point[0] - point[0], n.point[1] - point[1]) <=
          toleranceMillimeters,
    );
    if (found >= 0) return found;
    nodes.push({ point, group, edges: [] });
    return nodes.length - 1;
  }
  next.contours.forEach((c, index) => {
    if (c.type !== "path" || !c.segments.length || contourClosed(c)) {
      output.push({ index, contour: c });
      return;
    }
    const group = JSON.stringify([!!c.hole, !!c.construction, c.sourceLayer]),
      a = node(c.start, group),
      b = node(c.segments.at(-1)!.end, group),
      id = edges.length;
    edges.push({ path: c, nodes: [a, b], index });
    nodes[a].edges.push(id);
    nodes[b].edges.push(id);
  });
  const used = new Set<number>();
  function walk(first: number, start: number) {
    let edgeId = first,
      current = start,
      path: Path | undefined,
      index = Infinity;
    while (!used.has(edgeId)) {
      used.add(edgeId);
      const edge = edges[edgeId],
        forward = edge.nodes[0] === current,
        end = edge.nodes[forward ? 1 : 0],
        part = forward ? edge.path : reversed(edge.path);
      part.start = [...nodes[current].point];
      part.segments.at(-1)!.end = [...nodes[end].point];
      if (!path) path = { ...part, segments: [...part.segments] };
      else {
        delete path.id;
        path.segments.push(...part.segments);
      }
      index = Math.min(index, edge.index);
      current = end;
      if (nodes[current].edges.length !== 2) break;
      const candidate = nodes[current].edges.find((id) => !used.has(id));
      if (candidate === undefined) break;
      edgeId = candidate;
    }
    if (path) output.push({ index, contour: path });
  }
  nodes.forEach((n, id) => {
    if (n.edges.length !== 2)
      for (const edge of n.edges) if (!used.has(edge)) walk(edge, id);
  });
  edges.forEach((e, id) => {
    if (!used.has(id)) walk(id, e.nodes[0]);
  });
  next.contours = output
    .sort((a, b) => a.index - b.index)
    .map((o) => o.contour);
  validateSketchDrawing(next);
  return next;
}
