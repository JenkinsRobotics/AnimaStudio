import {
  evaluateDocumentVariables,
  type DocumentVariable,
} from "@aether/core/document";
import {
  resolveSketchTextExpression,
  type SketchTextItem,
} from "@aether/core/sketch";

/** Formula presentation only; Core owns evaluation, units and variable scope. */
export function mountTextExpression(
  parent: HTMLElement,
  text: HTMLTextAreaElement,
  variables: () => readonly DocumentVariable[] | undefined,
  changed: () => void,
) {
  const row = document.createElement("label"),
    enabled = document.createElement("input");
  enabled.type = "checkbox";
  enabled.setAttribute("aria-label", "Use text expression");
  row.append(enabled, "Use text expression");
  const formulaRow = document.createElement("label"),
    formula = document.createElement("textarea");
  formula.setAttribute("aria-label", "Text expression");
  formula.rows = 2;
  formula.placeholder = 'roundToPrecision(#length/mm, 2) ~ " mm"';
  formulaRow.append("Text expression", formula);
  const hint = document.createElement("p");
  hint.textContent =
    "Use #variable names and ~ to combine text. Convert lengths or angles to a unit before displaying them.";
  parent.append(row, formulaRow, hint);
  const present = () => {
    text.readOnly = enabled.checked;
    formulaRow.hidden = hint.hidden = !enabled.checked;
  };
  enabled.onchange = () => {
    if (enabled.checked && !formula.value.trim())
      formula.value = JSON.stringify(text.value);
    present();
    changed();
  };
  formula.oninput = changed;
  present();
  return {
    read() {
      if (!enabled.checked) return { expression: null, text: text.value };
      const expressionVariables = evaluateDocumentVariables(variables());
      const resolved = resolveSketchTextExpression(
        formula.value,
        expressionVariables,
      );
      text.value = resolved;
      return { expression: formula.value, text: resolved, expressionVariables };
    },
    load(item: SketchTextItem) {
      enabled.checked = item.expression !== undefined;
      formula.value = item.expression ?? "";
      present();
    },
    reset() {
      enabled.checked = false;
      formula.value = "";
      present();
    },
    dispose() {
      enabled.onchange = formula.oninput = null;
      row.remove();
      formulaRow.remove();
      hint.remove();
      text.readOnly = false;
    },
  };
}
