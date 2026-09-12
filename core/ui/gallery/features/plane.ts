/** Plane feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoInput, demoUnit, demoWindow } from "./shared";

export const buildPlaneDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Plane 2", "Apply plane");
  const box = win.entitiesBox("Entities");
  let refs = ["Top plane"];
  const method = win.picker(["Offset", "Mid plane"], { ariaLabel: "Plane method", onChange: () => validate() });
  const validate = () => {
    const needed = method.value() === "Mid plane" ? 2 : 1;
    win.setError(
      refs.length === needed
        ? null
        : `${method.value()} needs exactly ${needed} reference${needed > 1 ? "s" : ""}.`,
    );
  };
  const render = () => {
    box.render(
      refs.map((label, index) => ({
        label,
        onRemove: () => {
          refs = refs.filter((_, at) => at !== index);
          render();
          validate();
        },
      })),
    );
  };
  render();
  win.body.append(method.element);
  win.row("Offset distance", demoInput("25"), demoUnit("mm"));
  win.row("Flip normal", demoCheckbox());
  validate();
};
