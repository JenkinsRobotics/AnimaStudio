# Sketch editor contributor guide

The sketch editor uses one canonical `SketchDrawing` from `@aether/core/sketch`.
Do not invent a second model for a panel or tool. Geometry units are millimeters;
angles use explicitly named degree fields. Rendering flips sketch Y only at the
SVG boundary.

## Where to make a change

| Change | File |
|---|---|
| Tool instructions and modification IDs | `tool-instructions.ts` |
| Multi-click trim/split/extend interaction | `direct-modification.ts` |
| Click sequence for a drawing tool | `drawing-tool.ts` |
| Pointer preview and measurement labels | `preview.ts` |
| Saved contour/grid/handle rendering | `canvas-renderer.ts` |
| Exact-curve to SVG path conversion | `svg-geometry.ts` |
| Picking points/lines/circles | `picking.ts` |
| Constraint controls | `constraint-panel.ts` |
| Mirror/pattern/transform controls and preview | `modification-panel.ts` |
| Delete, hole, construction controls | `contour-list.ts` |
| Session lifecycle, plane selection, undo, input binding, save | `../sketch-workspace.ts` |
| Ribbon groups/variants and command IDs | `../cad-tool-catalog.ts`, `../cad-command-registry.ts` |
| Constraint entities/equations/numerical solving | `../../engine/src/sketch/solver/` (this product owns its engine) |
| Shared exact geometry/operations | `../../engine/src/sketch/` |

Core geometry is renderer/UI independent. The workspace controller wires the
pieces together; new geometry algorithms do not belong there or in `main.ts`.
The existing controller still contains DOM assembly and event binding, but tool
placement, preview, picking, constraints, and modifications have dedicated
modules. Keep unrelated shell/legacy refactoring out of a tool change.

## Adding or changing a tool

1. Implement a pure Core operation beside its family in `operations/`. Return a
   new drawing, preserve source data, and validate finite inputs/degeneracy.
   If entity indices change, remap surviving constraint references explicitly.
2. Add deterministic tests beside the Core operation. Include invalid input,
   unchanged source, boundary cases, and constrained drawings.
3. Add the interaction to `drawing-tool.ts` or a dedicated operation panel.
   Preview must call the same geometry operation as Apply. Preview never enters
   the undo stack. Commit through the session callback once per user operation.
4. Register the command once, add the ribbon entry or grouped variant, and write
   a mounted interaction test in `../sketch-workspace.dom.test.jsx` (or a focused
   tool DOM test as that suite grows).
5. Test native serialization/reopening and OCCT evaluation for solid-producing
   profiles. Update `dev/docs/reality/STATUS.md` and the parity ledger.

Do not add inert buttons or silently approximate exact geometry. Unsupported
operation cases should reject atomically and stay listed as gaps. A working
limited tool is not full parity.

## Checks from the repository root

```sh
npm test --prefix engine
npm run check --prefix engine
npm test --prefix 'Aether CAD'
npm run build --prefix 'Aether CAD'
```

For shared UI changes, also run the Core UI tests/typecheck/build and the
Animation build. Use the real browser for the final drawing walkthrough when
connected; DOM tests do not verify WebGPU or actual pointer/layout rendering.

## Team workflow

Read `CONVENTIONS.md` and your mailbox. Check `git status`, claim only the files
needed for the task in the active briefing, and preserve others' changes.
Format only claimed files. Add a handoff with changed files and actual test
results, then release the claim. Prefer one behavior family per reviewable
change; tests stay beside their owner rather than one global test file.

`trim-gesture.ts` owns pointer capture, drag threshold, cancellation and the
single undo transaction for sweep Trim; Core owns stroke intersections.

`fillet-manipulator.ts` owns the preview radius handle, pointer capture, keyboard
controls and cancellation. Core projects the radius; Apply remains the commit.

The Fillet panel uses Core `pickCurve` and `filletSketchCurves` for finite
curve-pair selection, previews and atomic Apply. Geometry and reference mapping
stay in Core; the panel does not implement intersection or tangent math.

Clicking a curved corner routes its adjacent segment pair to the same Core
operation as two-curve selection. Both curved and straight corners enter the shared-radius batch selection.

`chamfer-panel.ts` owns chamfer mode fields, vertex selection, preview and Apply.
The existing modification controller delegates its lifecycle; corner geometry
and reference semantics stay in Core `operations/chamfer.ts`.

The constraint list shows effective numeric values and marks linked dimensions.
Its Update action edits the shared Core driver; Remove materializes surviving
followers through Core rather than leaving dangling IDs.

