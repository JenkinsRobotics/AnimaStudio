import { mountDimensionFormulaEditor } from "./dimension-formula-editor";
import type { DocumentVariable } from "@aether/core/document";
import { mountDimensionLinkEditor } from "./dimension-link-editor";
import { bindDimensionInput } from "./dimension-input";
import { mountContactModeEditor } from "./contact-mode-editor";
import { mountQuadrantEditor } from "./quadrant-editor";
import { mountPatternGroupEditor } from "./pattern-group-editor";
import { mountMirrorRelationEditor } from "./mirror-relation-editor";
import {
  isMirrorRelation,
  setPatternInstanceSuppressed,
  setDimensionReference,
  dimensionValue,
  dimensionDriver,
  editDrawingDimension,
  removeDrawingConstraint,
  referenceDimensionKinds,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Presentation and actions for saved relations. Core owns every mutation;
 * the creation panel retains only creation inputs and dimension-focus routing. */
export function renderSavedConstraints(
  constraintsList: HTMLElement,
  getDrawing: () => SketchDrawing,
  commit: (drawing: SketchDrawing) => void,
  message: HTMLElement,
  variables: () => readonly DocumentVariable[] | undefined = () => undefined,
) {
  const button = (text: string, run: () => void, parent: HTMLElement) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.onclick = run;
    parent.append(b);
    return b;
  };
  const disposals: (() => void)[] = [];
  constraintsList.replaceChildren();
  const shownPatternGroups = new Set<string>();
  for (const constraint of getDrawing().constraints ?? []) {
    const row = document.createElement("div");
    row.textContent =
      constraint.kind +
      (constraint.value !== undefined ? ` ${constraint.value}` : "");
    row.dataset.constraintKind = constraint.kind;
    row.dataset.constraintId = constraint.id;
    constraintsList.append(row);
    mountContactModeEditor(
      row,
      getDrawing,
      constraint,
      commit,
      (text) => (message.textContent = text),
    );
    if (constraint.kind === "quadrant")
      mountQuadrantEditor(
        row,
        getDrawing,
        constraint,
        commit,
        (text) => (message.textContent = text),
      );
    if (constraint.patternGroup) {
      row.setAttribute("data-pattern-instance", constraint.id);
      row.prepend(
        document.createTextNode(
          `Instance ${(constraint.patternInstance ?? 0) + 1} · `,
        ),
      );
      button(
        constraint.patternSuppression
          ? "Unsuppress instance"
          : "Suppress instance",
        () => {
          try {
            commit(
              setPatternInstanceSuppressed(
                getDrawing(),
                constraint.id,
                !constraint.patternSuppression,
              ),
            );
          } catch (error) {
            message.textContent = (error as Error).message;
          }
        },
        row,
      );
    }
    if (
      constraint.patternGroup &&
      !shownPatternGroups.has(constraint.patternGroup)
    ) {
      shownPatternGroups.add(constraint.patternGroup);
      mountPatternGroupEditor(
        row,
        getDrawing,
        constraint.patternGroup,
        commit,
        (text) => (message.textContent = text),
      );
    }
    if (isMirrorRelation(constraint))
      mountMirrorRelationEditor(
        row,
        getDrawing,
        constraint,
        commit,
        (text) => (message.textContent = text),
      );
    if (
      [
        "distance",
        "horizontal-distance",
        "vertical-distance",
        "length",
        "radius",
        "diameter",
        "angle",
        "offset",
        "slot",
      ].includes(constraint.kind)
    ) {
      const input = document.createElement("input");
      input.type = "text";
      input.step = "any";
      input.setAttribute("aria-label", `${constraint.kind} value`);
      input.dataset.dimensionId = constraint.id;
      const caption = document.createElement("span");
      row.firstChild?.replaceWith(caption);
      const binding = bindDimensionInput(
        input,
        () => constraint.kind,
        (unit, format) => {
          caption.textContent = `${constraint.kind} ${format(dimensionValue(getDrawing(), constraint))} ${unit}`;
        },
      );
      binding.write(dimensionValue(getDrawing(), constraint));
      disposals.push(binding.dispose);
      const formulaDriver = constraint.reference
        ? undefined
        : dimensionDriver(getDrawing(), constraint);
      const formulaBound = formulaDriver?.valueExpression !== undefined;
      input.readOnly = !!constraint.reference || formulaBound;
      if (formulaBound)
        row.append(
          document.createTextNode(
            ` (formula: ${formulaDriver!.valueExpression})`,
          ),
        );
      if (constraint.reference)
        row.append(document.createTextNode(" (reference)"));
      if (constraint.valueFrom) {
        const link = document.createElement("span");
        link.textContent = " (linked)";
        row.append(link);
      }
      row.append(input);
      if (!constraint.reference && !formulaBound)
        button(
          "Update",
          () => {
            try {
              if (!input.value.trim())
                throw new Error("Enter a dimension value.");
              commit(
                editDrawingDimension(
                  getDrawing(),
                  constraint.id,
                  binding.read(),
                ),
              );
            } catch (error) {
              message.textContent = (error as Error).message;
            }
          },
          row,
        );
      if (!constraint.reference)
        disposals.push(
          mountDimensionLinkEditor(
            row,
            constraint,
            getDrawing,
            commit,
            (text) => {
              message.textContent = text;
            },
          ),
        );
      if (!constraint.reference)
        disposals.push(
          mountDimensionFormulaEditor(
            row,
            constraint,
            getDrawing,
            variables,
            commit,
            (text) => {
              message.textContent = text;
            },
          ),
        );
      if (referenceDimensionKinds.some((kind) => kind === constraint.kind))
        button(
          constraint.reference ? "Make driving" : "Make reference",
          () => {
            try {
              commit(
                setDimensionReference(
                  getDrawing(),
                  constraint.id,
                  !constraint.reference,
                ),
              );
              if (!constraint.reference)
                message.textContent =
                  "Reference dimension created. Any dependent dimensions retain their current values as independent drivers.";
            } catch (error) {
              message.textContent = (error as Error).message;
            }
          },
          row,
        );
    }
    button(
      "Remove",
      () => {
        try {
          commit(removeDrawingConstraint(getDrawing(), constraint.id));
        } catch (error) {
          message.textContent = (error as Error).message;
        }
      },
      row,
    );
  }
  return () => disposals.forEach((dispose) => dispose());
}
