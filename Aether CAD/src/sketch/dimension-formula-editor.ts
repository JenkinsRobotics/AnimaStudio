import {
  evaluateDocumentVariables,
  type DocumentVariable,
} from "@aether/core/document";
import {
  dimensionDriver,
  setDimensionExpression,
  type DrawingConstraint,
  type SketchDrawing,
} from "@aether/core/sketch";

/** Presentation only. Formula evaluation and geometry solving remain in Core. */
export function mountDimensionFormulaEditor(
  parent: HTMLElement,
  constraint: DrawingConstraint,
  drawing: () => SketchDrawing,
  variables: () => readonly DocumentVariable[] | undefined,
  commit: (drawing: SketchDrawing) => void,
  report: (message: string) => void,
) {
  const driver = dimensionDriver(drawing(), constraint);
  const target = driver.valueExpression !== undefined ? driver : constraint;
  const root = document.createElement("details"),
    title = document.createElement("summary"),
    label = document.createElement("label"),
    input = document.createElement("input"),
    hint = document.createElement("p");
  title.textContent = "Dimension formula";
  root.open = target.valueExpression !== undefined;
  input.type = "text";
  input.value = target.valueExpression ?? "";
  input.setAttribute("aria-label", `Formula for ${constraint.id}`);
  input.dataset.formulaDimensionId = constraint.id;
  input.placeholder =
    constraint.kind === "angle" ? "#angle + 10 deg" : "#diameter / 2";
  label.append("Formula", input);
  hint.textContent =
    target.id !== constraint.id
      ? `Edits shared driver ${target.id}; linked dimensions update together.`
      : "Use #variables and explicit units (for example 10 mm or 45 deg). Applying a formula replaces this dimension's link.";
  const apply = document.createElement("button"),
    remove = document.createElement("button");
  apply.type = remove.type = "button";
  apply.textContent = "Apply formula";
  remove.textContent = "Remove formula";
  remove.disabled = target.valueExpression === undefined;
  const run = (expression: string | null) => {
    try {
      commit(
        setDimensionExpression(
          drawing(),
          target.id,
          expression,
          evaluateDocumentVariables(variables()),
        ),
      );
    } catch (error) {
      report((error as Error).message);
    }
  };
  apply.onclick = () => run(input.value);
  remove.onclick = () => run(null);
  input.onkeydown = (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      run(input.value);
    }
  };
  root.append(title, label, hint, apply, remove);
  parent.append(root);
  return () => {
    apply.onclick = remove.onclick = null;
    input.onkeydown = null;
    root.remove();
  };
}
