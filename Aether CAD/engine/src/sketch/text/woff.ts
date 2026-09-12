/** HarfBuzz accepts SFNT fonts. Unwrap WOFF1 without rewriting OpenType tables,
 * preserving substitution/positioning data for the shaper. */
export async function shapingFontBytes(
  input: ArrayBuffer,
): Promise<ArrayBuffer> {
  if (input.byteLength < 4 || new DataView(input).getUint32(0) !== 0x774f4646)
    return input;
  const view = new DataView(input);
  if (input.byteLength < 44) throw Error("Truncated WOFF header.");
  const count = view.getUint16(12),
    size = view.getUint32(16);
  if (
    !count ||
    count > 4096 ||
    44 + count * 20 > input.byteLength ||
    size > 32 * 1024 * 1024 ||
    size < 12 + count * 16
  )
    throw Error("Invalid WOFF table directory.");
  const output = new ArrayBuffer(size),
    target = new DataView(output),
    bytes = new Uint8Array(output);
  target.setUint32(0, view.getUint32(4));
  target.setUint16(4, count);
  const power = 2 ** Math.floor(Math.log2(count));
  target.setUint16(6, power * 16);
  target.setUint16(8, Math.log2(power));
  target.setUint16(10, count * 16 - power * 16);
  let cursor = 12 + count * 16,
    head: number | undefined;
  const tags = new Set<number>();
  for (let i = 0; i < count; i++) {
    const source = 44 + 20 * i,
      tag = view.getUint32(source),
      offset = view.getUint32(source + 4),
      compressed = view.getUint32(source + 8),
      length = view.getUint32(source + 12);
    if (
      tags.has(tag) ||
      !length ||
      compressed > length ||
      offset + compressed > input.byteLength ||
      cursor + length > size
    )
      throw Error("Invalid WOFF table bounds.");
    tags.add(tag);
    let data = input.slice(offset, offset + compressed);
    if (compressed < length) {
      const reader = new Blob([data])
        .stream()
        .pipeThrough(new DecompressionStream("deflate"))
        .getReader();
      const unpacked = new Uint8Array(length);
      let written = 0;
      try {
        for (;;) {
          const { value, done } = await reader.read();
          if (done) break;
          if (written + value.length > length)
            throw Error("WOFF table exceeds its declared size.");
          unpacked.set(value, written);
          written += value.length;
        }
        if (written !== length) throw Error("Truncated WOFF table.");
      } finally {
        await reader.cancel();
        reader.releaseLock();
      }
      data = unpacked.buffer;
    }
    const entry = 12 + i * 16;
    target.setUint32(entry, tag);
    target.setUint32(entry + 4, view.getUint32(source + 16));
    target.setUint32(entry + 8, cursor);
    target.setUint32(entry + 12, length);
    bytes.set(new Uint8Array(data), cursor);
    if (tag === 0x68656164) {
      if (length < 12) throw Error("Truncated font head table.");
      head = cursor;
      target.setUint32(head + 8, 0);
    }
    cursor += (length + 3) & ~3;
  }
  if (cursor !== size)
    throw Error("WOFF decoded size does not match its header.");
  if (head !== undefined) {
    let sum = 0;
    for (let i = 0; i < size; i += 4) sum = (sum + target.getUint32(i)) >>> 0;
    target.setUint32(head + 8, (0xb1b0afba - sum) >>> 0);
  }
  return output;
}
