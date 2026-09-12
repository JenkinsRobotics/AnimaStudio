/** Loft feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoWindow } from "./shared";

export const buildLoftDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Loft 1", "Apply loft");
  win.tabs(["Solid", "Surface", "Thin"]);
  win.tabs(["New", "Add", "Remove", "Intersect"]);
  const profiles = win.entitiesBox("Profiles");
  let items = ["Sketch 6", "Sketch 7"];
  const validate = () => win.setError(items.length >= 2 ? null : "Loft needs at least two profiles.");
  const render = () => {
    profiles.render(
      items.map((label, index) => ({
        label,
        onRemove: () => {
          items = items.filter((_, at) => at !== index);
          render();
          validate();
        },
      })),
    );
  };
  render();
  win.row("Start profile condition", win.picker(["None", "Normal", "Tangent"], { ariaLabel: "Start profile condition" }).element);
  win.row("End profile condition", win.picker(["None", "Normal", "Tangent"], { ariaLabel: "End profile condition" }).element);
  for (const label of ["Guides and continuity", "Path", "Connections", "Show isocurves"])
    win.row(label, demoCheckbox());
  validate();
};
