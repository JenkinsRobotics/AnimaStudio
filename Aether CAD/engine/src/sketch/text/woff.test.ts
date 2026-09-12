import { expect, it } from "vitest";
import { deflateSync } from "node:zlib";
import { readFileSync } from "node:fs";
import { shapingFontBytes } from "./woff";
import { sketchTextOutline } from "./outline";
it("preserves real compressed WOFF font tables and shaped outlines", async () => {
  const sfnt = Uint8Array.from(
      readFileSync(
        new URL(
          "../../../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf",
          import.meta.url,
        ),
      ),
    ).buffer,
    original = new DataView(sfnt),
    count = original.getUint16(4);
  const tables = Array.from({ length: count }, (_, i) => {
    const entry = 12 + i * 16,
      length = original.getUint32(entry + 12),
      offset = original.getUint32(entry + 8),
      data = new Uint8Array(sfnt.slice(offset, offset + length)),
      compressed = deflateSync(data);
    return {
      tag: original.getUint32(entry),
      checksum: original.getUint32(entry + 4),
      length,
      data: compressed.length < length ? compressed : data,
    };
  });
  const size =
      44 +
      count * 20 +
      tables.reduce((n, t) => n + ((t.data.length + 3) & ~3), 0),
    woff = new ArrayBuffer(size),
    header = new DataView(woff);
  header.setUint32(0, 0x774f4646);
  header.setUint32(4, original.getUint32(0));
  header.setUint32(8, size);
  header.setUint16(12, count);
  header.setUint32(
    16,
    12 + count * 16 + tables.reduce((n, t) => n + ((t.length + 3) & ~3), 0),
  );
  let cursor = 44 + count * 20;
  tables.forEach((table, i) => {
    const at = 44 + i * 20;
    header.setUint32(at, table.tag);
    header.setUint32(at + 4, cursor);
    header.setUint32(at + 8, table.data.length);
    header.setUint32(at + 12, table.length);
    header.setUint32(at + 16, table.checksum);
    new Uint8Array(woff).set(table.data, cursor);
    cursor += (table.data.length + 3) & ~3;
  });
  const decoded = await shapingFontBytes(woff),
    view = new DataView(decoded);
  for (let i = 0; i < count; i++)
    expect(view.getUint32(12 + i * 16)).toBe(original.getUint32(12 + i * 16));
  expect(
    await sketchTextOutline(woff, "office", { emSizeMillimeters: 10 }),
  ).toEqual(await sketchTextOutline(sfnt, "office", { emSizeMillimeters: 10 }));
  header.setUint32(48, size + 100);
  await expect(shapingFontBytes(woff)).rejects.toThrow(/bounds/);
}, 30000);
