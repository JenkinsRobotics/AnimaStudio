/** Thicken feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoInput, demoUnit, demoWindow } from "./shared";

export const buildThickenDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Thicken 1", "Apply thicken");
  win.tabs(["New", "Add", "Remove", "Intersect"]);
  const faces = win.entitiesBox("Faces and surfaces to thicken");
  let has = true;
  const validate = () => win.setError(has ? null : "Thicken needs a face or surface.");
  const render = () => {
    faces.render(has ? [{ label: "Surface 1", onRemove: () => { has = false; render(); validate(); } }] : []);
  };
  render();
  win.row("Mid plane", demoCheckbox());
  win.row("Thickness 1", demoInput("5"), demoUnit("mm"));
  win.row("Thickness 2", demoInput("0"), demoUnit("mm"));
  win.row("Keep tools", demoCheckbox());
  validate();
};
