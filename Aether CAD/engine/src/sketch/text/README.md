# Sketch text

`outline.ts` converts caller-provided OpenType bytes into ordinary sketch contours.
The parser and HarfBuzz shaper load lazily. Quadratic curves convert algebraically to cubic Beziers;
cubic curves remain cubic. Implicit CFF contours close at the next move or end of
path. Nested counters use the shared imported-region classifier. Placement is a
baseline origin and counterclockwise rotation; size measures the font's em.

`records.ts` defines optional native `SketchDrawing.textItems`: wording, embedded
font bytes as base64, explicit millimeter/degree placement, generated contour IDs
and a SHA-256 outline digest. Metadata validation allows missing/edited contours
so ordinary sketch edits and deletion remain possible. The edit-state API reports
that divergence. IDs and provenance do not contribute to the geometry digest.

`edit.ts` owns explicit retained-text operations:

- `putSketchText` creates or replaces text. Replacement can reuse the embedded
  font after native reopening, regenerates outlines, and remaps unrelated
  constraint indices through the existing contour-deletion operation.
- `sketchTextEditState` reports editable, modified or constrained outlines.
  Replacement rejects manually modified geometry and constraints on letter outlines.
  Constraints attached only to the stable construction frame survive rewording,
  font changes and native reopening; their equations drive the resulting placement/size.
- `detachSketchText` removes authoring metadata while preserving all geometry.

The CAD text panel supports retained creation, selection, editing and detachment,
alongside ordinary outline insertion and explicit Add text frame. Additional font families and broader mixed-script layout remain. Intersecting/touching outlines need region repair. WOFF2 requires
separate decompression. Noto Sans regular/bold/italic/bold-italic fonts are bundled under `core/assets/fonts/noto-sans/` with their original license. Tests use both original synthetic fonts and these real fonts.

Kernel text tests exercise actual new-solid and through-cut operations, including
counters, multiple letters, cubic curves, scaling, rotation and native reopening.
`regions/groups.ts` cuts each solid's holes before combining disconnected regions.

`placement.ts` supplies the shared text transform: optional horizontal/vertical reflections about the frame center (or legacy baseline axes), followed by rotation and translation. Positive scale handles normalized UI previews. Flip flags persist with retained text; outline conversion and the panel use the same transform. Kernel tests cover reflected new/cut solids and counters.

`shaping.ts` uses HarfBuzz glyph substitution and positioning, then reads exact
per-glyph paths from OpenType. This avoids OpenType.js's unsupported contextual
substitution lookup path. It currently shapes a single run; mixed-direction/script
itemization and full text layout remain incomplete. `woff.ts` unwraps WOFF1 tables
without rewriting layout data, preserving parity with the original SFNT font.
WOFF2 still needs decompression support. `bundled-fonts.test.ts` checks all four
real styles; `woff.test.ts` compares shaped compressed/original font geometry.

`solver/text-coordinates.ts` treats intact retained outlines as one similarity
object for solving and diagnostics: translation X/Y, rotation and positive uniform
scale. Constraints on letter geometry therefore move/scale the entire text,
including counters, instead of deforming individual vertices. Successful solves
update placement, em size and digest. Modified/detached outlines retain ordinary
sketch behavior. Fixing any owned contour fixes the whole retained group.

`digest.ts` uses synchronous SHA-256 from Noble hashes, preserving the previous
WebCrypto digest contract so the synchronous solver can refresh saved digests.
`frame.ts` attaches an ordinary selectable construction rectangle, identified in
`SketchTextItem.frameContourId` and included in its owned contour IDs/digest.
Its local baseline starts at the text origin, height follows the saved sizing mode, and positive
`frameWidthMillimeters` is independent of letter width. The initial width is a
conservative outline/control-point extent; it is not a font advance or wrapping
metric. Rotation and flips use the same placement transform as the letters.

Framed text has a fifth solver coordinate for independent frame width. A fixed
origin, horizontal baseline, width and height fully constrain the group. Height
scales letters uniformly; changing width does not stretch them. Regeneration
preserves the frame contour/edge/vertex identities, remaps constraint indices and
solves the retained equations before returning. Frames remain construction
geometry and do not add solid material. Add text frame is explicit and undoable;
new horizontal frames receive the creation-time baseline relation described below. The CAD panel supports drag/two-corner canvas box placement with live preview.
Full text-layout parity remains unfinished.

`putSketchText` accepts optional `frameWidthMillimeters`, creating a frame in the
same atomic operation as new text or requesting a new width on retained text.
Existing driving frame constraints take precedence through the solver.

`drag.ts` prepares pointer movement by translating every owned contour and the
retained baseline together, refreshing the digest before ordinary drag targets
enter the solver. This avoids breaking grouped text into independently deformable
curves. Existing constraints then determine the allowable motion: a free group
translates; a corner opposite a fixed/horizontal baseline can resize its frame
and proportional glyph height. Conflicting moves throw without changing source
geometry. No temporary pointer constraints persist. Modified/detached text keeps
ordinary curve behavior. This is constraint-driven vertex/edge dragging; dedicated
frame resize handles use the explicit operation below.

