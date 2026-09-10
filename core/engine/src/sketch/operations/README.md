# Sketch operations

Pure drawing-to-drawing operations. These modules must not import DOM, React,
Three.js, file dialogs, or host APIs. Input objects remain unchanged.

- `transform.ts`: uniform planar transforms and independent copying; covers
  circles, lines, circular arcs, ellipses and cubic Beziers. Moves reject if they
  conflict with existing constraints.
- `mirror.ts`: reflection about an arbitrary 2D line; reuses the transform layer.
- `pattern.ts`: linear grids and circular copies; reuses the transform layer.
- `trim-extend.ts`: straight-line picking and exact extension against points, lines,
  circles, arcs, ellipses and cubic Beziers. Line Trim delegates to `trim.ts`;
  it has no separate topology or constraint-remapping implementation.
- `trim.ts`: clicked interval removal for lines, arcs, ellipses and cubics,
  preserving exact remaining segments. Circles become arcs; standalone points
  delete. Circle radius/center relations survive conversion to arcs. Path constraints on surviving vertices/whole segments remap by provenance;
  supporting-circle and line-direction relations survive partial segments with
  common-locus links across remnants. Fixed/sliding finite contacts remap to surviving
  parameter intervals through `trim-contact.ts`. Other changed/removed-entity relations
  are removed. Finite line/conic overlap endpoints are supported; unresolved cubic overlaps reject.
- `extend-curves.ts`: free arc/ellipse endpoint extension on the original conic,
  to the nearest finite boundary or a second picked point. Reuses line Extend;
  existing constraints are retained when satisfied, with named atomic conflict
  rejection. `extension-contacts.ts` remaps finite contact parameters to preserve
  their locations on the extended line/conic. Cubic source extension remains open.
- `split.ts`: exact path-segment subdivision and surviving endpoint-reference
  remapping. Arc radius/concentric/equal/tangent relations survive with linked arc halves;
  line direction relations survive with collinear halves and original length
  becomes outer-endpoint distance. Line midpoint/equal-length relations retain their original full span through
  `split-line-span.ts`, which creates construction geometry linked to the original
  outer endpoints. Arc midpoint uses `split-arc-span.ts` with an endpoint/circle-linked construction arc.
  Both use `split-span-links.ts` for endpoint linkage. Other unsupported finite/control relations still reject. `split-contact.ts` remaps fixed/sliding finite contacts
  to their exact subdivided segment. Two-point circle
  splitting preserves radius and center relations across the new arcs.
- `preserve-constraints.ts`: checks retained relations after topology-preserving
  edits, without allowing a solver to undo the requested geometry change.
- `split-relations.ts`: supporting-circle relation classification and generated
  concentric/equal-radius links for split arcs, and collinearity/outer-endpoint
  dimensions for split lines.
- `circle-references.ts`: shared circle-to-arc reference conversion for Trim
  and Split, retaining referenced centers as linked construction points.
- `trim-references.ts`: segment/vertex provenance maps across open/closed path
  replacement, including closed-seam aliases and later contour shifts.
- `trim-sweep.ts`: exact stroke/curve crossings for drag Trim, reusing the
  single-interval operation without depending on pointer event spacing. Standalone
  points use a stroke capsule with caller-provided hit tolerance.
- `delete.ts`: removal plus surviving-constraint reference remapping.
- `operations.test.ts`: geometric behavior, source immutability and rejection
  tests. Solid rebuild tests live with the kernel evaluator.

Mirror and pattern operations create associative relations; grouped instances support
count/placement edits, suppression and repair through their focused helpers.
General transform copies remain independent geometry. See the parity ledger for
remaining topology limits and unverified workflows.

Add algorithm families in dedicated files and reuse common math rather than
copying it into the UI. Keep persisted contracts in `../drawing.ts` and exports
in `../index.ts`. Every new persisted field needs validation and round-trip tests.

- `fillet.ts`: exact circular fillets at connected straight-line corners,
  including closed seams. Persists radius/tangency plus a construction virtual
  sharp and remaps original corner/length references. Unsupported finite line
  relations reject. Curved corners route through `fillet-connected-curves.ts`.

