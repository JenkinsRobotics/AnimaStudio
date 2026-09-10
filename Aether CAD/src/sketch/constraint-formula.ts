import {
  evaluateDocumentVariables,
  type DocumentVariable,
} from "@aether/core/document";
import {
  resolveDimensionExpression,
  type DrawingConstraintKind,
  type SketchEntityRef,
} from "@aether/core/sketch";

/** Initial dimension formula controls; Core resolves values before one creation solve. */
export function mountConstraintFormula(
  parent: HTMLElement,
  numeric: HTMLInputElement,
  variables: () => readonly DocumentVariable[] | undefined,
) {
  const root = document.createElement("div"),
    toggleLabel = document.createElement("label"),
    toggle = document.createElement("input"),
    label = document.createElement("label"),
    input = document.createElement("input"),
    hint = document.createElement("p");
  toggle.type = "checkbox";
  toggle.setAttribute("aria-label", "Use constraint formula");
  toggleLabel.append(toggle, "Use formula");
  input.type = "text";
  input.setAttribute("aria-label", "Constraint formula");
  input.placeholder = "#diameter / 2";
  label.append("Formula", input);
  hint.textContent =
    "Use #variables and explicit units, such as 10 mm or 45 deg. The formula remains linked after creation.";
  root.append(toggleLabel, label, hint);
  parent.append(root);
  let dimensional = false,
    reference = false;
  const present = () => {
    root.hidden = !dimensional || reference;
    label.hidden = hint.hidden = !toggle.checked;
    numeric.disabled = reference || (dimensional && toggle.checked);
  };
  toggle.onchange = present;
  present();
  return {
    sync(isDimensional: boolean, isReference: boolean) {
      dimensional = isDimensional;
      reference = isReference;
      present();
    },
    read(
      kind: DrawingConstraintKind,
      a: SketchEntityRef,
      readNumeric: () => number,
    ) {
      if (!dimensional || reference) return {};
      if (!toggle.checked) return { value: readNumeric() };
      return {
        value: resolveDimensionExpression(
          { id: "pending", kind, a },
          input.value,
          evaluateDocumentVariables(variables()),
        ),
        valueExpression: input.value,
      };
    },
    dispose() {
      toggle.onchange = null;
      root.remove();
    },
  };
}
