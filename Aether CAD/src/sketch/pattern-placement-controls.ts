import {
  patternPlacements,
  setPatternPlacementSuppressed,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Placement controls use saved settings and commit one atomic Core operation. */
export function mountPatternPlacementControls(
  parent: HTMLElement,
  getDrawing: () => SketchDrawing,
  id: string,
  commit: (d: SketchDrawing) => void,
  report: (s: string) => void,
) {
  const section = document.createElement("section");
  section.setAttribute("aria-label", "Pattern placements");
  parent.append(section);
  const heading = document.createElement("h4");
  heading.textContent = "Repeated placements";
  section.append(heading);
  const note = document.createElement("p");
  note.textContent =
    "These actions use saved pattern settings and apply to every source contour at the chosen position.";
  section.append(note);
  for (const placement of patternPlacements(getDrawing(), id)) {
    const row = document.createElement("div");
    row.textContent = `Placement ${placement.instance + 1} · ${placement.suppressed}/${placement.relationIds.length} contours suppressed${placement.complete ? "" : " · restore missing instances first"}`;
    section.append(row);
    for (const suppressed of [true, false]) {
      const action = suppressed ? "Suppress placement" : "Restore placement",
        button = document.createElement("button");
      button.type = "button";
      button.textContent = action;
      button.setAttribute("aria-label", `${action} ${placement.instance + 1}`);
      button.disabled =
        !placement.complete ||
        (suppressed
          ? placement.suppressed === placement.relationIds.length
          : placement.suppressed === 0);
      button.onclick = () => {
        try {
          commit(
            setPatternPlacementSuppressed(
              getDrawing(),
              id,
              placement.instance,
              suppressed,
            ),
          );
        } catch (error) {
          report((error as Error).message);
        }
      };
      row.append(button);
    }
  }
}