- `fillet-batch.ts`: applies original corner selections in stable index order,
  then retains one driving radius with equal-radius links. Invalid selections
  reject without mutating the source; duplicate selections are deduplicated.

- `fillet-lines.ts`: maps two adjacent lines, or two single-line contours sharing
  an endpoint, into the corner fillet operation. Endpoint/line references remap
  through joining. Disconnected lines, multi-segment separate contours and
  direction-sensitive constraints requiring reversal remapping remain open.

- `fillet-line-intersection.ts`: virtual intersections for disconnected/crossing
  single lines, retaining the side indicated by each pick. Endpoint moves must
  satisfy existing constraints before joining and filleting.

- `fillet-handle.ts`: renderer-neutral projection of a generated fillet radius
  and virtual sharp into handle geometry; computes radius from a dragged point.

- `fillet-radius-edit.ts`: resolves shared-radius links from a picked fillet arc
  and edits the existing driving dimension through the canonical solver. It
  preserves IDs/topology and rejects invalid radius values or solver conflicts.

- `fillet-curves.ts`: joins independently drawn single-segment curves using exact
  Core subdivision and a circular bridge. Owns topology/reference remapping and
  generated radius/finite tangent constraints. Outer endpoints and arc loci
  survive; unsupported references reject before commit. The existing line
  operation remains responsible for line virtual sharps and corner batches.

- `fillet-connected-curves.ts`: rounds adjacent curved path segments, retains
  surrounding geometry and remaps untouched indices, including a closed seam.
  Removed corner/control references reject until virtual-sharp mapping exists.
- `fillet-constraints.ts`: shared finite-contact/radius constraint generation for
  both independent and connected curved fillets; stable unique IDs in each draft.

Fillet batches dispatch straight versus curved corners through their dedicated
operations and generate one driving radius. Curved finite tangent references
are reparameterized into retained intervals, allowing both ends of a curve to
be rounded without losing the first join. `fillet-handle.ts` recognizes both
virtual-sharp and finite-contact fillets; curved handles use the arc center.

- `break-line-corner.ts`: shared topology/virtual-sharp/reference remapping for
  straight fillets and chamfers. Callers calculate the break geometry and own
  dimensional constraints and final validation; no UI state enters this helper.
- `chamfer.ts`: computes equal/two-distance/distance-angle straight-corner bevels,
  generates driving dimensions, and validates edits before returning a draft.

- `edit-dimension.ts`: edits a literal/shared driver through any follower, solves
  the draft and validates it; constraint removal preserves dependent values.
  Equal-distance chamfers use stable links rather than duplicate numeric values.

- `line-corner-selection.ts`: shared connected/separate-line selection, virtual
  intersection joining and reference remapping. Calls a supplied corner operation
  and reports whether the first selected line is incoming in the path.
- `chamfer-lines.ts`: applies that selection contract to chamfer dimensions; first
  distance/angle follows selection order. `fillet-lines.ts` is now a thin wrapper
  over the same join logic. Separate multi-segment joins remain unsupported.

- `chamfer-batch.ts`: applies deduplicated vertex selections in descending order,
  then links one driver per numeric parameter. Equal setbacks retain their local
  links; angular followers carry the orientation sign of their corner.

- `drag-entity.ts`: moves selected points/edges with temporary point targets,
  solves existing constraints and strips drag targets before returning a draft.
- `chamfer-edit.ts`: identifies saved bevel dimensions from virtual-sharp
  relationships and projects/edit their setbacks. The dedicated chamfer handle
  UI is still pending; this is tested Core support for that next integration.

`polygon-definition.ts` recognizes an intact convex regular polygon from its ordinary sizing-circle and equality/coincidence constraints. `polygon-sides.ts` updates side count without adding a second stored count, preserving sizing references and remapping surviving point attachments. Changed-edge/disappearing-vertex attachments reject atomically. `Aether CAD/src/sketch/polygon-controls.ts` owns the inline editor.

`polygon-attachments.ts` maps surviving vertices, directed supporting lines and bounded finite contacts during side-count edits. Contact parameters follow physical positions. Final constraint checks reject conflicting lengths; missing geometry and contacts beyond shortened edges are not silently rebound.