Chamfer controls accept either a straight vertex or two line picks. Core keeps
selected sides and resolves virtual intersections; the panel previews the merged
contour and handles Apply through the existing undoable commit callback.

Chamfer vertex picks accumulate a deduplicated batch and preview all selected
contours. Core generates shared drivers; editing linked dimensions after reopen
uses the existing constraint editor, including opposite-turn angle signs.

`selection-drag.ts` owns pointer gestures and one-undo-step commit; Core owns
constrained movement. `selection-renderer.ts` draws the current vertex/edge
highlight. `dimension-manipulator.ts` now holds shared pointer/keyboard logic;
`fillet-manipulator.ts` supplies its specific geometry and styling. Chamfer
manipulator wiring is still pending. Constraint-state text comes from Core local
Jacobian diagnostics; geometry/state styling uses the existing light/dark tokens.

Slot uses `slot-panel.ts` for edge/chain selection, preview and commit. `slot-manipulator.ts` adapts the shared dimension handle. Core owns the exact envelope and saved width relation; smooth chain joins retain tangency. Do not duplicate geometry in panel code.

Ellipse snapping uses Core `ellipseSnapPoints`; ordinary placement invokes `inferEllipseQuadrants` only when geometry snapping is enabled, before committing its undo checkpoint. Geometry and inference must remain one undo transaction. Alternate gesture paths still need equivalent inference integration.

`projection-editor.ts` owns whole-source projection creation/relinking in the viewport. It previews Core `resolveProfileDrawing`, then commits one reference-only ProfileFeature through the normal document apply boundary. It never stores rendered contours. Existing projection features route here from feature-authoring; authored sketches retain their ordinary editor. Mixed projected/authored geometry and subentity picking remain future work.

Center snap candidates and persistent concentric inference live in Core `sketch/operations/center-snaps.ts`. Ordinary drawing placement runs inference before its undo checkpoint is committed. Do not duplicate analytic center calculations in UI tools. Alternate gesture paths still require equivalent integration.

`drawing-inference.ts` is the gesture-policy entry point for ordinary placement inference. It composes Core center, quadrant, endpoint/origin and line alignment helpers before the workspace undo commit. Add geometric behavior in Core, not the workspace controller.

`projection-source-selection.ts` translates editor menu choices to stable Core contour references. Menu indices are transient; source IDs and projected references must be committed atomically through the candidate document. Missing IDs must remain broken until explicitly replaced.

Dimension label dragging lives in `dimension-label-drag.ts`. Store committed coordinates in the Part document sketchPresentation metadata, keyed by feature and constraint IDs. Include positions in sketch undo snapshots; never move solver geometry to implement annotation layout.

`center-controls.ts` owns arc/ellipse center selection presentation. Core `operations/ellipse-center.ts` and `arc-center.ts` create persistent construction points; `center-snaps.ts` owns analytic snapping and inference. Concentric equations stay in the Core solver.

`ellipse-axis-controls.ts` selects construction diameters created by Core `operations/ellipse-axes.ts`. Standard quadrant constraints link endpoints to the ellipse, and existing length/orientation constraints edit them. Do not store duplicate radii in UI state.

`quadrant-editor.ts` edits saved local ellipse endpoint choices through Core `operations/quadrant-edit.ts`; updates use the normal single undo commit and solver validation.

`dxf-anchor.ts` projects anchor choices from Core geometry helpers. `dxf-placement.ts` owns anchor-to-destination UI, optional screen-space snapping, cancellation and previews; Core similarity transforms own the actual geometry mapping.

`contact-mode-editor.ts` changes saved curve-contact sliding modes independently via Core `operations/contact-mode.ts`. Freeze uses the solved parameter; never recompute a contact from a screen position merely to change its mode.

`polygon-controls.ts` owns inline side-count edit state and validation through Core. `polygon-preview.ts` draws candidate geometry using the shared SVG contour paths. Candidate previews never mutate the drawing; Apply commits through workspace history, Cancel/Escape clears, and a changed drawing invalidates the editor.

Constraint UI ownership:
- `constraint-panel.ts` owns creating relations, selecting references and routing dimension-focus events.
- `saved-constraints.ts` owns rendering saved relations and their update/remove actions; it composes dedicated contact, quadrant, pattern and mirror editors.
- Core sketch operations remain the only mutation/solver implementation. Both panels receive the same drawing getter and undoable commit callback. New saved-relation controls belong in the saved renderer or a focused child editor, not in the creation form.

