import {
  evaluateDocumentVariables,
  type DocumentVariable,
} from "@aether/core/document";
import {
  regenerateSketchTextExpressions,
  regenerateDimensionExpressions,
  type SketchDrawing,
} from "@aether/core/sketch";

/** Edits a sketch-local draft. The owner includes both outputs in one undo step. */
export function mountSketchVariables(
  parent: HTMLElement,
  state: () => { drawing: SketchDrawing; variables?: DocumentVariable[] },
  commit: (drawing: SketchDrawing, variables: DocumentVariable[]) => void,
) {
  const root = document.createElement("details"),
    title = document.createElement("summary");
  title.textContent = "Document variables";
  const rows = document.createElement("div"),
    add = document.createElement("button"),
    apply = document.createElement("button"),
    status = document.createElement("p");
  add.textContent = "Add variable";
  apply.textContent = "Apply variables to sketch";
  add.type = apply.type = "button";
  status.setAttribute("role", "status");
  root.append(title, rows, add, apply, status);
  parent.append(root);
  let signature = "",
    disposed = false,
    generation = 0;
  const changed = () => {
    ++generation;
    apply.disabled = false;
  };
  function row(value: DocumentVariable) {
    const group = document.createElement("fieldset"),
      name = document.createElement("input"),
      kind = document.createElement("select"),
      expression = document.createElement("input"),
      remove = document.createElement("button");
    name.setAttribute("aria-label", "Variable name");
    name.value = value.name;
    kind.setAttribute("aria-label", "Variable type");
    for (const type of ["number", "length", "angle", "string"]) {
      const option = document.createElement("option");
      option.value = option.textContent = type;
      kind.append(option);
    }
    kind.value = value.kind;
    expression.setAttribute("aria-label", "Variable expression");
    expression.value = value.expression;
    remove.type = "button";
    remove.textContent = "Remove variable";
    remove.onclick = () => {
      group.remove();
      changed();
    };
    name.oninput = expression.oninput = kind.onchange = changed;
    group.append(name, kind, expression, remove);
    rows.append(group);
  }
  add.onclick = () => {
    row({ name: "", kind: "number", expression: "0" });
    changed();
  };
  function sync() {
    const current = JSON.stringify(state().variables);
    if (current === signature) return;
    signature = current;
    ++generation;
    apply.disabled = false;
    rows.replaceChildren();
    for (const value of state().variables ?? []) row(value);
  }
  function readRows() {
    return [...rows.children].map((group) => ({
      name: group.querySelector<HTMLInputElement>(
        '[aria-label="Variable name"]',
      )!.value,
      kind: group.querySelector<HTMLSelectElement>("select")!
        .value as DocumentVariable["kind"],
      expression: group.querySelector<HTMLInputElement>(
        '[aria-label="Variable expression"]',
      )!.value,
    }));
  }
  apply.onclick = async () => {
    const request = ++generation,
      source = structuredClone(state()),
      snapshot = JSON.stringify(source);
    apply.disabled = true;
    try {
      const variables = readRows();
      const resolved = evaluateDocumentVariables(variables);
      const drawing = regenerateDimensionExpressions(
        await regenerateSketchTextExpressions(source.drawing, resolved),
        resolved,
      );
      if (disposed || request !== generation) return;
      if (JSON.stringify(state()) !== snapshot)
        throw Error("The sketch changed. Review and apply variables again.");
      commit(drawing, variables);
      sync();
      status.textContent =
        "Variables applied to this draft. Finish sketch saves all affected sketches; Cancel discards these changes.";
    } catch (error) {
      if (!disposed && request === generation)
        status.textContent = (error as Error).message;
    } finally {
      if (!disposed && request === generation) apply.disabled = false;
    }
  };
  sync();
  return {
    sync,
    pending: () =>
      JSON.stringify(readRows()) !== JSON.stringify(state().variables ?? []),
    dispose() {
      disposed = true;
      ++generation;
      root.remove();
    },
  };
}