`resize.ts` owns explicit baseline-preserving frame resizing. Width preserves letter size while updating the frame/reflection center; em height scales all glyph curves/counters uniformly.
Rotation/flips, stable frame identities and embedded font data remain intact.
Temporary targets on three frame corners enforce the requested dimensions and
baseline during the existing constraint solve. Conflicts reject atomically and
temporary constraints never persist. CAD handles are a presentation of this
operation, not a second solver or font-layout implementation.

`content.ts` shares text validation between authoring and native records: CRLF/CR
normalize to LF; blank-only text, tabs/control characters and content exceeding
1000 characters reject explicitly. `shaping.ts` shapes each line independently
with one font, resetting horizontal advance and stepping subsequent baselines
downward using font ascender/descender/line-gap metrics (at least one em). Empty
lines retain spacing. The frame still describes the first line; frame width does
not wrap or stretch text. Multiline letters remain one retained solver group and
resize proportionally. The panel uses a textarea; native records keep line breaks.

Remaining reference gaps include text
expressions tied to document variables, and mixed-script/direction itemization.
These are separate from multiline support; full Text parity is not established.

`flipAboutFrame` persists the reflection convention. New text created with a
frame defaults to center reflection; absent/false retains legacy baseline-axis
geometry. The panel exposes the convention so existing text changes only on an
explicit edit. `textFramePlacement` keeps construction frame axes unflipped in
center mode while `textPlacementTransform` reflects letters about half the
frame width/em height before rotation. Preview uses actual frame dimensions
with normalized glyph curves, without scaling the center offset twice.

`frame-width.ts` adjusts horizontally reflected letters when independent width
changes through either the solver or resize operation. It shifts glyph placement
to the new center without changing font size, keeping native regeneration and
numeric/pointer edits consistent. Legacy records and frame axes stay unchanged.

`baseline.ts` adds a normal horizontal constraint when a frame is first created
and its baseline is already horizontal. It skips deliberately rotated frames
and retained text with existing driving constraints, avoiding redundant inferred
relations. Regeneration preserves/remaps the constraint identity; once removed,
it is not inferred again. New free horizontal frames have five geometric solver
coordinates and four remaining degrees of freedom. Authors remove the baseline
relation through ordinary constraint controls before rotating the frame.

`font.ts` shares lazily parsed fonts between shaping setup and metrics through a
WeakMap keyed by immutable font buffers. `height.ts` projects first-line frame
height from canonical em size and optional persisted `fontAscenderRatio`. Missing
ratio preserves legacy em-height geometry. The ratio is read from the embedded
font during authoring and refreshed when changing fonts; synchronous solves use
the saved metric without parsing fonts inside each numerical iteration.

`putSketchText.textHeightMillimeters` requests baseline-to-font-ascender height,
converting to canonical em size. `null` explicitly selects em sizing; omission
preserves an existing sizing mode. Frame creation, vertical center flips, numeric
dimensions and pointer handles use the same height projection. The explicit
resize Core operation still takes em size; UI handles convert physical height
using the persisted ratio. Actual glyph/cap bounds may differ from font ascender.


### Expression-bound wording

`expression.ts` resolves a retained formula using the shared typed evaluator and
an ephemeral map from `evaluateDocumentVariables`. Dimensional values must be
converted explicitly (for example `#length / mm`) before text conversion.
`putSketchText` stores the formula and generated wording; omitting `expression`
preserves the binding, while `null` explicitly returns to literal wording.

`regenerate-expressions.ts` owns atomic drawing regeneration. It snapshots input
variables, evaluates every formula, then updates only changed wording through the
normal retained-text operation. Frame IDs/constraints, embedded fonts, placement,
flips and ascender mode survive. Failures return no partial drawing. Unchanged
wording preserves contour identities, including intentional manual curve edits.

`document/update-variables.ts` now provides the document-wide transaction.
It updates direct and projection-authored drawings in feature order, including
suppressed/rolled-back history, and rejects orphaned downstream projections.
`validatePartDocument` verifies every retained formula against saved variables;
stale wording cannot be serialized or reopened. A drawing alone validates syntax,
while document validation supplies variable scope. The CAD variable/text-expression authoring panels use this contract.


### Independent transformed copies

`copy.ts` attaches a new retained record when all contours of an intact text item
are copied. It remaps ownership/frame IDs, composes translation/rotation/scale,
preserves fonts/formulas/ascender mode, and refreshes the outline digest. Copied
constraints are remapped separately by `operations/copy-constraints.ts`.
Partial or manually edited groups copy as ordinary curves. Associative patterns
explicitly omit retained metadata, since their source graph owns regeneration.
Reflected copies preserve whole-frame handedness via `placementReflected`, including frame-centered letter flips and stable frame reference ordering. The Transform UI's positive-scale translation/rotation path is also supported.

### Mirrored placement contract

`placementReflected?: boolean` records the handedness of the whole local text coordinate system, before world rotation. Missing/false preserves existing documents. This differs from letter flip controls: the entire construction frame and its stable corner/edge ordering reflect with the text. Copy operations toggle it for negative-determinant transforms. Frame-center letter flips continue within that coordinate system. Core placement, regeneration, resizing and the UI preview share this field.
