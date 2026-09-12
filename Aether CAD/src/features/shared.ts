/** Shared plumbing for the feature editors. One file per feature lives beside
 *  this one, each owning that feature's controls, its window layout, and its
 *  serialization — the three things that used to be spread across three
 *  parallel if/else chains in feature-authoring.ts.
 *
 *  Layouts mirror `core/ui/gallery/features/` exactly: same control types
 *  (pickers, sub-settings, entity boxes), same order, same captions. Where the
 *  engine cannot yet honour a gallery control it stays visible but disabled
 *  with a "Planned" title — the gallery shows the target, this shows the truth. */
import type { openFeatureWindow } from "@aether/ui";
import type { PartDocument } from "@aether/core/document";

export type FeatureWindow = ReturnType<typeof openFeatureWindow>;
export type Control = HTMLInputElement | HTMLSelectElement;
export type Controls = Record<string, Control>;

export interface FeatureEditorContext {
  win: FeatureWindow;
  form: HTMLFormElement;
  /** Unit-aware field factory. `(mm)`/`(degrees)` captions are rewritten to the
   *  document's configured unit and values converted on the way in and out. */
  field: (name: string, value: string, choices?: string[]) => Control;
  /** A `<select>` of earlier features of the given types, labelled by name. */
  reference: (label: string, types: string[], value?: string) => Control;
  /** The feature being edited, or undefined when adding. */
  feature: any;
  doc: PartDocument;
  lengthUnitLabel: string;
  angleUnitLabel: string;
}

export interface FeatureEditor {
  /** Feature `type` as stored in the document. */
  type: string;
  /** Build the form controls this feature needs. */
  controls(context: FeatureEditorContext): Controls;
  /** Lay the controls out in the window, gallery-exact. Optional: features
   *  without a bespoke layout fall back to plain label-left parameter rows. */
  layout?(context: FeatureEditorContext, controls: Controls): void;
  /** What this feature needs before it can be committed, checked live on every
   *  control change. Return an error message, or null when valid. The window
   *  disables its accept control while a message is showing, so an invalid
   *  feature cannot be submitted at all — the same discipline the plane window
   *  uses for its per-method reference count. */
  validate?(controls: Controls, context: FeatureEditorContext): string | null;
  /** Canonical (already unit-converted) values → the feature payload fields.
   *  Identity fields (id/type/name/suppressed) are added by the caller. */
  serialize(values: Record<string, string>, context: FeatureEditorContext): Record<string, unknown>;
}

/** A parameter row inside a nested sub-setting body — the gallery's `rowIn`. */
export function rowIn(label: string, ...controls: HTMLElement[]): HTMLElement {
  const row = document.createElement("div");
  row.className = "aui-feature-row";
  const caption = document.createElement("span");
  caption.textContent = label;
  const control = document.createElement("span");
  control.className = "aui-feature-row-control";
  control.append(...controls);
  row.append(caption, control);
  return row;
}

export function unitSuffix(text: string): HTMLElement {
  const unit = document.createElement("span");
  unit.className = "aui-feature-unit";
  unit.textContent = text;
  return unit;
}

/** A control the gallery shows live but this engine cannot honour yet. Visible
 *  and disabled beats quietly absent: the shape of the feature stays legible. */
export function planned<T extends HTMLElement>(control: T): T {
  (control as unknown as { disabled: boolean }).disabled = true;
  control.title = "Planned — not functional yet.";
  return control;
}

export function plannedCheckbox(): HTMLInputElement {
  const box = document.createElement("input");
  box.type = "checkbox";
  return planned(box);
}

export function textInput(value: string): HTMLInputElement {
  const input = document.createElement("input");
  input.type = "text";
  input.value = value;
  return input;
}

/** Body-type and boolean-operation tab rows. Every solid feature in the gallery
 *  opens with these two, in this order. `operation` is the live control; the
 *  tabs drive it and the select itself is hidden but form-associated. */
export function bodyAndOperationTabs(
  win: FeatureWindow,
  form: HTMLFormElement,
  operation: Control,
  operationValues: readonly string[],
) {
  const solids = win.tabs(["Solid", "Surface", "Thin"], 0);
  [...solids.children].forEach((tab, index) => {
    if (index > 0) planned(tab as HTMLButtonElement);
  });
  const ops = win.tabs(
    ["New", "Add", "Remove", "Intersect"],
    Math.max(0, operationValues.indexOf(operation.value)),
  );
  const opButtons = [...ops.children] as HTMLButtonElement[];
  planned(opButtons[3]);
  opButtons.forEach((tab, index) => {
    if (index >= operationValues.length) return;
    tab.onclick = () => {
      operation.value = operationValues[index];
      operation.dispatchEvent(new Event("change"));
      opButtons.forEach((other, i) => other.classList.toggle("active", i === index));
    };
  });
  operation.closest("label")?.remove();
  operation.setAttribute("form", form.id);
  operation.hidden = true;
  form.append(operation);
}

/** The gallery's Entities box, backed by a real `<select>` of document features:
 *  the current choice shows as a removable chip, and clearing it reveals the
 *  select so another can be picked. */
export function entityChips(win: FeatureWindow, caption: string, source: Control, form: HTMLFormElement) {
  const box = win.entitiesBox(caption);
  source.closest("label")?.remove();
  source.setAttribute("form", form.id);
  box.element.append(source);
  const render = () => {
    const selected = (source as HTMLSelectElement).selectedOptions?.[0];
    box.render(
      source.value && selected
        ? [{ label: selected.textContent ?? source.value, onRemove: () => { source.value = ""; render(); } }]
        : [],
    );
    source.style.display = source.value ? "none" : "";
  };
  source.addEventListener("change", render);
  render();
  return box;
}

/** The common case: named controls that must hold a selection. Nothing is
 *  pre-selected for the user, so "empty" always means "not yet chosen". */
export function requireSelections(
  controls: Controls,
  required: readonly { key: string; noun: string }[],
): string | null {
  const missing = required.filter(({ key }) => !controls[key]?.value);
  if (!missing.length) return null;
  const nouns = missing.map((m) => m.noun);
  const list =
    nouns.length === 1 ? nouns[0] : `${nouns.slice(0, -1).join(", ")} and ${nouns.at(-1)}`;
  return `Select ${list} to continue.`;
}
