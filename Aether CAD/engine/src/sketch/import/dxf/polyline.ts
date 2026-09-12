import { numberTag, type DxfTag } from "./tags";
/** Consume a classic POLYLINE/VERTEX/SEQEND sequence into the shared 2D carrier. */
export function legacyPolyline(
  tags: DxfTag[],
  start: number,
  header: DxfTag[],
): { body: DxfTag[]; next: number } {
  const paper = numberTag(header,67,0) === 1;
  const flags = paper ? 0 : numberTag(header, 70, 0);
  if (!Number.isInteger(flags) || (flags & ~129) !== 0)
    throw Error("Fitted, mesh and 3D DXF polylines are not supported yet.");
  if (!paper && (numberTag(header, 40, 0) !== 0 || numberTag(header, 41, 0) !== 0))
    throw Error("Wide DXF polylines need outline conversion.");
  const vertices: DxfTag[][] = [];
  let i = start;
  while (i < tags.length && tags[i].code === 0 && tags[i].value === "VERTEX") {
    let end = i + 1;
    while (end < tags.length && tags[end].code !== 0) end++;
    const vertex = tags.slice(i + 1, end);
    if (!paper && (numberTag(vertex, 70, 0) !== 0 || numberTag(vertex, 30, 0) !== 0))
      throw Error("Only planar unfitted DXF polyline vertices are supported.");
    vertices.push(vertex.filter((t) => [10, 20, 40, 41, 42].includes(t.code)));
    i = end;
  }
  if (tags[i]?.code !== 0 || tags[i]?.value !== "SEQEND")
    throw Error("DXF POLYLINE is missing SEQEND.");
  i++;
  while (i < tags.length && tags[i].code !== 0) i++;
  return {
    next: i,
    body: [
      ...header.filter((t) => [30, 39, 210, 220, 230, 67].includes(t.code)),
      { code: 70, value: String(flags) },
      { code: 90, value: String(vertices.length) },
      ...vertices.flat(),
    ],
  };
}
