import { mountPatternPlacementControls } from "./pattern-placement-controls";
import {
  missingPatternInstances,
  restorePatternInstances,
  editPatternGroup,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Shared parameter form; Core owns transforms, reseeding and constraint resolution. */
export function mountPatternGroupEditor(
  parent: HTMLElement,
  getDrawing: () => SketchDrawing,
  id: string,
  commit: (d: SketchDrawing) => void,
  report: (s: string) => void,
) {
  const open = document.createElement("button");
  open.type = "button";
  open.textContent = "Edit pattern";
  parent.append(open);
  open.onclick = () => {
    if (parent.querySelector(".sketch-pattern-group-editor")) return;
    const group = getDrawing().patternGroups?.[id];
    if (!group) {
      report("Pattern group is missing.");
      return;
    }
    const draft = structuredClone(group),
      section = document.createElement("section");
    section.className = "sketch-pattern-group-editor";
    section.setAttribute("aria-label", "Edit pattern");
    parent.append(section);
    const note = document.createElement("p");
    note.textContent = `${draft.kind === "linear" ? draft.countFirst * draft.countSecond : draft.count} instances. Counts include the original; removing constrained instances requires resolving their dependencies first.`;
    section.append(note);
    const values: { input: HTMLInputElement; set: (v: number) => void }[] = [];
    const field = (name: string, value: number, set: (v: number) => void) => {
      const label = document.createElement("label"),
        input = document.createElement("input");
      label.textContent = name;
      input.setAttribute("aria-label", name);
      input.type = "number";
      input.step = "any";
      input.value = String(value);
      label.append(input);
      section.append(label);
      values.push({ input, set });
    };
    if (draft.kind === "linear")
      for (const k of [0, 1] as const) {
        field(
          `Pattern spacing ${k ? "Y" : "X"} (mm)`,
          draft.first[k],
          (v) => (draft.first[k] = v),
        );
        field(
          `Pattern second spacing ${k ? "Y" : "X"} (mm)`,
          draft.second[k],
          (v) => (draft.second[k] = v),
        );
      }
    else {
      for (const k of [0, 1] as const)
        field(
          `Pattern center ${k ? "Y" : "X"} (mm)`,
          draft.center[k],
          (v) => (draft.center[k] = v),
        );
      field(
        "Pattern step (degrees)",
        draft.stepDegrees,
        (v) => (draft.stepDegrees = v),
      );
    }
    if (draft.kind === "linear") {
      field("Pattern count", draft.countFirst, (v) => (draft.countFirst = v));
      field(
        "Pattern second count",
        draft.countSecond,
        (v) => (draft.countSecond = v),
      );
    } else field("Pattern count", draft.count, (v) => (draft.count = v));
    const update = document.createElement("button");
    update.type = "button";
    update.textContent = "Update pattern";
    update.onclick = () => {
      try {
        for (const { input, set } of values) {
          if (!input.value.trim() || !Number.isFinite(Number(input.value)))
            throw Error("Enter finite pattern parameters.");
          set(Number(input.value));
        }
        commit(editPatternGroup(getDrawing(), id, draft));
      } catch (error) {
        report((error as Error).message);
      }
    };
    const cancel = document.createElement("button");
    cancel.type = "button";
    cancel.textContent = "Cancel pattern edit";
    cancel.onclick = () => section.remove();
    section.append(update, cancel);
    const missing = missingPatternInstances(getDrawing(), id);
    if (missing.length) {
      const restore = document.createElement("button");
      restore.type = "button";
      restore.textContent = "Restore missing instances";
      const explanation = document.createElement("p");
      explanation.textContent = `${missing.length} missing linked copies. Restore uses saved settings and keeps detached geometry.`;
      restore.onclick = () => {
        try {
          commit(restorePatternInstances(getDrawing(), id));
        } catch (error) {
          report((error as Error).message);
        }
      };
      section.append(explanation, restore);
    }

    mountPatternPlacementControls(section,getDrawing,id,commit,report);
    values[0]?.input.focus();
  };
}
