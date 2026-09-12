import { validateDimensionExpression } from "./dimension-expressions";
import { textSimilarityCoordinates } from "./text-coordinates";
import { ellipseLocusCoordinates } from "./ellipse-locus-coordinates";
import { contactParameterCoordinates } from "./contact-parameters";
import { dimensionDriver } from "./dimension-links";
import type { SketchDrawing, SketchPoint } from "../drawing";
import { constraintResiduals } from "./residuals";
/** SPIKE (2026-09-12): see solver/planegcs-spike.ts. Delete with the spike. */
type SolverComparisonHost = {
  __aetherSolverComparison?: (
    source: SketchDrawing,
    options: { fixedContours?: ReadonlySet<number> },
    outcome: SketchDrawing | Error,
  ) => void;
};
/** Damped least-squares solve. Never mutates input or silently accepts conflicts. */
export function solveDrawingConstraints(source: SketchDrawing, options: { fixedContours?: ReadonlySet<number> } = {}): SketchDrawing {
  // SPIKE (2026-09-12): a harness may register a comparison hook here to run
  // every real solve through FreeCAD's PlaneGCS as well. Nothing in production
  // sets it and nothing is imported, so browser bundles are untouched.
  const compare = (globalThis as SolverComparisonHost).__aetherSolverComparison;
  if (!compare) return solveDrawingConstraintsCore(source, options);
  const given = structuredClone(source);
  try {
    const solved = solveDrawingConstraintsCore(source, options);
    compare(given, options, solved);
    return solved;
  } catch (error) {
    compare(given, options, error as Error);
    throw error;
  }
}

function solveDrawingConstraintsCore(source: SketchDrawing, options: { fixedContours?: ReadonlySet<number> } = {}): SketchDrawing {
  const d = structuredClone(source),
    constraints = d.constraints ?? [];
  const parameters=contactParameterCoordinates(d);
  if (!constraints.length) return d;
  if (constraints.length > 512)
    throw new Error("This sketch supports up to 512 constraints.");
  if (new Set(constraints.map((c) => c.id)).size !== constraints.length)
    throw new Error("Duplicate constraint IDs.");
  for (const c of constraints) validateDimensionExpression(c);
  for (const c of constraints)
    if (c.valueFrom !== undefined || c.valueSign !== undefined || c.valueScale !== undefined || c.valueOffset !== undefined)
      dimensionDriver(d, c);
  // Already-satisfied constraints need validation, not a numerical solve. This
  // also permits saving large generated curves without allocating a Jacobian.
  const initial = constraints.flatMap(c => constraintResiduals(d,c));
  if (!initial.every(Number.isFinite)) throw new Error("Invalid constraint geometry.");
  if (Math.max(...initial.map(Math.abs)) < 1e-7) return d;
  const vars: { get: () => number; set: (v: number) => void; differenceStep?:()=>number }[] = [];
  const addPoint = (p: SketchPoint, alias?: SketchPoint) => {
    for (let k = 0; k < 2; k++)
      vars.push({
        get: () => p[k],
        set: (v) => {
          p[k] = v;
          if (alias) alias[k] = v;
        },
      });
  };
  const used = new Set(
    constraints.filter(c=>!c.reference).flatMap((c) => [c.a.contour, ...(c.b ? [c.b.contour] : []), ...(c.axis ? [c.axis.contour] : [])]),
  );
  const textGroups = textSimilarityCoordinates(d, { fixed: options.fixedContours, used });
  vars.push(...textGroups.coordinates);
  const linkedEllipses = ellipseLocusCoordinates(d, options.fixedContours);
  vars.push(...linkedEllipses.coordinates);
  d.contours.forEach((c, i) => {
    if (!used.has(i) || options.fixedContours?.has(i) || linkedEllipses.covered.has(i) || textGroups.covered.has(i)) return;
    if (c.type === "circle") {
      addPoint(c.center);
      vars.push({ get: () => c.radius, set: (v) => (c.radius = v) });
    } else {
      const last = c.segments.at(-1);
      const closed =
        last &&
        Math.hypot(last.end[0] - c.start[0], last.end[1] - c.start[1]) < 1e-6;
      addPoint(c.start, closed ? last.end : undefined);
      c.segments.forEach((s, j) => {
        if (!(closed && j === c.segments.length - 1)) addPoint(s.end);
        if (s.type === "ellipse") {
          for(const key of ["radiusX","radiusY"] as const) vars.push({get:()=>Math.log(s[key]),set:v=>{s[key]=Math.exp(v);}});
          vars.push({get:()=>s.rotationDegrees*Math.PI/180,set:v=>{s.rotationDegrees=v*180/Math.PI;}});
        }
        if (s.type === "arc") addPoint(s.middle);
        if (s.type === "bezier") s.controls.forEach((p) => addPoint(p));
      });
    }
  });
  vars.push(...parameters);
  if (vars.length > 512)
    throw new Error("Too many constrained sketch coordinates (maximum 512).");
  const residual = () => constraints.flatMap((c) => constraintResiduals(d, c));
  const norm = (r: number[]) => r.reduce((n, v) => n + v * v, 0);
  const linearSolve = (a: number[][], b: number[]) => {
    const n = b.length;
    for (let i = 0; i < n; i++) {
      let pivot = i;
      for (let j = i + 1; j < n; j++)
        if (Math.abs(a[j][i]) > Math.abs(a[pivot][i])) pivot = j;
      [a[i], a[pivot]] = [a[pivot], a[i]];
      [b[i], b[pivot]] = [b[pivot], b[i]];
      const q = a[i][i];
      if (Math.abs(q) < 1e-18)
        throw new Error("Constraint system is singular.");
      for (let k = i; k < n; k++) a[i][k] /= q;
      b[i] /= q;
      for (let j = 0; j < n; j++)
        if (j !== i) {
          const f = a[j][i];
          for (let k = i; k < n; k++) a[j][k] -= f * a[i][k];
          b[j] -= f * b[i];
        }
    }
    return b;
  };
  let damping = 1e-5;
  for (let iteration = 0; iteration < 100; iteration++) {
    const r = residual();
    if (!r.every(Number.isFinite))
      throw new Error("Invalid constraint geometry.");
    if (Math.max(...r.map(Math.abs)) < 1e-7) return textGroups.finish();
    const before = vars.map((v) => v.get());
    const columns = vars.map((v, j) => {
      const h = v.differenceStep?.() ?? 1e-5 * Math.max(1, Math.abs(before[j]));
      v.set(before[j] + h);
      const plus = residual();
      v.set(before[j]);
      return plus.map((p, i) => (p - r[i]) / h);
    });
    const matrix = r.map((_, i) =>
      r.map(
        (_, j) =>
          columns.reduce((sum, c) => sum + c[i] * c[j], 0) +
          (i === j ? damping : 0),
      ),
    );
    const step = linearSolve(
      matrix,
      r.map((v) => -v),
    );
    vars.forEach((v, j) =>
      v.set(before[j] + columns[j].reduce((sum, c, i) => sum + c * step[i], 0)),
    );
    if (norm(residual()) < norm(r)) {
      damping = Math.max(1e-10, damping * 0.3);
    } else {
      vars.forEach((v, j) => v.set(before[j]));
      damping *= 10;
    }
  }
  throw new Error(
    "Constraints conflict or cannot converge. No geometry was changed.",
  );
}
