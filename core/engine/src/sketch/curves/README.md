# Exact sketch curve math

- `parameterization.ts`: curve evaluation, ellipse endpoint-to-center conversion,
  and closest-parameter picking. Sampling is used only to find picking basins;
  it never changes persisted geometry.
- `subdivide.ts`: exact segment subdivision, including de Casteljau for cubic
  Beziers. Both output segments keep the original representation and degree.
- `intersections.ts`: infinite-line intersections with finite line, circular arc,
  ellipse and cubic Bezier boundaries. Polynomial roots are isolated through
  derivative extrema so tangent roots are included.
- `curves.test.ts`: shape invariance across parameter ranges, finite arc bounds,
  crossing/tangent roots and constraint reference preservation.

- `pairs.ts`: finite line/conic/cubic pair intersections. Conic pairs use a
  quartic substitution; cubic/conic uses polynomial roots; cubic pairs use
  control-hull subdivision and numerical refinement. Finite line/conic overlaps return shared interval endpoints; ambiguous cubic overlaps reject.
- `picking.ts`: shared nearest-curve picking and exact circle decomposition.
- `pairs.test.ts`: crossing, tangent, adjacent, disjoint and overlap cases.

General cubic-overlap handling and robust constraint remapping remain acceptance
work. This is not a complete arrangement/region solver. Numerical tolerances and
bounded cubic subdivision need broader scale/stress coverage before full parity.

- `cubic-overlap.ts`: affine parameter matching for duplicate/reversed cubic
  curves and shared subintervals. Endpoint candidates are verified against the
  exact reparameterized control polygon. Degenerate retracing/non-affine cases
  still need dedicated handling.

- `derivatives.ts`: cached exact point/first/second derivative evaluators for
  lines, circular/elliptical arcs and cubic Beziers.
- `tangent-circle.ts`: finite-domain normal-offset intersections for a requested
  fillet radius, using bounded damped Newton searches over both normal sides.
  Candidate coverage is numerical; singular offsets/retracing need more work.
- `fillet-pieces.ts`: exact retained curve portions and a circular bridge,
  verifying tangent direction at both joins. Drawing reference/constraint and
  application integration are separate, unfinished work.
