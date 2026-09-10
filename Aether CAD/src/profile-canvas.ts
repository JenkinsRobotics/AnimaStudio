/** A 2D editing surface for the persisted, millimeter-valued profile controls. */
export function mountProfileCanvas(
  form: HTMLFormElement,
  controls: Record<string, HTMLInputElement | HTMLSelectElement>,
  unit = "mm",
  millimetersPerUnit = 1,
) {
  const ns = "http://www.w3.org/2000/svg";
  const wrap = document.createElement("section");
  wrap.className = "profile-canvas";
  const note = document.createElement("p");
  note.textContent = `${unit} · 1 mm physical snap. Polygon: click to add points, drag vertices to move them. Circle: click center, then click its radius.`;
  wrap.append(note);
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute(
    "viewBox",
    `${-50 / millimetersPerUnit} ${-50 / millimetersPerUnit} ${100 / millimetersPerUnit} ${100 / millimetersPerUnit}`,
  );
  svg.setAttribute("aria-label", "Sketch profile canvas");
  svg.setAttribute("role", "img");
  svg.style.touchAction = "none";
  wrap.append(svg);
  const tool = document.createElement("div");
  wrap.append(tool);
  const command = (label: string, run: () => void) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    b.onclick = run;
    tool.append(b);
  };
  let circleStep = 0,
    dragIndex: number | null = null;
  let bounds = {
    x: -50 / millimetersPerUnit,
    y: -50 / millimetersPerUnit,
    size: 100 / millimetersPerUnit,
  };
  const points = () =>
    controls.points.value.trim()
      ? controls.points.value
          .split(";")
          .map((p) => p.trim().split(",").map(Number))
      : [];
  const write = (p: number[][]) => {
    controls.points.value = p.map((v) => v.join(",")).join("; ");
    render();
  };
  const element = (tag: string, attrs: Record<string, string | number>) => {
    const e = document.createElementNS(ns, tag);
    for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
    svg.append(e);
    return e;
  };
  const render = () => {
    svg.replaceChildren();
    const size = bounds.size;
    const step = Math.max(
      5 / millimetersPerUnit,
      (Math.round((size * millimetersPerUnit) / 100) * 5) / millimetersPerUnit,
    );
    for (
      let x = Math.ceil(bounds.x / step) * step;
      x < bounds.x + size;
      x += step
    )
      element("line", {
        x1: x,
        y1: bounds.y,
        x2: x,
        y2: bounds.y + size,
        stroke: "#29394b",
        "stroke-width": size / 500,
      });
    for (
      let y = Math.ceil(bounds.y / step) * step;
      y < bounds.y + size;
      y += step
    )
      element("line", {
        x1: bounds.x,
        y1: y,
        x2: bounds.x + size,
        y2: y,
        stroke: "#29394b",
        "stroke-width": size / 500,
      });
    element("line", {
      x1: 0,
      y1: bounds.y,
      x2: 0,
      y2: bounds.y + size,
      stroke: "#51947e",
      "stroke-width": size / 300,
    });
    element("line", {
      x1: bounds.x,
      y1: 0,
      x2: bounds.x + size,
      y2: 0,
      stroke: "#a16472",
      "stroke-width": size / 300,
    });
    const circle = controls.shape.value === "circle";
    for (const key of ["radius", "center"])
      controls[key].parentElement!.hidden = !circle;
    controls.points.parentElement!.hidden = circle;
    if (circle) {
      const [x, y] = controls.center.value.split(",").map(Number);
      const r = Number(controls.radius.value);
      if ([x, y, r].every(Number.isFinite) && r > 0) {
        element("circle", {
          cx: x,
          cy: -y,
          r,
          fill: "#3d94ee22",
          stroke: "#72baff",
          "stroke-width": size / 220,
        });
        element("circle", { cx: x, cy: -y, r: size / 150, fill: "#fff" });
      }
    } else {
      const p = points();
      if (p.every((v) => v.length === 2 && v.every(Number.isFinite))) {
        element("polygon", {
          points: p.map(([x, y]) => `${x},${-y}`).join(" "),
          fill: "#3d94ee22",
          stroke: "#72baff",
          "stroke-width": size / 220,
        });
        p.forEach(([x, y], i) => {
          const handle = element("circle", {
            cx: x,
            cy: -y,
            r: size / 100,
            fill: "#eaf5ff",
            "data-vertex": i,
          });
          handle.style.cursor = "grab";
        });
      }
    }
  };
  const coordinate = (event: PointerEvent) => {
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const p = point.matrixTransform(svg.getScreenCTM()!.inverse());
    return [
      Math.round(p.x * millimetersPerUnit) / millimetersPerUnit,
      Math.round(-p.y * millimetersPerUnit) / millimetersPerUnit,
    ];
  };
  svg.onpointerdown = (e) => {
    e.preventDefault();
    const point = coordinate(e);
    const index = (e.target as Element).getAttribute("data-vertex");
    if (index !== null) {
      dragIndex = Number(index);
      svg.setPointerCapture(e.pointerId);
      return;
    }
    if (controls.shape.value === "polygon") write([...points(), point]);
    else {
      if (circleStep === 0) {
        controls.center.value = point.join(",");
        circleStep = 1;
      } else {
        const center = controls.center.value.split(",").map(Number);
        controls.radius.value = String(
          Math.max(
            1 / millimetersPerUnit,
            Math.round(
              Math.hypot(point[0] - center[0], point[1] - center[1]) *
                100 *
                millimetersPerUnit,
            ) /
              (100 * millimetersPerUnit),
          ),
        );
        circleStep = 0;
      }
      render();
    }
  };
  svg.onpointermove = (e) => {
    if (dragIndex === null) return;
    const p = points();
    p[dragIndex] = coordinate(e);
    write(p);
  };
  svg.onpointerup = () => (dragIndex = null);
  svg.onpointercancel = () => (dragIndex = null);
  command("Clear polygon", () => {
    controls.shape.value = "polygon";
    write([]);
  });
  command("Undo point", () => write(points().slice(0, -1)));
  command("Fit sketch", () => {
    const circle = controls.shape.value === "circle",
      center = controls.center.value.split(",").map(Number),
      r = Number(controls.radius.value);
    const p = circle
      ? [
          [center[0] - r, center[1] - r],
          [center[0] + r, center[1] + r],
        ]
      : points();
    if (!p.length || !p.every((v) => v.every(Number.isFinite))) return;
    const xs = p.map((v) => v[0]),
      ys = p.map((v) => -v[1]);
    const size =
      Math.max(
        20 / millimetersPerUnit,
        Math.max(...xs) - Math.min(...xs),
        Math.max(...ys) - Math.min(...ys),
      ) * 1.3;
    bounds = {
      x: (Math.max(...xs) + Math.min(...xs) - size) / 2,
      y: (Math.max(...ys) + Math.min(...ys) - size) / 2,
      size,
    };
    svg.setAttribute("viewBox", `${bounds.x} ${bounds.y} ${size} ${size}`);
    render();
  });
  for (const control of Object.values(controls))
    control.addEventListener("input", render);
  form.append(wrap);
  render();
}
