# Sketch constraint solver

`../drawing-constraints.ts` is the stable public facade. Implementation is split
by responsibility, so changing a constraint does not require editing the whole
numerical solver:

- `types.ts`: persisted entity references and constraint kinds/options.
- `entities.ts`: resolve references to geometry; enumerate selectable entities.
- `residuals.ts`: equations for each constraint. A satisfied equation returns
  zero. Keep units explicit and reject incompatible entity selections.
- `solve.ts`: bounded damped least-squares numerical solve; clones source data.
- `curves.test.ts`: arc/circle and point/curve behavior. Existing regression tests
  remain in `../drawing-constraints.test.ts`.

Legacy circle/arc references use their analytic loci. New `kind: "curve"`
references carry a fixed `parameter` in [0,1]; two such references with Tangent
constrain contact position and parallel derivatives. The UI exposes each segment
start/end. Curvature adds a signed-curvature equation through `curve-continuity.ts`, adjusted for reversed parameter orientation. It supports finite line/arc/ellipse/Bézier contacts; analytic circle-locus selections are not accepted. Free sliding contact parameters, curve-to-plane normal, pierce, symmetry
remain incomplete. Stationary tangent points reject. Local DOF classification is described below. The solver is bounded to 512 constraints and 512 involved coordinates; the higher constraint budget accommodates the existing 100-side polygon tool with persisted regularity relations.

Add a constraint by defining its typed contract, compatible entity resolution,
and residual equations, followed by convergent, conflicting, and degenerate
system tests. The UI panel edits the contract; it must not implement solver math.

`dimension-links.ts` resolves a numeric dimension's stable driver ID and checks
unit compatibility/cycles. A constraint has either `value` or `valueFrom`, never
both. Geometry-removing operations call `preserveRemovedDimensionDrivers` to
materialize surviving followers at their last resolved value when a driver is
removed. New operations that filter constraints must preserve this invariant.

Angular `valueFrom` links may carry `valueSign: 1 | -1`. Resolution accumulates
signs across chains; dimensional edits divide by the resolved sign before
updating the root driver. Driver removal materializes the signed value and
removes both link fields. Signs on literal or non-angular dimensions reject.

`diagnostic-coordinates.ts` projects independent geometric coordinates for local
rank analysis; arcs use a bulge rather than two arbitrary through-point values.
`diagnostics.ts` evaluates a normalized numerical Jacobian, conflicts and
redundancy, returning explicit unavailable status beyond 256 coordinates. It
never modifies the supplied drawing and does not prove global uniqueness.

Shape placement intent lives in dedicated `../operations/rectangle-relations.ts` and `polygon-relations.ts` modules. These append ordinary constraints and construction entities, avoiding an independent shape evaluator. Polygons use equal chords on a common circle; circumscribed polygons add a concentric inner sizing circle tangent to an edge. Equal edge lengths and inner-circle tangency alone would permit nonregular rhombi. Existing free paths are not automatically converted.

`normal.ts` owns line-to-curve normal equations: center incidence for circular loci, or contact incidence plus perpendicular tangent for finite curve references. Normal uses the existing two-entity persisted contract; no second geometric representation is introduced. Line extents are not constrained. Plane references are not yet supported.

`offset.ts` owns signed circle-radius/center and corresponding line-endpoint relations. `operations/offset-relations.ts` attaches these after exact offset geometry creation and links a batch to one dimensional driver. Supported offsets use ordinary solver constraints, including source/follower edits and driver removal. Individual circular arcs also preserve their center, start angle, signed sweep and radial distance using five independent equations. Line chains use a persisted `contour` reference and independent vertex residuals against exact mitered offset geometry in `curves/offset.ts`. Closed paths omit the duplicate closing vertex. Topology-changing split/trim rejects until remapping is supported; whole-contour deletion removes the relation. Offset is a length-valued dimension and may be negative.

Mixed line/arc contours use `offset-mixed.ts` locus equations and open-end parameter conditions, avoiding singular carrier intersections in numerical derivatives. Tangent joins can still have singular local Jacobians; local DOF and derived geometric error bounds remain limitations, even when residuals converge.

Slot width is a positive length-valued `slot` constraint. `curves/slot.ts` constructs exact line/arc envelopes, `operations/slot.ts` creates shared width links, and `solver/slot.ts` compares independent vertices/arc bulges. Standalone centerlines become construction geometry; larger source contours are not reclassified. Chain/closed-profile/spline slots and end-cap topology repair are still incomplete.

