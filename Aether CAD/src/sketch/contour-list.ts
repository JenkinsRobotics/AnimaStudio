import {
  contourClosed,
  deleteSketchContour,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Contour-level actions use the session's one undoable document commit. */
export function renderContourList(
  root: HTMLElement,
  drawing: SketchDrawing,
  commit: (next: SketchDrawing) => void,
) {
  root.replaceChildren();
  const button = (row: HTMLElement, label: string, run: () => void) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    b.onclick = run;
    row.append(b);
  };
  drawing.contours.forEach((contour, index) => {
    const row = document.createElement("div");
    row.textContent = `${index + 1}. ${contour.type} · ${contourClosed(contour) ? "Closed" : "Open"}`;
    root.append(row);
    button(row, "Delete", () => commit(deleteSketchContour(drawing, index)));
    const toggle = (field: "hole" | "construction") => {
      const next = structuredClone(drawing);
      next.contours[index][field] = !next.contours[index][field];
      commit(next);
    };
    button(
      row,
      contour.construction ? "Make regular geometry" : "Make construction",
      () => toggle("construction"),
    );
    if (contourClosed(contour))
      button(row, contour.hole ? "Make region" : "Make hole", () =>
        toggle("hole"),
      );
  });
}
