export interface DxfTag {
  code: number;
  value: string;
}
/** ASCII DXF is paired group-code/value lines, not whitespace-delimited tokens. */
export function dxfTags(text: string): DxfTag[] {
  if (text.startsWith("AutoCAD Binary DXF"))
    throw Error("Binary DXF is not supported yet. Export ASCII DXF.");
  if (text.length > 20_000_000)
    throw Error("DXF exceeds the 20 MB text limit.");
  const lines = text
    .replace(/^\uFEFF/, "")
    .trimEnd()
    .split(/\r\n|\n|\r/);
  if (lines.length % 2)
    throw Error("DXF has an incomplete group-code/value pair.");
  const tags: DxfTag[] = [];
  for (let i = 0; i < lines.length; i += 2) {
    if (!/^\s*\d+\s*$/.test(lines[i]))
      throw Error(`Invalid DXF group code at line ${i + 1}.`);
    const code = Number(lines[i]);
    if (code > 1071) throw Error(`Unsupported DXF group code ${code}.`);
    if (code !== 999) tags.push({ code, value: lines[i + 1].trim() });
  }
  if (tags.at(-1)?.code !== 0 || tags.at(-1)?.value !== "EOF")
    throw Error("DXF is missing its EOF marker.");
  return tags;
}
export function numberTag(
  tags: DxfTag[],
  code: number,
  fallback?: number,
): number {
  const raw = tags.find((t) => t.code === code)?.value;
  if (raw === undefined) {
    if (fallback !== undefined) return fallback;
    throw Error(`DXF entity is missing group ${code}.`);
  }
  if (!raw || !Number.isFinite(Number(raw)))
    throw Error(`DXF group ${code} must be numeric.`);
  return Number(raw);
}
