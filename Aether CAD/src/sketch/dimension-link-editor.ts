import {
  linkSketchDimension,
  unlinkSketchDimension,
  referenceDimensionKinds,
  type DrawingConstraint,
  type SketchDrawing,
} from "@aether/core/sketch";
import { evaluateQuantityExpression } from "@aether/core/units";
import { bindDimensionInput } from "./dimension-input";

/** Relationship presentation only; Core validates units/cycles and solves it. */
export function mountDimensionLinkEditor(
  parent: HTMLElement,
  constraint: DrawingConstraint,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
  report: (text: string) => void,
) {
  const box = document.createElement("details"),
    summary = document.createElement("summary");
  summary.textContent = "Dimension relationship";
  box.append(summary);
  const select = document.createElement("select");
  select.setAttribute("aria-label", `Driver for ${constraint.id}`);
  const blank = document.createElement("option");
  blank.value = "";
  blank.textContent = "Choose a driving dimension";
  select.append(blank);
  const angular = constraint.kind === "angle";
  for (const [index, other] of (drawing().constraints ?? []).entries()) {
    if (
      other.id === constraint.id ||
      other.reference ||
      (other.kind === "angle") !== angular ||
      ![...referenceDimensionKinds, "offset", "slot"].includes(other.kind)
    )
      continue;
    const option = document.createElement("option");
    option.value = other.id;
    option.textContent = `${index + 1}: ${other.kind}`;
    select.append(option);
  }
  select.value = constraint.valueFrom ?? "";
  const scale = document.createElement("input"),
    offset = document.createElement("input"),
    offsetLabel = document.createElement("label"),
    caption = document.createElement("span");
  scale.type = offset.type = "text";
  scale.setAttribute("aria-label", `Multiplier for ${constraint.id}`);
  scale.value = String(
    (constraint.valueScale ?? 1) * (constraint.valueSign ?? 1),
  );
  offset.setAttribute("aria-label", `Offset for ${constraint.id}`);
  offsetLabel.append(caption, offset);
  const binding = bindDimensionInput(
    offset,
    () => constraint.kind,
    (unit) => {
      caption.textContent = `Offset (${unit})`;
    },
  );
  binding.write(constraint.valueOffset ?? 0);
  const explanation = document.createElement("p");
  explanation.textContent =
    "This dimension = multiplier × driver + offset. Updating its value also updates the shared driver.";
  const apply = document.createElement("button");
  apply.type = "button";
  apply.textContent = "Apply dimension relationship";
  apply.onclick = () => {
    try {
      commit(
        linkSketchDimension(
          drawing(),
          constraint.id,
          select.value,
          evaluateQuantityExpression(scale.value),
          binding.read(),
        ),
      );
    } catch (error) {
      report((error as Error).message);
    }
  };
  box.append(explanation, select, scale, offsetLabel, apply);
  if (constraint.valueFrom !== undefined) {
    const unlink = document.createElement("button");
    unlink.type = "button";
    unlink.textContent = "Unlink dimension";
    unlink.onclick = () => {
      try {
        commit(unlinkSketchDimension(drawing(), constraint.id));
      } catch (error) {
        report((error as Error).message);
      }
    };
    box.append(unlink);
  }
  parent.append(box);
  return binding.dispose;
}
