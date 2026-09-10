import {
  addSketchEllipseAxis,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
export function mountEllipseAxisControls(
  parent: HTMLElement,
  entity: HTMLSelectElement,
  drawing: () => SketchDrawing,
  commit: (drawing: SketchDrawing) => void,
  chooseTool: (tool: string) => void,
  message: HTMLElement,
) {
  for (const axis of ["x", "y"] as const) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = `Select ellipse ${axis.toUpperCase()} axis`;
    button.onclick = () => {
      try {
        const result = addSketchEllipseAxis(
          drawing(),
          JSON.parse(entity.value) as SketchEntityRef,
          axis,
        );
        commit(result.drawing);
        chooseTool("select");
        entity.value =
          [...entity.options].find((option) => {
            const ref = JSON.parse(option.value) as SketchEntityRef;
            return (
              ref.kind === result.axis.kind &&
              ref.contour === result.axis.contour &&
              ref.index === result.axis.index
            );
          })?.value ?? "";
        message.textContent =
          "Ellipse axis selected. Set a length for the full axis diameter, or an angle/alignment constraint for orientation.";
      } catch (error) {
        message.textContent = (error as Error).message;
      }
    };
    parent.append(button);
  }
}
