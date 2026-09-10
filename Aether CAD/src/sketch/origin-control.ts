import { addSketchOrigin, type SketchDrawing } from "@aether/core/sketch";

/** Pick the origin as the second reference without losing the first selection. */
export function mountOriginControl(
  parent: HTMLElement,
  entityB: HTMLSelectElement,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
  chooseTool: (name: string) => void,
  message: HTMLElement,
) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = "Select sketch origin";
  button.onclick = () => {
    try {
      const before = drawing();
      const result = addSketchOrigin(before);
      if (result.drawing.contours.length !== before.contours.length)
        commit(result.drawing);
      chooseTool("select");
      entityB.value = JSON.stringify(result.origin);
      message.textContent =
        "Sketch origin selected as Entity B. Select Entity A and apply a distance or alignment constraint.";
    } catch (error) {
      message.textContent = (error as Error).message;
    }
  };
  parent.append(button);
}
