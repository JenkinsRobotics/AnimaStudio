import { ellipticalArcGuide, type SketchPoint } from "@aether/core/sketch";
/** Optional fixed secondary radius during elliptical-arc placement; blank uses the start point. */
export function mountEllipticalRadiusControl(
  parent: HTMLElement,
  preview: () => void,
) {
  const label = document.createElement("label");
  label.textContent = "Secondary radius (mm)";
  const input = document.createElement("input");
  input.type = "number";
  input.step = "any";
  input.min = "0";
  input.placeholder = "From start point";
  input.setAttribute("aria-label", "Elliptical arc secondary radius (mm)");
  input.addEventListener("input", preview);
  label.append(input);
  parent.append(label);
  label.hidden = true;
  let remembered: number | undefined;
  return {
    observe(tool: string, pending: SketchPoint[], cursor: SketchPoint | null) {
      if (tool !== "elliptical-arc" || pending.length < 2) {
        remembered = undefined;
        return;
      }
      if (pending.length !== 2 || !cursor || input.value.trim()) return;
      try {
        const guide = ellipticalArcGuide([...pending, cursor]);
        const segment = guide.segments[0];
        if (segment.type === "ellipse") remembered = segment.radiusY;
      } catch {
        /* Axis points cannot size a new ellipse; keep the last valid width. */
      }
    },
    remembered: () => remembered,
    value: () => (input.value.trim() ? Number(input.value) : undefined),
    update: (tool: string) => {
      label.hidden = tool !== "elliptical-arc";
    },
  };
}