`symmetric.ts` owns point reflection and line/circular supporting-locus symmetry. `DrawingConstraint.axis` is a third live geometry reference: coordinate participation and all topology remapping must include it. Arc endpoints are intentionally independent. Elliptical segment symmetry uses a reflected shape tensor; spline symmetry remains unsupported. New full ellipses retain shared half geometry through `ellipse-shape.ts`; `operations/ellipse-relations.ts` creates the relation. Older unlinked full ellipses can be explicitly constrained. Shape-linked ellipse splitting is guarded until topology remapping exists. Ellipse radii use logarithmic solver coordinates to remain positive, and rotation uses radians internally.

`ellipse-contact.ts` owns point-on-ellipse and quadrant equations. A quadrant index is captured at creation and saved; never recompute nearest on every solver iteration, which would allow branch jumping. Index 0/1/2/3 means ellipse local +X/+Y/-X/-Y, not world coordinates.

`spline-shape.ts` derives natural or periodic fit-spline handles from existing contour vertices. `operations/spline-relations.ts` attaches the persistent whole-contour relation; it stores no duplicate control net. Removing the relation detaches interpolation intent. Topology-changing operations must remap the whole-contour reference or reject the edit. `solve.ts` validates already-satisfied residuals before iterative coordinate allocation; iterative limits still apply to unsatisfied systems.

### Selected-entity mobility

`sketchConstraintState(drawing, entity?)` optionally reports local DOF of one entity in the full sketch system. `entity-observables.ts` supplies its geometric quantities; `diagnostic-rank.ts` computes row-normalized Jacobian rank. Entity DOF is rank([constraint Jacobian; observable Jacobian]) minus rank(constraint Jacobian). This avoids counting unrelated free geometry against a fixed selected entity. Reference dimensions contribute no equations. Conflict/redundancy flags are still sketch-wide. The existing 256-coordinate limit and singular-configuration limitations apply. UI code only presents this Core result.

`sketchConstraintStates(drawing, entities)` batches local mobility queries, sharing numerical perturbations and constraint equations. An undefined entry requests whole-sketch DOF. Results preserve input order; the existing single-query API delegates to this implementation. UI colors should consume these results rather than count constraints or infer mobility from appearance.

### Pattern geometry

`pattern` is a generated source/instance contour relation with a persisted uniform planar transform (`tx`/`ty` in millimeters). `curves/similarity.ts` owns transform math; `operations/pattern-relations.ts` attaches relations; `solver/pattern.ts` compares independent coordinates, including arc bulge rather than through-point placement. Linear/circular tools now generate these relations. Removing a relation detaches its instance. Pattern transforms currently retain fixed spacing/rotation; group count/spacing editing and topology remapping remain open. Whole-contour references must be remapped or rejected by geometry-editing operations.

Mirror uses the same generated contour relation. With `axis`, the current line determines reflection through `curves/reflection.ts`; a simultaneous fixed `transform` is invalid. Without `axis`, numeric reflection is fixed. Axis coordinates participate in solve/remapping through the existing third-reference contract. Copy selection cannot contain the live axis contour. A whole-geometry move that violates a fixed reflection rejects; detach or edit the axis instead.

`operations/mirror-edit.ts` updates a saved relation axis without changing relation/instance identity. It reconstructs representative numeric axis endpoints from a reflection matrix, reseeds the instance, and invokes the ordinary coupled solver. `mirror-relation-editor.ts` in CAD is presentation only. Editing is per relation; grouped mirror/pattern parameter editing is not yet represented.

### Canonical pattern settings

New linear/circular patterns store `SketchDrawing.patternGroups[id]` (linear spacing/counts or circular center/count/step). Instance relations store `patternGroup` and `patternInstance`; `patternRelationTransform` derives the matrix, preventing duplicate transform/settings truth. Legacy `transform` relations remain supported, but cannot also reference a group. Group definitions contain no contour indices. `operations/pattern-group.ts` edits shared placement parameters with stable relation/instance IDs and invokes the solver; count changes use `operations/pattern-resize.ts`. CAD `pattern-group-editor.ts` presents the shared settings once per group.

Pattern resizing retains 2D grid coordinates while remapping flattened instance indices. Out-of-grid targets are removed only if no retained sketch constraint references them. Unrelated contour references use the existing deletion remapper. Incomplete partially detached membership rejects resizing; fully detached source sets are no longer group members. Tests cover identity, multiple sources, removals and dependency guards.

