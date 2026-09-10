import {
  fitSketchSpline,
  constrainFitSpline,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
} from "@aether/core/sketch";
/** UI lifecycle only; interpolation belongs to Core. Pending points do not
 * enter the document until this explicit finish action succeeds. */
export function mountFitSplineTool(
  parent: HTMLElement,
  root: HTMLElement,
  options: {
    state: () => {
      tool: string;
      pending: SketchPoint[];
      drawing: SketchDrawing;
      construction: boolean;
      busy: boolean;
    };
    commit: (drawing: SketchDrawing) => void;
    error: (message: string) => void;
  },
) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = "Finish spline";
  parent.append(button);
  const close = document.createElement("button");
  close.type = "button";
  close.textContent = "Close spline";
  parent.append(close);
  const finish = (closed = false) => {
    const s = options.state();
    if (s.tool !== "fit-spline" || s.busy) return;
    try {
      const contour = fitSketchSpline(s.pending, { closed });
      if (s.construction) contour.construction = true;
      const next = structuredClone(s.drawing);
      next.contours.push(contour);
      validateSketchDrawing(next);
      options.commit(constrainFitSpline(next, next.contours.length - 1));
    } catch (e) {
      options.error((e as Error).message);
    }
  };
  button.onclick = () => finish();
  close.onclick = () => finish(true);
  const key = (e: KeyboardEvent) => {
    if (
      e.key !== "Enter" ||
      options.state().tool !== "fit-spline" ||
      (e.target as Element | null)?.tagName?.toLowerCase() !== "svg"
    )
      return;
    e.preventDefault();
    e.stopPropagation();
    finish();
  };
  root.addEventListener("keydown", key, true);
  return {
    refresh() {
      const s = options.state();
      close.hidden = s.tool !== "fit-spline";
      close.disabled = s.busy || s.pending.length < 3;
      button.hidden = s.tool !== "fit-spline";
      button.disabled = s.busy || s.pending.length < 2;
    },
    dispose() {
      root.removeEventListener("keydown", key, true);
      button.remove();
      close.remove();
    },
  };
}