`closed-slot.ts` appends circular or closed line/arc slot boundaries to the working copy. Each boundary constraint declares `slotBoundary: "inner" | "outer"`. `curves/closed-slot.ts` computes inside/outside from exact signed area; `solver/closed-slot.ts` reuses offset residuals for chains, while `solver/circular-slot.ts` links circle centers and radii. Mixed open/closed slots share width drivers. `slot-handle.ts` supplies radial circle or chain-normal handles. Collapsed offsets are rejected; spline/ellipse slots remain unsupported.

`curves/line-overlap.ts` owns finite collinear contact checks. Straight-chain offsets use it for nonadjacent parallel edges; adjacent shared endpoints retain their existing valid joins. This validates output and does not perform topology repair.

`insert-spline-point.ts` owns exact cubic join insertion. It composes `splitSketchSegment` for geometry/reference remapping and adds a fixed-parameter G2 curvature relation at the new join. It does not add a second spline representation. Unsupported fit-spline/control references reject atomically; native knot insertion and UI integration remain separate work.

`insert-fit-spline-point.ts` preserves natural/periodic fitted curves by splitting their existing parameter interval. Optional `splineSpanIntervals` on `spline-shape` stores positive relative knot spacing only; fit points remain the contour vertices. Missing intervals retain legacy chord-length fitting. After insertion, intervals remain fixed during edits, so refitting preserves the parameterization. Unsupported external control/whole-contour relations still reject through Split.

`spline-handle.ts` exposes cubic endpoint-to-control vectors as construction lines linked by two coincidence constraints. The native cubic control points remain canonical. Repeated requests reuse an existing linked line. Standard length/angle/alignment constraints can act on the handle; zero tangent vectors reject. These handles currently make insertion through their referenced control span reject until control-reference remapping is implemented.

`split-control.ts` remaps cubic control references through De Casteljau subdivision. Optional positive `controlScale` on a point/control reference retains the original endpoint-relative vector; `solver/control-point.ts` resolves it from native geometry. Repeated splits multiply the scale. Existing dimensions/fixed points and exposed tangent handles keep their meaning; unscaled references retain legacy behavior.

`projected-snaps.ts` enumerates identified external endpoints, centers and line/arc midpoints using existing analytic helpers. Inference attaches newly placed authored vertices with coincidence/concentricity/midpoint relations, retaining external IDs. Existing local attachments take precedence; old vertices and unidentified source contours are ignored.

`split-identities.ts` owns identities for an editing split: new child edges receive fresh IDs, the terminal vertex keeps its identity, and the join receives a fresh vertex ID when the original endpoint was identified. Split normalizes stable references before numeric remapping and recaptures child IDs for local contacts/controls. External whole-edge references remain explicitly broken until relinked; endpoint references survive. Pure subdivision does not duplicate source identities.

`trim-identities.ts` assigns output vertex/edge IDs from the retained interval layout used by constraint remapping. Unchanged segments and retained endpoints keep their identities; newly cut endpoints/partial edges receive new identities. Moved starts never inherit a removed vertex identity. `trim-references.ts` resolves stable references before remapping and captures the retained identity afterward. A trim producing multiple contours still clears the original contour ID; cross-contour lineage and external whole-edge remapping remain pending.

Projected snap enumeration also uses ellipse local-axis quadrants (clipped to visible spans) and circle sketch-axis quadrants. Candidate `quadrant` indices persist on inferred external constraints. `solver/ellipse-contact.ts` provides `quadrantFrame` for circle/ellipse equations and manual constraint creation; circular arcs use directed-span validation. Existing endpoint/center candidate precedence is retained.

`projected-curve-snap.ts` finds the nearest point on identified projected native segments/circles. The UI calls it after discrete snaps and before grid/alignment fallback. `inferProjectedSnaps` uses exact placed-point matching to persist external coincidence; native finite path contacts set `sliding:true`, allowing solver contact parameters to move with subsequent dimensions. Circles use radial coincidence. Source curves remain read-only. Large-sketch spatial acceleration and live pointer acceptance are pending.

