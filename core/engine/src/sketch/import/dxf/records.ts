import { numberTag, type DxfTag } from "./tags";
/** Structural model-space records. Legacy vertex sequences belong to their
 * POLYLINE header; unsupported geometry is decoded only after layer selection. */
export function* dxfModelEntities(tags: DxfTag[]) {
  let section = "",
    entities = false;
  for (let i = 0; i < tags.length; i++) {
    const t = tags[i];
    if (t.code !== 0) continue;
    if (t.value === "SECTION") {
      if (section) throw Error("Nested DXF sections.");
      if (tags[i + 1]?.code !== 2) throw Error("DXF section has no name.");
      section = tags[++i].value;
      if (section === "ENTITIES") entities = true;
      continue;
    }
    if (t.value === "ENDSEC") {
      section = "";
      continue;
    }
    if (t.value === "EOF") {
      if (section) throw Error("DXF section was not closed.");
      break;
    }
    if (section !== "ENTITIES") continue;
    let end = i + 1;
    while (end < tags.length && tags[end].code !== 0) end++;
    const body = tags.slice(i + 1, end),
      vertexStart = t.value === "POLYLINE" ? end : undefined;
    if (vertexStart !== undefined) {
      let cursor = end;
      while (
        cursor < tags.length &&
        !(tags[cursor].code === 0 && tags[cursor].value === "SEQEND")
      ) {
        if (
          tags[cursor].code === 0 &&
          ["ENDSEC", "EOF"].includes(tags[cursor].value)
        )
          throw Error("DXF POLYLINE has no SEQEND.");
        cursor++;
      }
      if (cursor >= tags.length) throw Error("DXF POLYLINE has no SEQEND.");
      end = cursor + 1;
      while (end < tags.length && tags[end].code !== 0) end++;
    }
    i = end - 1;
    if (numberTag(body, 67, 0) === 1) continue;
    yield {
      type: t.value,
      body,
      vertexStart,
      layer: body.find((t) => t.code === 8)?.value || "0",
    };
  }
  if (!entities) throw Error("DXF has no ENTITIES section.");
}
