/** Shared authoring/native validation. Newlines are layout, not font glyphs. */
export function normalizeSketchText(value: unknown): string {
  if (typeof value !== "string" || !value.trim() || value.length > 1000)
    throw Error("Enter nonempty sketch text, up to 1000 characters.");
  if (/[\u0000-\u0009\u000b\u000c\u000e-\u001f\u007f]/.test(value))
    throw Error("Sketch text cannot contain tabs or control characters.");
  return value.replace(/\r\n?/g, "\n");
}