`operations/pattern-repair.ts` enumerates absent slots for surviving source memberships and restores them using resize logic. Restoration preserves existing detached geometry, creates new linked copies and is idempotent. Fully detached sources cannot be inferred from remaining relations. UI restoration uses saved group settings, not unsaved parameter fields.

### Suppressed pattern slots

A grouped relation may carry `patternSuppression` with only contour identity/construction/hole flags and omit `b`. It contributes no equations but retains source membership and instance index. Its generated contour is absent. Unsuppression uses current source geometry and group settings; optional identity is assigned explicitly so JSON omission cannot copy the source ID. Suppressed slots participate in resize bookkeeping and are not missing slots for repair. Dependent sketch references reject suppression before geometry deletion.

`operations/pattern-placement.ts` projects the relation members of each repeated placement and batches suppression/restoration atomically. It returns only a complete successful drawing. UI code commits once, so the entire placement is one history action. Incomplete source membership requires repair first; existing per-instance dependency guards still apply.

### Selected-edge mirrors

`pattern-source.ts` projects a source entity into the contour geometry consumed by pattern residuals; no duplicate source geometry is inserted. `mirror-entities.ts` creates individual mirrored contours with live source segment references. In this relation, a curve reference denotes the source segment geometry, not a tangent contact, so a stationary endpoint is valid. `mirrorAxisConflicts` permits a distinct axis segment in the same source contour. Saved mirror-axis editing uses the same source projection. Selected-edge linear/circular groups use the same source projection and canonical pattern-group membership.

### Shared ellipse solver coordinates

`ellipse-locus-coordinates.ts` supplies transient center, log-radius, rotation and vertex-angle coordinates for a connected all-ellipse path whose explicit conic relations are already satisfied and whose axis representations agree. `solve.ts` excludes those paths from generic endpoint/radius variables. The original residuals still validate every constraint; conflicting dimensions reject. Fixed contours, mixed paths, unlinked arcs and alternate axis representations use the general solver. Native geometry remains ordinary ellipse segments; no solver coordinate state is persisted. Regression tests cover sequential diameter changes after Split, closure, immutable failures and mounted native editor reopening.

### Linked ellipse mobility

Diagnostics use the shared ellipse coordinates for eligible paths and omit their intrinsically enforced conic residuals from rank, while counting additional graph relations as redundant equations. Satisfaction checks still use every complete residual. `diagnostic-residuals.ts` provides equality rows for mobility analysis: finite quadrant span bounds constrain allowable directions but are not endpoint-fixing equalities. `ellipse-diagnostics.test.ts` verifies remaining sketch/selected-axis freedoms through sequential dimensions and retains duplicate-relation detection. Other singular inequality configurations remain outside this verification.

`entity-observables.ts` uses `referencedContour` and `resolveSegmentReference` for both authored and projected arc/ellipse endpoints. Stable IDs are authoritative over numeric indexes. Projected-only selections still undergo validation; external source coordinates are absent from the local Jacobian, so valid projected entities have zero local mobility. Whole-sketch empty status remains tied to authored geometry.

`pattern-source.ts` resolves stable segment IDs before reading source endpoints/segments and captures available IDs in source choices. `pattern-source-key.ts` keys membership by stable identity when present and includes projected contour scope. Numeric indexes remain the legacy fallback only when no stable ID is supplied. Missing IDs reject; extracting an edge retains its source layer. `pattern-source-identities.test.ts` covers earlier-edge insertion, resizing and native persistence.

`mirrorAxisConflicts` accepts the current drawing to normalize mixed stable/numeric references before source/axis exclusion. It compares projected contour scope separately from authored indexes. Mirror creation/edit capture available axis IDs; CAD source and saved-axis menus call the same comparator, including preselection. Legacy references without IDs continue using current numeric positions.

### Affine dimension dependencies

A `valueFrom` link may include `valueScale` (finite, nonzero, dimensionless; default 1) and `valueOffset` (canonical millimeters/degrees; default 0). The equation is `valueScale * valueSign * driver + valueOffset`; legacy `valueSign` remains angular-only. `resolveDimensionLink` composes scale/sign and offsets through stable-ID chains, rejects cycles, unit mismatch and nonfinite arithmetic, and returns the root driver plus composed transform. `dimensionValue` evaluates it. Editing a follower inverts the transform to edit the shared root driver. Removing/converting a driver materializes dependent values and clears all transform metadata. No duplicate cached value or formula string is persisted.
