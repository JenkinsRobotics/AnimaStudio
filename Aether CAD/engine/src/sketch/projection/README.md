# Sketch projection geometry

`frame-map.ts` maps source-plane points into target-plane coordinates by
orthogonal projection along the target normal. Both frames use millimeter
origins and unit orthogonal directions. `conic.ts` extracts projected ellipse
axes from a 2×2 shape matrix. `drawing.ts` applies those transformations to
solved native sketch geometry, preserving contour construction/hole flags.

Lines and cubic controls transform directly. Circular/elliptical arcs remain
native ellipse segments, including sweep reversal under orientation changes.
Oblique full circles become two ellipse halves; circular results remain circles.
`collapsed-conic.ts` handles rank-one (edge-on) conic images analytically.
Full circles and closed line/conic contours become a single bounded line interval;
open arcs retain projected turning points, including coincident endpoint cases.
Collapsed contours have no hole flag. Nearly singular nonzero conics below the
existing ellipse tolerance still reject; this is not a tessellated approximation.

The result is geometry only. Source dimensions/constraints are deliberately not
copied into the target plane: for example a projected circle radius is no longer
a circle radius. Document-level source references must own update/broken-link
behavior. This module owns geometry; document and UI layers own association
and editing.

`document/profile-projection.ts` now supplies whole-profile association. A
ProfileFeature may persist `profile: {type: "projection", sourceFeatureId, sourceContourId?}`;
the source must be an earlier, unsuppressed profile. The resolver evaluates the
source at rebuild time and maps it into the target feature frame, with no saved
copy of derived contours. The kernel consumes this resolver. Selection of
individual edges/vertices and mixing derived with authored contours still need
stable subentity references and editor integration. Broken links fail explicitly;
the projection editor supports source/contour relinking for documents already
loaded. Recovery of files rejected during parsing remains future work.

Projection records may also contain `authored?: SketchDrawing`. `document/mixed-projection.ts` solves authored constraints in their own contour index space before combining them with live projected geometry. Source topology changes cannot shift authored references. No derived contours are stored. Duplicate contour IDs reject explicitly. External constraints and mixed editing are supported through the runtime context described below. Source relinking preserves authored data.

`document/projected-constraints.ts` resolves authored references carrying `projectedContourId` (persisted contour index -1) into temporary indices for identified projected contours. Solver `fixedContours` excludes those contours from variables, including arc/ellipse/cubic internals. Results restore external IDs and sliding parameters and discard temporary geometry. Document validation resolves external equations with source context; suppression does not invalidate structural references. UI selection/constraint editing still needs this context wired through all operations. New external edge references capture optional segment IDs; legacy index-only references and vertex references still lack stable topology identity.

Editor operations may carry ephemeral `SketchDrawing.projectionContext`; entity resolution consults it for external IDs while solver coordinates remain authored-only. `projectedSketchEntities` is a separate enumeration for selection UI, avoiding accidental source mutation in drawing inference. Part validation rejects the runtime context in persisted profiles; the authoring adapter strips it before save.

`document/profile-contour-identities.ts` assigns missing IDs atomically when referencing an entire sketch. It visits authored geometry in upstream projection chains, preserves existing IDs/constraints, and converts legacy primitive profiles to native drawings. Validation covers the source prefix so an editor can still repair an invalid downstream projection. Preview candidates never mutate the source document.

`solver/segment-reference.ts` captures and resolves optional edge identities. One-to-one projections preserve segment IDs; identity assignment creates missing IDs on authored segments. Identified references never fall back to numeric indices when missing or ambiguous. Collapsed projections and topology replacement do not claim identity preservation. New projected endpoint references capture vertex IDs through `solver/vertex-reference.ts`; legacy references remain index-based. General split/trim remapping is still pending.

Path `startVertexId` and segment `endVertexId` identify endpoints independently of array positions. The closing endpoint may share the start ID; resolution canonicalizes that seam to index zero. Whole-source identity assignment and noncollapsed one-to-one projection preserve these fields. Missing or ambiguous `SketchEntityRef.vertexId` fails explicitly. New source topology must carry surviving identities deliberately; no geometric proximity remapping is implied.

`document/identify-sketch-contour.ts` centralizes candidate-only contour, edge and vertex identity assignment. Both whole-sketch and selected-contour entry points use it, including already identified contours missing subentity IDs. Selecting from a derived sketch identifies upstream authored geometry atomically, and keeps the reference on the selected derived feature. The UI never bypasses assignment merely because a contour already has an ID. Source-prefix validation permits repairing downstream broken references.

`mapSketchDrawing` accepts an explicit collapse tolerance, defaulting to zero for general affine import mappings. The sketch-frame projection wrapper supplies its near-edge-on tolerance. `projectedEllipse` normalizes the shape matrix before squaring and derives the minor radius from the affine determinant, retaining small-scale and thin-but-usable conics. Geometric resolution/finite-number limits still reject; this does not promise arbitrary precision.
