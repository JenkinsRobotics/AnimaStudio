/** Mate feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoInput, demoUnit, demoWindow } from "./shared";

export const buildMateDemo = (host: HTMLElement) => {
  const win = demoWindow(host, "Revolute 1", "Accept mate");
  const box = win.entitiesBox("Mate connectors");
  let connectors = ["Moving · Bracket · Shaft axis", "Fixed · Base · Hub center"];
  const validate = () =>
    win.setError(connectors.length === 2 ? null : "A mate needs exactly two connectors.");
  const render = () => {
    box.render(
      connectors.map((label, index) => ({
        label,
        onRemove: () => {
          connectors = connectors.filter((_, at) => at !== index);
          render();
          validate();
        },
      })),
    );
  };
  render();
  win.body.append(win.picker(["Fastened", "Revolute", "Slider", "Cylindrical", "Pin slot", "Planar", "Ball"], { ariaLabel: "Mate type" }).element);
  win.row("Flip primary axis", demoCheckbox());
  win.row("Offset Z", demoInput("12"), demoUnit("mm"));
  validate();
};
