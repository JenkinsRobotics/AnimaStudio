import {
  addSketchSplineHandle,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";

/** Presentation only: expose and select Core's dimensionable construction handle. */
export function mountSplineHandleControls(
  parent: HTMLElement,
  entity: HTMLSelectElement,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
  chooseTool: (tool: string) => void,
  message: HTMLElement,
) {
  for (const end of ["start", "end"] as const) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = `Select spline ${end} handle`;
    button.onclick = () => {
      try {
        const source = drawing();
        const result = addSketchSplineHandle(
          source,
          JSON.parse(entity.value) as SketchEntityRef,
          end,
        );
        if (result.drawing.contours.length !== source.contours.length)
          commit(result.drawing);
        chooseTool("select");
        entity.value = Array.from(entity.options).find(option => {
          if (!option.value) return false;
          const ref = JSON.parse(option.value) as SketchEntityRef;
          return ref.kind === result.handle.kind && ref.contour === result.handle.contour && ref.index === result.handle.index;
        })?.value ?? "";
        message.textContent =
          "Spline tangent handle selected. Apply length, angle or alignment constraints to this construction line.";
      } catch (error) {
        message.textContent = (error as Error).message;
      }
    };
    parent.append(button);
  }
}
