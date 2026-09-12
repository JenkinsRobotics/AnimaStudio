/** Enclose feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoWindow } from "./shared";

export const buildEncloseDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Enclose 1", "Apply enclose");
  win.tabs(["New", "Add", "Remove", "Intersect"]);
  const entities = win.entitiesBox("Entities");
  let has = true;
  const validate = () => win.setError(has ? null : "Enclose needs at least one entity.");
  const render = () => {
    entities.render(has ? [{ label: "Body 1", onRemove: () => { has = false; render(); validate(); } }] : []);
  };
  render();
  win.row("Keep tools", demoCheckbox());
  validate();
};