`circular-quadrants.ts` enumerates sketch-axis quadrants for circles and visible arc spans, and skips degenerate draft arcs without blocking other snap targets. The existing quadrant enumeration/inference path consumes these alongside ellipses, avoiding duplicate point attachments. `curves/angular-span.ts` provides the shared directed-span distance for candidate filtering, manual nearest-quadrant selection and solver residuals. Arc quadrant constraints must satisfy both axis position and visible-span membership.

`quadrantSpan` in the shared solver contact helper exposes finite spans for circular/elliptical arcs. A full ellipse shape relation has no finite span. Quadrant residuals penalize out-of-span targets in addition to coordinate mismatch; manual creation chooses among visible quadrants. Ellipse candidate enumeration uses the same angular-span calculation, avoiding a separate clipping rule.

`retained-ellipse-relations.ts` replaces a full ellipse's closed-half relation after trimming with pairwise `ellipse-locus` relations across surviving arcs. `solver/ellipse-locus.ts` compares centers and normalized shape matrices, respecting equivalent swapped axes and circular orientation freedom. Trim reference remapping permits ellipse-shape conversion and retains conic links across partial fragments. Ordinary whole-contour relations that lack a valid conversion still reject atomically.

`split-ellipse-relations.ts` converts full-ellipse shape constraints after Split, remaps quadrant references to a visible output arc, and links partial ellipse children to their common conic. It reuses `retained-ellipse-relations.ts` with Trim.

`ellipse-axis-references.ts` resolves diameter endpoints across an explicit `ellipse-locus` component. It chooses visible quadrants using physical endpoint positions (including equivalent axis orientations), and rejects missing endpoints. `ellipse-axes.ts` uses these references for both creation and reuse; it does not infer a conic relationship merely from coincident geometry.

Offset and slot source references capture available stable edge IDs before creating derived geometry. `offset-relations.ts` also captures target IDs; `curves/slot.ts` normalizes centerline references for later residual evaluation. Earlier edge insertion must not redirect a relation, and missing IDs reject instead of falling back. `source-edge-identities.test.ts` covers serialized source edits for both operations. This does not remap a source edge that has itself been split/deleted.

`identify-source-edges.ts` assigns missing IDs to selected authored edges on a caller-owned candidate and returns identified references. Pattern-group, mirror (including axis edits), offset and slot creation use it before generating geometry, so fresh edges receive the same protection as preidentified sources. Newly generated slot boundaries discard borrowed centerline subentity IDs. Existing IDs are preserved and collisions avoided. It does not invent IDs for source-owned projected geometry or change whole-contour/plain-point reference contracts. Callers retain atomic commit ownership.

`ellipse-support.ts` supplies a full construction conic when a partial ellipse lacks an axis endpoint. Explicit ellipse-locus relations tie both support segments to the source. `ellipse-axes.ts` invokes this only for missing finite endpoints (other reference errors propagate), then reuses ordinary quadrant/length dimensions; subsequent axis selection reuses the same support. No independent radius metadata is stored.

### Semicircle placement inference

`../semicircle-snap.ts` projects the pending curvature point onto the circle whose diameter is the endpoint chord, within the caller's screen-scaled tolerance. `semicircle.ts` handles newly committed three-point arcs only: a linked center, endpoint-linked construction chord, and one center-on-chord equation preserve 180 degrees. Do not substitute two midpoint equations: one is redundant with the circle's chord-bisector geometry. The operation is a placement pass, not a repeated edit command. Helpers remain construction geometry and ordinary native constraints.

`link-dimension.ts` exposes atomic `linkSketchDimension(source, id, driverId, scale, offset)`. The existing solver validates dimensional compatibility and chain cycles before returning solved geometry. It supports one driver per relation, chained as needed. General multi-input expressions and named variables remain planned.

`unlinkSketchDimension` materializes a linked dimension at its resolved value, clears only its upstream affine link, and retains its stable ID/downstream followers. It validates before and after cloning; geometry is unchanged. Repeating it on an independent driving dimension is harmless. Reference dimensions must first be made driving.

Fillet editing routes through `editDrawingDimension`, including linked/scaled radius drivers. `fillet-handle.ts` resolves the radius with `dimensionValue`; it never assumes a literal `value` exists. Reference-radius measurements do not expose an editable fillet handle. The CAD modification panel also reads the resolved driver value when reopening a fillet.
