import { cadCommands } from "../cad-command-registry";
/** The ribbon command is enabled only after the sketch plane is selected. */
export function registerSketchTextCommand() {
  const unregister = cadCommands.register("sketch-text", () => {
    window.dispatchEvent(
      new CustomEvent("aether-sketch-tool", { detail: "select" }),
    );
    window.dispatchEvent(new Event("aether-sketch-text"));
  });
  cadCommands.setEnabled("sketch-text", false);
  const mode = (event: Event) =>
    cadCommands.setEnabled(
      "sketch-text",
      Boolean((event as CustomEvent).detail),
    );
  window.addEventListener("aether-sketch-mode", mode);
  return () => {
    unregister();
    window.removeEventListener("aether-sketch-mode", mode);
    cadCommands.setEnabled("sketch-text", false);
  };
}