`slot-panel.ts` offers circle centerlines alongside line/arc edges and open or closed chains. Circular slots preview both native circle boundaries and reuse the width manipulator. Core owns the inner/outer boundary relations and hole semantics.

Spline point insertion is a direct modification command in the spline dropdown. `tool-instructions.ts` owns the shared direct-tool guard used by placement and preview; `direct-modification.ts` calls Core insertion. `preview.ts` marks the new curvature join without mutating the drawing. Commit, undo, redo and cancellation use the existing workspace lifecycle. Fit-spline/control-reference restrictions come from Core and are reported on click.

Insert spline point also supports natural and periodic fit splines through Core interval-preserving insertion. Preview markers use the picked span rather than assuming insertion creates a new constraint ID, since fit insertion preserves the original shape-constraint ID.

`spline-handle-controls.ts` offers Select spline start/end handle for Entity A. It delegates construction and relations to Core, commits only new handles, and selects the returned line by reference fields rather than JSON property order. Dimensions use the normal constraint panel.

`projection-authoring.ts` isolates the mixed-sketch edit session: it resolves a read-only projected backdrop and supplies authored drawing/save composition. The normal workspace edits only authored geometry with its existing undo/constraints. The projection editor offers Save and edit geometry. Background contours are never copied into history or the saved authored array; cross-projection constraints are still pending.

Projection authoring supplies ephemeral `projectionContext` and solves it on entry. Constraint selectors list identified projected entities separately from authored entities. Core resolvers use that read-only context; normal geometry mutation enumeration remains authored-only. Saving explicitly removes the context, and native document validation rejects accidental derived snapshots. Pointer picking/snapping and identity assignment for whole-source legacy sketches remain pending.

`projected-picking.ts` composes authored-only picking with identified read-only source contours for selection. Authored geometry wins coincident ties. Selection dragging uses this result to reject external drags; mutation tools keep the authored-only picker. Picked curve-interior parameters are added to selectors when absent. Selection overlays resolve external contours and display read-only status.

Projected snap candidates participate in the standard pointer snap picker. The final drawing-inference pass asks Core to retain exact projected placements after local inference. This does not copy source geometry and does not infer attachments for numeric placements or existing vertices.

`projected-curve-workflow.dom.test.jsx` mounts the actual sketch workspace with a simulated SVG coordinate transform. It verifies pointer placement on a projected edge, Undo/Redo, native save/reopen, source edits and retained sliding constraints; a second flow verifies circle-quadrant placement and source center/radius edits. These are integration tests, not browser rendering or live input acceptance.

`dxf-block-workflow.dom.test.jsx` covers block import through the mounted editor: effective layers, filtered preview, numeric placement, Undo/Redo and native geometry reopening. It verifies nonuniformly scaled circles remain ellipses with expected coordinates/radii. The file input is simulated; this does not replace real browser/file-picker acceptance.

`ellipse-trim-workflow.dom.test.jsx` authors a full ellipse/cutters through workspace commands and trims via simulated pointer input. It verifies Undo/Redo, converted shared-ellipse relations, native persistence and the reopened outline. The SVG coordinate transform is simulated, so live browser trim acceptance remains separate.

`arc-direction-control.ts` owns the Center arc gesture direction selector. It is visible only for that tool and refreshes the current pointer preview without committing geometry. `drawing-tool.ts` and `preview.ts` pass the same clockwise option to Core `sketchVariantContour`; saved arc middle/end points encode the chosen sweep, so reopening needs no extra preference metadata.

Elliptical arc uses the four-point Core construction in `elliptical-arc.ts`: center, primary radius, start (which determines the secondary radius), and end direction. Preview adds a temporary dashed full ellipse and uses the same primitive for the committed arc. `drawing-tool.ts` attaches a selectable center; `arc-direction-control.ts` also serves this variant. Native ellipse geometry handles reopening. Primary-axis start placement is available by setting the optional secondary radius in millimeters. Pointer-only placement retains the last valid temporary-ellipse radius when the cursor reaches the primary axis. Immediate diameter entry is provided by recent-ellipse.ts.

