/** Sketch feature editor — window layout, controls, and validation. */
import { demoCheckbox, sketchDocument, validatedFeatureWindow } from "./shared";

export const buildSketchDemo = (host: HTMLElement) => {
  return validatedFeatureWindow(host, {
    title: "Sketch 6",
    accept: "Apply sketch",
    caption: "Sketch plane",
    entities: ["Top plane"],
    document: sketchDocument,
    build: (win, mountEntities) => {
      mountEntities();
      for (const label of ["Disable imprinting", "Show constraints", "Show expressions", "Show errors"])
        win.row(label, demoCheckbox());
    },
  });
};
