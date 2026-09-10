import { dxfModelEntities } from "./records";
import { dxfCoordinates } from "./coordinates";
import { numberTag, type DxfTag } from "./tags";
import type { SketchFrameMap } from "../../projection/frame-map";
import type { SketchPoint } from "../../drawing";

const tag = (code: number, value: string): DxfTag => ({ code, value });
const section = (body: DxfTag[]) => [
  tag(0, "SECTION"),
  tag(2, "ENTITIES"),
  ...body,
  tag(0, "ENDSEC"),
  tag(0, "EOF"),
];
interface Block {
  header: DxfTag[];
  entities: DxfTag[];
}
function blocks(tags: DxfTag[]) {
  const result = new Map<string, Block>();
  let inBlocks = false;
  for (let i = 0; i < tags.length; i++) {
    if (tags[i].code !== 0) continue;
    if (tags[i].value === "SECTION") inBlocks = tags[i + 1]?.value === "BLOCKS";
    if (tags[i].value === "ENDSEC") inBlocks = false;
    if (!inBlocks || tags[i].value !== "BLOCK") continue;
    let start = i + 1;
    while (start < tags.length && tags[start].code !== 0) start++;
    const header = tags.slice(i + 1, start),
      name = header.find((t) => t.code === 2)?.value;
    let end = start;
    while (
      end < tags.length &&
      !(
        tags[end].code === 0 &&
        ["ENDBLK", "ENDSEC", "EOF"].includes(tags[end].value)
      )
    )
      end++;
    if (!name || result.has(name) || tags[end]?.value !== "ENDBLK")
      throw Error("Invalid or duplicate DXF block definition.");
    result.set(name, { header, entities: section(tags.slice(start, end)) });
    i = end;
  }
  return result;
}
export interface ExpandedDxfEntity {
  type: string;
  body: DxfTag[];
  layer: string;
  transforms: SketchFrameMap[];
  tags: DxfTag[];
  vertexStart?: number;
}
/** Expand structural references before geometry decoding so layer filtering remains possible. */
export function* expandedDxfEntities(
  tags: DxfTag[],
): Generator<ExpandedDxfEntity> {
  const definitions = blocks(tags);
  let visited = 0;
  function* visit(
    records: DxfTag[],
    parentLayer: string | undefined,
    transforms: SketchFrameMap[],
    stack: string[],
  ): Generator<ExpandedDxfEntity> {
    for (const record of dxfModelEntities(records)) {
      if (++visited > 10000)
        throw Error("DXF block expansion exceeds 10000 records.");
      const layer =
        record.layer === "0" && parentLayer !== undefined
          ? parentLayer
          : record.layer;
      if (record.type !== "INSERT") {
        yield {
          type: record.type,
          body: record.body,
          tags: records,
          vertexStart: record.vertexStart,
          layer,
          transforms,
        };
        continue;
      }
      const body = record.body,
        n = (code: number, fallback: number) => numberTag(body, code, fallback);
      const name = body.find((t) => t.code === 2)?.value,
        block = name ? definitions.get(name) : undefined;
      if (!block || !name)
        throw Error(`Missing DXF block: ${name ?? "unnamed"}.`);
      if (stack.includes(name) || stack.length >= 32)
        throw Error("Cyclic or excessively deep DXF block references.");
      if (numberTag(block.header, 70, 0) & (4 | 8 | 16))
        throw Error("External DXF block references are not embedded geometry.");
      dxfCoordinates("BLOCK", block.header);
      const coordinates = dxfCoordinates("INSERT", body),
        sx = n(41, 1),
        sy = n(42, 1),
        sz = n(43, 1);
      if (!sx || !sy || !sz) throw Error("DXF block scale must be nonzero.");
      if (n(66, 0) !== 0)
        throw Error("DXF block attributes are not supported yet.");
      const columns = n(70, 1),
        rows = n(71, 1);
      if (
        !Number.isInteger(columns) ||
        !Number.isInteger(rows) ||
        columns < 1 ||
        rows < 1 ||
        columns * rows > 10000
      )
        throw Error("Invalid DXF block array size.");
      const angle = (n(50, 0) * Math.PI) / 180,
        cos = Math.cos(angle),
        sin = Math.sin(angle),
        sign = coordinates.normalSign;
      const base: SketchPoint = [
        numberTag(block.header, 10, 0),
        numberTag(block.header, 20, 0),
      ];
      for (let row = 0; row < rows; row++)
        for (let column = 0; column < columns; column++) {
          const vector = (p: SketchPoint): SketchPoint => [
            sign * (cos * sx * p[0] - sin * sy * p[1]),
            sin * sx * p[0] + cos * sy * p[1],
          ];
          const offset: SketchPoint = [column * n(44, 0), row * n(45, 0)];
          const insertion: SketchPoint = [
            sign * (n(10, 0) + cos * offset[0] - sin * offset[1]),
            n(20, 0) + sin * offset[0] + cos * offset[1],
          ];
          const map: SketchFrameMap = {
            determinant: sign * sx * sy,
            vector,
            point(p) {
              const v = vector([p[0] - base[0], p[1] - base[1]]);
              return [v[0] + insertion[0], v[1] + insertion[1]];
            },
          };
          yield* visit(
            block.entities,
            layer,
            [map, ...transforms],
            [...stack, name],
          );
        }
    }
  }
  yield* visit(tags, undefined, [], []);
}
