import { cadCommands } from "../cad-command-registry";
/** App-lifetime command wiring; the mounted sketch panel owns the file picker. */
export function registerSketchImportCommand() {
  cadCommands.register("sketch-import-dxf", () => {
    window.dispatchEvent(new Event("aether-sketch-import-dxf"));
  });
  cadCommands.setEnabled("sketch-import-dxf", false);
  window.addEventListener("aether-sketch-mode", (event) =>
    cadCommands.setEnabled(
      "sketch-import-dxf",
      Boolean((event as CustomEvent).detail),
    ),
  );
}
