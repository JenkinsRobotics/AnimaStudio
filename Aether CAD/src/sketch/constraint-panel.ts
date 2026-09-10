import { mountConstraintFormula } from "./constraint-formula";
import type { DocumentVariable } from "@aether/core/document";
import { bindDimensionInput } from "./dimension-input";
import { quadrantFrame, quadrantSpan } from "@aether/core/sketch";
import { renderSavedConstraints } from "./saved-constraints";
import { mountPolygonControls } from "./polygon-controls";
import { mountOriginControl } from "./origin-control";
import { mountEllipseAxisControls } from "./ellipse-axis-controls";
import { mountCenterControls } from "./center-controls";
import { mountSplineHandleControls } from "./spline-handle-controls";
import {
  referenceDimensionKinds,
  resolve,
  nearestEllipseQuadrant,
  sketchEntityPoint,
  drawingConstraintKinds,
  sketchEntities,
  projectedSketchEntities,
  solveDrawingConstraints,
  contourClosed,
  validateSketchDrawing,
  type DrawingConstraintKind,
  type SketchEntityRef,
  type SketchPoint,
  type SketchDrawing,
} from "@aether/core/sketch";
interface Options {
  parent: HTMLElement;
  svg: SVGSVGElement;
  getDrawing: () => SketchDrawing;
  getVariables?: () => readonly DocumentVariable[] | undefined;
  commit: (drawing: SketchDrawing) => void;
  coordinates: () => SketchPoint;
  chooseTool: (name: string) => void;
  message: HTMLElement;
}
/** Constraint controls edit the canonical drawing through one undoable commit callback. */
export function mountConstraintPanel({
  parent,
  svg,
  getDrawing,
  getVariables = () => undefined,
  commit,
  coordinates,
  chooseTool,
  message,
}: Options) {
  const button = (text: string, run: () => void, parent: HTMLElement) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.onclick = run;
    parent.append(b);
    return b;
  };
  const constraintBox = document.createElement("section");
  constraintBox.className = "sketch-constraints";
  parent.append(constraintBox);
  const constraintTitle = document.createElement("h3");
  constraintTitle.textContent = "Sketch constraints";
  constraintBox.append(constraintTitle);
  const select = (label: string) => {
    const l = document.createElement("label");
    l.textContent = label;
    const input = document.createElement("select");
    input.setAttribute("aria-label", label);
    l.append(input);
    constraintBox.append(l);
    return input;
  };
  const kind = select("Constraint"),
    entityA = select("Entity A"),
    entityB = select("Entity B"),
    axis = select("Symmetry axis");
  for (const name of drawingConstraintKinds.filter(
    (kind) => kind !== "pattern",
  )) {
    const o = document.createElement("option");
    o.value = name;
    o.textContent = name[0].toUpperCase() + name.slice(1).replaceAll("-", " ");
    kind.append(o);
  }
  const valueLabel = document.createElement("label");
  const valueCaption = document.createElement("span");
  valueLabel.append(valueCaption);
  const constraintValue = document.createElement("input");
  constraintValue.type = "text";
  constraintValue.step = "any";
  constraintValue.value = "10";
  constraintValue.setAttribute("aria-label", "Constraint value");
  valueLabel.append(constraintValue);
  const dimensionInput = bindDimensionInput(
    constraintValue,
    () => kind.value,
    (unit) => {
      valueCaption.textContent = `Value (${unit})`;
    },
  );
  constraintBox.append(valueLabel);
  const referenceLabel = document.createElement("label"),
    reference = document.createElement("input");
  reference.type = "checkbox";
  reference.setAttribute("aria-label", "Reference dimension");
  referenceLabel.append(reference, " Reference dimension (measurement only)");
  constraintBox.append(referenceLabel);
  const creationFormula = mountConstraintFormula(constraintBox, constraintValue, getVariables);
  const constraintHint = document.createElement("p");
  constraintBox.append(constraintHint);
  const hints: Record<string, string> = {
    coincident:
      "Select a point and another point, line, circle, arc, ellipse or finite curve contact.",
    quadrant:
      "Select a point and a circle, arc or ellipse. The nearest local-axis endpoint is retained as the ellipse changes.",
    horizontal: "Select a line or two points.",
    vertical: "Select a line or two points.",
    parallel: "Select two lines.",
    perpendicular: "Select two lines.",
    concentric: "Select circle/arc centers or a point.",
    equal: "Select two lines, circles or circular arcs.",
    midpoint: "A: line or arc. B: point.",
    tangent:
      "Select a circle/arc and a line, circle, arc or finite curve contact; or two finite curve contacts.",
    slot: "A: line/arc centerline. Slot width is its cap diameter in the displayed unit.",
    offset:
      "A: source circle, arc or line. B: offset of the same type. Enter signed distance in the displayed unit.",
    pattern:
      "Created by the pattern tools. Remove this relation to detach an instance.",
    "spline-shape":
      "Select a whole fit spline to retain smooth interpolation through its vertices.",
    "ellipse-locus":
      "Select two elliptical arcs to retain the same center, radii and orientation.",
    "ellipse-shape":
      "Select a full ellipse contour to retain its shared radii and orientation.",
    symmetric:
      "Select two points, lines, circles/arcs, ellipses or whole splines and a symmetry line. Splines require matching segment counts; reverse correspondence if drawn in opposite directions.",
    normal:
      "Select a line and circle/arc, or a line and a finite curve contact.",
    curvature:
      "Select two finite curve contacts, or a circle/arc and a finite curve contact, for tangent and matching curvature.",
    distance:
      "Select two points, a point and a line, or two parallel lines; enter the displayed unit. Line distances use perpendicular spacing. Driving line-to-line distance also keeps the lines parallel.",
    "horizontal-distance":
      "Select two points. Signed X distance from A to B in the displayed unit; negative places B left of A.",
    "vertical-distance":
      "Select two points. Signed Y distance from A to B in the displayed unit; negative places B below A.",
    length: "Select a line; enter the displayed unit.",
    radius:
      "Select a circle or circular arc; enter radius in the displayed unit.",
    diameter:
      "Select a circle or circular arc; enter diameter in the displayed unit.",
    angle: "Select two lines; enter signed angle in the displayed unit.",
    fix: "Select a point to hold its current position.",
  };
  const splineDirectionLabel = document.createElement("label"),
    splineDirection = document.createElement("input");
  splineDirection.type = "checkbox";
  splineDirection.setAttribute("aria-label", "Reverse spline correspondence");
  splineDirectionLabel.append(
    splineDirection,
    " Reverse spline correspondence",
  );
  constraintBox.append(splineDirectionLabel);
  const slidingLabel = document.createElement("label"),
    sliding = document.createElement("input");
  sliding.type = "checkbox";
  sliding.setAttribute("aria-label", "Allow curve contacts to slide");
  slidingLabel.append(sliding, " Allow curve contacts to slide");
  constraintBox.append(slidingLabel);
  const updateConstraintInputs = () => {
    dimensionInput.refresh();
    slidingLabel.hidden = ![
      "coincident",
      "tangent",
      "curvature",
      "normal",
    ].includes(kind.value);
    splineDirectionLabel.hidden = kind.value !== "symmetric";
    constraintHint.textContent = hints[kind.value];
    referenceLabel.hidden = !referenceDimensionKinds.some(
      (k) => k === kind.value,
    );
    if (referenceLabel.hidden) reference.checked = false;
    constraintValue.disabled = reference.checked;
    axis.parentElement!.hidden = kind.value !== "symmetric";
    valueLabel.hidden = ![
      "distance",
      "horizontal-distance",
      "vertical-distance",
      "length",
      "radius",
      "diameter",
      "angle",
      "offset",
      "slot",
    ].includes(kind.value);
    creationFormula.sync(!valueLabel.hidden, reference.checked);
    entityB.parentElement!.hidden = [
      "length",
      "radius",
      "diameter",
      "fix",
      "ellipse-shape",
      "spline-shape",
    ].includes(kind.value);
  };
  reference.onchange = updateConstraintInputs;
  kind.onchange = updateConstraintInputs;
  updateConstraintInputs();
  const constraintEvent = (event: Event) => {
    const name = (event as CustomEvent).detail;
    if (drawingConstraintKinds.includes(name)) {
      chooseTool("select");
      kind.value = name;
      updateConstraintInputs();
      tangency.parentElement!.hidden = name !== "tangent";
      constraintBox.scrollIntoView?.({ block: "nearest" });
      entityA.focus();
    }
  };
  window.addEventListener("aether-sketch-constraint", constraintEvent);

  const tangency = select("Tangency");
  for (const mode of ["external", "internal"]) {
    const option = document.createElement("option");
    option.value = mode;
    option.textContent = mode;
    tangency.append(option);
  }
  tangency.parentElement!.hidden = true;
  const update = updateConstraintInputs;
  kind.onchange = () => {
    update();
    tangency.parentElement!.hidden = kind.value !== "tangent";
  };
  let disposeSaved = () => {};
  const constraintsList = document.createElement("div");
  constraintBox.append(constraintsList);
  const editDimensionEvent = (event: Event) => {
    const id = (event as CustomEvent).detail;
    // Tool switching refreshes the panel; retain uncommitted numeric edits.
    const pending = new Map(
      Array.from(
        constraintsList.querySelectorAll<HTMLInputElement>(
          "input[data-dimension-id]",
        ),
        (input) => [input.dataset.dimensionId!, input.value],
      ),
    );
    const pendingFormulas = new Map(Array.from(constraintsList.querySelectorAll<HTMLInputElement>("input[data-formula-dimension-id]"), input=>[input.dataset.formulaDimensionId!,input.value]));
    chooseTool("select");
    for (const input of constraintsList.querySelectorAll<HTMLInputElement>(
      "input[data-dimension-id]",
    )) {
      const value = pending.get(input.dataset.dimensionId!);
      if (value !== undefined && !input.readOnly) input.value = value;
    }
    for (const formula of constraintsList.querySelectorAll<HTMLInputElement>("input[data-formula-dimension-id]")) {
      const value = pendingFormulas.get(formula.dataset.formulaDimensionId!);
      if (value !== undefined) formula.value = value;
    }
    const input = Array.from(
      constraintsList.querySelectorAll<HTMLInputElement>(
        "input[data-dimension-id]",
      ),
    ).find((element) => element.dataset.dimensionId === id);
    const formula = Array.from(constraintsList.querySelectorAll<HTMLInputElement>("input[data-formula-dimension-id]")).find(element=>element.dataset.formulaDimensionId===id);
    if (input?.readOnly && formula) {
      const details = formula.closest("details"); if (details) details.open = true;
      formula.focus(); formula.select(); return;
    }
    if (input) {
      input.scrollIntoView?.({ block: "nearest" });
      input.focus();
      input.select();
    }
  };
  window.addEventListener("aether-sketch-edit-dimension", editDimensionEvent);
  button(
    "Apply constraint",
    () => {
      try {
        if (!entityA.value) throw new Error("Draw and select geometry first.");
        const a = JSON.parse(entityA.value) as SketchEntityRef,
          b = entityB.value
            ? (JSON.parse(entityB.value) as SketchEntityRef)
            : undefined;
        const next = structuredClone(getDrawing());
        const type = kind.value as DrawingConstraintKind;
        if (!slidingLabel.hidden && sliding.checked) {
          if (a.kind === "curve") a.sliding = true;
          if (b?.kind === "curve") b.sliding = true;
        }
        const dimensionFields = creationFormula.read(type, a, dimensionInput.read);
        const fixed = sketchEntityPoint(next, a);
        let quadrant: 0 | 1 | 2 | 3 | undefined;
        if (type === "quadrant") {
          const first = resolve(next, a),
            second = b ? resolve(next, b) : undefined;
          const point = first.point ?? second?.point,
            ellipse =
              quadrantFrame(first) ??
              (second ? quadrantFrame(second) : undefined);
          if (!point || !ellipse)
            throw Error("Select a point and a circle, arc or ellipse.");
          quadrant = nearestEllipseQuadrant(
            ellipse,
            point,
            quadrantSpan(first) ?? (second ? quadrantSpan(second) : undefined),
          );
        }
        next.constraints = [
          ...(next.constraints ?? []),
          {
            id: crypto.randomUUID(),
            kind: type,
            ...(type === "tangent"
              ? { tangentMode: tangency.value as "external" | "internal" }
              : {}),
            a,
            ...(quadrant !== undefined ? { quadrant } : {}),
            ...(type === "symmetric"
              ? {
                  axis: JSON.parse(axis.value),
                  ...(a.kind === "contour" && b?.kind === "contour"
                    ? { splineReversed: splineDirection.checked }
                    : {}),
                }
              : {}),
            ...(!entityB.parentElement!.hidden ? { b } : {}),
            ...(reference.checked ? { reference: true } : {}),
            ...dimensionFields,
            ...(type === "fix" && fixed
              ? { point: [...fixed] as SketchPoint }
              : {}),
          },
        ];
        const solved = solveDrawingConstraints(next);
        validateSketchDrawing(solved);
        commit(solved);
      } catch (error) {
        message.textContent = (error as Error).message;
      }
    },
    constraintBox,
  );
  button(
    "Set selected point / circle center",
    () => {
      try {
        const ref = JSON.parse(entityA.value) as SketchEntityRef;
        const next = structuredClone(getDrawing()),
          c = next.contours[ref.contour];
        const point = sketchEntityPoint(next, ref);
        if (!point) throw new Error("Select a point or a circle center.");
        const px = coordinates()[0],
          py = coordinates()[1];
        if (!Number.isFinite(px) || !Number.isFinite(py))
          throw new Error("Enter finite coordinates.");
        const closed = c.type === "path" && contourClosed(c);
        point[0] = px;
        point[1] = py;
        if (
          closed &&
          c.type === "path" &&
          ref.control === undefined &&
          (ref.index === 0 || ref.index === c.segments.length)
        ) {
          c.start = [px, py];
          c.segments.at(-1)!.end = [px, py];
        }

        const solved = solveDrawingConstraints(next);
        validateSketchDrawing(solved);
        commit(solved);
      } catch (error) {
        message.textContent = (error as Error).message;
      }
    },
    constraintBox,
  );

  const polygon = mountPolygonControls(
    constraintBox,
    svg,
    entityA,
    getDrawing,
    commit,
    message,
  );
  mountOriginControl(
    constraintBox,
    entityB,
    getDrawing,
    commit,
    chooseTool,
    message,
  );
  mountCenterControls(
    constraintBox,
    entityA,
    getDrawing,
    commit,
    chooseTool,
    message,
  );
  mountSplineHandleControls(
    constraintBox,
    entityA,
    getDrawing,
    commit,
    chooseTool,
    message,
  );
  mountEllipseAxisControls(
    constraintBox,
    entityA,
    getDrawing,
    commit,
    chooseTool,
    message,
  );

  return {
    entityA,
    entityB,
    kind,
    hints,
    dispose: () => {
      polygon.dispose();
      dimensionInput.dispose();
      creationFormula.dispose();
      disposeSaved();
      window.removeEventListener("aether-sketch-constraint", constraintEvent);
      window.removeEventListener(
        "aether-sketch-edit-dimension",
        editDimensionEvent,
      );
    },
    refresh() {
      polygon.refresh();
      for (const selector of [entityA, entityB, axis]) {
        const previous = selector.value;
        selector.replaceChildren();
        for (const entity of [
          ...sketchEntities(getDrawing()),
          ...projectedSketchEntities(getDrawing()),
        ]) {
          if (selector === axis && entity.ref.kind !== "line") continue;
          const option = document.createElement("option");
          option.value = JSON.stringify(entity.ref);
          option.textContent = entity.label;
          selector.append(option);
        }
        if ([...selector.options].some((o) => o.value === previous))
          selector.value = previous;
      }
      disposeSaved();
      disposeSaved = renderSavedConstraints(
        constraintsList,
        getDrawing,
        commit,
        message,
        getVariables,
      );
    },
  };
}
