/** Relocate linear dimension graphics from current label coordinates. Source
 * endpoints are render-time attributes and never a second persisted model. */
export function updateLinearDimensionLayout(label: SVGTextElement) {
  const group = label.parentElement,
    axis = group?.getAttribute("data-dimension-axis");
  if (!group || !axis) return;
  const extensions = Array.from(
    group.querySelectorAll<SVGLineElement>("[data-dimension-extension]"),
  );
  const measure = group.querySelector<SVGLineElement>(
    "[data-dimension-measure]",
  );
  if (extensions.length !== 2 || !measure) return;
  const gap = Number(group.getAttribute("data-label-gap"));
  const a = [
    Number(extensions[0].getAttribute("x1")),
    Number(extensions[0].getAttribute("y1")),
  ];
  const b = [
    Number(extensions[1].getAttribute("x1")),
    Number(extensions[1].getAttribute("y1")),
  ];
  if (axis === "x") a[1] = b[1] = Number(label.getAttribute("y")) + gap;
  else if (axis === "y") a[0] = b[0] = Number(label.getAttribute("x"));
  else {
    const dx = b[0] - a[0],
      dy = b[1] - a[1],
      length = Math.hypot(dx, dy);
    if (length < 1e-10) return;
    const nx = -dy / length,
      ny = dx / length;
    const offset =
      (Number(label.getAttribute("x")) - a[0]) * nx +
      (Number(label.getAttribute("y")) + gap - a[1]) * ny;
    for (const p of [a, b]) {
      p[0] += offset * nx;
      p[1] += offset * ny;
    }
  }
  for (const [i, p] of [a, b].entries()) {
    extensions[i].setAttribute("x2", String(p[0]));
    extensions[i].setAttribute("y2", String(p[1]));
  }
  for (const [key, value] of Object.entries({
    x1: a[0],
    y1: a[1],
    x2: b[0],
    y2: b[1],
  }))
    measure.setAttribute(key, String(value));
  label.setAttribute("data-guide-x", String((a[0] + b[0]) / 2));
  label.setAttribute("data-guide-y", String((a[1] + b[1]) / 2));
}
