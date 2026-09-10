import { updateDimensionLabelLeader } from "./dimension-label-leader";
interface Box {
  x: number;
  y: number;
  width: number;
  height: number;
}
const overlaps = (a: Box, b: Box) =>
  a.x < b.x + b.width &&
  a.x + a.width > b.x &&
  a.y < b.y + b.height &&
  a.y + a.height > b.y;

/** Deterministic label-to-label spacing. Manual positions reserve space first;
 * automatic positions are recomputed on render and never persisted. */
export function spaceDimensionLabels(layer: SVGGElement) {
  const labels = Array.from(
    layer.querySelectorAll<SVGTextElement>(".sketch-dimension text"),
  );
  const occupied: Box[] = [];
  const box = (label: SVGTextElement): Box => {
    const font = Number(label.getAttribute("font-size")) || 2,
      pad = font * 0.4;
    let measured: Box | undefined;
    try {
      const b = label.getBBox?.();
      if (b?.width > 0 && b.height > 0) measured = b;
    } catch {
      /* Hidden or headless SVG: estimate until browser layout is available. */
    }
    const width =
      measured?.width ?? (label.textContent?.length ?? 0) * font * 0.65;
    return {
      x: (measured?.x ?? Number(label.getAttribute("x")) - width / 2) - pad,
      y: (measured?.y ?? Number(label.getAttribute("y")) - font) - pad,
      width: width + 2 * pad,
      height: (measured?.height ?? font) + 2 * pad,
    };
  };
  for (const label of labels.filter((l) =>
    l.hasAttribute("data-manual-position"),
  ))
    occupied.push(box(label));
  for (const label of labels.filter(
    (l) => !l.hasAttribute("data-manual-position"),
  )) {
    const original = box(label);
    if (!occupied.some((b) => overlaps(original, b))) {
      occupied.push(original);
      continue;
    }
    let chosen: Box | undefined;
    for (let ring = 1; ring <= 8 && !chosen; ring++) {
      for (const [dx, dy] of [
        [0, -ring * original.height],
        [0, ring * original.height],
        [-ring * original.width, 0],
        [ring * original.width, 0],
      ]) {
        const candidate = {
          ...original,
          x: original.x + dx,
          y: original.y + dy,
        };
        if (!occupied.some((b) => overlaps(candidate, b))) {
          chosen = candidate;
          break;
        }
      }
    }
    // A final lane above all labels guarantees separation in dense sketches.
    chosen ??= {
      ...original,
      y: Math.min(...occupied.map((b) => b.y)) - original.height,
    };
    label.setAttribute(
      "x",
      String(Number(label.getAttribute("x")) + chosen.x - original.x),
    );
    label.setAttribute(
      "y",
      String(Number(label.getAttribute("y")) + chosen.y - original.y),
    );
    updateDimensionLabelLeader(label);
    occupied.push(chosen);
  }
}
