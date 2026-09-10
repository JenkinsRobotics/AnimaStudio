import { textSimilarityCoordinates } from "./text-coordinates";
import { diagnosticResiduals } from "./diagnostic-residuals";
import { ellipseLocusCoordinates } from "./ellipse-locus-coordinates";
import { contactParameterCoordinates } from "./contact-parameters";
import { diagnosticRank } from "./diagnostic-rank";
import { entityObservables } from "./entity-observables";
import type { SketchEntityRef } from "./types";
import { solveDrawingConstraints } from "./solve";
import type { SketchDrawing } from "../drawing";
import { constraintResiduals } from "./residuals";
import { diagnosticCoordinates } from "./diagnostic-coordinates";
export interface SketchConstraintState {
  state:
    | "empty"
    | "under-constrained"
    | "fully-constrained"
    | "over-constrained"
    | "invalid";
  degreesOfFreedom: number | null;
  redundantEquations: number;
  conflictingConstraints: string[];
  message?: string;
}
/** Local Jacobian rank; optional entity DOF measures its mobility in the whole constraint system.
 * Conflict/redundancy flags remain sketch-wide. Never mutates the drawing. */
export function sketchConstraintState(
  source: SketchDrawing,
  entity?: SketchEntityRef,
): SketchConstraintState {
  return sketchConstraintStates(source, [entity])[0];
}
/** Shares coordinate perturbation and constraint equations across a batch of entities. */
export function sketchConstraintStates(
  source: SketchDrawing,
  entities: (SketchEntityRef | undefined)[],
): SketchConstraintState[] {
  const common = (state: SketchConstraintState) =>
    entities.map(() => ({ ...state }));
  const base = {
    degreesOfFreedom: null,
    redundantEquations: 0,
    conflictingConstraints: [] as string[],
  };
  try {
    if (!source.contours.length && entities.every((entity) => !entity))
      return common({ ...base, state: "empty", degreesOfFreedom: 0 });
    const d = structuredClone(source),
      linkedEllipses = ellipseLocusCoordinates(d),
      textGroups = textSimilarityCoordinates(d),
      geometry = [
        ...linkedEllipses.coordinates,
        ...textGroups.coordinates,
        ...diagnosticCoordinates(d, new Set([...linkedEllipses.covered, ...textGroups.covered])),
      ],
      vars = [...geometry, ...contactParameterCoordinates(d)],
      constraints = d.constraints ?? [];
    if (vars.length > 256)
      throw new Error(
        "Constraint-state analysis supports up to 256 geometric coordinates.",
      );
    const conflicts = constraints
      .filter((c) =>
        constraintResiduals(d, c).some(
          (v) => !Number.isFinite(v) || Math.abs(v) > 1e-6,
        ),
      )
      .map((c) => c.id);
    if (conflicts.length) {
      try {
        return sketchConstraintStates(solveDrawingConstraints(d), entities);
      } catch {
        return common({
          ...base,
          state: "over-constrained",
          conflictingConstraints: conflicts,
          message: "The solver cannot satisfy these constraints.",
        });
      }
    }
    // Common-conic coordinates enforce these relations intrinsically. Count
    // graph cycles separately so duplicate constraints remain visible.
    const intrinsic = constraints.filter(
      (c) =>
        c.kind === "ellipse-locus" &&
        !c.reference &&
        linkedEllipses.covered.has(c.a.contour) &&
        c.b?.contour === c.a.contour,
    );
    const intrinsicSet = new Set(intrinsic);
    const activeConstraints = constraints.filter((c) => !intrinsicSet.has(c));
    let intrinsicRedundancy = 0;
    for (const contour of linkedEllipses.covered) {
      const path = d.contours[contour];
      if (path.type === "path")
        intrinsicRedundancy +=
          5 *
          Math.max(
            0,
            intrinsic.filter((c) => c.a.contour === contour).length -
              (path.segments.length - 1),
          );
    }
    const lengths = entities.map((entity) =>
      entity ? entityObservables(d, entity).length : 0,
    );
    const residual = () => [
        ...activeConstraints.flatMap((c) => diagnosticResiduals(d, c)),
        ...entities.flatMap((entity) =>
          entity ? entityObservables(d, entity) : [],
        ),
      ],
      equationCount = activeConstraints.flatMap((c) =>
        diagnosticResiduals(d, c),
      ).length,
      r = residual();
    const columns = vars.map((v) => {
      const value = v.get(),
        h = 1e-5 * Math.max(1, Math.abs(value));
      v.set(value + h);
      const plus = residual();
      v.set(value - h);
      const minus = residual();
      v.set(value);
      return plus.map((x, i) => (x - minus[i]) / (2 * h));
    });
    const rows = r.map((_, i) => columns.map((col) => col[i]));
    const constraintRows = rows.slice(0, equationCount);
    const rank = diagnosticRank(constraintRows);

    const redundant =
      intrinsicRedundancy +
      constraintRows.filter((row) => Math.hypot(...row) > 1e-8).length -
      rank;
    let offset = equationCount;
    return entities.map((entity, index) => {
      const selectedRows = rows.slice(offset, offset + lengths[index]);
      offset += lengths[index];
      const dof = entity
        ? diagnosticRank([...constraintRows, ...selectedRows]) - rank
        : geometry.length -
          rank +
          diagnosticRank(
            constraintRows.map((row) => row.slice(geometry.length)),
          );
      return {
        ...base,
        state:
          !entity && !source.contours.length
            ? "empty"
            : redundant
              ? "over-constrained"
              : dof
                ? "under-constrained"
                : "fully-constrained",
        degreesOfFreedom: dof,
        redundantEquations: redundant,
      } as SketchConstraintState;
    });
  } catch (error) {
    return common({
      ...base,
      state: "invalid",
      message: (error as Error).message,
    });
  }
}
