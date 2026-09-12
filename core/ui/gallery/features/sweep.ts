/** Sweep feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoWindow } from "./shared";

export const buildSweepDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Sweep 1", "Apply sweep");
  win.tabs(["Solid", "Surface", "Thin"]);
  win.tabs(["New", "Add", "Remove", "Intersect"]);
  const profile = win.entitiesBox("Faces and sketch regions to sweep");
  const path = win.entitiesBox("Sweep path");
  let hasProfile = true;
  let hasPath = true;
  const validate = () =>
    win.setError(!hasProfile ? "Sweep needs a profile." : !hasPath ? "Sweep needs a path." : null);
  const render = () => {
    profile.render(hasProfile ? [{ label: "Sketch 6", onRemove: () => { hasProfile = false; render(); validate(); } }] : []);
    path.render(hasPath ? [{ label: "Curve 1", onRemove: () => { hasPath = false; render(); validate(); } }] : []);
  };
  render();
  win.row("Profile control", win.picker(["None", "Follow path", "Lock direction"], { ariaLabel: "Profile control" }).element);
  win.row("Twist", demoCheckbox());
  win.row("Scale", demoCheckbox());
  validate();
};
