import { sha256 } from "@noble/hashes/sha2.js";
import type { SketchContour } from "../drawing";
/** Same SHA-256 contract as WebCrypto, also usable during synchronous solving. */
export function textOutlineDigest(contours: SketchContour[]): string {
  const json = JSON.stringify(contours, (key, value) =>
    ["id", "startVertexId", "endVertexId", "sourceLayer"].includes(key)
      ? undefined
      : value,
  );
  return Array.from(sha256(new TextEncoder().encode(json)), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}
