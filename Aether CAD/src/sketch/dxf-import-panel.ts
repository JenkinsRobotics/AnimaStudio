import { mountDxfLayerControl } from "./dxf-layer-control";
import { mountDxfPlacement } from "./dxf-placement";
import {
  importDxfSketch,
  moveSketchContours,
  validateSketchDrawing,
  type DxfImport,
  type SketchDrawing,
} from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
/** File reading, units and preview lifecycle; Core owns all DXF interpretation. */
export function mountDxfImportPanel(
  parent: HTMLElement,
  svg: SVGSVGElement,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
) {
  const root = document.createElement("details"),
    summary = document.createElement("summary");
  summary.textContent = "Import DXF";
  root.append(summary);
  parent.append(root);
  const file = document.createElement("input");
  file.type = "file";
  file.accept = ".dxf";
  file.setAttribute("aria-label", "DXF file");
  root.append(file);
  const units = document.createElement("select");
  units.setAttribute("aria-label", "DXF source units");
  for (const [value, text] of [
    ["auto", "From file"],
    ["1", "Millimeters"],
    ["25.4", "Inches"],
    ["10", "Centimeters"],
    ["1000", "Meters"],
  ]) {
    const o = document.createElement("option");
    o.value = value;
    o.textContent = text;
    units.append(o);
  }
  root.append(units);
  const joinLabel = document.createElement("label"),
    join = document.createElement("input");
  join.type = "checkbox";
  join.checked = true;
  join.setAttribute("aria-label", "Join connected DXF edges");
  joinLabel.append(join, "Join connected edges");
  root.append(joinLabel);
  const holesLabel = document.createElement("label"),
    holes = document.createElement("input");
  holes.type = "checkbox";
  holes.checked = true;
  holes.setAttribute("aria-label", "Detect DXF holes");
  holesLabel.append(holes, "Detect nested holes");
  root.append(holesLabel);
  const status = document.createElement("p");
  status.setAttribute("role", "status");
  root.append(status);
  const apply = document.createElement("button");
  apply.type = "button";
  apply.textContent = "Insert DXF";
  apply.disabled = true;
  root.append(apply);
  const cancel = document.createElement("button");
  cancel.type = "button";
  cancel.textContent = "Cancel DXF";
  root.append(cancel);
  const layers = mountDxfLayerControl(root, () => preview());
  const placement = mountDxfPlacement(root, svg, () => renderPlacement(), drawing);
  let placed: SketchDrawing | undefined;
  let source = "",
    parsed: DxfImport | undefined,
    generation = 0,
    disposed = false;
  const clear = () => svg.querySelector(".sketch-dxf-preview")?.remove();
  const reset = () => {
    generation++;
    source = "";
    layers.source("");
    parsed = undefined;
    placed = undefined;
    placement.reset();
    placement.available(false);
    file.value = "";
    apply.disabled = true;
    status.textContent = "";
    root.open = false;
    clear();
  };
  const preview = () => {
    parsed = undefined;
    try {
      if (source)
        parsed = importDxfSketch(
          source,
          units.value === "auto" ? undefined : Number(units.value),
          { joinConnected: join.checked, classifyHoles: holes.checked, includedLayers: layers.selected() },
        );
    } catch (e) {
      clear();
      placed = undefined;
      apply.disabled = true;
      placement.available(false);
      status.textContent = (e as Error).message;
      return;
    }
    placement.source(parsed?.drawing);
    renderPlacement();
  };
  function renderPlacement() {
    clear();
    placed = undefined;
    apply.disabled = true;
    placement.available(Boolean(parsed));
    if (!parsed) return;
    try {
      placed = moveSketchContours(
        parsed.drawing,
        parsed.drawing.contours.map((_, i) => i),
        placement.transform(),
      );
      const ns = "http://www.w3.org/2000/svg",
        g = document.createElementNS(ns, "g");
      g.classList.add("sketch-dxf-preview");
      g.setAttribute("pointer-events", "none");
      svg.append(g);
      for (const c of placed.contours) {
        const node = document.createElementNS(
          ns,
          c.type === "circle" || c.segments.length === 0 ? "circle" : "path",
        );
        node.classList.add("sketch-preview");
        if (c.type === "circle") {
          node.setAttribute("cx", String(c.center[0]));
          node.setAttribute("cy", String(-c.center[1]));
          node.setAttribute("r", String(c.radius));
        } else if (c.segments.length === 0) {
          node.setAttribute("cx", String(c.start[0]));
          node.setAttribute("cy", String(-c.start[1]));
          node.setAttribute("r", "0.3");
        } else node.setAttribute("d", contourPath(c));
        g.append(node);
      }
      status.textContent = `${parsed.entityCount} entities · ${placed.contours.filter((c) => c.hole).length} holes · ${parsed.millimetersPerUnit} mm per source unit`;
      apply.disabled = false;
    } catch (e) {
      status.textContent = (e as Error).message;
    }
  }
  file.onchange = async () => {
    const selected = file.files?.[0],
      request = ++generation;
    source = "";
    layers.source("");
    parsed = undefined;
    placed = undefined;
    placement.reset();
    placement.available(false);
    apply.disabled = true;
    clear();
    if (!selected) return;
    try {
      const text = await selected.text();
      if (disposed || request !== generation) return;
      source = text;
      layers.source(text);
      preview();
    } catch (e) {
      if (!disposed && request === generation)
        status.textContent = (e as Error).message;
    }
  };
  units.onchange = preview;
  join.onchange = preview;
  holes.onchange = preview;
  cancel.onclick = reset;
  apply.onclick = () => {
    if (!placed) return;
    try {
      const next = structuredClone(drawing());
      next.contours.push(...placed.contours);
      validateSketchDrawing(next);
      commit(next);
      reset();
    } catch (e) {
      status.textContent = (e as Error).message;
    }
  };
  const requestImport = () => {
    root.open = true;
    file.click();
  };
  window.addEventListener("aether-sketch-import-dxf", requestImport);
  return {
    dispose() {
      window.removeEventListener("aether-sketch-import-dxf", requestImport);
      disposed = true;
      placement.dispose();
      reset();
      root.remove();
    },
  };
}