Reference: [Onshape Elliptical Arc](https://cad.onshape.com/help/Content/Sketch/elliptical_arc.htm).

`recent-curve-sizing.ts` composes circle/arc radius entry and `recent-ellipse.ts` diameter entry under one lifecycle. Ellipse fields follow document length units; Enter commits the primary diameter and focuses secondary, then commits secondary and returns to canvas. The combined button commits both atomically. Core `set-ellipse-diameter.ts` creates or updates ordinary axis-length drivers.

`elliptical-radius-control.ts` supplies an optional numeric secondary radius for elliptical-arc placement. Blank preserves radius inference from the third point; a value allows start/end directions anywhere on the conic, including primary-axis starts. Preview and placement pass the same Core option. Commit persists a normal secondary diameter driver using setSketchEllipseDiameter.

The radius control observes valid temporary ellipses during the current gesture and passes a remembered-radius fallback to Core. Core uses it only for an otherwise ambiguous axis start; ordinary third-point sizing stays dynamic and an explicit numeric radius takes precedence. The fallback resets when the gesture ends or another tool is selected, and is not persisted as a dimension.

Temporary elliptical-arc guides snap to their four axis endpoints through Core `elliptical-guide-snap.ts`, using viewport tolerance and the same fixed/remembered-radius construction. Geometry snapping controls this behavior. `ellipse-endpoint-quadrants.ts` infers canonical quadrant relations for exact new-arc endpoints on commit; no temporary guide is serialized.

Three-point arcs use Core `snapSemicircle` during pointer curvature placement and `inferSketchSemicircle` during commit when geometry snapping is enabled. Numeric exact semicircles also receive the relation. `drawing-tool.ts` owns placement integration; the workspace only supplies pointer tolerance/policy. Construction centers/chords are excluded from the open/closed profile counter. Tests cover disabled snapping, undo, persistence, radius edits, and retained trim/offset behavior. Live browser acceptance is still required.

Immediate radius/ellipse-diameter entry uses Core `quantity-expression.ts` through `@aether/core/units`. Supported calculator syntax: decimal/scientific numbers, pi/π, parentheses, unary signs, + - * / and right-associative ^. Calculate in the selected display unit, then convert to canonical millimeters. No eval or executable input is used. These are evaluated numeric entries; named variables, explicit unit suffixes and persisted expression dependencies are not implemented by this parser. Invalid combined ellipse input never commits a partial edit.

`constraint-panel.ts` and `saved-constraints.ts` also use the shared numeric calculation parser. Creation evaluates only numeric driving constraints; reference dimensions and geometric relations do not parse irrelevant values. Saved numeric drivers evaluate before `editDrawingDimension`, preserving atomic validation and undo. `dimension-input.ts` binds these fields to document display units, converts calculations to canonical millimeters/degrees, and converts pending valid entries when units change. Creation labels, saved values and reference measurements show their selected unit. Dispose each binding on list replacement or panel closure. Invalid pending calculations are cleared on unit change to avoid reinterpreting an unfinished value.

`dimension-label-units.ts` formats canonical values for sketch labels and accessible offset/slot handle text. A single workspace subscription refreshes annotation text/spacing on document-unit changes without re-rendering controls. The subscription is removed on close. Annotation geometry and manipulation remain canonical. `constraint-panel.ts` preserves pending saved-dimension input across the selection-mode refresh triggered by clicking a label.

`dimension-link-editor.ts` owns the expandable relationship editor in each saved numeric driver row. It selects a stable-ID driver, a dimensionless calculation for multiplier, and an offset in document display units; Core `linkSketchDimension` validates and solves the relationship. Dispose its offset unit binding with the containing saved row. Editing a linked dimension value adjusts its shared driver; the editor explains that behavior. Named variables and multi-input formula authoring remain open.

Linked rows expose **Unlink dimension** in the relationship editor. Core preserves the current value; the normal commit path provides undo/redo and persistence. Subsequent changes to the former upstream driver no longer resize the unlinked dimension. Its own downstream followers still follow it.

## Text outlines

`text-panel.ts` owns font-file selection, async preview lifecycle, numeric placement and insertion controls. Core `sketch/text/outline.ts` owns font parsing and contour geometry. The workspace supplies its existing undoable commit and disposal hooks. The panel offers ordinary outlines or retained editable text. `text-items.ts` owns saved-item selection, Core regeneration, detach, history synchronization and async conflict/disposal checks. `text-panel.dom.test.jsx` exercises the mounted workspace and native save/reopen.

`text-placement.ts` owns temporary baseline picking, geometry snapping and Escape/disposal cleanup. It updates the panel coordinates without committing. `text-panel.ts` caches outlines at one millimeter em size and applies Core similarity transforms for preview; only font/text changes invoke font generation. Text-box constraints, height sizing and retained text authoring remain separate unfinished work.

`text-retained.dom.test.jsx` covers retained creation, native reopening without selecting the font again, editing, undo/redo, detachment and stale async results. `sketch-workspace.ts` calls the panel sync hook during history/geometry rendering. Text-box constraints and styles remain unfinished.

Horizontal/vertical text flip controls use Core `textPlacementTransform` for previews and persist through retained-text updates. Reflections occur before rotation around the baseline origin. Keep this transform shared with font outline generation.

`text-fonts.ts` offers locally served Noto Sans Regular/Bold/Italic/Bold italic.
It cancels obsolete fetches when another font, custom file or saved item is chosen.
The panel owns preview generation; Core owns shaping. Font/shaping licenses are
linked and emitted as build assets. Vite excludes `harfbuzzjs` from dependency
prebundling so its relative WebAssembly asset resolves in development.

`text-command.ts` registers the ribbon Text command. It is enabled after plane
selection, switches the drawing tool to Select, and opens the text panel. With no
font selected, the panel requests bundled Noto Sans Regular; otherwise it redraws
the cached preview. The command and panel remove their listeners on disposal.
The illustrated Text icon is shared through `@aether/ui` and uses theme colors.

`text-items.ts` exposes **Add text frame** for a selected retained text item.
The frame is construction geometry with ordinary selectable edges/vertices:
constrain the baseline origin and rotation, dimension height for em size, and
width independently of letters. The Core frame/solver modules own geometry and
constraint meaning. Frame references survive Update editable text and native
reopening; manual letter constraints still require resolution before replacing
letters. Undo/redo restores frame presence and saved text fields. The mounted
`text-frame.dom.test.jsx` covers this workflow; live browser acceptance remains.

`text-box-placement.ts` owns **Draw text frame**: drag or choose two opposite
corners, with geometry snapping, live cached-letter/em-height preview and a
dashed construction frame. Reverse corners use the current rotation/flip axes.
Escape/tool switching restores the pre-gesture fields; zero-area frames remain
unaccepted. Creation is committed by Create editable text; the panel's optional
frame width is passed to Core for atomic retained creation/update. This module
contains gesture state only; Core text placement/frame modules own geometry.
Existing text frames now also have dedicated resize handles.

Retained text uses the ordinary `selection-drag.ts` flow and Core
`text/drag.ts` preparation. A free frame/letter drag moves the whole text;
constraints can hold its baseline while a corner drag changes width and em height.
`text-drag.dom.test.jsx` drives selection pointer events with a real font, native
reopening and anchored resizing. This does not prove live viewport acceptance or
by itself verify the dedicated frame resize handles.

`text-resize.ts` supplies width/height/corner handles for selected saved text.
Pointer motion previews Core `resizeSketchTextFrame` results, pointer release
commits once through the normal workspace checkpoint, and Escape/cancel/tool
switching discard the preview. Locked dimension conflicts and concurrent sketch
changes cannot overwrite document state. Handles preserve the baseline and
rotation/flips. `text-resize.dom.test.jsx` tests real-font pointer interaction,
native persistence, cancellation/conflicts and stale-commit prevention.

The Sketch text editor is a textarea. Core normalizes line endings, shapes lines
independently, preserves blank lines and puts subsequent baselines below the
first-line frame using font metrics. `text-multiline.dom.test.jsx` covers preview,
retained update, undo/redo and native line-break persistence. Frame width does
not cause wrapping; width and em height retain their existing meaning.

**Flip about frame center** selects the retained reflection convention. New
framed text defaults on; legacy records load their baseline-axis behavior until
explicitly changed. Preview, frame drawing and resize handles use the Core glyph
and frame transforms respectively. Center flips leave the frame stationary;
width edits move reflected letters with the center without stretching them.
`text-frame-flips.dom.test.jsx` checks real-font preview/frame geometry and native
mode persistence, using numeric tolerance for normalized preview rounding.

New horizontal text frames show their default horizontal relation in the existing
Sketch constraints list. Remove uses the normal Core mutation and undo/redo
checkpoint; rewording never recreates the removed relation.
`text-baseline.dom.test.jsx` verifies removal, undo/redo, rotation and native
persistence using the actual workspace controls. Deliberately rotated frames
and already-constrained retained letters do not receive redundant inference.

`text-height.ts` owns the optional **Size text by ascender height** control and
**Text height (mm)** field, synchronized with canonical em sizing. Existing em
authoring remains available. Core supplies font metrics and saved height meaning;
the UI does not infer glyph bounds. Frame gestures convert physical height to em
size and handles reopen/resize using the persisted ratio. The real-font
`text-height.dom.test.jsx` covers physical entry, native reopen, handle resizing
and undo/redo. Font metric and outline loading share the Core parsed-font cache.

Numeric dimension inputs use Core's shared expression parser with unit/variable
and text syntax disabled, keeping the current display-unit contract. They accept
sqrt, scalar trigonometry (radians), min/max and rounding functions alongside
arithmetic. `constraint-units.dom.test.jsx` now creates inch/radian constraints
using functions, retaining canonical/native unit checks. Native document-variable
definitions exist in Core, but a variable editor and geometry/text bindings are
not exposed by this numeric-field change.


`text-expression.ts` owns the formula toggle/field and resolved-wording display.
It calls Core's variable resolver/text evaluator; no expression semantics live in
UI code. `text-panel.ts` previews the resolved wording and passes the binding plus
an ephemeral variable map to retained-text creation. Loading/undo restores mode;
turning the toggle off passes null to explicitly detach the formula, preserving
visible wording. Invalid expressions disable creation and clear stale preview.
If variables change after preview, saving refreshes and requires another click.
Workspace supplies the current document-variable getter. The separate variable
editor and draft-variable undo/transaction integration are still planned.


`variables.ts` owns the sketch-local variable-definition form. Core validates
names/types/units/dependencies and regenerates expression text. Apply commits
variables and drawing through one workspace checkpoint; `history.ts` snapshots
both. Invalid edits, concurrent draft changes and disposed work cannot commit.
Finish rejects unapplied form entries and invokes `updatePartDocumentVariables`
with the complete sketch draft, so binding removal, new variables and insertion
at rollback are one validated document transaction. Cancel discards the draft.
The finish path checks for geometry/variable changes across asynchronous work.
Variable formulas currently drive text; binding them to dimensional constraints
is still planned.


Variable Apply now also calls `regenerateDimensionExpressions` after text updates.
Core resolves every dimensional driver before solving once; native document
validation rejects stale formula caches. Formula drivers reject numeric overwrites
until explicitly unbound. The dimensional formula creation/editor UI is next;
current variable editing can update already-bound dimensions.


`dimension-formula-editor.ts` presents formulas for saved driving dimensions.
It evaluates document/draft variables through Core and commits `setDimensionExpression`
through the ordinary sketch checkpoint. Bound numeric fields are read-only; explicit
Remove formula keeps the solved value. A follower of a formula driver edits the
shared driver with a visible explanation. Annotation focus targets the formula and
preserves pending formula text across selection-mode refresh. Reference dimensions
have no formula editor. Formula creation directly in the initial constraint entry
and broader geometry-tool propagation remain to be completed.


`constraint-formula.ts` owns initial driving-dimension formula mode. It resolves
through Core before the new constraint is solved/committed once; ordinary numeric
fields retain their display-unit behavior. Formula mode requires typed explicit
units and is inactive for reference measurements or nondimensional relations.
The creation panel persists the formula with its canonical value, making it
available immediately to the saved formula editor and variable regeneration.


Transform offers independent copies through `copySketchContours`. Core's focused
`copy-constraints.ts` remaps owned geometry and dimension IDs, scales dimensional
values/formulas, preserves internal driver graphs and transforms fixed points.
Relations to unselected geometry and original pattern membership are omitted.
Quarter turns swap horizontal/vertical relations; arbitrary rotations omit axis
relations that cannot remain true. Compatibility is checked against transformed
geometry before returning. Associative pattern construction explicitly requests
geometry-only copying because its source/instance equations own the relation.
Complete intact text copies now retain metadata through Core text/copy.ts.
Clipboard transport, frame-centered reflected text and arbitrary-rotation DOF
replacement remain planned; the existing move operation still rejects conflicts.

### Clipboard

`clipboard.ts` owns browser clipboard events, contour selection, placement preview and lifecycle guards. Core `document/sketch-clipboard.ts` owns the versioned payload and geometry validation; `document/clipboard-variables.ts` owns expression dependency packaging and variable conflict detection. The workspace commits the returned drawing and variables through its existing history checkpoint. Keep serialization and constraint semantics out of the browser adapter.

Reflected retained text uses Core's optional `placementReflected` orientation. The text panel keeps it when loading/editing a saved item and clears it when starting new text. Preview and two-corner box placement use the shared placement helpers; do not reverse frame vertices in the UI because dimensions may reference their stable identities.
