/** Revolve feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoWindow } from "./shared";

export const buildRevolveDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Revolve 1", "Apply revolve");
  win.tabs(["Solid", "Surface", "Thin"]);
  win.tabs(["New", "Add", "Remove", "Intersect"]);
  const regions = win.entitiesBox("Faces and sketch regions to revolve");
  const axis = win.entitiesBox("Revolve axis");
  let hasRegion = true;
  let hasAxis = true;
  const validate = () =>
    win.setError(!hasRegion ? "Revolve needs a profile region." : !hasAxis ? "Revolve needs an axis." : null);
  const render = () => {
    regions.render(hasRegion ? [{ label: "Sketch 6", onRemove: () => { hasRegion = false; render(); validate(); } }] : []);
    axis.render(hasAxis ? [{ label: "Origin · Y axis", onRemove: () => { hasAxis = false; render(); validate(); } }] : []);
  };
  render();
  const full = demoCheckbox();
  full.checked = true;
  win.row("Full revolve", full);
  validate();
};
