type Point = [number, number];
const originals = new WeakMap<
  Element,
  { nodes: { node: Element; attributes: [string, string][] }[]; anchor: Point }
>();
/** Presentation-only relocation. Rendered Core geometry is supplied as local
 * attributes, and cancellation restores the original automatic layout. */
export function updateCurvedDimensionLayout(
  label: SVGTextElement,
  manual: boolean,
) {
  const group = label.parentElement,
    raw = group?.getAttribute("data-curved-dimension");
  if (!group || !raw) return;
  const data = JSON.parse(raw) as {
    kind: string;
    center: Point;
    radius?: number;
    startAngle?: number;
    sweep?: number;
  };
  if (!originals.has(group))
    originals.set(group, {
      nodes: Array.from(
        group.querySelectorAll(
          "[data-dimension-measure],[data-dimension-extension],path",
        ),
      ).map((node) => ({
        node,
        attributes: Array.from(node.attributes).map((a) => [a.name, a.value]),
      })),
      anchor: [
        Number(label.getAttribute("data-guide-x")),
        Number(label.getAttribute("data-guide-y")),
      ],
    });
  if (!manual) {
    const saved = originals.get(group)!;
    for (const { node, attributes } of saved.nodes)
      for (const [key, value] of attributes) node.setAttribute(key, value);
    label.setAttribute("data-guide-x", String(saved.anchor[0]));
    label.setAttribute("data-guide-y", String(saved.anchor[1]));
    return;
  }
  const target: Point = [
    Number(label.getAttribute("x")),
    -Number(label.getAttribute("y")),
  ];
  const center = data.center,
    dx = target[0] - center[0],
    dy = target[1] - center[1],
    distance = Math.hypot(dx, dy);
  const at = (angle: number, r: number): Point => [
    center[0] + r * Math.cos(angle),
    center[1] + r * Math.sin(angle),
  ];
  const setLine = (line: Element, p: Point, q: Point) => {
    for (const [key, value] of Object.entries({
      x1: p[0],
      y1: -p[1],
      x2: q[0],
      y2: -q[1],
    }))
      line.setAttribute(key, String(value));
  };
  let anchor: Point;
  if (data.kind === "angle") {
    const r = Math.max(distance / 1.3, 1e-6),
      start = data.startAngle!,
      sweep = data.sweep!,
      p = at(start, r),
      q = at(start + sweep, r);
    const extensions = group.querySelectorAll("[data-dimension-extension]");
    if (extensions.length !== 2) return;
    setLine(extensions[0], center, p);
    setLine(extensions[1], center, q);
    group
      .querySelector("path")
      ?.setAttribute(
        "d",
        `M ${p[0]} ${-p[1]} A ${r} ${r} 0 0 ${sweep >= 0 ? 0 : 1} ${q[0]} ${-q[1]}`,
      );
    anchor = at(start + sweep / 2, r);
  } else {
    if (distance < 1e-10) return;
    let angle = Math.atan2(dy, dx);
    if (data.sweep !== undefined && data.startAngle !== undefined) {
      const tau = 2 * Math.PI,
        travel =
          (((Math.sign(data.sweep) * (angle - data.startAngle)) % tau) + tau) %
          tau;
      if (travel > Math.abs(data.sweep)) {
        const a = at(data.startAngle, data.radius!),
          b = at(data.startAngle + data.sweep, data.radius!);
        angle =
          Math.hypot(target[0] - a[0], target[1] - a[1]) <=
          Math.hypot(target[0] - b[0], target[1] - b[1])
            ? data.startAngle
            : data.startAngle + data.sweep;
      }
    }
    const q = at(angle, data.radius!),
      p = data.kind === "radius" ? center : at(angle + Math.PI, data.radius!);
    const line = group.querySelector("[data-dimension-measure]");
    if (!line) return;
    setLine(line, p, q);
    anchor = q;
  }
  label.setAttribute("data-guide-x", String(anchor[0]));
  label.setAttribute("data-guide-y", String(-anchor[1]));
}
