# STATUS

> Truthful, or it's worthless. Any commit that changes behavior updates
> this file in the same commit — see `CONVENTIONS.md` → "STATUS stays
> truthful."

## Product-owned CAD engine, and sketch-plane fixes — 2026-09-11

- **The CAD engine moved to `Aether CAD/engine/`.** It was `core/engine/`, named `@aether/core` as though suite-shared, but its only consumers were Aether CAD (104 files) and two `core/ui/gallery` demos — `aether-animation/web` never imported it. Aether Studio is the server (`core/host/`, `core/session/`); products own their engines, the way Onshape owns its kernel binding and feature library. Import name `@aether/core` is unchanged, so no consumer source changed; only dependency wiring and two asset paths that reached out of the package. `core/ui` now carries the engine as a **devDependency** for its gallery demos only, so the shared design system no longer sits downstream of one product's engine — `aether-animation/web/node_modules/@aether/` contains only `ui`. Verified: 462 CAD tests + typecheck + build, 719 engine tests, 163 core/ui tests + typecheck + build, animation web build.
- **Sketches render again, and the sketch plane is a real object.** The in-world sketch SVG is reparented into the viewer's CSS3D layer, but 40 geometry CSS rules were still scoped to the workspace ancestor, so every line drew with `stroke:none` — nothing appeared. The plane is now one 160 mm square anchored to the selected plane's (or planar face's) frame origin, with face, grid, axes, origin marker and name label all drawn inside it; it no longer follows the pan/zoom viewport. The world floor grid hides while a sketch is open, so a sketch on XY no longer shows a second, perpendicular grid beside it.
- **Reference-plane visibility persists** across reloads and is no longer discarded when a sketch finishes. **Placing a sketch plane no longer arms the line tool** — the first click selects until a tool is chosen.
- **The sketch feature window matches the Aether UI gallery again.** Nine bare-element rules under `.cad-sketch-workspace` outranked the shared widget's own styling and repainted it (the green accept and red discard had become neutral bordered boxes); every control the app creates there is `display:none`, so those rules styled nothing else. Also `index.html` pinned `color-scheme: dark`, painting native checkboxes as black squares inside light panels.

## Universal collapsible sidebar — 2026-09-10

- Shared `CollapsibleSidebar`/`SidebarLabel` in @aether/ui collapse any sidebar to an icon rail with persisted per-sidebar preference; the CAD Home library nav adopts it (210px ↔ 56px). Header-size standard moved to the larger 56px bar with 36px app tiles; selected items use the new paired text-on-selected token; the Studio sidebar shows one identity block.

## PDM v1: continuous saving, commits, branches — 2026-09-10

- CAD documents autosave continuously (debounced revisions on the content-addressed history; failures surface, success is quiet) and the Save command is now an annotated **Commit** (name + message, listed in Version control). The host models branches as a revision DAG (branch heads, parent pointers) with branch-aware save/read isolated from Main, all under the existing optimistic-revision guards. Design and staged path to simultaneous editing: dev/docs/roadmap/PDM_Versioning.md.

## Team-scale host and workspace themes — 2026-09-10

- The host no longer serializes requests behind one global lock: suite assets are lock-free and app bundles stream outside it, with SQLite in WAL mode — sized for a ~200-person team. Workspace theme administration ships end to end: admin Appearance page sets the company base theme and per-application overrides; members can set a personal override on My account; precedence personal > application > base, applied on every host page with light/dark working inside any theme.

## Hot-swap themes and icon packs — 2026-09-10

- Themes install and activate at runtime (installAetherTheme + setAetherTheme; injected scoped CSS, persisted, cross-tab) and icon packs hot-swap every mounted icon through the registry store with per-icon fallback — no rebuilds. Asset layout is formalized (themes/, icons/, icon-packs/) with contributor READMEs.

## Default theme and icon pack shipped — 2026-09-10

- The default theme is a JSON manifest (both modes) generating tokens.css via `dev/build-theme-css.mjs` (parity-verified); the default icon pack is manifested with a registry↔artwork drift guard; row/icon-slot/grid geometry tokens make the sidebar block system reusable for toolbars and tables. New themes and packs are data, not CSS rewrites.

## Theme contract enforced — 2026-09-10

- Studio stylesheets contain zero raw color literals: structure uses --aether-* tokens, decoration uses scoped theme variables with dark and light values. `dev/check-theme-literals.mjs` gates the studio build; the theming/icon-pack contract and expansion plan live in the roadmap.

## Suite-wide appearance — 2026-09-10

- Appearance (System/Light/Dark) now applies on every suite page at load via a shared bootstrap, follows OS scheme changes live in System mode, syncs across open tabs, and cascades into the Studio home-theme wrappers. Default is System.

## Account popover and account page — 2026-09-10

- The suite account popover matches the Onshape reference: identity header plus uniform button rows (My account, Aether Studio, Sign out); appearance and profile-picture controls moved out. Appearance is a single device-local system (shared toggle + light tokens); the legacy per-user server theme path is removed. The Studio account page now covers name, email, password, and profile picture with upload validation.

## Focus halo disabled and tokenized — 2026-09-10

- The focused-field glow halo is disabled suite-wide as the named `--aether-focus-halo` token (default `none`); every application point references it, so grep finds them and any future placement is a scoped one-line override. Focus border colors and keyboard focus outlines remain.

## Modern document bar and native header trio — 2026-09-10

- Document-bar controls render as plain macOS-style glyphs (no boxes; hover highlight; accent when active); the redundant New/Open/Save/Insert header buttons are gone — the ribbon owns them, with data-command anchors on ribbon tools.
- The native header trio is imported faithfully into shared `@aether/ui` StudioChrome: preset-colored studio-mode button (click cycles, menu with reset and product extras), workspace windows/tabs menu (browser-managed entries visibly disabled), and the System→Light→Dark appearance toggle with persisted, immediately-applied theme. CAD uses all three; native semantic palette tokens and seven icons back them.
- Verification: core/ui 156 tests, typecheck, build; CAD 443 tests, typecheck, production build; live header confirmed by screenshot.

## Studio pages bottom tray — 2026-09-10

- Every Studio host page (home, library, sign-in, admin) now shows the shared bottom tray — connection light, "Aether Studio", site name, and the signed-in identity — matching the native app's always-visible status bar. CAD already showed its tray on all screens; Animation's regional tray remains for its convergence pass.
- Verification: studio typecheck and production build; the host serves the new bundle.

## History timeline and feature context menu — 2026-09-10

- The bottom History tab is a Fusion-style horizontal timeline: icons-only feature strip, rollback playback controls, and a draggable rollback marker, all through the undoable document path; the bottom panel shrank to fit. The sidebar History keeps its vertical list.
- Feature tree rows have a right-click context menu: Rename (new), Edit, Suppress, Roll back before, visibility and folder operations work today; the remaining Onshape-reference entries are visible but disabled pending build-out.
- Verification: CAD 443 tests, typecheck, production build; live reload with visual confirmation of the timeline.

## Ribbon workspace dropdown — 2026-09-10

- The DESIGN ▾ workspace switcher renders at the ribbon's left in both chrome themes (previously suite-only); the interim bottom-tray workspace menu is removed so there is one switcher, matching the Fusion-style reference.
- Verification: CAD 439 tests and production build; live tab reloaded.

## Universal tree folders — 2026-09-10

- `@aether/core` now provides a universal, validated tree folder organization (create, rename, dissolve, assign, cycle-safe nesting, generic foldered display builder); `PartDocument.organization` persists it in `.acpart`, and folders never affect feature evaluation order.
- The CAD Feature tree uses it end to end: footer button creates folders from the selection, drag in/out/nest, rename and dissolve actions, per-folder expansion, top-level rollback line — all undoable and save/reopen-safe.
- Feature tree polish: the search sits in the fixed top section like the native app, and tree badges show state only (Suppressed / Rolled back / Under-defined) instead of parameter summaries.
- Verification: engine 710 tests and typecheck; CAD 439 tests, typecheck, production build; core/ui 153 tests; live tab reloaded.

## Feature tree header and rollback polish — 2026-09-10

- The left Model panel is renamed Feature tree with a single clean header (icon, name, count) — no subtitle, float/close buttons or placement menu; shared WorkspaceShell supports per-panel `chromeless` docked presentation. The tree filter shows its count only while filtering.
- The rollback bar is a plain draggable accent line (unselectable, no row chrome or hover buttons); under-defined sketch features render red in the tree.
- Verification: core/ui 153 tests, typecheck, build; CAD 436 tests and production build; live tab reloaded.

## CAD left-rail buildup — 2026-09-09

- The left rail now carries Version control in both chromes plus three visibly-mocked panels — Comments, Document notes and Action items — with greyed-out tools and a "Planned — not functional yet" note; new shared `comment`/`notes`/`tasks` icons back them.
- Verification: core/ui 152 tests, typecheck and build; CAD 435 tests and production build; live tab reloaded.

## CAD Model panel and workspace switcher convergence — 2026-09-09

- The Items panel matches the native tree: features list flat (no document wrapper folder) between Reference Geometry and Bodies; the rollback position is a slim draggable accent line; hidden reference planes, bodies and imported parts show a pinned slashed-eye icon (shared `visible`/`hidden` icons) instead of a "Visible" text badge; the folder/commands footer attaches to the bottom of the slide-out panel.
- The Design/Animate/Show/Hardware switcher left the top document bar and is a Workspace dropdown beside the app name in the bottom tray (disabled entries keep their suite-routing explanations).
- Shared tree gains per-node `className` and pinned action support; both are unit-tested. Verification: core/ui 152 tests, typecheck, build; CAD 434 tests and production build; live browser reload confirmed the panel.

## CAD suite status tray — 2026-09-09

- The CAD bottom tray now leads with app identity: connection light (backend state), the "Aether CAD" name and the renderer label, moved down from the top document bar. The center is a flexible truncating notification area with the live status message and background-task control; workspace metrics and the interface-theme menu (now opening upward) trail.
- Shared `@aether/ui` StatusBar supports optional leading/center/trailing regions; the plain-children form is unchanged, so Aether Animation and the gallery render as before until they adopt regions.
- Verification: core/ui 151 tests, typecheck and build; CAD 434 tests and production build passed; the served app was reloaded in Safari and the tray visually confirmed.

## Reflected editable text frames — 2026-09-09

- Added optional `placementReflected` to retained text placement. Reflection now applies to the entire local coordinate system; construction corners/edges keep their ordering and identities. Existing documents default to unchanged placement. Letter flip controls remain independent.
- Copied framed text now remains editable through regeneration, dimensions, solving, resizing and native save/reopen. The CAD text preview and box-placement calculations use the same Core orientation. This removes the previous explicit rejection of frame-centered reflected copies.
- Verification: Core **698 tests passed**, Core typecheck and CAD build passed. CAD broad run passed **430 existing tests**; the new reflected-frame test initially failed on exact floating-point SVG string equality, then passed after switching to numerical tolerances. The corrected test covers preview, rewording, undo/redo, native reopening and unchanged frame identities. Live browser verification remains outstanding.
- Full parity remains open: transform constraint adaptation, partial-edge clipboard selection, text shaping/import gaps and the remaining acceptance matrix still require work.

## Sketch clipboard controls — 2026-09-09

- Added a focused `sketch/clipboard.ts` browser adapter: contour selection, native canvas copy/paste, clipboard buttons, offset/rotation/scale preview, explicit Apply/Cancel and Escape cancellation. Text fields retain normal clipboard behavior.
- Paste commits geometry, compatible internal dimensions/constraints, complete retained text groups and referenced variables in one draft undo step. Conflicting variable definitions fail before mutation; stale asynchronous reads are discarded. Finish requires resolving a pending preview.
- Verification: CAD suite 429 tests passed, then the added workspace integration test passed with all four focused clipboard tests; CAD typecheck/build passed. Core's unchanged clipboard contract was previously verified in 696 tests. Native save/reopen and variable-aware undo/redo are covered in JSDOM. No live browser session was available (`browsers.list() = []`); visual and OS clipboard acceptance remain outstanding.
- Limits: clipboard selection currently copies whole contours. Partial-edge packaging, frame-centered reflected text, broader transform constraint adaptation and full parity remain open.

## Portable sketch clipboard contract — 2026-09-09

- Added versioned `aether-sketch-clipboard` fragments in focused `document/sketch-clipboard.ts`, with bounded parsing/serialization, internal-geometry validation and formula-cache checks. Fragment creation preserves compatible copied constraints and complete editable text groups using the same copy implementation as Transform.
- `clipboard-variables.ts` walks expression ASTs to include only referenced definitions and transitive dependencies. Paste merges identical definitions and rejects conflicting names before returning geometry/variables for one draft commit. External projected context/relations never travel in the payload.
- Extracted a shared internal append primitive so copying a 1,000-contour selection does not temporarily need 2,000 contours. Repeated pastes get independent geometry, text and constraint identities; targets remain unchanged on validation/capacity/conflict errors.
- Five tests cover selected dependencies, repeated paste/native persistence, malformed/stale/conflicting payloads, embedded editable text and capacity. Full Core **696** / CAD **426** tests, Core typecheck and production build passed; all handles exited 0. Existing warnings remain.
- This slice implements the Core clipboard contract, not browser clipboard commands. UI selection/clipboard events, placement preview, draft-variable undo integration for paste and live browser acceptance remain next; broader parity stays open.

## Editable text Transform copies — 2026-09-09

- Added focused Core `text/copy.ts`: complete intact text groups retain independent wording/font/formula metadata, transformed placement/em/frame sizing, ascender mode and remapped ownership/frame IDs. Copied frame constraints remain independent; outline digests are refreshed.
- Partial or manually edited groups remain ordinary curves. Associative pattern copies explicitly omit retained metadata because their source graph owns geometry. Unframed reflection is supported; frame-centered reflected copies reject explicitly pending frame-reference remapping.
- Four Core tests cover scaled/rotated independent editing/native persistence, multi-copy expression regeneration, partial/manual selections and reflected regeneration geometry. A mounted Transform workflow covers copied-text selection, independent rewording, undo/redo and native reopening. Full Core **691** / CAD **426** tests, Core typecheck and production build passed. All process handles exited 0; existing warnings remain.
- Clipboard transport, frame-centered reflection, arbitrary-rotation constraint replacement, move-transform adaptation and live browser/full parity remain open.

## Constraint-preserving transform copies — 2026-09-09

- Rechecked [Onshape Transform Sketch](https://cad.onshape.com/help/Content/Sketch/sketch_transform.htm): internal relations survive translations/half turns, horizontal/vertical swap at quarter turns, and directed dimensions may be removed or replaced.
- Added focused Core `copy-constraints.ts`: copies remap internal contour/constraint identities, preserve independent dimension links and variable formulas, scale dimensional values, transform fixed points and swap applicable axis relations. Unselected external references and original pattern membership are omitted. Incompatible retained relations reject before returning geometry. Arbitrary rotations omit incompatible axis constraints; replacement construction geometry is not yet implemented.
- Associative pattern construction explicitly uses geometry-only copies to avoid duplicate source/instance equations. Added Transform's Copy selected geometry option with copied-geometry preview and a visible explanation of omitted relations.
- Five Core tests cover linked drivers/scaling, external-driver formula retention, quarter-turn/fixed-point remapping, multiple copies and native irrational-formula persistence. A mounted workflow covers preview, independent radius edits, undo and native reopening. Full Core **687** / CAD **425** tests, Core typecheck and build passed. After final explanatory hint wiring, the copy workflow and build passed again. All process handles exited 0; existing warnings remain.
- Clipboard transport, retained text metadata copying, arbitrary-rotation DOF replacement and move-transform constraint adaptation remain open, alongside live browser/full sketch acceptance.

## Initial dimension formula creation — 2026-09-09

- Added focused `sketch/constraint-formula.ts`: initial driving dimensions can use retained formulas evaluated against current draft variables. Numeric mode retains document display units; formula mode requires explicit compatible units and disables the numeric entry.
- Creation resolves through Core before a single constraint solve/undo commit. Invalid formulas commit nothing. Reference measurements and nondimensional relations ignore formula input. Saved formulas flow into the existing dimension editor and native variable validation.
- Three mounted workflows cover length/radius/angle creation, missing variables, undo/redo, native persistence and exclusion from reference measurements. Full CAD **424** tests, production build and Core typecheck passed; all process handles exited 0. Existing build warnings remain.
- Read-only propagation audit found `copySketchContours` currently copies geometry without its constraints. Constraint-preserving copy and broader tool propagation remain next, alongside live browser/full sketch acceptance.

## Saved dimension formula editor — 2026-09-09

- Added focused `sketch/dimension-formula-editor.ts` for applying/removing formulas on saved driving dimensions using current draft variables. Formula-bound numeric values are read-only and show the formula; removal restores independent numeric editing at the current value.
- Linked followers of formula drivers edit the shared driver with an explicit explanation. Annotation focus opens/selects the formula; pending formula text survives selection-mode refresh. Every mutation uses Core operations and the normal sketch undo checkpoint.
- Full CAD **420** tests and production build passed. Final **2/2** formula workflow tests cover entry/unit errors, draft-variable update, undo/redo, annotation focus, native reopen/removal and shared-driver editing. A test selector initially matched the SVG annotation instead of the saved row; narrowed to the row and reran successfully. All process handles exited 0; existing build warnings remain.
- Formula entry during initial constraint creation, broader geometry-tool propagation and live browser acceptance remain open. Full sketch parity is not complete.

## Native dimensional expression bindings — 2026-09-09

- Added optional `valueExpression` for independent driving dimensions, with syntax/type validation and a canonical mm/degree value cache. Focused solver expression and operation modules resolve explicit typed units; unknown variables, incompatible units, invalid formula state and unsolvable dimensions reject.
- `setDimensionExpression` binds/unbinds formulas; variable regeneration resolves all drivers before one solve. Linked followers follow formula drivers. Numeric overwrites reject until the formula is removed; explicit conversion to a link or reference dimension removes its formula.
- Document validation now checks dimensional caches against variables, and document/draft variable transactions regenerate dimensional geometry as well as text. No resolver or variable cache persists in the sketch.
- Five Core tests cover typed lengths/angles, followers, rejection/immutability, explicit conversion and native transactions. Full Core **682** / CAD **418** tests, Core typecheck and CAD build passed. A subsequent focused workspace test confirms variable-driven radius regeneration/native save; all **3/3** variable UI tests passed. All handles exited 0; existing warnings remain.
- Formula creation/editing controls in the dimension panel remain next. Full tool propagation, live browser acceptance and the broader sketch parity ledger remain open.

## Sketch draft variable editor — 2026-09-09

- Added focused `sketch/variables.ts` for adding/removing/editing typed variable definitions. Core evaluates expressions and regenerates draft text atomically; invalid definitions and concurrent/disposed edits cannot commit. The text-expression panel now reads draft variables.
- Sketch undo snapshots include variables alongside geometry and annotation positions. Cancel discards variable changes. Finish rejects unapplied form edits, snapshots draft state across asynchronous work, and commits variables plus the edited profile through one Core transaction.
- `updatePartDocumentVariables` accepts an optional profile draft, supporting removal of a binding and its variable together, or insertion at rollback with new definitions. Canonical insertion bookkeeping is retained. Other affected sketches regenerate before final validation.
- Full Core **677** / CAD **417** tests, Core typecheck and CAD build passed. A subsequent focused second UI test for adding typed variables/removing unused ones passed (**2/2** variable tests). Existing formula UI test now verifies draft isolation. All process handles exited 0; existing build warnings remain.
- Variable-to-dimension bindings, richer variable presentation and live browser acceptance remain unfinished. Full sketch parity stays open.

## Sketch text expression authoring — 2026-09-09

- Focused `sketch/text-expression.ts` adds Use text expression, a formula field and resolved read-only wording. It uses Core evaluation with document variables, supports explicit return to literal text, and restores formula mode when loading saved items or undoing/redoing changes.
- The text panel previews resolved lettering and passes native bindings to Core. Invalid formulas clear preview and disable saves. Variable changes after preview trigger refresh and require another save attempt; ordinary outline insertion performs the same check. Workspace wiring supplies current document variables without duplicating evaluation logic.
- A real-font mounted workspace test covers preview, missing variables, stale-preview rejection, update, undo/redo, native save/reopen and conversion to literal wording. Full CAD **416** tests/build passed; after the stale-preview guard, all **22** text tests and final production build passed. All process handles exited 0. Existing build warnings remain.
- Browser discovery returned no sessions. A variable-definition editor, sketch draft-variable undo/transaction integration and live browser acceptance remain unfinished. Full sketch parity stays open.

## Document-wide text variable transactions — 2026-09-09

- `document/text-expressions.ts` validates resolved wording against saved variables after feature structure validation. Missing references and stale wording reject native validation, saving and reopening, including suppressed and rolled-back sketches.
- `updatePartDocumentVariables` snapshots the document and definitions, regenerates affected direct and projection-authored drawings in feature order, and validates the complete result before returning. Temporary projection context never persists. Unchanged wording retains contour identities; failed regeneration or orphaned downstream selected-contour projections reject the entire update.
- Six new document tests cover native stale-cache rejection, suppressed/projected authored updates, invalid definitions/glyphs, caller-input snapshots, clearing unused variables and downstream projection identity failure. Full Core **675** / CAD **415** tests, Core typecheck and CAD build passed; all process handles exited 0. Initial fixture error (missing empty-document name) was corrected before final checks. Existing build warnings remain.
- Variable/text-expression authoring UI, draft/undo integration and live browser acceptance remain next. Full sketch parity remains open.

## Retained text expression regeneration — 2026-09-09

- Retained text now supports an optional syntax-validated formula and resolved wording. Core uses the shared typed evaluator and ephemeral variable map; dimensional values require explicit unit conversion. Omitting the formula preserves its binding; null explicitly selects literal text.
- Focused `text/expression.ts` and `text/regenerate-expressions.ts` separate evaluation from atomic regeneration. Changed wording regenerates from embedded fonts while preserving construction frames/constraints, placement, flips and ascender sizing. Unchanged wording preserves edge identities and manual edits. Any failure leaves the source drawing unchanged.
- Full Core **668** / CAD **415** tests, Core typecheck and CAD build passed. A subsequent sixth expression test verifies rollback after an earlier item successfully regenerates; final focused **6/6** and Core typecheck passed. Existing build warnings remain.
- Document-wide variable update transactions, validating cached wording against document variables, and the variable/text-expression editor remain unfinished. Native drawing validation currently checks expression syntax only. Live browser acceptance and the broader parity ledger remain open.

## Shared typed expressions and native variables — 2026-09-09

- Added focused Core expression modules for a bounded AST/parser, SI quantities with length/angle powers, strings, unit-safe evaluation and allowed functions. Supports unit conversion, #variables, concatenation and roundToPrecision without JavaScript evaluation or property access.
- Added optional native Part variable definitions (name/kind/expression), validated and resolved through a dependency map. Unknown references, cycles, wrong declared dimensions and duplicate names reject; only definitions persist, not resolved caches.
- Existing numeric-field calculations now use the same parser/evaluator with units/variables/text disabled, preserving display-unit semantics and incomplete-input guidance. Numeric functions such as sqrt, trigonometry, min/max and rounding are available; mounted inch/radian constraint tests exercise them.
- Added 25 expression tests, eight native-variable tests and four numeric-function cases. Final full Core **663** / CAD **415** tests, Core typecheck and CAD production build passed; all final process handles exited 0. Initial checks identified and corrected numeric error-message compatibility and a parameterized-test array issue. Existing build warnings remain.
- This is the shared evaluation/native-storage foundation. The variable editor, sketch-text expression bindings and automatic geometry regeneration are not implemented by this slice. Other parity/live browser acceptance remains open.

## Ascender-based text sizing — 2026-09-09

- Added shared `text/font.ts` parsed-font caching/ascender metrics and `text/height.ts` frame-height projection. Optional native `fontAscenderRatio` preserves physical height during synchronous solving; absence keeps legacy em-height geometry.
- `putSketchText.textHeightMillimeters` converts requested baseline-to-font-ascender height into em size. Null explicitly selects em sizing; omission preserves the existing mode. Frames and vertical center flips use the shared physical-height projection.
- Focused CAD `text-height.ts` supplies optional ascender mode and Text height (mm), retaining the existing em control. Box gestures and resize handles convert physical frame height consistently, and saved fields follow undo/redo/native reopening.
- Four Core tests cover metric conversion, frame height, native dimension/resize behavior, flips/legacy mode and invalid input. A real-font workspace test covers entry/reopening/handle sizing/undo. Full Core **626** / CAD **415** tests, Core typecheck and CAD production build passed; all process handles exited 0. Existing build warnings remain.
- Browser discovery returned no sessions. Text expressions, mixed-script/direction layout and the remaining overall sketch/live acceptance ledger stay open. Ascender mode is explicit; existing em authoring remains available.

## Default text baseline constraint — 2026-09-09

- Added focused Core `text/baseline.ts`: newly created horizontal frames receive a normal horizontal relation on the lower edge. Explicitly rotated frames and existing retained letters with driving constraints skip this inference to avoid forcing orientation or adding redundant relations.
- The relation is creation-only. Native text regeneration remaps/preserves its identity, and removal through ordinary constraint controls is never undone by rewording. A newly created unconstrained horizontal frame now has four remaining DOF, with its five geometric coordinates unchanged.
- Three Core tests cover creation/rewording identity, removal/rotation/native persistence and inference exclusions. A mounted real-font workspace test covers visible constraint removal, undo/redo, rotation and native save. Existing drag/resize fixtures were updated to retain the newly inferred relation; a rotated fixture explicitly removes it first.
- Final full Core **622** / CAD **414** tests, Core typecheck and CAD production build passed; all final process handles exited 0. Existing build warnings remain. Ascender sizing, text expressions, mixed-script layout and full/live browser parity remain open.

## Frame-center text flips — 2026-09-09

- Added persisted `flipAboutFrame`: new framed text defaults to reflection around frame width/em-height centers; absent/false preserves legacy baseline-axis placement. The panel exposes the convention for explicit editing of older text.
- Shared placement separates glyph reflection from construction frame axes. Preview, native generation, box gestures and resize handles use the matching transforms. Focused `text/frame-width.ts` adjusts reflected glyph placement for independent width changes in both solver and explicit resize operations; letters are not stretched.
- Four Core tests cover stationary-frame flips/resizing, driving width, rotated multiline native regeneration and absent-field compatibility. A real-font mounted workspace test covers preview, unchanged frame and native mode persistence. An initial exact-path comparison was corrected to numerical tolerance for normalized preview rounding.
- Full Core **619** / CAD **413** tests, Core typecheck and CAD production build passed; all final process handles exited 0. Existing build warnings remain. First-line ascender sizing, variable text expressions, mixed-script layout and full/live browser acceptance remain unfinished.

## Multiline retained sketch text — 2026-09-09

- Rechecked [Onshape Text documentation](https://cad.onshape.com/help/Content/Sketch/text.htm): later lines appear below the first-line frame. Added shared `text/content.ts` validation/newline normalization and per-line HarfBuzz shaping with font-metric baseline advance. Empty lines retain spacing; width does not wrap or stretch text.
- The CAD text field is now a themed textarea. Multiline wording persists in retained text, previews before commit, participates in undo/redo and survives native reopening. Existing first-line em-frame sizing and proportional resizing continue across all lines.
- Three Core tests cover line placement/counters/blank lines, native persistence/resizing/rewording and validation. One mounted real-font workspace test covers textarea preview, update, undo/redo and reopening. Full Core **615** / CAD **412** tests and Core typecheck passed. CAD production build passed again after the final textarea CSS adjustment. All process handles exited 0; existing build warnings remain.
- Full Text parity is still incomplete: reference flips about frame centers versus current baseline axes, ascender-based first-line sizing versus explicit em sizing, document-variable text expressions, mixed-script/direction itemization and live browser acceptance remain. Ledger stays open.

## Explicit retained text resize handles — 2026-09-09

- Added focused Core `text/resize.ts`: explicit frame width/em height resizing preserves baseline, rotation/flips, frame identities and glyph proportions. Temporary corner targets enforce the requested resize against saved constraints; conflicts reject atomically and targets never persist.
- CAD `text-resize.ts` projects width/height/corner handles for selected saved text. Pointer motion previews Core results, release commits through the normal workspace checkpoint, and Escape/cancel/tool switching discard previews. Concurrent document changes and disposal cannot commit stale previews.
- Four Core tests cover independent width/proportional height, rotated/reflected identities, locked dimensions and malformed/modified geometry. Three mounted real-font tests cover preview/commit/native persistence, cancellation/conflicts and stale/disposed operations. Full Core **612** / CAD **411** tests, Core typecheck and CAD production build passed; all process handles exited 0. Existing build warnings remain.
- Browser discovery again returned no sessions. Full live viewport acceptance, broader text layout and remaining sketch parity stay open. This implements dedicated baseline-preserving resize handles; it does not establish complete Text parity.

## Retained text pointer editing — 2026-09-09

- Fixed ordinary vertex/edge dragging invalidating retained text's digest before solving. Focused Core `text/drag.ts` now seeds movement by translating all owned contours and baseline metadata together; saved constraints then solve against the intact group.
- Free text moves together and remains editable. With a fixed baseline origin and horizontal baseline, dragging the opposite frame corner changes width/em height while preserving glyph proportions. Incompatible anchored moves reject atomically; temporary drag constraints are removed.
- Three Core tests cover movement/rewording, anchored resizing and conflict immutability. A mounted selection-controller test uses real font outlines and native reopening before anchored resizing. Full Core **608** / CAD **408** tests, Core typecheck and CAD production build passed; all process handles exited 0. Existing build warnings remain.
- Browser discovery returned no sessions. Dedicated resize handles for unconstrained frames, broader layout, remaining sketch parity and full live browser workflows remain unfinished.

## Canvas text frame placement — 2026-09-09

- Added focused CAD `text-box-placement.ts`: drag or click two corners with shared geometry snapping (including arc centers), current text rotation/flip axes, reverse-corner normalization and synchronous cached-letter/frame preview. Escape and switching to baseline placement restore pre-gesture fields; zero-area and invalid-rotation frames cannot finish.
- The panel exposes optional frame width, renders a separate dashed frame and passes width through Core `putSketchText` for atomic retained-text/frame creation or update. The shared Core frame projection supplies preview geometry. Existing frame constraints continue to drive solved updates.
- Four mounted real-font tests cover drag/click placement, live resizing, snapping, native persistence, cancellation, cleanup and rotated/reverse corners. A Core test covers atomic framed creation, independent width update and invalid width rejection. Full Core **605** / CAD **407** tests, Core typecheck and CAD production build passed; all process handles exited 0. Existing build warnings remain.
- Creation still requires Create editable text after positioning. Direct resize handles on existing frames, broader text layout, full sketch parity and live browser acceptance remain unfinished. Mounted DOM verification is not live browser verification.

## Constrainable retained text frame — 2026-09-09

- Added focused Core `text/frame.ts` and optional persisted frame identity/width. Explicit **Add text frame** creates selectable construction edges using the text baseline, rotation and flips; it leaves letter outlines unchanged.
- Framed text contributes five solver coordinates: translation, rotation, uniform em scale and independent frame width. Width does not stretch letters. Baseline anchoring/orientation plus width/height dimensions fully constrain the group.
- Text regeneration preserves frame contour/edge/vertex identities and remaps its constraints, then returns solved geometry. Constraints on regenerated letter outlines and manual geometry changes still require resolution.
- Four Core tests cover dimension behavior/DOF, native reopening and rewording with retained references, conflict protection and metadata validation. A mounted real-font CAD test covers frame add/undo/redo and saved constrained text editing. Full Core **604** / CAD **403** tests, Core typecheck and CAD production build passed; all process handles exited 0. Existing build warnings remain.
- Browser discovery returned no sessions; mounted tests are not live-browser verification. Direct canvas text-box creation/resize, broader text layout and overall sketch parity remain unfinished. No silent default frame constraints are added.

## Retained text constraint grouping — 2026-09-09

- Added focused solver `text-coordinates.ts`: intact retained text contributes four transient coordinates (X/Y translation, rotation, positive uniform scale). Letter contours and counters transform together. Successful dimension solves update retained placement/em size and outline digest.
- Solver and constraint-state diagnostics use the same grouped coordinates. This prevents letter deformation under dimension constraints and reports meaningful text degrees of freedom. Modified or detached outlines continue through ordinary sketch coordinates.
- Shared `text/digest.ts` uses Noble hashes 2.4.0 for synchronous SHA-256 during solving; a compatibility test verifies the existing WebCrypto digest contract. License notice included in the text dependency notice asset.
- Four tests cover free/fully constrained DOF, proportional dimension-driven resizing with preserved holes and native reopening, incompatible aspect-ratio rejection, and digest compatibility. Full Core 600 / CAD 402 tests, Core typecheck and CAD production build passed. Existing build warnings remain.
- This establishes grouped text geometry; the dedicated selectable text frame, frame dimensions/constraints and rewording while retaining frame references are still unfinished. Live browser acceptance remains open.

## Sketch Text ribbon command and icon — 2026-09-09

- Added a dedicated illustrated Text SVG to the shared icon registry and Text entry in the sketch Insert ribbon group. The command registry now has 123 commands and the ribbon catalog 217 entries.
- Focused `sketch/text-command.ts` enables the command only for an active sketch after plane selection. Executing selects the selection tool, opens/focuses text controls, loads bundled Noto Sans Regular when needed, and restores the cached preview when returning from another tool. Existing custom/embedded fonts remain selected.
- The mounted real-font command test verifies plane gating, focus, local default loading, reuse without refetching, preview restoration and cleanup after sketch cancellation. Shared UI 149 tests/typecheck/build and CAD 402 tests/production build passed. Core unchanged from verified 596 tests. Icon thumbnail rendered and visually inspected; existing build warnings remain.
- Live browser discovery again returned no sessions. Text-box constraints/dimensions, broader text layout and full browser acceptance remain unfinished.

## Bundled font styles and real text shaping — 2026-09-09

- Added unmodified Noto Sans Regular/Bold/Italic/BoldItalic assets with original OFL license and source/checksum manifest. `sketch/text-fonts.ts` loads the selected style from the installation, cancels obsolete requests and preserves custom-file/embedded-font workflows. License links are emitted into the production assets.
- Real-font tests exposed OpenType.js's unsupported contextual substitution lookup. Added lazy HarfBuzz 1.6.1 shaping in focused Core `text/shaping.ts`, retaining OpenType for exact per-glyph curves. `text/woff.ts` unwraps compressed WOFF1 tables for shaping without losing substitution/positioning data.
- Tests cover distinct closed real-font style profiles, compressed/original font shaping equivalence, and mounted style creation/change with native retained-font persistence. Full Core 596 / CAD 401 tests, Core typecheck and CAD production build passed. Final build also passed after license/config updates.
- Production emits all four font files and HarfBuzz WASM locally. A temporary Vite server returned valid 200 responses for transformed shaping JS, WASM magic/MIME, TTF and license; server stopped afterward. Vite excludes HarfBuzz from prebundling to preserve the WASM URL. These HTTP checks are not live browser acceptance.
- Existing chunk-size warning remains; Emscripten's Node-only module import is externalized for browsers. Text-box constraints/dimensions, mixed-script/direction layout, WOFF2 and live browser verification remain open.

## Persistent text flips — 2026-09-09

- Added shared Core `text/placement.ts`: reflect in local horizontal/vertical baseline axes, then rotate and translate; positive scaling supports normalized previews. The font outline generator and CAD text panel use this same transform.
- Optional validated flip flags persist in retained text records. The panel exposes horizontal/vertical checkboxes and restores them when selecting saved text. Existing records default to unflipped.
- Six transform tests verify local-axis behavior, baseline anchoring, preview scaling and invalid options. Retained/native UI tests verify saved flip flags and mirrored geometry. Four additional real OCCT cases cover reflected multi-letter new/cut solids with correct volume, counters and closed meshes.
- Full Core 594 / CAD 400 tests, Core typecheck and CAD production build passed. Existing chunk warning remains. Text-box constraints/dimensions, font styling, broader shaping and live browser acceptance remain incomplete.

## Retained text editing in the sketch panel — 2026-09-09

- Added focused `sketch/text-items.ts` for saved-text selection, create/update, detach and async commit checks. `text-panel.ts` loads embedded fonts and authoring fields; workspace rendering synchronizes the selector and fields after undo/redo.
- Users can create retained editable text or insert ordinary outlines. Saved text reopens without selecting the font file again. Detach preserves curves, and undo restores the retained item. Delayed generation is discarded after input changes/disposal and rejects a changed sketch snapshot.
- Mounted real-font/native tests exercise create, undo/redo, save/reopen, select/edit, field history synchronization, detach and undo-detach. A controlled async test proves concurrent sketch edits and disposed panels are not overwritten. Full CAD 400 tests and production build passed; Core unchanged from verified 584 tests. Existing chunk warning remains.
- Text-box dimensions/constraints, styling/flips, broader shaping and live browser acceptance remain incomplete. Existing manual edits or constraints on generated outlines still require resolution before text regeneration.

## Retained sketch text Core contract — 2026-09-09

- Added `text/records.ts` and optional validated `SketchDrawing.textItems`: wording, embedded font bytes, explicit em size/baseline/rotation, generated contour identities and an outline digest. Ordinary manual edits/deletion remain valid; divergence is reported by edit-state inspection.
- Added `text/edit.ts` operations to create/replace retained text, inspect editability and detach metadata without changing geometry. Replacement reuses embedded fonts, regenerates atomically and remaps unrelated constraint indices. It currently rejects text whose outlines have manual changes or constraints, rather than losing that work.
- Four tests cover native save/reopen and regeneration without an external font, unrelated constraint remapping, input immutability, modified/constrained detection, detachment and malformed metadata. Full Core 584 / CAD 398 tests, Core typecheck and CAD build passed. Focused edit tests also passed after the contour-ID prefix adjustment. Existing chunk warning remains.
- The current CAD panel still inserts exploded outlines: retained creation/selection/editing UI is the next integration step. Text-box constraints, styling/flips, broader shaping and live browser acceptance remain incomplete. No full-parity claim.

## Text solids and disconnected profile holes — 2026-09-09

- Real OCCT text tests exposed a missing-region bug: subtracting a later letter's hole from an already combined 2D drawing could discard an unrelated letter that already contained a hole. Two rotated rectangular O glyphs lost half their expected volume.
- Added focused `sketch/regions/groups.ts`: simple disjoint/nested boundaries are grouped by solid and relevant holes, with nested islands and redundant deeper holes handled. `kernel/part-evaluator.ts` now cuts each solid's holes before fusing completed regions. Touching/intersecting boundaries retain ordered Boolean evaluation.
- Eight native save/reopen OCCT tests cover new-solid and through-cut text, multiple letters, counters, cubic glyph boundaries, em scaling and rotation. Checks measure analytic volume, watertight tessellation and extrusion depth. Four grouping tests cover disconnected holes, nested islands, multiple holes and fallback behavior.
- Full Core 580 / CAD 398 tests, Core typecheck and CAD production build passed. Existing chunk-size warning remains. Interactive retained text editing, text-box constraints/styles and live browser acceptance remain incomplete; these tests do not establish full Text parity.

## Text canvas placement and outline caching — 2026-09-09

- `sketch/text-placement.ts` adds baseline picking with a live outline preview, origin/endpoint/midpoint/arc-center snapping, a snapping toggle, click acceptance, Escape restoration and listener cleanup. Canvas placement itself does not commit the sketch; Insert remains undoable.
- `text-panel.ts` caches a normalized outline after font/text changes. Size, rotation and numeric/canvas positioning use Core similarity transforms synchronously without reparsing the font.
- Mounted tests verify arc-center and origin snapping, immediate preview updates, one font-generation call during resizing/placement, no underlying sketch-click leakage, explicit insertion, Escape restoration and disposal. Existing real-font/native-save tests also passed. Full CAD 398 tests and production build passed; Core unchanged from verified 568 tests. Existing chunk warning persists.
- This remains an outline insertion workflow. Onshape's [Text reference](https://cad.onshape.com/help/Content/Sketch/text.htm) also requires editable text-box dimensions/constraints, styling, flips and other text authoring behavior; those are not claimed complete. Live browser acceptance and actual text-solid verification remain outstanding.

## Sketch text outline workspace insertion — 2026-09-09

- Added `Aether CAD/src/sketch/text-panel.ts` and mounted it in the sketch workspace: caller-selected OTF/TTF/WOFF font, text, em size, baseline X/Y, rotation, asynchronous live preview, cancel and atomic insertion into the active sketch. Core remains the font/geometry owner; workspace only wires undo and cleanup.
- Inserted outlines are ordinary editable contours, including nested holes. The UI explicitly explains that insertion converts text to curves; persisted text/font authoring and a complete Text ribbon tool are still outstanding.
- Mounted tests cover preview, size/placement, insertion, undo/redo, native reopening, unsupported glyphs and cancellation during a pending font read. Full CAD 396 tests and production build passed (existing chunk warning); Core remains at the prior verified 568 tests with no Core changes this slice.
- Browser discovery again returned no sessions. Live browser acceptance, text extrusion verification, canvas-driven placement and retained text/font editing remain open.

## Sketch text outline foundation — 2026-09-09

- Added focused Core `sketch/text/outline.ts` with lazy OpenType parsing, implicit font contour closure, exact quadratic-to-cubic conversion, nested counters, em sizing and baseline placement/rotation. Caller supplies font bytes; no fonts bundled.
- Five tests cover serialized synthetic-font geometry, holes, placement, curve conversion and rejected inputs. Full Core 568 / CAD 394 tests, Core typecheck and CAD production build passed; existing chunk-size warning remains.
- This is not the complete Text tool: interactive placement, font/text metadata and editing, font selection, complex shaping and intersecting outline repair remain. Actual text extrusion and live browser acceptance are still outstanding.

## Linked ring solid acceptance — 2026-09-09

- Added actual OCCT evaluation of a native ring sketch with outer radius = 2 × inner radius + 1 mm. Four cases cover unchanged dimensions, editing the inner driver, inversely editing the outer follower and editing after unlinking. Each case serializes/reopens before modification and again before solid evaluation.
- All four kernel tests passed: exactly one hollow solid, expected inner/outer radial bounds, 5 mm depth, and triangulated volume within 3% of the analytic annular volume (display meshing tolerance 0.08 mm). Core typecheck passed. This is solid-evaluation coverage, not only solver-value assertions.
- Test-only work: previous full Core559/CAD394 baseline remains; no new full-suite/build claim. Live browser, full wheel interaction and remaining sketch parity gaps stay open.

## Linked fillet radius integration — 2026-09-09

- Audited transforms: moves preserve driving constraints and reject conflicts; copied contours are intentionally independent geometry. Found/fixed literal-radius assumptions in the Fillet edit path instead of changing that transform contract.
- Fillet handles and the reopened Fillet panel now use resolved `dimensionValue`. `editFilletRadius` delegates to `editDrawingDimension`, preserving affine links and updating the shared driver. Reference-only radius measurements do not expose editable fillet handles.
- Full Core 559 / CAD 394 tests, Core check and CAD build passed (existing size warning). Core tests verify actual arc radius, resolved handles, immutable input and reference rejection. Mounted editor test opens a native linked fillet, edits through the Fillet tool, undoes/redoes and verifies retained links/driver values after reopening. Browser list empty; live/full parity remains open.

## Unlinking dimension relationships — 2026-09-09

- Core `unlinkSketchDimension` preserves the current resolved value and exact geometry while removing the upstream driver/scale/offset/sign fields. It retains the dimension ID and downstream relationships. Repeated unlink is harmless; missing/reference dimensions reject without mutation.
- Linked dimensions expose Unlink dimension in their relationship editor. The existing commit flow supports undo/redo; formerly linked dimensions can then be edited independently.
- Full Core 557 / CAD 393 tests, Core check and CAD build passed (existing size warning). Core tests verify a three-dimension chain, immutable input, unchanged geometry, independent upstream edits and retained downstream behavior. Mounted editor coverage verifies unlink undo/redo, independent edits and native persistence. Browser list empty; full/live parity remains open.

## Persistent multiplier/offset dimension relationships — 2026-09-09

- Existing stable-ID `valueFrom` links support optional dimensionless nonzero finite `valueScale` and canonical-mm/degree `valueOffset`. Core composes chained transforms, preserves legacy angular signs, rejects cycles/missing or incompatible drivers/nonfinite arithmetic, and inversely updates the shared root when a follower value is edited.
- `linkSketchDimension` creates/replaces a relationship atomically through the existing solver. Removing a driver or converting it to a reference dimension materializes surviving values and clears link-transform metadata. Native files retain the relationship without duplicate cached values.
- Saved numeric dimensions expose an expandable relationship editor: driver, multiplier calculation and offset in document units. Core owns semantics; `dimension-link-editor.ts` owns presentation and unit-binding disposal. One-driver affine relationships are implemented; named variables and general multi-input expressions remain open.
- Full Core 555 / CAD 393 tests, Core check and CAD build passed (existing size warning). Tests cover chains/inverse edits, signs, coefficients/overflow/cycles/unit mismatch, deletion/reference transitions, UI authoring/undo, dependent geometry and native reopening. Browser list empty; live/full parity acceptance remains outstanding.

## Unit-aware sketch dimension annotations — 2026-09-09

- Sketch dimension labels now use document length/angle units and decimal precision, including reference/linked markers. Unit changes update text and spacing without rebuilding pending constraint fields. Offset/slot handle accessible value text uses display units; geometry and handle computations remain canonical.
- Label activation previously discarded pending saved-dimension edits through selection-mode refresh. The panel now captures/restores those numeric input strings before focusing the chosen dimension. `dimension-label-units.ts` owns formatting and the workspace subscription, disposed on close.
- Full CAD 392 tests and CAD build/typecheck passed (existing size warning). Mounted tests verify inch/radian labels, precision, label activation with pending calculations, live unit changes without replacing inputs, unchanged native dimension values and cleanup. Core unchanged (546-test/check baseline). Browser list empty; live/full parity remains outstanding.

## Document units in constraint fields — 2026-09-09

- Creation and saved dimension fields now display document length/angle units and convert numeric calculations to solver millimeters/degrees. Saved reference measurements use the same display conversion. Updated instructions identify the displayed unit rather than assuming mm/degrees.
- Focused `sketch/dimension-input.ts` owns presentation conversion, labels and subscriptions. Valid pending calculations preserve their physical value through unit changes; invalid unfinished input clears. Bindings are disposed on saved-list replacement and panel closure; document geometry is unchanged by presentation conversion.
- Full CAD 390 tests and CAD build/typecheck passed (existing size warning), followed by instruction-copy corrections. Mounted tests verify inch fractions/radian angles, unit-switch conversion of pending calculations, canonical native persistence and listener disposal. Core unchanged (546-test/check baseline). Browser list empty; live/full sketch parity remains open.

## Calculations in constraint creation and editing — 2026-09-09

- Numeric driving constraints now accept the shared arithmetic syntax when created and when edited in the saved-constraint list. Input fields accept calculation text; parsing completes before any solver mutation is committed. Reference dimensions remain read-only measurements, and geometric constraints do not parse irrelevant numeric text.
- Existing panel units remain millimeters/degrees; display-unit-aware panel presentation, named variables, explicit unit suffixes and persisted expression dependencies remain open. Immediate curve sizing already converts its selected display units.
- Full CAD 388 tests and CAD build/typecheck passed (existing size warning). New mounted tests exercise length/radius/angle creation, invalid create/edit atomicity, undo/redo and native persistence. Core unchanged; prior 546-test/check baseline retained. Browser list empty; live and full parity acceptance still outstanding.

## Calculator input for immediate curve dimensions — 2026-09-09

- Core `quantity-expression.ts` parses decimal/scientific numbers, pi/π, parentheses, unary signs, arithmetic and right-associative powers without executing code. Bounded length/nesting and finite-result checks reject malformed/unsupported input. `parseQuantity` evaluates arithmetic before applying the selected unit factor.
- Immediate radius and ellipse-diameter fields share this parser, including conversion of pending valid calculations when display units change. Combined ellipse sizing remains atomic on invalid input. Persisted dimensions store the calculated numeric value; named variables, explicit unit suffixes, expression dependencies and other sketch input paths remain unfinished.
- Full Core 546 / CAD 385 tests, Core check and CAD build passed (existing size warning). Tests cover precedence, malformed/non-finite input, units, inch fractions, invalid-entry recovery, undo/native radius persistence and atomic ellipse sizing. Geometry assertions use solver-appropriate numeric tolerance. Browser list remains empty; live/full parity acceptance is outstanding.

## Three-point arc semicircle inference — 2026-09-09

- Three-point arc curvature placement snaps to the endpoint-diameter circle within screen-scaled tolerance, on either side and at arbitrary angular positions. Degenerate endpoints/center placements do not produce a snap. Geometry snapping controls inference; exact numeric half-circles also receive the relation when enabled.
- Core `semicircle-snap.ts` owns geometric snapping; `operations/semicircle.ts` adds a linked center and construction chord with a single center-on-chord constraint. This preserves the 180-degree sweep through radius edits without the redundant equation from a full midpoint relation. CAD placement integration stays in `sketch/drawing-tool.ts`.
- Profile counts now exclude construction geometry. Regression expectations account for persistent center/chord geometry through trim, offset, center snaps and undo. Core tests cover direction, rotation, tolerance, degeneracy, source immutability, radius edits and under-constrained diagnostics. Mounted pointer tests cover snapping on/off, undo/redo and native persistence.
- Full Core 517 / CAD 383 tests, Core typecheck and CAD build passed (existing chunk-size warning). Browser discovery returned no sessions; live visual and full sketch parity acceptance remain open. Reference: [Onshape 3 Point Arc](https://cad.onshape.com/help/Content/Sketch/3_point_arc.htm).

## Stable arc-center constraints — 2026-09-09

- Arc-center exposure resolves stable edge IDs before reading geometry and retains the ID in its concentric constraint. Inserting an earlier edge no longer redirects center selection; missing IDs reject atomically. Repeated selection reuses the center.
- Sketch center controls match stable identities and verify the center before committing. Both retained and fresh numeric selections resolve to the same construction point.
- Core regressions verify center identity through insertion, fixed-center radius edits and JSON roundtrip, source immutability and stale-reference rejection. Mounted UI verifies selection and reuse. Full Core 509 / CAD 381 tests and Core check passed; targeted UI regression and CAD build rerun passed after final selection guard (existing size warning). Browser list empty; live verification and full sketch parity remain outstanding.

## Temporary ellipse guide quadrant snapping — 2026-09-09

- Elliptical-arc construction guides snap start/end placement to their four local-axis endpoints within screen-scaled tolerance. Fixed, inferred and remembered radii are supported, including rotated frames. Preview displays the quadrant snap label. Known construction center is used directly to avoid reconstruction drift between preview and committed coordinates.
- Geometry snapping controls both guide snapping and new-arc endpoint quadrant inference. Canonical saved quadrant constraints keep those endpoints attached as diameters change; inference is idempotent and no temporary guide is persisted.
- Full Core 507 / CAD 380 tests, Core typecheck and CAD build passed after the center correction (existing size warning). Tests include snap tolerance, rotation, retained diameter relations and mounted enabled/disabled snapping with native save. Live browser/full parity acceptance remains outstanding.

## Pointer-sized elliptical axis starts — 2026-09-09

- Elliptical arcs remember the most recent valid temporary-ellipse width within the current gesture. Moving to a primary-axis start reuses that width; ordinary off-axis sizing stays dynamic. Explicit secondary radius takes precedence. The fallback resets for a new gesture/tool and does not become an unintended driving dimension.
- Core tests cover fallback versus dynamic sizing/explicit override. Mounted pointer test verifies guide continuity, axis-start preview/commit, native reopen and no width leakage into a new gesture.
- Full Core 505 / CAD 378 tests, Core typecheck and CAD build passed (existing size warning). Browser availability rechecked: no browsers. Temporary-guide quadrant snapping and broader/live parity remain open.

## Elliptical arc primary-axis starts — 2026-09-09

- Optional Secondary radius (mm) allows an elliptical arc to start at either primary-axis endpoint. Blank preserves third-point radius inference. With a supplied radius, start/end inputs define directions on the exact ellipse; preview and commit share the option. The entered radius persists as an ordinary secondary diameter driver.
- Focused Core tests verify both primary-axis ends, exact radius and invalid numeric values. Mounted editor test verifies axis-start placement, radius changes in preview, undo/redo, saved driving value, native reopen and tool-specific visibility.
- Full Core 504 / CAD 377 tests, Core typecheck and CAD build passed (existing size warning). Pointer-only remembered-radius placement, temporary-guide quadrant inference and live/full parity remain open.

## Elliptical arc solid evaluation — 2026-09-09

- Added actual OCCT acceptance for an elliptical arc closed by a chord, with endpoint quadrant constraints, before and after both diameter edits. Each case passes through native serialization/reopening before extrusion.
- Two kernel tests passed: exactly one body, expected depth and triangulated volume within 3% of the analytic elliptical-segment volume (display meshing tolerance is 0.08 mm). Supporting construction ellipse/axes do not add material. Core typecheck passed.
- Test-only slice; previous full baseline Core 501 / CAD 376 and check/build retained. Full parity and live browser acceptance remain open.

## Immediate ellipse diameter entry — 2026-09-09

- Newly drawn ellipses and elliptical arcs offer inline primary/secondary diameter fields in document length units. Enter commits primary and focuses secondary; Enter again commits secondary and returns to the canvas. The combined button computes both on a candidate before committing. Blank/invalid input reports an error without changing the sketch.
- `recent-ellipse.ts` owns the UI; `recent-curve-sizing.ts` composes lifecycle with existing radius entry. Core `set-ellipse-diameter.ts` owns driver creation/reuse through ordinary construction-axis length constraints. Values remain native editable dimensions.
- Full Core 501 / CAD 376 tests, Core typecheck and CAD build passed (existing size warning). Tests cover whole/partial ellipses, repeated Core edits without duplicate drivers, keyboard focus progression, invalid combined input, undo/redo and native reopen. Live browser, expressions and remaining parity gaps stay open.

## Partial elliptical-arc diameter controls — 2026-09-09

- Existing ellipse X/Y axis controls now work when a partial arc lacks the required finite quadrant endpoints. A dedicated candidate-only `ellipse-support.ts` adds a visible construction ellipse linked by canonical conic relations; ordinary axis quadrant/length constraints resize the source. Existing linked arcs remain preferred. Missing/invalid references still propagate; only missing finite endpoints trigger support creation.
- Repeated axis selection reuses support and dimensions. Core tests verify sequential primary/secondary edits, source immutability and residuals; mounted editor tests cover authoring, both axis dimensions, undo/redo, native reopen and reuse.
- Full Core 499 / CAD 374 tests, Core typecheck and CAD build passed (existing size warning). Immediate post-placement dimension entry, axis-start placement, temporary-guide inference and live/browser/full parity remain open.

## Elliptical arc authoring variant — 2026-09-09

- Added Elliptical arc to the Arc dropdown with a distinct theme-aware vector icon. Four clicks define center, primary radius, secondary radius/start, then end direction. Core `elliptical-arc.ts` owns exact native conic construction; preview shares it and shows a temporary dashed ellipse. Both sweep directions are selectable, and a linked selectable center persists.
- Core tests cover radius/center geometry, rotated frames, both sweep branches and invalid construction. Mounted editor coverage verifies temporary guide, direction-switch preview, exact commit, undo/redo and native reopen. Registry includes the new command.
- Verification: full Core 498 / CAD 373 / shared UI 149 tests passed. Core/UI typechecks and CAD/UI builds passed (existing CAD size warning). Initial CAD registry count and guide return-type issues were corrected; affected CAD suite/build and Core check reran successfully.
- Remaining for this variant: primary-axis start placement with an independently known secondary radius, temporary-guide quadrant inference, immediate primary/secondary diameter entry, modeling and live-browser acceptance. Overall parity remains open.

## Center arc direction control — 2026-09-09

- Center-point arcs now offer Clockwise/Counterclockwise selection while drawing. Switching refreshes the pending preview immediately; preview and placement use the same Core geometry option. The control is scoped to Center arc, with its own UI module. Saved geometry encodes direction without new document metadata.
- Core tests verify selected signed sweeps, constant radius/end direction and coincident-endpoint rejection. Mounted editor coverage verifies toggled pointer preview, identical commit, undo/redo, native reopen and control visibility.
- Full Core 495 / CAD 372 tests passed; Core typecheck and CAD build passed (existing size warning). Broader direction inference, elliptical arc variants, live browser acceptance and full sketch parity remain open.

## Arc Split editor acceptance — 2026-09-09

- Added a mounted real-editor workflow for a midpoint-constrained arc: Split, native save/reopen, edit the existing saved radius from 5 to 7, undo/redo, second save/reopen. The rendered geometry changes and reopens consistently; the midpoint relation and construction arc persist with one radius driver.
- Targeted DOM test passed. No production changes; prior full baseline remains Core 493 / CAD 370 with check/build passing. This verifies editor wiring, not live browser interaction; browser/full parity acceptance remains open.

## Split with retained arc midpoint — 2026-09-09

- Arc Split retains the midpoint of the original angular span through a visible construction arc linked to the outer endpoints and supporting circle. Dedicated `split-arc-span.ts` owns arc remapping; `split-span-links.ts` shares endpoint linking with line spans. Construction geometry remains excluded from solid boundaries.
- Tests cover both arc directions, radius edits, repeated Split, native drawing validation, immutable inputs and midpoint preservation together with a fixed endpoint. Corrected an old rejection fixture that used reversed midpoint operands; it now tests the supported relationship.
- Core 493 / CAD 370 full tests passed, Core typecheck and CAD build passed (existing size warning). Core was rerun after the test-fixture correction. Browser availability was rechecked and returned no browsers; live acceptance, arc-specific mounted workflow and broader topology/full parity remain outstanding.

## Split with retained line midpoint and equal length — 2026-09-09

- Line Split now retains midpoint/equal-length relations against an endpoint-linked construction span representing the original full line. `operations/split-line-span.ts` owns this remapping; supporting-line and overall-length handling stay in their existing modules. The construction span is visible reference geometry and does not contribute a solid boundary.
- Tests verify source immutability, identified source references, native drawing validation, overall-length edits moving the retained midpoint, equal-length residuals and repeated Split. A mounted editor test verifies Split, undo/redo and native save/reopen.
- Full Core 491 / CAD 369 tests, Core typecheck and CAD build passed (existing size warning). The subsequently added mounted Split-span test passed separately. Arc midpoint and broader finite-extent/control remapping, full sketch parity and live browser acceptance remain open.

## Imported face extrusion acceptance — 2026-09-09

- Added kernel-level acceptance for SOLID quadrilaterals, repeated-corner triangles, concave profiles and negative-Z TRACE. Each goes through ASCII import, unit scaling, native save/reopen and real OCCT extrusion.
- Four tests passed, verifying expected solid volume, depth and closed mesh edges. Core typecheck passed. No production changes in this slice; prior full baseline remains Core 486 / CAD 368, plus the subsequently added mounted face-import test. Live browser and full sketch parity acceptance remain outstanding.

## DXF SOLID / TRACE sketch boundaries — 2026-09-09

- Planar SOLID and TRACE entities import as editable closed line boundaries through dedicated `import/dxf/filled-face.ts`. DXF strip corner ordering and repeated-corner triangles are handled; scale, negative-Z OCS and source-layer provenance use the existing pipeline. Simple concave boundaries are supported. Crossing/zero-area boundaries and nonzero corner Z/thickness reject atomically.
- Verification: full Core 486 / CAD 368 tests passed, Core typecheck and CAD build passed (existing size warning). A subsequently added mounted editor test passed separately: preview, insert, undo/redo, native save/reopen. This is not live browser or full parity acceptance.

## Fresh mirror, offset and slot source identities — 2026-09-09

- Mirror sources/axes, offsets and slots now assign missing authored edge IDs on a candidate drawing before saving associative references. Earlier edge insertion no longer silently redirects these relationships; invalid operations leave the input untouched.
- Corrected slot boundary generation to avoid duplicating its centerline segment/vertex IDs onto newly generated boundary edges.
- Verification: Core 482 tests and CAD 368 tests passed; Core typecheck and CAD production build passed (existing bundle-size warning). Tests cover fresh and preidentified sources, insertion, persistence, immutable failure and mirror source/axis metadata. Live browser acceptance remains outstanding; full sketch parity remains open.

## Identity assignment for fresh pattern source edges — 2026-09-09

- Selected-edge pattern creation now assigns missing source edge IDs on its private candidate drawing before constructing relations. This makes stability available to ordinary freshly drawn edges, not only edges previously identified for projection. Existing IDs are preserved; projected geometry is not assigned locally invented IDs.
- Dedicated `operations/identify-source-edges.ts` owns selected-edge identification. Whole-contour and plain-point source contracts remain unchanged. Assignment is part of the pattern operation, so errors/cancellation leave the input drawing untouched.
- Core 480 / CAD 368 tests, Core typecheck and CAD build passed. The expanded fresh/preidentified source regression verifies earlier insertion, count edits and native persistence. Three targeted identity tests passed again after adding success/failure source-immutability assertions. Pattern repair/count tests now explicitly expect generated source IDs.
- Automatic ID assignment for other associative tool creation, general topology remapping and full sketch/live browser parity remain open.

## Stable modification source mouse selection — 2026-09-09

- The shared modification source picker now matches available stable edge IDs against the current picked segment instead of relying on an old option index. Legacy choices without IDs still use numeric positions.
- A mounted regression changes source segment order after creating the source list, then verifies click selection, exact source highlighting, click deselection and refusal to select a replacement edge with a different identity. Highlight geometry already used the corrected Core source projection.
- All 368 CAD tests and CAD typecheck/production build passed. Core production is unchanged from the prior477-test full baseline (two later handle tests also passed individually). Live browser/full parity acceptance remain open.

## Derived dimension handle verification — 2026-09-09

- Added focused offset/slot regressions that insert an earlier source edge, serialize the drawing, fix the source geometry, compute a new dimension from handle movement and edit the saved dimension. Both handles stay on the intended source midpoint; resulting constraints satisfy their residuals and input drawings remain unchanged.
- Both new tests passed. Production is unchanged from the prior Core477/CAD367/check/build baseline; this test-only work does not claim a new full-suite/build run.
- This verifies Core handle geometry and dimension-edit integration. Real pointer rendering/input, general topology remapping and full parity remain open.

## Stable offset and slot source references — 2026-09-09

- Selected-edge offsets now normalize/capture available source IDs instead of dropping them during relation creation. Shared offset relation construction captures available source/target IDs, including single-edge whole-contour offsets. Extracted offset edges retain source layer labels.
- Slot creation captures source IDs, and slot centerline evaluation resolves them before reading geometry. An earlier source-edge insertion therefore no longer redirects an existing slot to the wrong centerline. Legacy numeric references remain supported when no ID is present.
- Core 477 / CAD 367 tests, Core typecheck and CAD build passed. Two new regressions cover earlier insertion, drawing serialization, satisfied derived relations, repeated creation through stale indexes and atomic missing-ID rejection. The CAD suite includes the previously added mirror-menu regression.
- General topology remapping, spline/ellipse offsets/slots and live/full sketch parity acceptance remain open.

## Stable mirror-axis menu verification — 2026-09-09

- Added a mounted test of the actual saved mirror-axis editor. After an earlier edge is inserted, the menu selects the axis by stable identity, excludes the mirrored source and instance, allows a distinct same-contour edge, and preserves the intended axis through cancel/reopen/save and native document roundtrip.
- The new targeted test passed. Production is unchanged from the previous Core475/CAD366 full passing baseline; no new full-suite/build run is claimed for this test-only work.
- This is DOM/component integration evidence. Live browser verification and full sketch parity remain open.

## Stable mirror-axis validation and capture — 2026-09-09

- Mirror source/axis exclusion now resolves stable identities using the current drawing. The same edge is rejected despite stale numeric positions; a distinct edge in the same contour is allowed. Projected contour scope is distinguished, and missing stable IDs reject.
- Mirror creation and saved-axis edits capture available axis segment IDs. CAD source exclusion and saved-axis option filtering/preselection use the shared Core comparison, including mixed stable and legacy numeric references.
- Core 475 / CAD 366 tests, Core typecheck and CAD build passed after the final identity-capture change. New tests cover same-edge rejection, distinct-edge acceptance, saved-axis editing/capture, projected scope and missing IDs. Full source topology remapping and live/full sketch parity acceptance remain open.

## Stable selected-edge pattern sources — 2026-09-09

- Selected-edge patterns already existed; this pass fixed stale-index lookup in their shared source projection. `pattern-source.ts` resolves contour context and stable edge identity before extracting geometry. Source choices capture available segment IDs, and extracted edges retain imported layer labels.
- `pattern-source-key.ts` uses available stable segment/vertex identity and projected contour scope for membership/deduplication, retaining numeric indexes for legacy references. Missing IDs reject rather than silently selecting a replacement edge.
- Core 473 / CAD 366 tests, Core typecheck and CAD build passed. New coverage inserts an earlier source edge, resizes the pattern, verifies both instances still follow the intended edge/layer, and roundtrips native data. Broader source topology remapping, copied-edge joining and live/full parity acceptance remain open.

## Imported circle layer preservation through edits — 2026-09-09

- Circle-to-arc conversion in Split and Trim now preserves optional `sourceLayer`. Path splitting already retains contour metadata; cutter layers stay independent.
- New regressions import a DXF circle/cutter on separate layers, split the circle and a resulting arc, roundtrip a native document, and trim the circle while checking source immutability and layer labels.
- Core 471 / CAD 366 tests, Core typecheck and CAD build passed. Layer styling/editable membership, remaining import formats and full sketch parity/live browser verification remain open.

## Projected selection error presentation — 2026-09-09

- Selection status now asks Core to resolve a projected entity before labelling it read-only. Missing stable edges and missing source contours show an invalid-reference message. Restoring the source restores the read-only label and layer information; deselection clears the status.
- The dedicated status presenter contains no geometry validation logic: it displays Core's resolution result. A mounted DOM regression covers replacement edge identity, absent source, restoration and deselection.
- All 366 CAD tests and the CAD typecheck/production build passed. Core is unchanged from the previous 469-test passing baseline. Browser discovery still returns no sessions; live verification and full sketch parity remain open.

## Projected and identified curve diagnostics — 2026-09-09

- Core entity mobility analysis now resolves projected contour context and stable segment identity before reading arc/ellipse endpoints. Previously projected curves could invalidate the entire batched result, and a stale numeric index could supply endpoints from another edge.
- Projected-only selections are validated instead of returning early as an empty sketch. Valid projected geometry has zero local degrees of freedom; missing identities remain invalid. Whole sketches with no authored geometry still report empty. The UI's existing projected read-only label is unchanged.
- Core 469 / CAD 365 tests, Core typecheck and CAD build passed. Three new regressions cover projected arc/ellipse batches alongside free authored geometry, projected-only/missing-source cases, source immutability and stable authored arc selection. Live browser/full parity acceptance remain open.

## Linked ellipse mobility diagnostics — 2026-09-09

- Fixed a false over-constrained report for a split ellipse. Diagnostics now share the solver's stable common-conic coordinates for eligible linked ellipse paths. The regression verifies eight freedoms after Split, seven after one diameter, six after both, and three for a selected diameter's translation/orientation.
- Intrinsic conic relations are excluded from the numerical rank calculation; extra graph relations still count as redundant. Complete residuals remain active for satisfaction/conflict checks. `diagnostic-residuals.ts` excludes quadrant finite-span inequalities from mobility rank, so an endpoint bound does not falsely fix the endpoint.
- Core 466 / CAD 365 tests, Core typecheck and CAD build passed. Broader singular/inequality diagnostic cases, live browser acceptance and full sketch parity remain open.

## Sequential ellipse dimension solver and editor regression — 2026-09-09

- Mounted editor verification exposed failure when applying only the X diameter after Split. The prior engine test changed both dimensions together and did not establish this sequential workflow.
- `solver/ellipse-locus-coordinates.ts` now provides transient shared-conic and vertex-angle coordinates for connected all-ellipse paths. This avoids the singular endpoint/radius representation at half-ellipses. Fixed, unlinked, mixed-geometry or differently represented conics retain the general solver path. No saved format or second persisted geometry was added.
- The editor regression now authors an ellipse, splits it, applies X then Y diameter dimensions, exercises Undo/Redo, saves/reopens a native document and reuses the existing axis. Core tests also verify source immutability, shared radii, closure, residuals and conflicting-dimension rejection.
- Core 465 / CAD 365 tests, Core typecheck and CAD build passed. Browser verification remains outstanding; mounted DOM evidence does not prove real rendering/input. Broader solver singular cases and full sketch parity remain open.

## Ellipse dimensions after Split — 2026-09-09

- Diameter construction controls now follow explicit shared-ellipse relations to attach each endpoint to an arc containing its quadrant. Existing controls are reused after Split even when their endpoints reference different arcs. Isolated partial arcs with missing axis endpoints reject without changing the drawing.
- `operations/ellipse-axis-references.ts` owns linked-arc traversal and endpoint selection; `ellipse-axes.ts` owns construction control creation/reuse. Unrelated geometrically similar curves are not implicitly linked.
- Core 463 / CAD 364 tests, Core typecheck and CAD build passed. New tests resize both ellipse axes after drawing JSON roundtrip, check all split arcs and constraint residuals, verify control reuse/creation and atomic rejection. Existing bundle-size warning remains.
- Browser discovery still returns no sessions. Live browser acceptance and full sketch parity remain incomplete.

## Split ellipses with retained constraints — 2026-09-09

- Split now converts a full ellipse's shape relation into shared conic relations between the resulting arcs. Further splits preserve that shared geometry. Quadrant references move to a resulting arc that contains the required quadrant.
- Dedicated `split-ellipse-relations.ts` handles split reference conversion; `retained-ellipse-relations.ts` is shared with Trim. Geometry and constraints remain in Core.
- Core 461 / CAD 364 tests, Core typecheck and CAD production build passed. Regression coverage exercises repeated splits and checks all resulting constraint residuals; the CAD run also includes the previously added mounted ellipse Trim workflow.
- Live browser verification, general topology remapping and full sketch parity remain outstanding.

## Full-ellipse trim editor integration verification — 2026-09-09

- Added a focused mounted editor test that authors an ellipse and cutter lines, activates Trim and clicks the visible ellipse, then exercises Undo/Redo and native save/reopen. The resulting three arcs retain two shared-ellipse relations and the reopened outline matches the saved outline.
- The new test passed first through numeric placement and then through simulated pointer trimming. Production code is unchanged from the previous Core460/CAD363 full passing baseline; no new full-suite/build run is claimed for this test-only change.
- SVG screen coordinates are simulated. This proves editor command/persistence integration, not real browser input/rendering. Live trim acceptance and full sketch parity remain open.

## Trim full ellipses with retained shape — 2026-09-09

- Trimming a full constrained ellipse no longer rejects its whole-ellipse relation. The closed-half relation is replaced by `ellipse-locus` relations tying surviving arcs to a common supporting ellipse. Further trim fragments can retain the same supporting conic.
- The shared-ellipse residual compares centers and normalized conic shape matrices, so equivalent swapped axes do not conflict. The constraint is available in the existing panel/ribbon with an ellipse icon and explanatory hint.
- Core 460 / CAD 363 tests, Core typecheck and CAD build passed. New tests cover a three-arc trimmed result, satisfied shared relations, native persistence and equivalent axis representations. App checks caught and prompted the missing catalog icon/count integration, which was fixed before the passing rerun.
- Broader reference remapping, interactive solver singular cases, mounted/live full-ellipse trim acceptance and full parity remain open.

## Finite elliptical quadrant constraints — 2026-09-09

- Quadrant constraints now check visible-span membership for elliptical arcs as well as circular arcs. A point on the hidden supporting ellipse no longer counts as satisfied. Full constrained ellipses retain all four quadrants.
- Shared `quadrantSpan` supplies solver and manual-selection span data; ellipse snapping uses the existing angular-span helper rather than a separate clipping formula.
- Core 458 / CAD 363 tests, Core typecheck and CAD build passed. New tests cover local/external out-of-span relations, nearest visible quadrant choice and whole-ellipse preservation.
- General constraint/topology remapping, robust interactive solving across singular cases and live browser acceptance remain open. Full parity is not claimed.

## Circle and finite-arc quadrant snapping — 2026-09-09

- Ordinary sketches now expose circle quadrants and only the quadrants inside a circular arc's directed span. The shared projected snapping path also receives finite-arc quadrants. Inference retains quadrant constraints while avoiding duplicate point attachments.
- Manual quadrant creation accepts arcs and chooses the nearest visible quadrant; an arc with no axis quadrant reports that limitation. Solver equations include angular-span membership, so a point on the hidden supporting circle is not considered satisfied.
- Core 455 / CAD 363 tests, Core typecheck and CAD production build passed. Coverage includes both sweep directions, circle inference, duplicate prevention and out-of-span residuals. A draft-collinear-arc regression was found and fixed: invalid draft arc candidates are skipped while other snap targets remain usable.
- Broad singular-solver behavior, elliptical finite-span updates and live browser acceptance remain unfinished. Full parity remains open.

## Retained DXF source layers — 2026-09-09

- Imported contours retain optional `sourceLayer` provenance, including inherited block layers and the default layer `0`. Native save/reopen and affine placement preserve it. Projection carries the source layer into derived geometry.
- Endpoint joining now groups by source layer as well as construction/hole flags, preventing automatic cross-layer merging. Selected-entity status displays the source layer for authored and projected geometry using text content.
- Core 452 / CAD 363 tests, Core typecheck and CAD build passed; the updated mounted selection test also passed separately. Tests cover native persistence, layer-aware joining, invalid metadata and source-layer display after reopening. Updated the existing default-layer geometry assertion for the new metadata.
- This is provenance, not editable layer membership or visibility/style control. Layer style properties, general topology-operation propagation and live browser verification remain open.

## DXF block editor integration verification — 2026-09-09

- Added a mounted sketch-editor workflow for DXF block layer discovery/filtering, nonuniform circle-to-ellipse preview, numeric placement, Undo/Redo, native save/reopen and edit reopening. It verifies the placed ellipse coordinates and radii after persistence.
- The new integration test passed. Production code is unchanged from the previous Core450/CAD362 passing baseline; no new full-suite or build run is claimed for this test/documentation-only change.
- Corrected the primary DXF README and parity table to include embedded planar BLOCK/INSERT support, while retaining explicit attribute/xref/tilted geometry gaps.
- This uses a simulated DOM/file input, not a live browser. Browser import acceptance and full sketch parity remain open.

## Affine conic scale robustness — 2026-09-09

- General import mappings no longer apply the absolute near-edge-on tolerance used for sketch-plane projection. A small nonzero block determinant preserves conic geometry; the frame-projection entry point retains its explicit collapse tolerance.
- Conic axes are computed from a normalized shape matrix. Minor radius uses the map determinant and original radii, avoiding subtraction of nearly equal transformed products. Removed the determinant-only rejection of usable thin conics; geometric resolution limits remain explicit.
- Core 450 / CAD 362 tests, Core typecheck and CAD production build passed. New coverage includes a DXF circle scaled by 1e-8 from radius 1e8 to radius 1, a usable near-singular conic and large finite conic radii.
- Extreme underflow/resolution limits, nearly singular frame-collapse policy, other import gaps and live browser acceptance remain open. Full parity is not claimed.

## DXF block INSERT expansion — 2026-09-09

- ASCII DXF imports now expand nested embedded planar blocks using base points, insertion points, rotation, independent X/Y scales, planar reflection, and row/column arrays. Effective layer inheritance is exposed by the layer inventory; geometry decoding remains deferred until selected layers are filtered.
- Exact affine mapping is shared with the projection geometry implementation. Nonuniformly scaled circles become native ellipses. Expanded geometry is ordinary editable sketch geometry, not retained block instances.
- Core 447 / CAD 362 tests, Core typecheck and CAD production build passed. Tests cover nesting/base points, rotation/scaling, ellipses, arrays, reflection/units, layers, missing/cyclic definitions and invalid array counts. The first pass caught and fixed eager legacy-polyline decoding before layer filtering.
- Attributes, external references, tilted/elevated geometry, live import verification and remaining DXF/DWG/image coverage remain unfinished. Expansion has depth/record limits.
- Format basis: [Autodesk INSERT](https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-28FA4CFB-9D5E-4880-9F11-36C97578252F.htm) and [BLOCK](https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-66D32572-005A-4E23-8B8B-8726E8C14302.htm).

## Projected snapping editor integration verification — 2026-09-09

- Added a focused mounted workspace test file for actual pointer event dispatch, Undo/Redo, native save/reopen and source edits. Projected-edge placement retains its stable sliding contact and does not persist runtime projection context or modify source geometry.
- A second flow places a point at a projected circle quadrant, saves/reopens, and verifies visible authored geometry follows source center/radius changes. Cancel leaves the save count unchanged.
- All 362 CAD tests and the TypeScript/production build passed. Core implementation is unchanged from its prior 443-test passing baseline.
- Browser discovery returned no sessions. These tests simulate the SVG coordinate transform and do not prove live rendering, real pointer behavior or full browser acceptance. Full parity remains open.

## Continuous projected curve snapping — 2026-09-09

- Pointer placement can snap along identified projected path segments and circles after discrete endpoint/center/midpoint/quadrant candidates. Finite segment picking uses native curve evaluation; no tessellated geometry is saved.
- Inference persists external coincidence. Finite paths carry a stable segment reference and a sliding contact parameter; circles retain radial coincidence. This allows later dimensions to move the contact along its source curve.
- Core 443 / CAD 360 tests, Core typecheck and CAD build passed. Tests cover source edits with a later fixed-point constraint driving the sliding parameter, cubic/circle picking, finite-span rejection, and UI snap priority.
- Browser pointer acceptance, large-sketch snapping performance, broader topology lineage and remaining parity requirements remain open.

## Projected quadrant snapping — 2026-09-09

- Projected circles and ellipse spans expose quadrant snap candidates. Pointer placement records a persistent `quadrant` relation with the external contour/edge identity. Existing endpoint/center attachment precedence remains intact.
- Quadrant constraints now accept circles as well as ellipses in Core and the constraint panel. Circles use sketch axes; ellipses use local axes through a shared quadrant frame helper. Circular arcs are excluded from this extension.
- Core 441 / CAD 359 tests, Core typecheck and CAD build passed. Tests cover source circle center/radius edits driving a snapped point, ellipse quadrant coverage with stable segment references, and UI snapping before grid rounding.
- Continuous curve snapping, broader finite-span update validation, topology lineage and live browser acceptance remain open. Full parity is not claimed.

## Selected projection subentity identities — 2026-09-09

- Single-contour projection now assigns missing edge and vertex identities even when the contour already has an ID. Whole-sketch and selected-contour assignment share `document/identify-sketch-contour.ts`.
- A contour in a projected sketch can now be selected: assignment visits its upstream authored geometry atomically, while the reference retains the selected derived feature. The selector no longer disables unidentified derived contours.
- Core 439 / CAD 358 tests, Core typecheck and CAD build passed. Coverage includes native save/reopen, upstream chain assignment, identity reuse, and UI candidate immutability. No live browser acceptance claimed.
- Multi-contour topology lineage, external whole-edge remapping and the wider parity ledger remain open.

## Trim identity preservation — 2026-09-09

- Trim now assigns endpoint and edge identities from retained source intervals. Surviving endpoints/whole edges keep IDs; newly cut endpoints and partial edges get fresh IDs. A moved path start cannot inherit the removed start vertex identity.
- Local constraints resolve stable IDs before index remapping and capture retained identities afterward. Regression coverage includes a stale-index fixed endpoint, external surviving/deleted endpoint references, and a closed path whose start changes.
- Core 437 / CAD 357 tests, Core typecheck and CAD production build passed. The initial new fixed-point test omitted its required coordinate; the corrected fixture and full rerun passed.
- Trims that produce multiple contours still require external contour relinking. Cross-contour lineage, external whole-edge remapping and live browser acceptance remain unfinished.

## Split identity preservation — 2026-09-09

- Split retains original endpoint identities, creates identities for the new join/edges when the source is identified, and remaps local identified curve/control references onto the correct child. References are resolved before index remapping, so stored indices may be stale without redirecting constraints.
- External endpoint constraints remain attached after a source split. External references to the replaced whole edge fail explicitly and still need relinking; automatic external contact remapping remains unfinished.
- Ellipse subdivision no longer copies the original edge/endpoint identity to both pieces. Identity assignment belongs to the editing operation.
- Core 435 / CAD 357 tests, Core typecheck and CAD production build passed. Added projected-endpoint and identified cubic-contact regressions. Live browser verification remains outstanding.

## Stable projected endpoint references — 2026-09-09

- Authored paths now support start/end vertex identities. Whole-source projection assigns missing IDs atomically; one-to-one projection retains them. Closed paths share their start identity at the closing endpoint.
- Projected endpoint selection and snapping capture vertex IDs. Constraint resolution follows those IDs after earlier geometry is inserted, and missing/ambiguous references fail explicitly instead of falling back to stale indices. Legacy references remain supported.
- Core suite: 432 passed; added save/reopen identity test passed in the 3-test identity suite. CAD 357 passed, plus the updated picker test suite; Core typecheck and CAD production build passed. No live browser acceptance claimed.
- Split/trim topology remapping, collapsed projection identity mapping and full parity acceptance remain open.

## Stable projected edge references — 2026-09-09

- Projected edge selections, arc-center snaps and midpoint snaps now capture optional segment identities. One-to-one projection preserves those identities, and constraints resolve them instead of stale segment indices. Missing or ambiguous identified edges fail explicitly.
- Whole-sketch identity assignment includes authored path segments. New validation rejects duplicate or invalid segment IDs within a path. Legacy index-only references remain compatible.
- Core 430 / CAD 357 tests, Core typecheck and CAD production build passed. Regression coverage includes insertion before a constrained edge, deleted/replaced identities, projection preservation, duplicate validation and canvas selection identity capture.
- Vertex identities, topology-changing split/trim remapping, collapsed-projection mapping and live browser acceptance remain incomplete. Browser discovery returned no sessions.

## Whole-sketch projected identities — 2026-09-09

- Entire-sketch projection assigns missing contour identities in its candidate document, including upstream authored geometry in mixed projection chains. Existing IDs remain unchanged. Legacy primitive source profiles convert to equivalent native drawings so their contours can carry IDs.
- Core 428 / CAD 357 tests, Core typecheck and CAD build pass. Save commits identity assignment with the projection; Cancel leaves the input unchanged. The authoring workspace can therefore offer those whole-source contours for selection and snapping. Validation uses the source prefix while repairing a downstream broken reference.
- Stable segment/vertex topology, broader snapping and live browser acceptance remain unfinished.

## Persistent projected point snapping — 2026-09-09

- Identified projected endpoints, centers and line/arc midpoints participate in pointer snapping. Newly placed authored vertices retain the snap through external coincidence, concentricity or midpoint constraints. Existing local attachments take precedence to avoid duplicate inference.
- Core 426 / CAD 356 tests, Core typecheck and CAD build pass. Tests cover exact endpoint/midpoint attachment, source movement, arc-center candidates, unidentified/existing geometry exclusions, and mounted pointer placement/native save/source-update reopening.
- Projected quadrant/curve-locus snapping, broader identity assignment, stable subentity topology and live browser acceptance remain open.

## Projected geometry canvas selection — 2026-09-09

- Identified projected points, edges and curve contacts can be selected directly on the sketch canvas for constraints. Selection highlights resolve the external contour and show read-only source status. Authored geometry wins exact overlap ties.
- CAD 355 tests and build pass. Mounted tests verify canvas constraint selection, highlight, drag prevention and saved source immutability. Source dragging is blocked at the gesture boundary; mutation tools still pick only authored geometry. Interior curve contacts missing from selector options are inserted with their actual parameter rather than clearing the selection.
- Projected snapping/inference, unidentified source contour assignment, stable subentity topology and live browser acceptance remain open.

## Projected constraints in the sketch editor — 2026-09-09

- Mixed-sketch editing carries resolved projected geometry as ephemeral context. Identified projected entities appear in constraint selectors, and the existing solver/panel can constrain authored geometry to them. Entry solves against current source geometry before rendering.
- Core 424 / CAD 352 tests, Core typecheck and CAD build pass. A mounted concentric-circle flow verifies constraint creation, undo/redo, native save and updated geometry after source movement. Saving strips the context, and native validation rejects accidental derived snapshots. Authored geometry enumeration remains separate from external selection enumeration.
- Pointer selection/snapping of projected geometry, ID assignment for unidentified whole-source contours, stable segment IDs and live browser acceptance remain open.

## Projected constraint solver foundation — 2026-09-09

- Mixed sketches can resolve authored constraints against stable projected contour IDs. Temporary projected contours are excluded from solver variables, so source geometry cannot move to satisfy a target constraint. Returned data retains source IDs and optimized sliding parameters without storing derived geometry.
- Core 423 / CAD 351 tests, typecheck and CAD build pass. Document validation checks external equations in source context; ordinary drawing validation still handles local equations. Core tests cover fixed-source solving, reordering/source edits, missing references, conflicts, sliding contacts and native document rebuilding.
- This is solver/document support. Editor selection, snapping and constraint editing with projection context remain unfinished; segment identity through source topology changes also remains open.

## Mixed projection authoring workspace — 2026-09-09

- Save and edit geometry in the projection editor opens the normal sketch workspace. A dedicated session helper renders resolved projected geometry as a read-only background while the standard tools edit only authored contours. Finish retains the source link and authored drawing separately.
- CAD 351 tests and build pass. Mounted flows verify entry from the projection editor, drawing, undo/redo, native save/reopen, updated source geometry on reopen and cancel without changes. Core remains at the 419-test baseline.
- Cross-projection snapping/constraints and live browser acceptance remain open. The read-only background is context, not a claim that projected entity interaction is finished.

## Mixed projection document foundation — 2026-09-09

- Projection records accept optional authored sketch geometry while retaining the live source reference. Rebuild resolves projected geometry and independently solves authored constraints before composing contours, so changes in source topology cannot shift authored constraint indices.
- Core 419 / CAD 349 tests, Core typecheck and CAD build pass. A focused composition module rejects duplicate contour identities. The projection editor preserves authored geometry during relinking and displays it in the combined preview. Source edits and native serialization are tested.
- This is a document/rebuild foundation: editing authored geometry over the live projection and cross-projection constraints still need implementation. Browser connection/troubleshooting again reported no available browser; live acceptance remains open.

## Insertion with attached spline controls — 2026-09-09

- Split and spline-point insertion now preserve cubic control-point references, including dimensioned tangent handles and fixed controls. Optional positive `controlScale` retains the original endpoint-relative vector after subdivision. Repeated insertion accumulates this scale.
- Resolution and remapping live in focused modules, using native controls as the only geometry. Existing unscaled references retain their behavior; malformed scales reject. Handle reuse distinguishes retained scaled references from newly requested native handles.
- Core 417 / CAD 348 tests, Core typecheck and CAD build pass. Mounted tests verify preview, undo/redo and native saving with an attached dimensioned handle. Full sketch parity and live browser acceptance remain open.

## Dimensionable spline tangent handles — 2026-09-09

- Selecting a cubic span exposes start/end tangent handles as construction lines linked to native endpoints and controls. Repeated selection reuses a handle. Standard length/angle/alignment constraints operate on the line and affect the curve; stationary endpoints reject.
- Core 415 / CAD 347 tests, Core typecheck and CAD build pass. Mounted tests cover selection, dimensioning, undo/redo and native reopen; Core tests cover both handles, native roundtrip dimension editing, reuse, invalid references and fit-spline interpolation while adjusting a handle. The focused GUI control selects references by fields rather than JSON order.
- Control-reference remapping during insertion and live browser acceptance remain unfinished. Handles are construction geometry and do not enter solid profiles.

## Fit-spline insertion with preserved shape — 2026-09-09

- Insert spline point now supports natural open and periodic closed fit splines. Exact subdivision retains the whole curve, while the existing shape constraint stores optional positive `splineSpanIntervals`. The solver uses these intervals during later point edits; older sketches without intervals retain chord-length fitting.
- Fit points remain native contour vertices. The focused insertion helper splits one interval, preserves the shape constraint ID and uses the existing finite-contact remapping. No duplicate spline point model was added.
- Core 412 / CAD 346 tests, Core typecheck and CAD build pass. Mounted preview/undo/reopen preserves intervals; Core coverage includes exact span comparisons and constrained dragging after serialization. Full arbitrary-degree/control-reference remapping and live browser acceptance remain open.

## Cubic spline-point insertion UI — 2026-09-09

- The spline dropdown now includes Insert spline point. Hovering previews the exact subdivided curve and marks the new point; clicking commits through the standard sketch history. Endpoint/noncubic/unsupported-reference errors leave geometry unchanged.
- CAD 345 tests and build pass. Mounted tests verify preview without mutation, insertion, undo/redo, native reopening and invalid endpoint clicks without extra undo steps. A shared direct-tool guard keeps command placement and preview routing consistent. Catalog tests verify the dropdown action.
- Shape-linked fit-spline/control remapping and live browser acceptance remain unfinished. This exposes the cubic operation only, not arbitrary spline knot insertion.

## Core cubic spline-point insertion — 2026-09-09

- `insertSketchSplinePoint` inserts an editable join by exact cubic subdivision, reusing Split's finite-contact remapping. A saved curvature relation retains geometric smoothness when the inserted point is moved. Repeated insertion preserves prior continuity contacts and uses unique IDs.
- Core 410 tests and typecheck pass: sampled exact shape equality, saved/reopened constrained dragging, contact remapping, repeated insertion and endpoint/noncubic rejection. Shape-linked fit splines and unsupported control-reference remapping still reject through Split's existing validation.
- This is an engine operation, not a completed UI tool. Ribbon routing, pointer preview/selection, mounted undo tests and live browser acceptance remain outstanding.

## Offset collinear-contact validation — 2026-09-09

- Straight-chain offset validation now rejects collinear contact between nonadjacent output edges instead of skipping every parallel pair. A focused finite-line helper checks overlap, containment, reversal and endpoint contact using distance tolerance.
- Core 407 / CAD 342 tests, typecheck and CAD build pass. This closes a validation gap; automatic offset topology repair and full sketch parity remain unfinished. Browser connection query returned no available browsers.

## Closed line/arc centerline slots — 2026-09-09

- Closed line/arc chains now create linked inner and outer slot loops sharing one editable width. Exact signed area selects the inside for either drawing direction; the centerline becomes construction geometry. Collapsed or intersecting offsets are rejected.
- Focused Core closed-slot geometry, operation and residual modules reuse the offset implementation. Closed two-arc loops correctly permit their two shared endpoints. The existing slotBoundary relation now also supports contour references.
- Core 404 / CAD 342 tests, Core typecheck and CAD build pass. Coverage includes reflected rectangles and mixed arc chains, width edits, native persistence, preview/undo/reopen, and exact rectangular-ring extrusion volume. Spline/ellipse slots, topology-changing offsets and live browser acceptance remain incomplete.

## Circular centerline slots — 2026-09-09

- Slot accepts circular centerlines and creates exact inner/outer circle boundaries sharing one width driver. The source becomes construction geometry; the inner boundary is a hole. Width and source-radius edits remain associative, and a radial width handle uses the existing preview/manipulator flow.
- Core operations/circular-slot.ts owns boundary creation; solver/circular-slot.ts owns equations. The existing slot constraint gains optional slotBoundary: inner/outer for circle-source relations. These relations require the updated reader/solver. Positive width must remain below the source diameter.
- Core 400 / CAD 341 tests, Core typecheck and CAD build pass. Tests cover width/source-radius edits, shared mixed line/circle drivers, invalid topology, handle location, mounted preview/undo/reopen/edit/save and exact-kernel extrusion with an open bore. Noncircular closed chains, spline slots and live browser acceptance remain incomplete.

## Saved-constraint UI separation — 2026-09-09

- Extracted saved relation rendering/actions into sketch/saved-constraints.ts (186 lines); constraint-panel.ts now owns creation/reference inputs and focus routing (338 lines). Dimensions, contact modes, quadrants, pattern groups and mirror editing continue to call existing Core operations through the same undoable commit callback.
- CAD 340 tests and build/typecheck pass. This is a behavior-preserving refactor covered by existing mounted editing/undo/native-save tests; no new solver or saved format was introduced. The broader shell/viewer/main refactor and full sketch/browser parity remain open.

## Polygon side-count live preview — 2026-09-09

- Inline side-count edits preview the candidate polygon and sizing circles over the existing sketch. Preview uses Core's actual candidate geometry through the shared SVG path renderer, without modifying the drawing. Invalid counts/attachments remove the overlay and disable Apply.
- Escape/Cancel clears the preview; Enter/Apply commits one undoable change. Applying the same count avoids a no-op checkpoint. Drawing changes invalidate the editor, and canvas refresh redraws its cached candidate. polygon-preview.ts owns presentation; polygon-controls.ts owns the edit session.
- CAD 340 tests and CAD build/typecheck pass. Mounted checks cover unchanged original geometry, preview topology, invalid counts, keyboard apply/cancel, undo/redo, stale-editor cleanup and saving. Core geometry remains at its previously verified 396-test baseline. Live browser acceptance and full parity remain incomplete.

## Polygon attachment remapping — 2026-09-09

- Side-count edits now retain line references whose directed supporting line survives, including symmetry axes. Finite curve contacts remap to the corresponding new segment and parameter when their physical position remains within that segment. Constraint IDs and sliding modes persist.
- Core operations/polygon-attachments.ts owns correspondence; polygon-sides.ts retains final residual validation. Disappearing lines/vertices, out-of-segment contacts and conflicting fixed lengths reject atomically. Matching uses geometry, not reused edge indices.
- Core 396 / CAD 339 tests, Core typecheck and CAD build pass. Coverage includes 6↔12-side contact remapping, symmetry, line direction, native roundtrip, out-of-extent/fixed-length rejection and mounted undo/save. Browser connection list remains empty; full parity acceptance stays open.

## Polygon side-count editing — 2026-09-09

- Select a regular polygon entity and choose Edit polygon sides for inline 3–100-side editing. Side count comes from the path, with the existing equality/coincidence sizing recipe recognized by Core; no extra persisted count or polygon format is introduced.
- polygon-definition.ts recognizes intact convex regularity; polygon-sides.ts rebuilds it while retaining inner/outer sizing references, dimensions, center and clockwise/counterclockwise orientation. Surviving point attachments remap by location. Attachments to disappearing vertices/changed edges reject atomically rather than rebind silently. Broken/ambiguous recipes require repairing constraints first.
- Core 394 / CAD 338 tests, Core typecheck and CAD build pass. Tests cover inscribed/circumscribed sizing, later radius editing, IDs, native roundtrip, reflection, attachment rejection and mounted inline edit/undo/redo/save. Large-drag robustness, more automatic attachment remapping and live browser acceptance remain incomplete.

## DXF planar object coordinates — 2026-09-09

- DXF imports now accept negative-Z planar circle/arc and 2D polyline coordinates using the documented arbitrary-axis mapping. Ellipses preserve their WCS center and major axis while reversing the minor-axis direction/sweep. WCS line/point/spline positions are not reflected.
- Core import/dxf/coordinates.ts owns validation and OCS conversion, reusing the existing geometric reflection helper. Tilted OCS, elevation and thickness still reject. Layer filtering, unit conversion and atomic import behavior remain intact.
- Core 390 / CAD 337 tests, Core typecheck and CAD build pass. Coverage includes circular/elliptical arcs, signed lightweight/legacy polyline bulges, unchanged WCS lines, invalid normals and mounted preview/undo/native save. Full DXF/DWG and browser parity remain incomplete.

## Edge-on conic projection — 2026-09-09

- Rank-one circle/ellipse projection now produces native line geometry instead of rejecting. Full circles and closed line/conic contours reduce to their exact bounded interval; open arcs preserve interior turning points even when their projected endpoints coincide. Source contour identity/construction persist; collapsed geometry is not marked as a hole.
- Core projection/collapsed-conic.ts owns analytic extrema, keeping this separate from plane transforms and ordinary ellipse projection. Existing document references remain authoritative, so source radius edits update collapsed projections after native reopening.
- Core 386 / CAD 336 tests, Core typecheck and CAD build pass. Tests cover circles, rotated full ellipses, arc turning points, source immutability, invalid preview blocking and mounted edge-on creation/reopen/source edits. Nearly singular nonzero conics, stable edge/vertex references, mixed authored/projected sketches, invalid-file recovery and live browser acceptance remain incomplete.

## Unified line Trim implementation — 2026-09-09

- The public line-only Trim entry now uses the same picked-curve implementation as general Trim. It retains straight-line selection even when another entity is closer, while sharing exact curve intersections and surviving-contact/locus/vertex remapping. The obsolete blanket constrained-contour rejection and duplicate trimming algorithm are removed.
- Operations README now reflects associative mirror/pattern support and current finite-contact remapping. Core 383 / CAD 335 tests, Core typecheck and CAD build pass. New coverage verifies line-only selection beside a closer point, contact preservation, and deleting a constrained isolated line without modifying the source. Live browser/full sketch parity remain incomplete.

## Extend preserves existing finite contacts — 2026-09-09

- Extending a line, circular arc or elliptical arc now reparameterizes its existing finite curve contacts to preserve their physical positions. Both free ends and conic sweep directions are covered; IDs and sliding flags remain intact. Sliding contacts may subsequently move over the extended segment.
- Core operations/extension-contacts.ts owns the affine parameter mapping. Endpoint constraints that physically prevent extension still reject atomically; extending does not bypass constraint validation.
- Core 382 / CAD 335 tests, Core typecheck and CAD build pass. Tests cover fixed/sliding contacts, both ends and sweep directions, input immutability, fixed-end rejection, mounted undo/redo and native save. Cubic source extension, broader topology remapping and live browser acceptance remain incomplete.

## Trim remaps surviving finite contacts — 2026-09-09

- Trim records the source parameter interval of every retained segment and remaps finite curve references into those intervals. Contact IDs and fixed/sliding modes persist; relations whose contact lies inside the cut are removed. Cut endpoints remain attached to the retained geometry.
- Core operations/trim-contact.ts owns parameter mapping; trim.ts supplies provenance and trim-references.ts integrates it with existing vertex/locus remapping. Closed-path seam changes map to the correct new segment. Sliding is bounded to the retained piece, not across the removed gap.
- Core 380 / CAD 334 tests, Core typecheck and CAD build pass. Coverage includes line/arc/ellipse/cubic contacts, discarded intervals, endpoints, closed seams, immutability, mounted undo/redo and native save. Unsupported whole-chain/control topology and live browser acceptance remain open; full parity is not complete.

## Sketch origin dimension reference — 2026-09-09

- Select sketch origin sets Entity B to a fixed construction point, preserving Entity A for distance/alignment constraints. The point uses the existing fix relation and native drawing format; repeated selection reuses it, including after solver tolerance movement.
- Core operations/sketch-origin.ts owns creation/reuse; CAD sketch/origin-control.ts owns presentation. Existing arc-center snapping retains concentric relations and origin placement retains fix relations.
- Core 377 / CAD 333 tests, Core typecheck and CAD build pass. New checks cover source immutability, fixed origin versus free authored points, driving distance/DOF, reuse, mounted selection, undo and native save. Connected browser list is empty; live acceptance and full sketch parity remain outstanding.

## Split remaps finite curve contacts — 2026-09-09

- Splitting lines, circular arcs, elliptical arcs and Béziers now remaps fixed/sliding coincidence, tangent, curvature and normal contact references to the correct new segment and normalized parameter. IDs and sliding modes persist; a contact at the split is assigned to the left piece.
- Core `operations/split-contact.ts` owns exact affine parameter remapping. Unsupported control-point and whole-fit-spline topology changes retain explicit rejection. Sliding remains bounded to the assigned piece after splitting.
- Core 375 / CAD 332 tests, Core typecheck and CAD build pass. Tests cover contacts on both sides and at the split across all four curve types, tangent preservation, unsupported-control rejection, native roundtrip and mounted split/undo/save. Trim contact remapping and live browser acceptance remain open.

## Saved contact mode editing — 2026-09-09

- Saved finite curve contacts now expose independent Slide contact A/B controls. Releasing a parameter allows movement within its segment; freezing keeps the last solved parameter and leaves geometry unchanged. Constraint IDs and native references remain stable.
- Core `operations/contact-mode.ts` owns mode validation; CAD `contact-mode-editor.ts` owns controls and failure recovery. Tests cover fixed→sliding→drag→fixed, geometric DOF, out-of-scope selections, undo and native save. Core 373 / CAD 331 tests, Core typecheck and CAD build pass. Full sketch parity and singular/live-browser acceptance remain open.

## Bounded sliding curve contacts — 2026-09-09

- Curve-contact references can opt into sliding for coincidence, tangency, curvature and normal constraints. Core solves each relation's contact parameter within [0,1], including inward motion from either endpoint; source geometry and parameter updates commit together.
- `solver/contact-parameters.ts` owns bounded coordinates and validation. DOF diagnostics include contact parameters while measuring geometric mobility, so a point sliding on a fixed curve has one geometric freedom. Dragging now preserves solved relation parameters instead of restoring stale ones.
- CAD constraint creation exposes Allow curve contacts to slide. New Extend-to-cubic attachments opt in; previously saved contacts remain fixed unless edited/recreated. Tests cover parameter movement, tangent contact, bounds, DOF, malformed flags, native roundtrip and mounted creation/undo/save. Core 371 / CAD 330 tests, Core typecheck and CAD build pass. Singular contact configurations and broader live browser acceptance remain open.

## Persistent Extend curve-boundary attachment — 2026-09-09

- Extend now attaches to reached line, circle, arc, ellipse and cubic boundaries after point-boundary preference. Lines/conics use locus coincidence; cubic boundaries retain the reached finite parameter. Boundary edits therefore update the attached endpoint through the solver.
- Core `operations/extension-boundary.ts` owns finite boundary identification; the existing endpoint-link helper adds/reuses coincidence. Coincident curve contacts now accept stationary positions; tangent/curvature/normal equations still reject undefined direction.
- Core 367 / CAD 329 tests, Core typecheck and CAD build pass. Coverage includes moving a boundary line, native cubic control edits, stationary contact/tangent rejection and mounted extension/undo/save. Cubic attachments have fixed parameters, while conic/line attachments can slide on supporting loci; finite-extent enforcement after edits and general free sliding curve parameters remain open.

## Persistent Extend-to-point attachment — 2026-09-09

- Successful extensions ending at standalone authored points now create a persistent coincidence relation in the same undo step. The relation is reused if already present and survives native reopening; moving the boundary point keeps the extended endpoint attached through the solver.
- Core `operations/extension-point-link.ts` owns the relation. Near misses and implicit circle centers do not acquire attachments. Existing extension constraint guards run before linking. Core 364 / CAD 328 tests, Core typecheck and CAD build pass, including native boundary-point dragging, conic attachment, duplicate avoidance and mounted save.
- Attachments to curve boundaries, full sketch parity and live browser acceptance remain open.

## Extend to authored sketch points — 2026-09-09

- Line, arc and ellipse Extend now considers standalone authored sketch points alongside curve boundaries. It chooses the nearest point beyond the selected free end on the exact locus; off-locus points and implicit centers do not terminate extension.
- Core `curves/point-boundaries.ts` owns point enumeration and line parameter checks. Existing extension operations retain constraint guards and exact conic geometry. Core 362 / CAD 328 tests, Core typecheck and CAD build pass, including both line directions, circular/elliptical boundaries, off-locus points, conflicts and mounted undo/native-save.
- Extension reaches the point geometrically; automatic persistent attachment to boundary geometry remains separate work. Live browser acceptance remains open.

## DXF layer selection — 2026-09-09

- Import DXF lists used model-space layers and entity counts with inclusion checkboxes. Filtering happens before decoding, so users can exclude unsupported reference/text layers. Empty selections clear the preview and prevent insertion; supported selections preserve normal placement, undo and native geometry saving.
- Core `dxf/records.ts` owns structural scanning and complete legacy polyline sequences; `layers.ts` owns inventory. CAD `dxf-layer-control.ts` owns choices. Malformed structure still rejects, and selected unsupported entities still report errors. Layer names/styles are not retained as CAD layers after insertion.
- Core 359 / CAD 327 tests, Core typecheck and CAD build pass, covering layer counts, selective unsupported decoding, paper space, legacy sequences, malformed sequences and mounted preview/undo/save. Full import parity and browser acceptance remain open.

## DXF source anchors and placement snapping — 2026-09-09

- DXF import now supports numeric source anchors and choices from imported endpoints, centers, midpoints and ellipse quadrants. Coordinates are in converted millimeters. The source anchor lands at destination X/Y with rotation and scale applied around it.
- Canvas placement snaps to existing sketch geometry with a six-screen-pixel tolerance, optionally disabled. Escape restores the prior destination. Insertion remains one undoable operation and native geometry preserves the placement. Placement snapping does not create persistent attachment constraints.
- Focused CAD `dxf-anchor.ts` builds choices from Core geometry helpers; `dxf-placement.ts` handles interaction and uses Core similarity transforms. CAD 326 tests and typecheck/build pass; Core unchanged (356 baseline). Live browser acceptance and full import parity remain open.

## Whole-spline symmetry — 2026-09-09

- Whole Bézier spline contours can now retain symmetry across a live sketch line, constraining control points exactly. Reverse spline correspondence handles opposite traversal direction; it is stored as optional `splineReversed` on the canonical symmetric constraint.
- Core `solver/symmetric-spline.ts` owns the equations. Splines require equal segment counts and matching closure; closed splines use corresponding seams. Topology mismatches and conflicting fixed controls reject atomically.
- Core 356 / CAD 325 tests, Core typecheck and CAD build pass. Tests cover reversed/native control dragging, conflicts and mounted creation/undo/save. External axes, topology remapping and live browser acceptance remain open.

## Circle-locus tangent and curvature contacts — 2026-09-09

- Circle/arc references can now constrain tangency and signed curvature against a finite curve contact. The circle contact follows its supporting locus; the other curve parameter remains fixed. Opposite bending is distinguished from matching curvature.
- Core `solver/circle-continuity.ts` owns the equations. Existing constraint UI accepts the new pair and explains it. Tests cover traversal direction/speed, solving a circle to a fixed cubic, contradictory fixed radius, undefined contact, undo/redo and native persistence. Core 354 / CAD 324 tests, Core typecheck and CAD build pass.
- Supporting-arc extents are not enforced by these locus constraints; use finite arc contact references when a specific arc parameter is required. Free sliding parameters on the other curve and live browser acceptance remain open.

## Editable ellipse quadrant constraints — 2026-09-09

- Saved quadrant relations now expose +X/+Y/−X/−Y endpoint choices. Reassignment keeps the constraint ID, seeds the point at the requested analytic endpoint and solves remaining constraints before committing. Conflicts leave the input drawing unchanged.
- Core `operations/quadrant-edit.ts` owns the edit and validation; CAD `sketch/quadrant-editor.ts` owns the per-row selector. Automated coverage includes all endpoints, native roundtrip, invalid IDs/values, conflicts, mounted selection, undo and save. Core 351 / CAD 323 tests, Core typecheck and CAD build pass. Full parity and live browser acceptance remain open.

## Ellipse axis construction handles — 2026-09-09

- Select ellipse X/Y axis creates a reusable construction diameter with endpoints retained at opposite ellipse quadrants. Standard length dimensions control its full diameter; line angle/alignment constraints control orientation. These use canonical quadrant and line constraints, without duplicate ellipse sizing state.
- Core `operations/ellipse-axes.ts` owns construction/reuse; CAD `sketch/ellipse-axis-controls.ts` owns selection presentation. Added numeric solver/native-roundtrip and mounted dimension/undo/save tests. Core 349 / CAD 322 tests, Core typecheck and CAD build pass. Full parity and live browser acceptance remain open.

## Ellipse center selection and snapping — 2026-09-09

- Elliptical segments and full ellipses now support concentric constraints with points, circles, arcs and other ellipses. Select ellipse center creates a linked construction point for fixing, alignment or dimensions; it survives native persistence and follows constrained edits.
- Shared center snap candidates include ellipses. Ordinary placement infers persistent concentric attachment for new vertices at the center. CAD arc/ellipse center controls now share a dedicated presentation module.
- Core 347 and CAD 321 tests pass, including center drag, inference, invalid selection, repeat selection, undo/redo and native save. Core typecheck and CAD production build pass. Live browser acceptance and full sketch parity remain outstanding.

## Selected-edge grouped patterns — 2026-09-09

- Linear and circular sketch patterns now accept individual edges picked from the canvas or source list. Multiple edges of one contour retain distinct memberships through count/spacing edits, repair, suppression, and native JSON persistence.
- The shared modification source picker owns mirror/pattern selection and highlights; Core owns source projection, source identity, group operations, and validation. Existing contour patterns remain supported.
- Added Core regressions for same-contour edge identity, resize, repair, suppression, circular source edits, and a mounted CAD flow covering canvas picking, undo/redo, and save. Verification: 345 Core tests, 320 CAD tests, Core typecheck and CAD production build pass. Browser discovery still returns no available browser; live visual acceptance remains outstanding.
- Existing dimensions and arc-center inference tests also pass. Full sketch parity remains incomplete; this does not close the parity ledger.

## Canvas picking for mirror sources — 2026-09-09

- Mirror source contours or individual edges can now be picked directly on the sketch canvas. The first canvas pick replaces automatic all-selected defaults; subsequent clicks toggle membership. Explicit list selection is retained when continuing on the canvas. Clicking the live axis or empty space leaves the selection unchanged.
- A separate source-highlight layer updates with the generated preview. Apply/cancel removes it, and source-list listeners are disposed when the tool closes. `mirror-source-control.ts` owns selection state/picking; `mirror-source-selection.ts` renders highlights using the shared Core source projection.
- Verification: 319 CAD tests, Core typecheck and CAD production build pass. The mounted workflow covers multi-edge toggle, same-contour axis exclusion, blank clicks, highlights, cancel/reopen, apply and save. Core geometry behavior is unchanged; only its existing projection helper was exported.
- Live browser visual verification, copied-edge joining, selected-edge linear/circular patterns and broader topology work remain outstanding.

## Associative selected-edge mirrors — 2026-09-09

- Mirror exposes Mirror individual edges, switching the existing source list to segments/circles/standalone points. Each copied segment keeps a live source reference and its own generated contour. A live axis may share the source contour when it is a different edge; only the axis itself is excluded. Contour mode keeps its existing whole-contour guard.
- Core `solver/pattern-source.ts` projects source geometry without adding duplicate source contours; `operations/mirror-entities.ts` creates the relations. Saved axis editing preserves selected-edge geometry and permits compatible same-contour axes. Bézier source extraction does not require a nonzero endpoint tangent, so stationary-end cubics can be mirrored.
- Verification: 342 Core / 318 CAD tests pass, Core typecheck and CAD production build pass. Tests cover same-contour axes, endpoint edit propagation after serialization, self-axis rejection, stationary cubic geometry, edge-list selection, saved references and mounted undo/redo. Browser discovery still returns `[]`.
- Direct viewport picking for mirror edge lists, automatic joining of copied edges, selected-edge linear/circular patterns, broader topology remapping and live browser acceptance remain open.

## Whole-placement pattern suppression — 2026-09-09

- Group editors now list repeated placements with suppressed/total contour counts and Suppress placement / Restore placement actions. Each acts on every surviving source membership at that position using saved settings and commits once. Mixed suppression states are supported; incomplete memberships require repair first.
- Core `operations/pattern-placement.ts` projects placement membership and batches existing instance operations. A dependency failure on any member returns no partial drawing. CAD `pattern-placement-controls.ts` owns the focused controls; one Undo reverts the whole batch.
- Verification: 340 Core / 317 CAD tests pass, Core typecheck and CAD production build pass. Tests cover multiple source contours, mixed states, unaffected other placements, stable relation IDs, native restoration, late-member dependency failure and mounted batch undo/redo/save.
- Selected-edge patterns/mirrors, broader topology remapping, remaining manipulators and live browser acceptance remain open.

## Pattern-instance suppression — 2026-09-09

- Grouped pattern relations now expose Suppress instance / Unsuppress instance. Suppression removes the generated contour while retaining the slot, relation identity and minimal contour ID/flags. Unsuppression rebuilds from the current source and shared settings. No stale geometry snapshot is stored. Dependent sketch constraints block suppression explicitly.
- Suppressed slots survive count/spacing edits and are excluded from missing-instance repair. Resizing removes out-of-grid suppressed memberships without creating contours. Fully suppressed groups retain their source memberships. Core `operations/pattern-suppression.ts` owns the operation and `solver/pattern-suppression.ts` validates the retained record.
- Verification: 338 Core / 316 CAD tests pass, Core typecheck and CAD production build pass. Tests cover physical contour removal, current-source restoration, stable identity, suppressed count edits/shrink, dependency rejection, undo/native persistence and the anonymous-instance/source-ID serialization regression. CAD tests preceded the final identity-only fix; Core regression and CAD build were rerun afterward.
- Suppression currently applies to individual source/instance contour relations in grouped patterns. Whole-placement batch controls, selected-edge patterns, broader topology remapping and live browser acceptance remain open.

## Repair partially detached patterns — 2026-09-09

- Group editors now show Restore missing instances when a surviving source is missing linked slots. Restoration uses saved group settings, creates new linked copies and preserves detached contours unchanged. This repairs membership so count editing can resume. Restoration is undoable and persists natively.
- `operations/pattern-repair.ts` detects missing slots and invokes the shared resize/remapping logic in restoration mode. Duplicate membership rejects; fully detached source sets are not inferred. A group with no linked source left requires creating a new pattern from explicitly selected geometry. Repeated restoration is idempotent.
- Verification: 335 Core / 315 CAD tests pass, Core typecheck and CAD production build pass. Tests cover changed detached geometry, deleted instances, reference remapping, idempotence, restored count editing and mounted restore/undo/redo/native save.
- Instance suppression, selected-edge patterns, broader topology remapping and live browser acceptance remain outstanding.

## Pattern count editing — 2026-09-09

- Saved grouped linear/circular patterns now expose count fields, including both dimensions of a linear grid. Increasing counts adds linked instances; decreasing counts removes instances outside the new grid. Surviving instances retain their relation/contour IDs and grid coordinates, even when row width changes.
- `operations/pattern-resize.ts` owns membership/remapping. Removed instances with dependent sketch constraints reject atomically; unrelated references are remapped through the existing contour deletion operation. Partially detached membership rejects count edits rather than guessing missing slots. Fully detached sources are no longer members. Existing contour and solver limits still apply.
- Verification: 333 Core / 314 CAD tests pass, Core typecheck and CAD production build pass. Tests cover 2D identity preservation, growth/shrink, multiple sources, circular shrink, dependency rejection, unrelated-reference remapping, partial detachment and mounted count/undo/redo/native save.
- Instance suppression, partial-detachment repair, edge-level selection, broader topology remapping and live browser acceptance remain open. Count editing requires a grouped pattern; legacy ungrouped relations are unchanged.

## Shared pattern definitions and placement editing — 2026-09-09

- New linear/circular patterns store one canonical definition in `SketchDrawing.patternGroups`. Instance relations store the group ID and instance index; they no longer duplicate derived transforms. Legacy per-instance transforms still load. Mirror relations retain their fixed/live-axis representation.
- Saved grouped patterns expose Edit pattern for first/second linear spacing or circular center/step angle. Update preserves instance contours and relation IDs; Cancel discards edits. Count changes are explicitly unavailable pending safe instance remapping. Older ungrouped patterns are not automatically inferred/migrated.
- `pattern-groups.ts` owns settings validation and derived transforms; `operations/pattern-group.ts` owns creation/editing and solver integration; CAD `pattern-group-editor.ts` owns presentation. Group metadata contains no geometry references that need contour-index remapping.
- Verification: 330 Core / 313 CAD tests pass, Core typecheck and CAD production build pass. Tests cover 2D spacing, circular center/step, stable references, malformed/missing groups, contradictory transform storage, mounted cancel/undo/redo/native save and continued source-edit propagation. Full pattern parity, count editing, topology remapping and browser acceptance remain open.

## Edit saved mirror axes — 2026-09-09

- Saved mirror relations now expose Edit mirror axis. Users can reassign another live sketch line or switch to fixed coordinates; Update commits once and Cancel discards field edits. Source/instance contours cannot be selected as their own live axis. The existing relation and instance IDs survive the edit.
- Core `operations/mirror-edit.ts` owns axis reconstruction, validation, reseeding the reflected instance and solving the updated system. CAD `mirror-relation-editor.ts` owns fields and commits through workspace history. The coupled solver still enforces all existing geometry constraints; arbitrary conflicting edits are not forced through.
- Verification: 328 Core / 312 CAD tests pass, Core typecheck and CAD production build pass. Tests cover line reassignment, conversion to fixed coordinates, stable IDs, source nonmutation, invalid/missing/degenerate axis rejection and mounted cancel/update/undo/redo/native persistence.
- Editing applies to one saved source/instance relation. Group pattern count/spacing controls, selected-edge mirrors within the axis contour, topology remapping and live browser acceptance remain outstanding.

## Associative mirroring with a live axis — 2026-09-09

- Mirror now creates source/instance relations for a fixed coordinate axis or a live sketch-line axis. Source edits propagate; moving the live axis recomputes reflection through the solver. A live axis stores only its entity reference, not a second fixed transform. Conflicting whole-geometry transforms reject instead of silently breaking the relation.
- The mirror panel exposes a Mirror axis selector. Choosing a line disables numeric axis inputs and excludes that line's entire contour from the copy selection. Core rejects an included axis contour or incompatible axis. Generated relation removal detaches an instance. `curves/reflection.ts` owns shared math; `mirror-axis-control.ts` owns the selector.
- Verification: 326 Core / 311 CAD tests pass, Core typecheck and CAD production build pass. Tests cover live-axis motion and radius edits after serialization, fixed-axis linkage, invalid-axis rejection, conflicting-transform rejection, mounted selection/exclusion/undo/redo/native persistence. Original source constraints remain unchanged.
- Selected-edge mirroring within the axis contour, post-creation axis reassignment controls, topology remapping and live browser acceptance remain open. Pattern count/spacing editing is also still outstanding.

## Associative linear/circular pattern geometry — 2026-09-09

- New linear and circular patterns persist one generated `pattern` constraint per source/instance contour. Source radius, point and Bézier-control edits propagate through the ordinary solver. Removing that instance's relation detaches it. Native save/reopen retains the transform and contour references; original source constraints are preserved. The pattern panel explains the linkage.
- `curves/similarity.ts` owns shared transform math, re-exported by the existing operations API. `operations/pattern-relations.ts` owns relation creation; `solver/pattern.ts` compares independent geometry coordinates and rejects incompatible topology. Arc through-point gauge is not counted as an extra equation. Generated relations appear in the saved constraint list but are not offered as an incomplete standalone ribbon command.
- Verification: 324 Core / 310 CAD tests pass, Core typecheck and CAD production build pass. Tests cover linear/circular radius and position propagation after serialization, cubic-control propagation, detachment, arc DOF, topology rejection and mounted creation/edit/undo/redo/native reopen. The panel's final explanatory text was adjusted after these checks.
- This closes geometry linkage, not full pattern parity: editable count/spacing/center controls after creation, instance suppression, topology remapping, selected-edge patterns and a live mirror axis remain open. Current transforms are fixed per instance and solver size limits still apply. Existing independent mirror behavior is unchanged. Live browser acceptance remains outstanding.

## Per-entity sketch constraint colors — 2026-09-09

- Vertices, circles, individual path segments and Bézier controls now carry their own constraint-state colors. Movable entities use the accent color, fixed entities use theme text color, sketch conflicts/redundancy use danger color, and unavailable analysis uses muted text. Closed-region fills, construction dashes and selection overlays remain separate. State labels are also exposed on the SVG entities and the existing selected-entity readout.
- Core `sketchConstraintStates` shares coordinate perturbations and constraint residuals across a batch; the single-entity API delegates to it. CAD `geometry-constraint-colors.ts` maps rendered geometry to Core references. Cubic edges are fixed only when both endpoints and both controls are fixed. No geometry or diagnostics are persisted as a second source of truth.
- Verification: 321 Core / 309 CAD tests pass, Core typecheck and CAD production build pass. Tests cover mixed fixed/free geometry, construction styling metadata, updates after adding a driving dimension, free cubic controls, batched/single-result agreement and nonmutation. Theme colors are token-based; live browser visual verification remains outstanding. Existing numerical singularity and 256-coordinate analysis limits remain.

## Selected-entity constraint state — 2026-09-09

- Clicking a sketch vertex or edge now displays its local degrees of freedom separately from the whole sketch. A fixed point reports fully constrained even if other geometry is free; empty-space deselection hides the selection readout. Selection, model edits and undo use the same refresh path.
- Core `sketchConstraintState(drawing, entity?)` computes entity mobility as the additional rank of its geometric observables over the constraint Jacobian. `diagnostic-rank.ts` owns shared numerical rank; `entity-observables.ts` maps geometry; CAD `selection-constraint-status.ts` owns presentation. Existing sketch-wide conflicts/redundancy remain explicitly sketch-wide. This is local numerical analysis with the existing 256-coordinate limit, not a guarantee against singular configurations.
- Verification: 320 Core / 307 CAD tests pass, Core typecheck and CAD production build pass. Tests cover fixed/free points and lines, constrained circles, arc geometric DOF, unrelated free geometry, nonmutation, missing references and mounted selection/deselection. Browser discovery again returns no browser (`[]`); live visual acceptance, per-entity canvas coloring and broader parity remain open.

## Parallel-line distance dimensions — 2026-09-09

- Distance now accepts two line entities. A driving dimension maintains parallelism and perpendicular spacing between their infinite supporting lines. Reference distance measures parallel lines and rejects nonparallel or degenerate pairs rather than showing arbitrary endpoint spacing.
- Focused Core `solver/line-line-measurement.ts` shares geometry with residuals, reference measurement and CAD canvas annotations. Disjoint segments and reversed endpoint/selection orders are supported; the panel explains parallelism semantics.
- Verification: 318 Core / 306 CAD tests pass, Core typecheck and CAD production build pass. Tests cover measured feet, fixed-line edits, native reopening, reference conversion/rejection, canvas annotation and mounted creation/edit/undo/redo/native save. Live browser acceptance and full sketch parity remain outstanding.

## Point-to-line dimensions — 2026-09-09

- Distance accepts a point and line in either selection order, measures perpendicular to the infinite supporting line, and supports driving values and reference measurements. Zero-length lines are rejected.
- Core `solver/point-line-measurement.ts` owns shared measurement geometry; solver residuals, reference measurement and CAD annotations consume it. Canvas extension lines terminate at the perpendicular foot, including beyond a segment endpoint. Distance relations are classified as preserving the supporting line for split remapping.
- Verification: 315 Core / 304 CAD tests pass, Core typecheck and CAD production build pass. Tests cover extended/reversed lines, degenerate rejection, driving edits with fixed-line tolerance, reference conversion, native JSON reopening and canvas foot placement. Live browser verification and full sketch parity remain outstanding.

## Driving/reference dimension conversion — 2026-09-09

- Saved supported dimensions now expose Make reference / Make driving controls. Converting to reference removes driving values/links while preserving ID and geometry; converting back takes the current measurement as its driving value. Label metadata stays attached through the unchanged ID.
- Direct dependent dimensions of a converted driver retain their current numeric values as independent drivers. Their own downstream links remain intact. The UI explains this behavior after conversion. Existing Update action placement remains unchanged.
- Core `operations/dimension-reference.ts` owns the atomic conversion. Verification: 313 Core / 303 CAD tests, Core check and CAD production build pass. Tests cover dependency-chain values, stable identity, current measured value, idempotence, invalid IDs and mounted undo/redo/native save.
- Reference offset/slot types, broader parity and live browser visual acceptance remain open.

## Reference dimensions — 2026-09-09

- Length, point distance, X/Y distance, radius, diameter and angle dimensions can now be created as Reference dimension (measurement only). Native constraints store `reference: true` without a literal value or driver link. Core measures current geometry and contributes no solver equations.
- Reference values are read-only in the constraint panel and parenthesized on the canvas. They update after geometry changes. They cannot drive another dimension, and the radius-setting tool adds/updates a driving constraint rather than trying to edit a reference measurement.
- `solver/measured-dimension.ts` owns geometric measurement; no copied measured value is persisted. Verification: 311 Core / 302 CAD tests, Core check and CAD production build pass. Tests cover unchanged DOF, live measurement after driving edits, native save, signed axes/angles and invalid driver/value rejection.
- Reference offset/slot measurement, driving/reference conversion UI and full browser visual acceptance remain open, along with broader sketch parity.

## Automatic dimension-label spacing — 2026-09-09

- Automatic dimension labels now reserve space around manually positioned labels and move apart when their padded label bounds overlap. Layout is deterministic, recomputed on render and never saved over manual metadata. Associated measurement guides/connectors update after automatic movement.
- `sketch/dimension-label-spacing.ts` uses browser SVG text bounds when available, with an estimated fallback for hidden/headless rendering. Dense layouts can place labels above the existing label area; viewport fitting and geometry/leader collision avoidance remain incomplete. Manually overlapping labels are intentionally left in their chosen positions.
- Verification: 301 CAD tests and production typecheck/build pass. Tests cover label separation, pinned manual placement, deterministic rerender and unchanged drawing/metadata. Core unchanged (last verified 308 tests). Live browser visual acceptance and broader sketch parity remain open.

## Angular and radial manual placement — 2026-09-09

- Angular measurement arcs now expand/contract with label distance while retaining the measured line directions. Radius/diameter guides orient toward manually placed labels; partial-arc guides clamp to the visible sweep when the label lies outside it.
- `sketch/curved-dimension-layout.ts` handles render-time layout only and restores original graphics on cancellation. Connectors attach to the relocated radial endpoint or angular arc, not a stale guide position.
- Verification: 299 CAD tests and production build passed; an additional cancellation test was then added and all 12 canvas-renderer tests passed. Coverage includes angle arc radius, radial guide direction, partial-arc clipping and restoration. Core unchanged (last verified 308 tests). Overlap avoidance, broader sketch parity and live browser visual acceptance remain open.

## Aligned length/distance guide relocation — 2026-09-09

- Length and point-to-point distance annotations now have offset measurement lines and endpoint extension guides. Manual label placement relocates the dimension line perpendicular to its measured direction, preserving parallelism and measured span for diagonal geometry.
- Generalized `axis-dimension-layout.ts` to `linear-dimension-layout.ts`; X/Y and aligned layouts share the same presentation update path used during drag/restore.
- Verification: 297 CAD tests and production typecheck/build pass. Tests cover length and point-distance layouts on both sides of diagonal geometry, preserved span/parallelism and original source attachments. Core unchanged (last verified 308 tests). Angular/radial placement refinement, overlap handling and live browser acceptance remain open.

## X/Y dimension-line relocation — 2026-09-09

- Moving a horizontal/vertical distance label now relocates its measurement line and both extension guides during preview and after native reopen. Original source endpoints remain attached to geometry. Cancelling restores the original guide layout.
- `sketch/axis-dimension-layout.ts` derives SVG guide positions from current label placement; no extra layout truth is persisted. Other dimension types retain their existing connectors.
- Verification: 296 CAD tests and production typecheck/build pass. Tests cover saved X/Y placement, source attachment, live drag relocation and cancellation. Core unchanged (last verified 308 tests). Non-axis dimension-line relocation, overlap avoidance and live browser visual acceptance remain open.

## Manual label connector tracking — 2026-09-09

- Manually placed dimension labels now connect to their measurement guide. Connectors update during drag preview, restore/remove on cancellation and undo, and rebuild from current geometry after edits or reopening.
- `sketch/dimension-label-leader.ts` owns the SVG presentation update shared by rendering and dragging. No connector coordinates are persisted; only the label position remains saved metadata.
- Verification: 294 CAD tests and production typecheck/build pass. Mounted tests cover connector endpoints after geometry changes and drag/undo/cancel behavior. Core unchanged (last verified 308 tests). Dimension-line relocation, automatic overlap avoidance and live browser visual acceptance remain open.

## Manual dimension-label positions — 2026-09-09

- Dimension labels can be dragged within the sketch canvas. Release commits one presentation-only undo step; Escape/pointer cancellation restores the original position. Dragging captures the pointer and keyboard focus, and consumes the following click so a drag does not open an editor or place geometry. Ordinary label clicks still edit the value.
- Native Part documents now store optional `sketchPresentation[featureId].dimensionLabelPositionsMillimeters`, keyed by constraint ID. The format validator requires finite coordinate pairs. Solver/kernel geometry never consumes this metadata. Sketch history includes positions, save prunes removed constraint IDs, and reopening restores placement.
- Verification: 308 Core / 293 CAD tests pass; Core check and CAD production build pass. The final focus adjustment was additionally verified with all 110 mounted workspace tests. Tests cover metadata validation/roundtrip, dragging, undo/redo, cancellation, native reopen and unchanged geometry.
- Leader/extension geometry still uses automatic layout; only label placement is manual. Leader tracking, overlap handling, broader parity and live browser visual acceptance remain open.

## Offset and slot-width annotations — 2026-09-09

- Saved offset and slot dimensions now have selectable canvas annotations. Offset uses the canonical signed distance handle; slot width spans both sides of the centerline and displays the full width. No geometry/measurement formulas are duplicated from Core.
- Verification: 292 CAD tests and production typecheck/build pass. Tests cover negative offset direction, full-width span, rendered values and Enter-key activation without forwarding the keyboard gesture to the canvas. Core unchanged (last verified 306 tests). Browser discovery returned no connections; live visual acceptance, manual placement and overlap handling remain open.

## Angular annotations and axis extension guides — 2026-09-09

- Saved line-angle dimensions now show a signed degree label and arc centered at the supporting lines' intersection. Parallel lines use a finite fallback anchor; zero-length lines are excluded. The shared annotation activation opens the canonical saved value editor.
- X/Y dimension lines are offset from their source geometry with extension guides back to both points. Layout remains automatic and does not alter geometry or persisted dimensional values.
- `sketch/angular-dimension-layout.ts` owns the presentation geometry. Verification: 290 CAD tests and production typecheck/build pass, covering positive/negative arc direction, intersecting/parallel/invalid references, angle labels, extension guides and nonmutation. Core unchanged (last verified 306 tests). Manual placement, overlap handling, offset/slot annotations and live browser visual acceptance remain open.

## Canvas dimension annotations — 2026-09-09

- Saved radius, diameter, length, point distance and X/Y distance dimensions are now drawn on the 2D sketch canvas. Labels resolve canonical driver values, show millimeters and mark linked dimensions. Automatic label positions are presentation-only.
- Clicking a label or activating it with Enter/Space focuses the matching saved dimension input. Pointerdown/click propagation is stopped so annotation editing does not create or select geometry. Updates rebuild the geometry and annotation through the existing constraint commit path.
- `sketch/dimension-annotations.ts` owns rendering; Core still owns dimension values and referenced geometry. Theme variables style the annotations.
- Verification: 287 CAD tests and production typecheck/build pass. Mounted tests cover annotation click → focused editor → changed diameter/model/native save and linked signed axis labels. Core unchanged (last verified 306 tests). Draggable placement, dimension leaders/extension-line polish, angle/offset/slot annotations and live browser visual acceptance remain open.

## Independent X/Y distance dimensions — 2026-09-09

- Sketch constraints now include Horizontal distance and Vertical distance, each driving the signed coordinate difference B minus A in millimeters. Zero and negative values are supported. These are independent from straight-line distance and participate in native length-dimension links.
- The constraint panel/ribbon exposes both tools with explicit direction hints and editable saved values. Multiword constraint labels now display spaces in the tool selector/ribbon.
- Verification: 306 Core / 285 CAD tests pass; Core check and CAD production typecheck/build pass. Tests cover independent X/Y edits, zero/negative distances, fixed reference points, fully defined point state, invalid geometry/value rejection and mounted native save. Full graphical dimension placement and live browser parity remain open.

## Driving diameter dimensions — 2026-09-09

- Sketch constraints/ribbon now include Diameter for circles and circular arcs. The native solver stores the displayed diameter in millimeters and drives twice the circle radius. Positive finite values are required; dimension links use the literal displayed length value.
- Circle-to-arc splitting retains diameter constraints. Existing radius-setting operations update a diameter driver with twice the requested radius rather than adding a competing radius constraint. The constraint panel supports initial application and editing of saved diameter values.
- Verification: 304 Core / 284 CAD tests pass; Core check and CAD production typecheck/build pass. Tests cover fixed-center diameter edits after serialization, radius-tool reuse, invalid values, split arcs, linked dimensions and mounted diameter creation/native save. Full graphical dimension placement, other dimension variants and live browser acceptance remain open.

## Selected-contour projection editor — 2026-09-09

- Project sketch now offers Entire sketch or one source contour. New references assign a scoped stable ID to the authored source and save that source update together with the projection. Preview/cancellation never mutate the live document.
- Reopening identifies the selected contour by saved ID even after source reorder/coordinate edits. A deleted contour remains an explicit broken reference until a replacement contour or entire sketch is selected. Source changes reset the geometry selection. Projected-source contours can be selected when they already expose stable IDs; anonymous projected contours remain disabled.
- Focused `sketch/projection-source-selection.ts` owns menu-to-reference translation, using the Core transactional reference helper. Temporary menu indices are never persisted.
- Verification: 283 CAD tests and production typecheck/build pass. New mounted tests cover preview, atomic ID/source commit, cancellation, reorder/edit/native reopen and explicit broken-contour repair. Core remains at the last verified 301 tests (no Core changes in this unit). Individual segment/vertex references, mixed authored/projected sketches and live browser acceptance remain open.

## Persistent midpoint snapping — 2026-09-09

- Line and circular-arc midpoint candidates now come from Core `operations/midpoint-snaps.ts`, shared by CAD snapping and inference. Arc midpoint means halfway along its sweep, not chord midpoint or the stored through-point.
- Explicit canvas placement at a midpoint creates a native midpoint constraint, unless another inferred attachment already controls that point. Existing vertices, generated unplaced points and duplicate closed vertices are excluded. Undo groups the relation with new geometry.
- Verification: 301 Core / 281 CAD tests pass; Core check/CAD production build pass. Tests verify midpoint movement after endpoint edits and serialization, arc midpoint geometry, idempotence, generated-point exclusion and mounted canvas placement/undo/redo/native save. Live browser acceptance and remaining full parity are still open.

## Persistent line alignment — 2026-09-09

- Canvas placement of line and midpoint-line tools now retains exact horizontal/vertical alignment as native constraints. Existing segments and diagonal lines are not constrained retroactively. Duplicate inferred line relations are avoided.
- Core `operations/alignment-snaps.ts` owns geometric inference. CAD `sketch/drawing-inference.ts` now groups drawing gesture inference policy before the workspace undo commit, replacing inline orchestration.
- Verification: 299 Core / 280 CAD tests pass; Core typecheck/CAD production build pass. Tests verify constrained corner movement after serialization, appended-segment scope, idempotence, canvas creation, undo/redo and native save. Browser discovery returned no connections. Arbitrary alignment guides, alternate gesture coverage and full browser parity remain open.

## Endpoint and origin inference — 2026-09-09

- Canvas-click completion now infers saved endpoint coincidence and origin anchoring for explicitly placed vertices. Core `operations/point-snaps.ts` excludes existing vertices, off-target points, duplicate closed endpoints and points already attached by center/quadrant inference. Generated centers are excluded when they were not among gesture placement points.
- Numeric Place point remains explicit coordinate entry for this new inference path. Center/quadrant inference retains its existing behavior. Alternate gestures, consistent snap provenance across all tools and broader alignment inference remain open.
- Verification: 297 Core / 279 CAD tests pass; Core check and CAD production build pass. Tests cover source movement after serialization, origin anchoring, idempotence, generated-center exclusion and mounted canvas endpoint inference with undo/redo/native save. Live browser acceptance remains outstanding; full parity is incomplete.

## Persistent center snap inference — 2026-09-09

- Ordinary sketch point placement now adds a saved concentric constraint when a newly authored point exactly matches an existing circular arc or circle center and geometry snapping is enabled. Existing vertices and off-center points are not constrained retroactively; closed-path duplicate vertices are counted once.
- Core `sketch/operations/center-snaps.ts` owns center candidates and inference. CAD uses those same candidates for snapping. Geometry and inferred constraints share one undo checkpoint. This covers the ordinary drawing placement path; alternate gestures and broader coincidence/alignment inference remain open.
- Verification: 293 Core / 278 CAD tests pass; Core typecheck and CAD production build pass. Tests cover constrained edits after JSON reopen, off-center/existing point exclusion, degenerate arcs, circle centers, mounted native save and undo/redo removal/restoration. Live browser acceptance remains outstanding; full parity is incomplete.

## Arc-center dimension access and stable contour references — 2026-09-09

- Sketch snapping now includes analytic circular-arc centers, including later segments in a path. Degenerate arcs do not disable other snap targets. Snapping alone positions geometry; it does not yet create an automatic persistent concentric relationship.
- In the active sketch constraint panel, select an arc as Entity A and use **Select arc center**. This exposes/selects a construction point constrained concentric to the arc, reusable for distance, alignment and fix constraints. Existing exposed centers are reused. Empty/nonfinite dimension values are rejected. Radius edits and fixed-center behavior use the existing Core solver.
- Core contour references now support optional scoped stable IDs and projection `sourceContourId`; the transactional reference helper assigns IDs to authored contours. Reordering/coordinate edits preserve references; deleted selected contours fail explicitly. Copies/offsets discard IDs; multi-fragment trims and joined paths avoid arbitrary identity inheritance. The projection settings editor preserves existing selected-contour references. Creating individual-contour references from the GUI, segment/vertex identity, mixed authored/projected geometry and comprehensive topology remapping remain open.
- Verification: 290 Core tests and 277 CAD tests pass, including mounted sketch center selection/fix/native-save and projection-reference preservation. Core typecheck and CAD production build checked. Browser discovery returned no connections; live browser interaction and visual acceptance remain outstanding. Full Onshape parity is not complete.

## Whole-sketch projection editor — 2026-09-09

- Sketch ribbon Project sketch opens a viewport editor for whole-source projections. Choose an earlier source sketch, target named plane/offset, and name; native preview geometry updates before Create projection. Editing a projected feature routes to the same editor, retaining its ID and allowing source relinking or preservation of its explicit frame.
- The editor saves only the source reference. It protects active sketches and rejects stale-document apply, invalid/edge-on previews and suppressed sources. Cancellation leaves the document unchanged. An already-open document with a missing reference can select a replacement source; invalid files still fail document parsing, so file-level recovery remains incomplete.
- Feature dependency traversal now includes projected source IDs, so source suppression/unsuppression and cascading removal include projected sketches and their solids. Auto-fit previews bound grid density to avoid excessive grid elements for large coordinates.
- Verification: 286 Core / 273 CAD tests, Core check/CAD build pass. Mounted DOM tests cover reference-only creation, preview, relinking after native reopen, invalid/stale/cancel paths and replacement of a missing reference. Core tests cover dependency cascades. Browser discovery returned no connections; live visual acceptance remains open.
- This is a whole-sketch projection feature. Individual source edges/vertices, mixed projected/authored contours and their constraint references remain incomplete.

## Associative whole-sketch projection documents — 2026-09-09

- A profile can now persist `{type: "projection", sourceFeatureId}` instead of a geometry snapshot. Core `document/profile-projection.ts` resolves earlier profile IDs, solves source geometry, projects between source/target frames, and supports chained references. Renaming/editing the source retains the relationship.
- The kernel resolves projected profiles during rebuild, including extrusion consumers. Missing/forward references are rejected by document validation; suppressed sources report an explicit rebuild error. Rollback excludes downstream projection/body evaluation. Named frame conversion matches the evaluator's XY/XZ/YZ conventions; explicit frame origins avoid double-applying offsets.
- Verification: 285 Core / 269 CAD tests pass; Core check/CAD build pass. Includes serialized reference-only payload, rename/radius propagation, chained/suppressed/missing/forward references, frame conventions, native projected-solid dimensions after edits and rollback.
- Whole-source reference semantics now work in Core, but Project selection/creation UI, mixed authored/projected sketch geometry, stable subentity references, broken-link recovery UI and live browser acceptance remain incomplete. Direct editing of a projection currently raises an explicit source-driven-editing error to prevent accidental detachment.

## Sketch projection geometry foundation — 2026-09-09

- Core `sketch/projection/` now projects solved native curves between arbitrary orthonormal sketch frames. Lines/Bézier controls transform directly; circular and elliptical arcs become exact native ellipse segments. Oblique circles produce closed ellipse halves, while circular results remain circles. Orientation reversal changes sweep correctly.
- Output preserves construction/hole flags and omits source constraints whose meaning does not survive projection. Edge-on conics reject explicitly; no collapsed or tessellated substitute is silently created.
- Verification: 281 Core tests and Core check pass; CAD build passes. Includes pointwise geometry checks under translated/oblique frames, reflected sweep, source dimension solving, immutable source data, invalid/degenerate frames and actual native projected-ellipse save/reopen/extrusion with checked dimensions.
- This is a geometry foundation, not a shipped associative Project tool. Persisted source references, source-edit propagation, broken-reference reporting, edge/vertex picking and UI integration remain open. No new browser behavior was claimed.

## Persistent fit-spline refitting — 2026-09-09

- Newly authored open/closed fit splines save a `spline-shape` constraint referencing their whole native contour. Fit knots remain the existing vertices; no duplicate geometric point store was added. Solver residuals keep Bézier handles on the natural/periodic interpolant during point dragging and constraint solving.
- Shape-linked contours expose a whole-spline constraint selection. Removing the shape constraint allows independent handle editing. Unsupported segment splitting reports a remapping requirement rather than silently breaking the relationship.
- Verification: 276 Core / 269 CAD tests pass, Core check/CAD build pass. Tests verify six freedoms for three open fit points, eight for four closed fit points, fully defined status with fixed fit points, interior dragging with fixed neighbors, periodic seam dragging, native constraint persistence, topology guards and validation of a 100-point curve.
- Solver now checks already-satisfied residuals before allocating iterative coordinates, allowing large generated curves to save unchanged. Iterative editing still has the existing 512-coordinate limit; full diagnostics retain their 256-coordinate limit. Endpoint tangent controls, source-fit topology insertion/remapping, scalable solving/diagnostics and live browser acceptance remain open. Browser discovery returned no connections.

## Periodic closed fit-point splines — 2026-09-09

- Fit-point splines can close by clicking near their first point after at least three points, or using Close spline. Pointer preview uses the same closed geometry; completion is one undoable native contour. Closed splines require 3–1000 distinct consecutive fit points.
- Core `curves/periodic-spline.ts` solves the cyclic tridiagonal system in linear time/storage. Position, tangent and second derivative match across all fit points, including the seam. Open splines retain their natural endpoint behavior.
- Verification: 270 Core / 269 CAD tests pass, Core check/CAD build pass. Tests cover nonuniform triangular/five-point seam continuity, hover closure, click/button completion, undo/native persistence and actual OCCT extrusion of a saved periodic loop with checked depth.
- Initial periodic geometry is implemented; subsequent native-handle edits do not yet maintain fit-spline relationships. Persistent refitting, tangent endpoint controls and live browser acceptance remain open. Browser discovery returned no connections.

## Fit-point spline authoring — 2026-09-09

- The spline dropdown now exposes Fit-point spline. Click any number of distinct consecutive points (2–1001), preview the interpolated curve as the pointer moves, then use Finish spline or Enter on the canvas. Escape cancels pending points. Finishing the sketch with an unfinished spline reports the needed action instead of silently discarding it.
- Core `curves/fit-spline.ts` uses chord-parameterized natural cubic interpolation and emits native Bézier spans. Initial geometry passes through every fit point with C2 continuity in chord parameters. `sketch/fit-spline-tool.ts` owns completion controls; drawing/preview modules share the Core result. One completed spline is one undo step; construction mode and native save/reopen work.
- Verification: 268 Core / 268 CAD tests pass; Core check/CAD build pass. Tests cover interpolation/continuity, duplicate rejection, pointer and between-click previews, explicit/keyboard completion, cancellation, undo/redo and native reopening. Browser discovery remains empty.
- Persistent fit-point-driven refitting, periodic closed splines, tangent-end controls and arbitrary-degree/control insertion remain incomplete. Editing native Bézier handles does not preserve the initial natural-spline relationship automatically.

## DXF polynomial spline import — 2026-09-09

- ASCII DXF SPLINE control nets of degree 1–3 now import as native lines/cubic Bézier spans, preserving polynomial geometry rather than tessellating. Quadratic spans are degree-elevated; nonuniform and repeated knots and unclamped domains are supported. Equal positive weights cancel and are accepted. Closed/periodic flags require endpoint closure within 1e-7 mm.
- Focused Core `curves/bspline.ts` owns curve conversion; `import/dxf/spline.ts` owns DXF counts, coordinates, weights and flags. Existing preview, placement, endpoint joining, undo and native persistence apply. No curve evaluation logic was added to UI.
- Verification: 266 Core / 267 CAD tests, Core check/CAD build pass. Independent Cox–de Boor basis tests compare span geometry; tests cover invalid knot/control data, nonplanar later control points, unsupported weights, spline-to-line closed joining, preview, undo/redo and native save/reopen.
- Higher-degree and unequal-weight rational curves, fit-only splines, source B-spline control-net editing and associative continuity across converted spans remain incomplete. Browser discovery returned no connections; live browser acceptance remains open.

## Nested sketch region display — 2026-09-09

- Sketch region fills now follow outside-in containment order, preserving islands inside holes even when imported contours arrive in a different order. Open and construction geometry paints afterward so region fills do not hide it.
- Core `regions/order.ts` supplies the same ordering to the sketch renderer and extrusion kernel. Original contour indices, geometry and constraints are unchanged; rendered contours carry their original index. Ambiguous intersecting loops retain explicit solids-before-holes behavior rather than receiving inferred region semantics.
- Verification: 261 Core and 266 CAD tests pass, Core check/CAD build pass. Tests cover every permutation of three nested boundaries, fallback behavior, renderer ordering and unchanged source references. Live browser visual acceptance remains outstanding.

## Sketch dropdown construction icons — 2026-09-09

- Refined dedicated vector icons for corner, center-point and aligned rectangles: corner handles, center crosshair/diagonals and a rotated baseline/right-angle marker distinguish construction methods. Midpoint lines, three-point circles and center/three-point arcs now use consistent highlighted defining points. Existing dropdown rendering uses each variant’s own SVG at 28px and theme-aware colors.
- Verification: 149 shared UI tests and 265 CAD tests pass; UI typecheck/build and CAD build pass. Browser connection discovery returned no connections; live light/dark dropdown visual verification remains outstanding.

## Nested imported DXF regions — 2026-09-09

- Core classifies disjoint closed imported contours by containment depth into solids, holes and nested islands. Touching/intersecting/ambiguous loops reject automatic classification; Detect nested holes can be disabled for manual import. Open/construction geometry is preserved.
- Kernel extrusion processes disjoint nested loops from outside inward so islands survive enclosing hole cuts. Source contours and native hole flags persist.
- Verification: 259 Core tests, 265 CAD tests, Core check and CAD build pass, including nested-circle extrusion retaining all three radial boundaries, native roundtrip and the import-panel override.
- Sketch fill compositing for arbitrarily ordered islands and live browser verification remain open. Classification does not resolve intersecting manufacturing regions.

## DXF connected contour joining — 2026-09-09

- DXF import now joins endpoint-connected open paths by default; the panel offers Join connected edges to preserve separate entities when desired. Source entity count remains unchanged while preview/native contour count reflects joining.
- Core `import/join-contours.ts` traces unambiguous chains/cycles, reverses native arc/ellipse/Bezier geometry correctly, preserves construction/hole groups, and stops at branch nodes. Default endpoint tolerance is 1e-7 mm; Core options can override it. Matched endpoint movement is bounded by that tolerance. Constrained drawings reject joining until reference remapping is available.
- Verification: 255 Core / 264 CAD tests, Core check/CAD build pass. Includes reversed/shuffled closed outlines, native curve reversal, branch handling, tolerance bounds, UI toggle/native save and actual extrusion of independently imported DXF lines with checked solid dimensions.
- Interior intersections, ambiguous branches, nested-hole classification and live browser acceptance remain incomplete; joining does not infer manufacturing regions automatically.

## DXF placement controls — 2026-09-09

- Import preview now supports X/Y in millimeters, rotation in degrees and positive uniform scale about the source origin. Place DXF on canvas follows pointer movement; clicking fixes the origin location without inserting, and Escape restores the starting location. Insert remains one undoable action.
- `sketch/dxf-placement.ts` owns fields and pointer interception. The import panel caches parsing across placement updates and reuses Core similarity transforms, preserving native circles/arcs/ellipses. Combined drawing validation runs before committing insertion.
- Verification: 263 CAD tests and CAD build pass; 99 focused editor tests pass after adding insertion validation. Covers translated/rotated/scaled previews, invalid scale, pointer placement/cancel, no accidental geometry creation, undo/redo and saved placement. Browser discovery returned no connections; actual browser pointer verification remains open.
- Custom source anchors, placement snapping/manipulators, geometry joining/hole classification and broader DXF/DWG support remain incomplete.

## DXF ellipses and legacy polylines — 2026-09-09

- Added full/trimmed rotated ELLIPSE entities using actual ellipse parameters and major-axis vectors; full ellipses become two native half-arcs. Added planar unfitted POLYLINE/VERTEX/SEQEND sequences through the shared bulge converter, including closed clockwise curves.
- Dedicated `ellipse.ts` and `polyline.ts` keep entity geometry and sequence parsing separate. Paper-space polyline sequences are skipped as a unit. Missing sequence ends, invalid ellipse ratios and unsupported fitted/3D geometry reject.
- Verification: 249 Core / 261 CAD tests, Core check/CAD build pass; five focused curve-import tests pass after adding paper-space regression coverage. Includes unit-scaled rotated arcs, full ellipses, sequence boundaries, native UI reopen and actual rotated-ellipse extrusion.
- Import still lacks blocks, splines, object-coordinate transforms, DWG/binary input, layers, automatic edge joining/hole classification and interactive placement. Imported full ellipses are native geometry without automatically added shape relations; those can be applied explicitly. Live browser acceptance remains outstanding.

## Initial ASCII DXF sketch import — 2026-09-09

- Sketch ribbon Import DXF opens a dedicated panel with file selection, automatic/explicit source units, canvas preview and insertion in one undo step. Imported geometry saves as editable native contours. Common INSUNITS scales are supported; unspecified units require selection.
- Core `sketch/import/dxf/` separates tags, section/units handling and exact primitive conversion. Supports XY model-space LINE, POINT, CIRCLE, ARC and LWPOLYLINE (signed bulges and closure). Unsupported model-space entities reject atomically; paper-space entities are excluded.
- Verification: 244 Core / 260 CAD tests, Core check/CAD build pass. Includes unit conversion, wrapped arcs, bulged closure, invalid/unsupported inputs, file read/units/preview/undo/native reopen, and actual extrusion with cylindrical topology.
- Binary DXF/DWG, blocks, legacy polylines, splines/ellipses, text/hatches, object-coordinate transforms, layers, edge joining/hole classification, interactive placement and live browser verification remain incomplete. Import is a supported subset, not full parity.

## Ellipse quadrant snapping and inference — 2026-09-09

- Geometry snapping now offers exact ellipse-axis endpoints with a Quadrant label. Full ellipses provide four candidates; trimmed elliptical arcs exclude endpoints outside their visible span. Quadrant labels win ties with generic endpoint labels.
- Newly authored vertices exactly at an existing ellipse quadrant gain a persisted relationship when geometry snapping is enabled, grouped with geometry creation in one undo transaction. Existing vertices are untouched and repeated inference does not duplicate their relationships. Numeric placement at the exact point also follows this inference rule.
- Core `operations/ellipse-snaps.ts` owns candidates and reference creation; CAD `sketch-snapping.ts` presents snap positions, with a small placement hook in the workspace. This does not implement all other inferred constraints or complete every alternate drawing gesture path.
- Verification: 240 Core / 258 CAD tests and Core check/CAD build pass; 95 focused editor tests pass after adding snapping-disabled coverage. Tests include finite-arc clipping, named snaps, relationship preservation/undo/native reopen and the geometry-snapping toggle. Live browser verification remains outstanding.

## Ellipse point and quadrant constraints — 2026-09-09

- Coincident accepts point/ellipse pairs in either order and constrains the point to the supporting ellipse. Added illustrated Quadrant command: chooses the nearest local-axis endpoint when applied, persists its 0–3 index, and retains that endpoint as geometry changes. New `quadrant` kind/field requires updated readers.
- `solver/ellipse-contact.ts` owns radial contact, endpoint evaluation and nearest-quadrant selection. Existing constraint controls handle creation and undo; full ellipse shape constraints remain active during solving.
- Verification: 238 Core / 256 CAD / 149 UI tests; Core/UI checks and CAD/UI builds pass. Covers rotated quadrants, point-on-ellipse solving, reversed entity order, missing-index rejection, editor apply/undo/redo and native reopen.
- Automatic quadrant inference/snapping during drawing, direct quadrant reassignment controls, ellipse topology remapping and live browser acceptance remain open. Ellipse equal/concentric extensions were considered but not implemented in this work unit; Quadrant is an explicit reference parity requirement.

## Full ellipse shape relationships — 2026-09-09

- Newly drawn full ellipses now save an `ellipse-shape` constraint connecting both native half-arcs. Matching radii/rotation and diameter endpoints retain one ellipse with five geometric freedoms. The relation can be removed and reapplied through the constraint panel's Full ellipse selection.
- Core `operations/ellipse-relations.ts` captures intent; `solver/ellipse-shape.ts` owns five shape equations. Supporting-ellipse resolution uses the shared shape parameters for constrained full ellipses, avoiding singular endpoint-to-center reconstruction inside symmetry solving. Existing unlinked ellipse files remain unchanged until explicitly constrained.
- Verification: 235 Core / 255 CAD tests, Core check/CAD build pass. Includes five-DOF diagnostics, unequal-shape symmetry, linked half geometry, repeated drawing, undo/redo, native reopen and real-kernel extrusion. Browser discovery again returned no connections.
- Ellipse topology remapping, parameter-edit controls, stricter diametric geometric error bounds and full live browser verification remain open. Splitting a shape-linked ellipse currently rejects rather than losing its relationship; removing the relation permits independent editing.

## Elliptical-arc symmetry — 2026-09-09

- Elliptical segments expose a supporting-ellipse entity in constraint selectors. Symmetry reflects centers and quadratic shape, independent of trim endpoints, principal-axis swaps and half-turn-equivalent rotations. The native entity reference vocabulary adds `ellipse` (updated readers required).
- Solver coordinates now include ellipse radii (positive logarithmic coordinates) and rotation (radians internally). These were previously counted by diagnostics but absent from solving. Geometry representation remains the existing endpoint-arc format.
- Verification: 232 Core / 254 CAD tests, Core check and CAD/Animation builds pass. Covers rotated and radius-swapped equivalent ellipses, unequal-radius solving, source immutability, UI selection/application and native reopen.
- Full ellipses currently consist of two arc segments without a shared shape relationship: symmetry here applies to the selected segment's locus. Shared half-ellipse shape constraints, diametric/singular endpoint robustness, ellipse trim/split relation remapping, spline symmetry and live browser verification remain open.

## Sketch symmetry — 2026-09-09

- Added illustrated Symmetric ribbon constraint and a line-only axis selector. Supports reflected point pairs, line supporting loci, and circle/circular-arc centers with equal radii. Finite line/arc endpoints remain independent, matching the reference's underlying-curve semantics.
- Core `solver/symmetric.ts` owns equations. The native constraint adds `axis: SketchEntityRef`; solver participation, deletion and split/trim/fillet reference remapping include it. Updated readers are required for the new kind/field.
- Verification: full Core suite (228 tests), six focused symmetry tests after adding arc coverage, CAD (253) and UI (149) suites pass; Core/UI checks and CAD/UI builds pass. Covers rotated-axis solving, locus semantics, zero/missing axes, axis deletion/index shifting/splitting, UI apply/undo/redo and native reopen. Live browser verification remains outstanding.
- Ellipse/spline symmetry, external plane/edge references, multi-pair viewport picking and full sketch parity remain incomplete.

## Open-chain Slot — 2026-09-09

- Slot selection now includes open line/circular-arc chains. Envelopes use exact offset sides, rounded convex joins, intersected concave joins and semicircular end caps. Selected source chains become construction geometry; saved whole-contour relationships retain shared width and the width handle.
- Geometry lives in Core `curves/slot-chain.ts`; smooth-chain solver equations live in `solver/slot-chain.ts`. Tangent/collinear joins retain smoothness through locus equations, avoiding microscopic arcs during finite differences. CAD selection stays in `sketch/slot-panel.ts`.
- Verification: 223 Core / 252 CAD tests, Core check and CAD build pass. Covers sharp/tangent/collinear chains, width edits, invalid/overlapping input, editor preview/undo/native reopen and exact-kernel extrusion of a saved chain slot.
- Closed/spline slots, corner-topology changes/remapping, automatic overlap repair and full live browser acceptance remain open. Existing smooth joins remain smooth; changing a rounded join into a straight join requires topology work still outstanding.

## Sketch dropdown icon clarity — 2026-09-09

- Rectangle artwork now emphasizes a corner anchor, center crosshair, or tilted alignment edge respectively. Shared illustrated dropdown icons render at 28px in 36px rows in both themes, preserving each variant's own SVG and selected-tool behavior.
- UI tests/typecheck/build and CAD tests/build pass. Browser discovery returned no connections; live visual acceptance remains outstanding.

## Slot width handle and capture cleanup — 2026-09-09

- Slot preview now has an on-canvas width handle with keyboard adjustment. Width is the full diameter: handle displacement is half the width, measured normal to the centerline from either side. Cancellation restores the starting width; Apply creates one undo transaction.
- Core `operations/slot-handle.ts` owns projection; CAD `slot-manipulator.ts` adapts the shared dimension manipulator. Shared handle cleanup releases pointer capture on cancellation/tool switches and clears stale click suppression on fresh pointer gestures.
- Verification: 217 Core / 251 CAD tests, Core check/CAD build pass. Includes line/arc projection, diameter semantics, drag/cancel/keyboard/apply/undo, and capture release during tool changes. Browser discovery returned no connections; live pointer capture remains unverified. Chain/closed/spline slot variants remain open.

## Line and circular-arc Slot — 2026-09-09

- Added illustrated Slot tool with centerline click/list selection, live preview, numeric width, Enter/apply/cancel and undo. Individual line/arc slots retain exact sides and semicircular caps. Batch slots share an editable width driver and follow source changes; standalone centerlines become construction geometry for extrusion.
- Core geometry, operation and solver modules are separate; CAD owns `sketch/slot-panel.ts`. Native sketches save the new `slot` constraint kind with width as diameter in millimeters; updated readers are required. Oversized/collapsed arcs and overlapping major-arc end caps reject.
- Verification: 215 Core / 249 CAD / 149 UI tests; Core/UI checks, CAD/UI/Animation builds pass. Covers shared width/source edits, DOF, invalid-input immutability, native editor reopening and a saved slot extruded through the real kernel.
- Multi-curve/closed-profile/spline slots, width manipulators, sequential application semantics, topology repair and live browser acceptance remain incomplete.

## Mixed line/arc offset relationships — 2026-09-09

- Mixed line/circular-arc contours now retain shared signed offset relations. Dedicated `solver/offset-mixed.ts` constrains oriented line loci, arc centers/signed radii and open-end parameters. Shared vertices form joins; the solver does not repeatedly intersect tangent carriers during finite differences.
- Verification: 210 Core / 248 CAD tests, Core check/CAD build pass. Includes tangent capsule distance/source-growth edits, non-tangent joins, collapse rejection without mutation, and persisted editor distance changes. Tests compare offset geometry to the solved source, within solver residual tolerance.
- Near-singular tangent/diametric configurations still need improved DOF diagnostics and geometric error bounds: small residuals do not guarantee equally small derived center/vertex errors. Topology repair, split/trim remapping, branch robustness and live browser acceptance remain open; full Offset parity is not claimed.

## Mixed line/arc offset geometry — 2026-09-09

- Whole connected line/circular-arc profiles now offset using exact line/circle carriers. Tangent joins remain connected; supported non-tangent joins use nearest carrier intersections. Native arcs are preserved. Collapsed edges/arcs, disjoint joins requiring topology changes and detected self-intersections reject.
- Dedicated `curves/offset-carriers.ts` and `offset-mixed.ts` own intersections and assembly. Mixed-profile copies are currently independent: associative mixed joins, topology repair and spline/ellipse offsets remain incomplete. The UI states this limit.
- Verification: 206 Core / 247 CAD tests, Core check/CAD build pass. Includes signed closed capsule offsets, line-circle and circle-circle joins, invalid joins, source immutability, whole mixed-contour preview and native reopen. Live browser acceptance remains outstanding.

## Individual-edge Offset selection — 2026-09-09

- Offset supports whole contours or individual lines/circular arcs/circles. Clicking a curve enters edge selection and toggles it; selected edges share a distance while retaining original segment references. Only those edges are copied, and source edits update their offsets.
- Offset controls, selection, preview, handle and commit lifecycle now live in dedicated `sketch/offset-panel.ts`. General modification routing delegates to it. Core `operations/offset-entities.ts` reuses exact geometry and a shared relation constructor.
- Verification: 201 Core / 246 CAD tests, Core check/CAD build pass. Includes segment provenance, duplicate selection, invalid batches, source edits, click/toggle/native reopen, and existing contour/handle/fillet regressions. Test button queries now exclude hidden panels, matching visible interaction after extraction. General curved offsets, topology remapping and live browser acceptance remain open.

## Offset distance handle — 2026-09-09

- Offset preview now has a draggable signed-distance handle. Dragging projects onto the source normal; tangential motion does not change distance. Cancelling a drag restores its starting distance without committing geometry. Flip direction negates the numeric value; Enter in the distance field applies a valid preview. Arrow keys adjust the focused handle.
- Shared `dimension-manipulator.ts` is now generic over handle/value behavior. Fillet keeps its existing radius semantics; offset presentation lives in `offset-manipulator.ts`, with geometric projection in Core `operations/offset-handle.ts`.
- Verification: 198 Core / 245 CAD tests, Core check/CAD build pass. Includes signed projection for all supported offset types, linked dimensions, drag/cancel/flip/Enter/native persistence and existing fillet regression tests. Browser discovery returned no connections; live pointer-capture verification remains outstanding.

## Associative line-chain offsets — 2026-09-09

- Open and closed line-chain offsets now retain whole-contour correspondence, following joined corners, open ends and intermediate collinear vertices through source and distance edits. They participate in shared batch distance links and DOF diagnostics.
- Added persisted `contour` entity reference for this relationship; updated readers are required. Exact offset geometry moved to `sketch/curves/offset.ts` for reuse by creation and solver residuals. Operation orchestration and relation creation remain separate.
- Splitting/trimming a linked chain currently rejects until topology remapping is implemented; deleting a whole source contour removes its relationship normally. Mixed/spline/ellipse offsets, topology remapping, individual-edge selection, manipulators and live browser acceptance remain open.
- Verification: 193 Core / 244 CAD tests, Core check and CAD/Animation builds pass. Includes source resize, open/closed/collinear geometry, fully constrained DOF, collapse rejection, topology guards/deletion, native reopen and editor distance changes.

## Persistent circular arc offsets — 2026-09-09

- Individual circular arc offsets now save offset relations preserving center, start angle, signed sweep and radial separation. Clockwise/counterclockwise arcs follow source radius and signed distance edits. Five independent geometric equations avoid adding a redundant through-point constraint.
- Offset default selection excludes construction geometry and empty point contours, so center-point arcs can offset immediately. Construction curves remain explicitly selectable.
- Verification: 189 Core / 243 CAD tests, Core check/CAD build pass. Source/follower changes, direction signs, DOF classification, collapse rejection, native edit/reopen and center-arc selection covered. Multi-edge association, general curve offsets, manipulators and live browser remain incomplete.

## Persistent circle and line offsets — 2026-09-09

- Circle and single-line Offset creation now saves ordinary `offset` constraints and links a batch to one editable signed distance. Circle relations retain center and radius difference; line relations retain endpoint correspondence, direction and length. Source/follower edits solve together. Removing a shared driver materializes remaining follower values.
- Geometry, relation creation and residual math remain separate in `operations/offset.ts`, `operations/offset-relations.ts` and `solver/offset.ts`. New saved `offset` kind requires updated readers. Arc/polyline offsets remain independent; their association is still required for parity.
- Verification: 185 Core / 241 CAD tests, Core check and CAD build pass. Covers source resize/rotation, shared signed distance edits, collapsed radius rejection without mutation, driver removal, native reopen and editor distance updates. Live browser acceptance remains outstanding.

## Initial exact sketch Offset — 2026-09-09

- Offset ribbon command now opens signed distance controls and contour selection with transient preview, cancel, undo/redo and native persistence. Core `operations/offset.ts` owns exact circle, individual circular arc and mitered line-chain geometry. Positive means left of directed paths and outward for circles. Invalid selections, collapsed radii/edges, reversing corners and transverse self-intersections reject atomically.
- Offset geometry is currently independent. Associative source updates, mixed curve chains, spline/ellipse offsets, full topology cleanup, individual-edge selection, drag manipulator and shared distance constraints remain required for parity. Unsupported curves reject explicitly.
- Fixed modification Apply/Cancel leaving the ribbon tool active; finishing now returns to Select so the tool can reopen on the next click.
- Verification: 182 Core / 240 CAD tests, Core check and CAD build pass. Tests cover exact radii, open/closed chain offsets, sign reversal, conflict rejection, previews, cancel/reopen, undo/redo and native save/reopen. Live browser remains outstanding.

## Normal sketch constraint — 2026-09-09

- Added persisted `normal` constraint, illustrated ribbon icon and editor controls. A line normal to a circle/arc locus passes through its center. A line normal to a finite curve contact passes through that point perpendicular to its tangent. Both selection orders work; zero-length lines, stationary contacts and incompatible targets reject.
- Equations live in Core `solver/normal.ts`; UI contains no duplicate geometric logic. The saved constraint kind requires an updated reader. Curve-to-plane Normal and free sliding curve contact selection remain incomplete.
- Verification: 176 Core / 239 CAD / 149 UI tests; Core/UI type checks and CAD/UI/Animation builds pass. Includes fixed-geometry conflict immutability, finite cubic contact, selection order, apply/undo/redo and native reopen. Browser discovery still returns no connections; live acceptance remains outstanding.

## Finite-contact curvature continuity — 2026-09-09

- Curvature constraint is available in the sketch ribbon and constraint panel. Two finite segment contacts enforce coincident position, parallel tangent directions and matching signed curvature. Reversed parameter direction is handled. Math lives in the focused Core `solver/curve-continuity.ts`, shared with finite tangency.
- Native sketches persist the new `curvature` constraint kind; readers need this updated constraint vocabulary. Endpoint UI supports line/arc/ellipse/Bézier contacts, not circle-locus selections or freely sliding contacts. Stationary points and incompatible selections reject.
- Verification: 171 Core / 238 CAD tests, Core check and CAD build pass. Tests cover nonzero curvature, line joins, reversed parameter speed, fixed-geometry conflicts without mutation, DOF rank, editor apply/undo/redo and native reopen. Shared UI's 149 tests and UI/Animation builds passed with the new icon in the preceding artwork verification. Live browser remains unverified.

## Rectangle dropdown icon clarity — 2026-09-09

- Shared rectangle SVGs now distinguish corner placement with two orange square handles, center placement with a larger crosshair, and aligned placement with a rotated rectangular outline, highlighted baseline and three handles. Existing dropdown and selected-tool rendering share these assets and light/dark palette tokens.
- Verification: 149 shared UI tests, UI typecheck/build, CAD build and Animation build pass. Browser discovery returned no connections, so live dropdown verification remains outstanding. No solver behavior changed in this artwork task.

## Radius entry in document units — 2026-09-09

- Immediate radius entry follows document length units using the shared unit catalog and stores canonical millimeters. Switching units converts the pending numeric value without changing geometry; closing the sketch removes the preference subscription.
- Verification: 237 CAD tests and CAD typecheck/build pass. Tests cover in/cm/m/ft, native persistence and conversion of an unsubmitted value. Expressions/variables and live browser verification remain incomplete.

## Immediate curve radius entry — 2026-09-09

- Newly created circles and arcs offer inline radius entry in millimeters. Typing from the canvas focuses the field; Enter or Set radius creates a saved driving constraint. Focus returns to the canvas. Target state clears when starting another tool/gesture or undoing.
- Dedicated Core set-radius operation reuses existing/linked drivers; CAD recent-radius module owns presentation. Invalid values and solver conflicts preserve the original geometry.
- Verification: 165 Core / 232 CAD tests, Core check and CAD build pass. All current circle/arc creation tools, keyboard input, undo/native reopen, driver reuse and conflict rejection are covered. Expressions/variables, document-unit entry and live browser remain incomplete.

## Three-point arc chord drag — 2026-09-09

- Drag/release sets a three-point arc's endpoints; the next click sets curvature and commits one undo transaction. Open-path continuation, cancellation and ordinary three-click placement are preserved.
- Tangent and three-point arcs share `sketch/endpoint-drag-gesture.ts` (renamed from tangent-arc-gesture); chord staging lives in `arc-chord-tool.ts`.
- Verification: 226 CAD tests and CAD typecheck/build pass, including delayed commit, preview, undo/native reopen, closing a continued path and pointer cancellation. Live browser verification remains outstanding.

## Endpoint-first three-point arcs — 2026-09-09

- “3 point arc” now takes start/end before the curvature point. Preview bends around a fixed chord; open-path continuation and closure work with this order. Coincident endpoints and collinear curvature reject without committing geometry. Native arc storage is unchanged.
- Verification: 223 CAD tests and CAD typecheck/build pass, including both preview directions, closing a line with an arc, invalid-input recovery and undo/native reopen. Browser discovery returned no connections; live verification remains outstanding.

## Tangent arc drag placement — 2026-09-09

- Tangent arcs support click-drag-release as well as two-click placement. Preview stays transient; valid release commits one undo transaction. Escape, tool/history changes, pointer cancellation and lost capture cancel without changing geometry.
- Pointer gesture handling lives in `sketch/tangent-arc-gesture.ts`; geometry remains in the existing Core operation.
- Verification: 220 CAD tests and CAD typecheck/build pass. Mounted tests cover release, native save, synthetic-click suppression, undo/redo, cancellation, invalid releases and two-click compatibility. Live browser pointer capture remains unverified.

## Tangent arc tool — 2026-09-09

- Arc dropdown includes Tangent arc with dedicated illustrated SVG. Two-click placement starts at an existing curve endpoint, previews an exact arc and persists tangency. Compatible open path ends append directly; other endpoints create constrained branches. Straight-line targets reject.
- Core geometry/constraint operation and CAD gesture module are separate. Extracted sketch history retains active-path context through undo/redo, allowing Line → Tangent arc → Line closed profiles without losing continuation.
- Verification: 160 Core / 216 CAD / 149 UI tests; Core/UI checks and CAD/UI/Animation builds pass. Mounted tests cover dropdown action, preview, undo/redo continuation and native reopen; kernel test extrudes the saved profile. Live browser, drag-release gesture, automatic switching, immediate radius entry and branch joining remain incomplete.

## Persistent center-point arcs — 2026-09-09

- Center-point arc creation now retains a selectable construction center tied to the analytic arc through a concentric constraint. Fixing it preserves the center through endpoint or radius edits; it introduces no extra geometric freedom.
- Dedicated Core `sketch/operations/arc-center.ts`, called by CAD placement. Existing saved arcs remain unchanged.
- Verification: 155 Core / 213 CAD tests, Core check and CAD build pass, including center/endpoint dragging, radius edits, undo/native reopen and extrusion excluding the construction point. Other arc variants and live browser acceptance remain incomplete.

## Persistent three-point circles — 2026-09-09

- Three-point circle placement retains all three clicks as selectable construction points with persisted point-on-circle constraints. Fixing two permits editing through the third; fixing all three fully defines the geometry.
- Coincident point/curve picking now prioritizes the point, so placement handles remain selectable even when their parent circle comes first in the document. Core circle-points module owns placement relationships; CAD delegates.
- Verification: 151 Core / 212 CAD tests, Core check and CAD build pass. Tests include expected analytic circle after dragging, full definition/conflict handling, invalid placement rejection, undo/native reopen and extrusion excluding construction points. Live browser verification remains outstanding.

## Persistent midpoint lines — 2026-09-09

- Midpoint-line placement retains the first click as a selectable construction point tied to the edge by a persisted midpoint constraint. Dragging it translates the line; a fixed midpoint produces symmetric endpoint edits. Direction and length constraints can fully define the line.
- Dedicated Core `sketch/operations/line-midpoint.ts` module, called by CAD placement; old saved free lines remain unchanged.
- Verification: 147 Core / 210 CAD tests pass; Core check and CAD build pass. Tests cover midpoint/endpoint dragging, full definition, dimension edits, invalid-edge rejection, undo/redo and native save/reopen. Live browser verification remains outstanding.

## Persistent polygon relationships — 2026-09-09

- New inscribed/circumscribed polygons retain equal sides and regular angles during constrained vertex dragging. Selectable construction sizing circles support center and radius constraints; circumscribed polygons retain the inner sizing circle as well as the circumcircle needed for regularity. Existing saved free paths are unchanged.
- Dedicated Core polygon-relations module owns the canonical constraints. Solver constraint capacity is now 512, covering the existing 100-side tool; 512-coordinate solve and 256-coordinate diagnostic limits remain.
- Verification: 143 Core / 209 CAD tests, Core check and CAD build pass. Coverage includes 3–6-sided edits, circle sizing, 100-sided radius editing, undo/native persistence and exact extrusion excluding construction entities. Live browser verification and post-creation side-count editing remain open.

## Persistent rectangle relationships — 2026-09-09

- New corner/center rectangles preserve H/V edges; aligned rectangles preserve parallel opposite edges and right angles while allowing rotation. Center rectangles include a selectable construction center tied to a diagonal, so fixing the center makes resizing symmetric. Old free paths remain unchanged.
- Dedicated Core rectangle-relations module owns the constraints; CAD placement delegates to it. Constraint diagnostics report four free coordinates for axis rectangles and five for aligned rectangles, with two for a fixed-center rectangle.
- Verification: 137 Core / 208 CAD tests pass, Core check and CAD build pass. Tests include constrained dragging, atomic rejection, undo/redo/native reopen and exact extrusion with construction geometry. Browser discovery returned no connected browsers; live acceptance remains outstanding.

## Dropdown icon legibility — 2026-09-09

Illustrated tool menus now reserve a 24px icon column and explicitly size their SVGs to fit (previously 32px artwork overflowed an 18px column). Rectangle artwork emphasizes opposite corner handles, a center target with diagonals, and rotated edges with three placement points. Shared theme palette variables support light/dark surfaces. Verification: 207 CAD and 149 shared UI tests pass, including mounted variant menu coverage; UI typecheck and UI/CAD builds pass. Live browser visual verification remains outstanding.

## Sketch selection, constraint state and variant icons — 2026-09-09

- Active-tool clicks and Escape return to Select. Existing vertices/edges highlight; blank clicks deselect. Mouse dragging uses constrained Core edits and one undo step, rejecting conflicting moves. Bézier/ellipse curves are also pickable. Multi/window selection remains incomplete.
- Added visible whole-sketch under/fully/over-constrained state and local geometric degrees of freedom, plus redundancy/conflict reporting. Canonical arc coordinates avoid counting its arbitrary through-point as an extra freedom. Numerical analysis is capped at 256 coordinates and does not prove global uniqueness; per-entity coloring/singular cases remain work.
- Variant dropdowns now render distinct shared SVG artwork for rectangle variants, midpoint lines, center arcs, three-point circles, ellipses and circumscribed polygons; existing palette and original app marks preserved.
- Verification: 133 Core / 207 CAD / 149 shared UI tests pass; Core/UI typechecks and CAD/UI/Animation builds pass. Mounted tests cover Escape/tool toggle, deselection, edge drag undo/persistence, fully constrained circle and menu artwork. No live browser verification claimed.
- In-flight chamfer direct-edit support was preserved: tested Core bevel recognition/edit/handle projection and shared manipulator extraction landed, but dedicated chamfer handle UI remains unfinished while these user-requested interaction fixes took priority.

## Linked chamfer vertex batches — 2026-09-09

- Multiple picked straight corners now share driving chamfer dimensions across contours. Equal-distance batches keep one numeric setback, two-distance batches keep two, and angle batches retain the opposite turn of mirrored corners through signed angular links.
- Added angular `valueSign` to the existing driver-link contract, with sign-aware follower editing and driver removal. Signed links require an updated client; older clients ignoring this field cannot interpret them correctly. Geometry and batch semantics remain in dedicated Core modules.
- Verification: 127 Core / 203 CAD tests pass; Core check and CAD build pass. Tests cover opposite-turn angle solving/editing/removal, shared equal/two-distance batches, invalid atomic batches and mounted multi-corner native persistence. Edge-pair batches, dedicated reopened chamfer controls/handles and live browser verification remain unfinished.

## Two-edge sketch chamfers — 2026-09-09

- Chamfer now accepts two connected lines or two separately drawn single-line contours, including disjoint/crossing lines resolved at a virtual intersection. Picked sides are retained. Asymmetric distance and angle values follow the first selected line independent of path order.
- Extracted shared line-corner selection/reference mapping from fillets; fillet and chamfer wrappers use one implementation. Existing unrelated references remap when contours merge; unsupported constrained cases still reject rather than silently losing relationships.
- Verification: 124 Core / 202 CAD tests pass, Core check and CAD production build pass. Tests cover virtual intersections, first-selected direction/dimensions, unrelated references and mounted two-line preview/Apply/native reopen. Separate multi-segment joins, linked chamfer batches, dedicated handles and live browser verification remain open.

## Persistent linked sketch dimensions — 2026-09-09

- Equal-distance chamfers now store a single driving setback plus a `valueFrom` link. Editing a follower changes its driver and solves all linked dimensions. The constraint list displays effective values, marks links and offers Update; direct removal, contour deletion and Trim preserve dependent values when removing a driver.
- The saved contract is literal `value` or driver-ID `valueFrom`, mutually exclusive. Missing drivers, cycles and incompatible angular/length units reject. Older clients lacking this contract cannot solve these new constraints.
- Verification: 121 Core / 201 CAD tests pass; Core check and CAD production build pass. Tests cover follower editing after reopen, missing/cyclic/conflicting/unit-invalid links, constraint/contour/Trim removal and mounted equal-chamfer editing/native persistence. Chamfer batches, two-edge picking and dedicated drag controls remain open; no live browser verification claimed.

## Sketch chamfer authoring — 2026-09-09

- Added illustrated Sketch ribbon Chamfer with a dedicated control module, vertex selection, equal/two-distance and distance-angle variants, in-workspace preview, invalid-size feedback and atomic Apply/undo/native persistence. Geometry uses the shared corner-break/virtual-sharp remapping extracted from fillets.
- Angle and setback dimensions persist; original line-length references retain the virtual corner. Equal-distance creation currently stores two numeric setbacks rather than a persistent link. Two-edge selection, linked batches, reopened chamfer controls and drag handles remain unfinished.
- Verification: 117 Core / 200 CAD tests pass; Core check and CAD build pass. Tests include asymmetric geometry, angle-driven solve after reopen, closed seams, invalid input/cancel, mounted preview/Apply/undo/native save and reopened OCCT solid extrusion. Live browser verification remains outstanding.

## Curved fillet batches and radius editing — 2026-09-09

- Mixed straight/curved corner selections share one driving radius. Rounding both ends of a curve preserves existing endpoint tangent contacts by reparameterizing them into the retained interval. Removed contacts still reject atomically.
- Reopened curved fillets resolve their shared dimension and show a center-based radius handle; the existing numeric/drag editing flow works through persisted constraints. Underconstrained source curves can deform: original-curve design-intent preservation remains incomplete.
- Verification: 113 Core / 198 CAD tests pass, Core check and CAD production build pass. Tests cover mixed batches, finite contact retention, native reopen, shared-radius changes and visible handle. Browser connection retried using the documented runtime; no browser is available, so live visual verification remains outstanding.

## Connected curved fillets — 2026-09-09

- Adjacent curves in a connected path now support exact fillets without replacing surrounding segments. Closed seams remain closed; retained-side picks disambiguate two-edge loop corners. Picking a curved vertex in the app selects the pair directly.
- Shared finite-tangent/radius generation has its own module. Untouched endpoint/segment references shift with topology, arc-locus constraints survive; removed corner and changed control references reject atomically pending virtual-sharp remapping.
- Verification: 112 Core / 197 CAD tests pass; Core typecheck and CAD production build pass. A reopened closed line/Bezier profile extrudes through OCCT with a cylindrical fillet face. DOM tests cover picked-corner preview, Apply and native persistence. Separate multi-segment path joining, curved-corner batches/virtual sharps, radius design-intent preservation and live browser verification remain incomplete.

## Curved fillet authoring — 2026-09-09

- The Fillet tool now picks independently drawn finite curved segments, previews exact retained pieces and commits a circular bridge with persistent radius and two finite tangent constraints. Existing straight-line corner/batch behavior remains in its dedicated operation.
- Core remaps unchanged outer endpoints and circular-locus references, rejects unsupported trimmed references atomically, and checks all constraints before commit. Line/Bezier radius edits solve persisted constraints; unconstrained source curves can deform, so full design-intent preservation is still incomplete.
- Verification: 107 Core / 196 CAD tests pass; Core check and CAD production build pass. Tests cover reversed selections, arc radius preservation, rejected degenerate joins, preview/Apply/undo/redo/native reopen. Connected curved corners, longer paths, dedicated curved radius handles, and live browser verification remain outstanding.

## Persistent finite curve tangency — 2026-09-09

- Added curve references with a fixed finite parameter. Tangent between two such references constrains contact position and parallel exact derivatives. The constraint panel exposes segment start/end tangent references, including Beziers and ellipses. Invalid parameters and stationary points reject.
- Saved references include `kind: curve`, segment index and `parameter`; existing clients lacking that contract need updating. Trim remapping preserves parameter metadata for unchanged segments. Legacy circle/arc-locus tangency is unchanged; sliding contact parameters and broader diagnostics remain incomplete.
- Verification: 102 Core / 195 CAD tests pass; Core check and CAD build pass. Tests cover line/Bezier solving, fixed endpoints, degenerate references, unrelated Trim remapping and mounted constraint authoring/native reopen. Curved fillet operation integration and browser verification remain outstanding.

## Curved fillet Core groundwork — 2026-09-09

- Added exact curve derivative evaluators and a bounded normal-offset tangent-circle search. Exact subdivision/reversal constructs retained portions and a circular bridge, checking tangent direction at both joins.
- This is Core-only groundwork: persistent generic curve tangency/reference remapping and application UI integration remain unfinished. Numerical search does not establish exhaustive coverage of singular offsets or retracing curves.
- Verification: 99 Core tests and Core typecheck pass. New cases check line/arc, line/Bezier and arc/arc radius/orthogonality plus an exact line/Bezier bridge. CAD tests/build were not rerun for these unconnected internal modules; no new application behavior or live browser verification claimed.

## Existing fillet radius editing — 2026-09-09

- Pick a saved fillet arc while Fillet is active to edit its existing driving radius. Equal-radius links resolve any arc in a shared batch to the same dimension. Numeric input and the on-canvas handle update the preview; Apply commits the solved geometry without adding another fillet.
- Core `fillet-radius-edit.ts` owns link traversal and dimension solving. The modification panel owns edit selection. Broader finite-contact/inequality diagnostics remain separate solver work.
- Verification: 96 Core / 194 CAD tests pass; Core check and CAD build pass. Tests cover either batch arc resolving to one driver, shared radius updates, invalid values, and reopen/pick/edit/save with the original dimension retained. Live browser verification outstanding.

## Fillet preview radius handle — 2026-09-09

- Fillet preview displays an on-canvas radius handle. Dragging projects from the virtual sharp, updates the numeric radius and rebuilds the preview; Apply remains the only document commit. Pointer cancellation/lost capture/Escape restore the initial radius. Arrow keys adjust the handle radius.
- Core `fillet-handle.ts` owns geometric projection; UI `fillet-manipulator.ts` owns pointer/keyboard/display state. This handle currently operates in the creation preview; existing-fillets direct handle editing remains incomplete.
- Verification: 95 Core / 193 CAD tests pass; Core check and CAD build pass. Tests cover radius projection and mounted drag/cancel/no-document-mutation. Existing fillet workflows/native tests remain passing. Live browser verification outstanding.

## Virtual-intersection line fillets — 2026-09-09

- Two selected single lines can now be disconnected or cross internally. The operation extends/trims to their virtual intersection and retains the side indicated by each pick before creating the tangent fillet. Parallel lines reject.
- Endpoint moves are checked against existing constraints before joining; fixed-endpoint conflicts reject atomically. Separate multi-segment paths, arc/spline pairs and richer reversal-sensitive constraint remapping remain incomplete.
- Verification: 94 Core / 192 CAD tests pass; Core check and CAD build pass. Tests cover disconnected lines, picked crossing quadrants, fixed-endpoint conflicts and mounted two-line/native persistence. Live browser verification outstanding.

## Two-line sketch fillet selection — 2026-09-09

- Fillet accepts two picked straight lines. Adjacent segments reuse their existing corner; separate single-line contours sharing an endpoint join into a line/arc/line contour with remapped endpoint/line references and a virtual sharp.
- `operations/fillet-lines.ts` owns joining/remapping; the modification panel owns first/second selection and preview. Disconnected lines, separate multi-segment paths, arc/spline pairs and direction-sensitive constraints requiring reversal remapping remain incomplete.
- Verification: 92 Core / 191 CAD tests pass; Core check and CAD build pass. Tests cover reversed standalone line orientation, corner references, adjacent selection, duplicate-selection rejection and mounted two-pick/native persistence. Live browser verification outstanding.

## Shared-radius fillet batches — 2026-09-09

- Select multiple straight-line corners in the Fillet panel and preview/apply them together. Core applies original corner indices in descending order, deduplicates selections, and persists one driving radius plus equal-radius relations for the other arcs. Invalid batches leave the source unchanged.
- `operations/fillet-batch.ts` owns orchestration and shared-radius semantics; the existing single-corner operation owns exact geometry. Arc/spline/two-curve fillets and drag manipulators remain incomplete.
- Verification: 90 Core / 190 CAD tests pass; Core check and CAD build pass. Solver test edits the batch radius and checks both fillets; DOM/native test selects two corners and saves one driving radius. Live browser verification outstanding.

## Connected-line sketch fillet — 2026-09-09

- Ribbon Fillet opens in-workspace radius controls. Click a shared straight-line corner or select contour/vertex numerically, preview the exact tangent arc and apply with undo/redo. Excessive or degenerate radii reject without edits; closed-seam corners remain closed.
- Core `operations/fillet.ts` persists radius/tangency constraints and an original-corner construction point. Original vertex references map to that virtual sharp; original line lengths become distances to it. Unsupported finite relations reject. Arc/spline/two-curve selection, shared-radius batches and drag manipulators remain incomplete relative to the official sketch fillet reference.
- Verification: 88 Core / 189 CAD tests pass; Core check and CAD production build pass. Tests cover radius editing, virtual-sharp references/dimensions, closed seams, invalid radius, workspace preview/undo/native reopen, and OCCT extrusion with the expected cylindrical face. Live browser verification outstanding.

## Cubic overlap intervals — 2026-09-09

- Duplicate/reversed cubic Beziers and shared affine subintervals now return finite overlap endpoints. Candidate intervals are verified using exact reparameterized control polygons; curves sharing endpoints but different controls are not classified as overlaps. Trim retains exact cubic remnants.
- Dedicated `curves/cubic-overlap.ts` keeps recognition separate from general intersection/root isolation. Degenerate retracing or non-affine parameter equivalence remains unresolved; bounded intersection fallback can still reject those cases.
- Verification: 84 Core / 188 CAD tests pass; Core check and CAD build pass. Tests cover contained subcurves, reversal, distinct curves with common endpoints, and actual overlap Trim remnants. Live browser verification outstanding.

## Finite overlap Trim boundaries — 2026-09-09

- Coincident straight segments and conic arcs now return overlap endpoints instead of rejecting. Trim uses those endpoints as interval boundaries. Duplicate circles do not introduce false boundaries at their internal half-circle seams; arc targets similarly ignore seams from an identical supporting full circle.
- Near-equal curve picking distances use stable contour order, preventing numerical noise from changing the selected overlapping curve. This is deterministic selection, not a completed overlap-selection cycling UI.
- Verification: 81 Core / 188 CAD tests pass; Core check and CAD build pass. Tests cover collinear Trim, circular overlap Trim, ellipse endpoints, reversed lines and duplicate circles. General cubic overlaps and live browser verification remain incomplete.

## Point sweep Trim — 2026-09-09

- Drag Trim now removes standalone sketch points within a six-screen-pixel stroke tolerance, accounting for the canvas transform/zoom. Point deletion removes attached constraints and remaps surviving references through the shared deletion operation; the gesture remains one undo transaction.
- Core validates finite stroke coordinates/tolerance and handles point hits separately from exact curve crossings. Coincident curve overlap handling and live browser verification remain incomplete.
- Verification: 77 Core / 188 CAD tests pass; Core check and CAD build pass. Tests cover near-point hits, out-of-range points, surviving constraint remapping, invalid input, and mounted gesture undo.

## Drag Trim gesture — 2026-09-09

- Drag across sketch curves to trim all crossed intervals. Core intersects each stroke segment with exact curves, so sparse pointer events do not skip intervening curves. The entire gesture commits as one undo step; Escape, pointer cancellation and lost capture restore the original drawing.
- Dedicated `trim-gesture.ts` handles capture/threshold/transaction behavior. `trim-sweep.ts` owns geometry and reuses ordinary Trim. Click Trim remains available. Standalone point sweep and coincident-overlap cases remain incomplete.
- Verification: 76 Core / 187 CAD tests pass; Core check and CAD build pass. Tests cover sparse crossings, a twice-crossed circle, multi-line gesture undo/redo and cancellation. Live browser verification outstanding.

## Trim fragment relation preservation — 2026-09-09

- Partial arc remnants retain supporting-circle relations (radius, concentricity, equal radius and locus tangency). Separated remnants receive concentric/equal links. Partial lines retain direction/locus relations; parallel plus point-on-line links preserve collinearity across separated remnants.
- Finite length/midpoint and curve-control relations attached to changed geometry remain removed and reported. General curve constraints and finite-contact semantics remain parity work.
- Verification: 74 Core / 185 CAD tests pass; Core check and CAD build pass. Solver tests change an arc radius and verify both remnant circles; line tests verify retained horizontal and generated collinearity relations. Workspace native round-trip retains arc links. Live browser verification outstanding.

## Path Trim reference remapping — 2026-09-09

- Path Trim retains constraints on surviving original vertices and whole segments, remapping indices when contours split or reorder. Explicit segment provenance replaces blanket rejection of constrained paths. Closed-seam aliases and shifted later contours are handled by the helper.
- Constraints attached to changed/removed entities are removed, with a status count and undo restoration. Supporting-locus constraints on partially retained path segments still need richer preservation; this checkpoint does not claim that work is complete.
- Verification: 72 Core / 184 CAD tests pass; Core check and CAD build pass. Tests cover surviving endpoints, unchanged segment constraints, later contour shifts and constraint removal/undo through the workspace. Live browser verification outstanding.

## Circle Trim relation preservation — 2026-09-09

- Circle Trim maps radius and other circular references to the remaining arc. Referenced centers become linked construction points, preserving fixed-center constraints and later radius edits. Whole-circle deletion still removes its relationships through the existing deletion operation.
- Trim and Split now share `operations/circle-references.ts`, eliminating duplicate center/reference conversion. Path-contour Trim constraint remapping remains incomplete.
- Verification: 71 Core / 183 CAD tests pass; Core typecheck and CAD build pass. Tests cover a trimmed fixed-center circle followed by radius editing, existing circle-split behavior, and workspace native save/reopen. Live browser verification outstanding.

## Line Split relation preservation — 2026-09-09

- Splitting a line preserves direction/locus relations and adds parallelism between the two segments sharing the split endpoint. A retained length dimension becomes distance between the original outer endpoints, keeping its ID and value. Solver verification checks a subsequent overall-length edit with a fixed start and horizontal direction.
- Uses the existing focused split-relations module. Equal-length relationships to other finite segments, midpoint remapping, cubic controls and orientation/interval inequality constraints remain open; the current solver does not constrain the split point to remain between outer endpoints under arbitrary later edits.
- Verification: 70 Core / 182 CAD tests pass; Core check and CAD build pass. Workspace save/reopen preserves the outer-endpoint dimension and parallel relation. Live browser verification outstanding.

## Arc Split relation preservation — 2026-09-09

- Splitting a circular arc now retains radius, concentricity, equal-radius and supporting-circle tangency references. Generated concentric/equal relations keep both resulting arcs on one circle during later radius edits. Surviving endpoint references remap to their new indices.
- Relation classification and generated links live in a focused `operations/split-relations.ts` module. Finite-arc midpoint semantics, line length splitting and cubic control constraints remain unimplemented; those cases reject without changing source geometry.
- Verification: 69 Core / 181 CAD tests pass; Core check and CAD build pass. A solver test changes the retained radius and checks both radii and centers. Workspace/native round-trip preserves all three relations. Live browser verification outstanding.

## Constraint-preserving Extend — 2026-09-09

- Line/arc/ellipse Extend no longer rejects every constrained contour. It retains constraint IDs and references and verifies the resulting geometry satisfies the existing equations. A conflicting relation produces a named error and no mutation; the solver is not allowed to silently reverse the endpoint edit.
- Dedicated `operations/preserve-constraints.ts` owns this verification. Trim/Split topology remapping and general constrained dragging remain separate acceptance work.
- Verification: 67 Core / 180 CAD tests pass, Core typecheck and CAD build pass. Tests cover retained arc radius, horizontal lines/fixed starts, atomic fixed-end rejection and radius-constrained Extend through the workspace and native save/reopen. Live browser verification outstanding.

## Conic sketch Extend — 2026-09-09

- Extend now accepts free circular-arc and ellipse endpoints. It follows the original conic to the nearest finite boundary in the extension direction. Without a boundary, a second picked point projects to the original conic; shortening or closing the curve rejects.
- Exact curve parameters remain persisted, with preview/commit sharing `operations/extend-curves.ts`. Closed contours, non-free ends, cubic targets and constrained targets reject explicitly. Constraint remapping and cubic extension remain parity work.
- Verification: 66 Core / 179 CAD tests pass; Core check and CAD production build pass. Cases cover both ends, nearest boundaries, clockwise orientation, ellipse axes, source immutability and workspace preview/undo/save/reopen. Live browser verification remains outstanding.

## Curved sketch Trim — 2026-09-09

- Trim now removes clicked intervals from line, circular arc, ellipse and cubic paths; whole circles retain the complementary exact arc and standalone points can be removed. Preview and commit share the operation; undo and native save/reopen preserve cubic geometry.
- Dedicated Core curve-pair intersections and picking modules support this operation. Conic pairs use polynomial roots; cubic pairs use bounded subdivision/refinement. Overlapping/ambiguous geometry rejects. Constrained target contours still reject pending relationship remapping; drag-trim and curved Extend remain incomplete.
- Verification: 62 Core / 178 CAD tests pass, Core typecheck and CAD production build pass. New tests cover circle/circle crossings, tangent contacts, adjacent arcs, cubic intersections, overlap rejection and curved Trim persistence. Live browser verification remains outstanding.

## Two-point circle split and free line extension — 2026-09-09

- Split circles through two clicked positions into exact circular arcs. Radius/circle references map to the first arc; generated concentric/equal-radius relations keep both arcs circular together. Existing fixed-center references map to an explicit construction center linked to the arcs. Changing the persisted radius after splitting updates both arcs while retaining the fixed center.
- Line Extend now enters a second-click endpoint gesture if no boundary intersects. The endpoint projects onto the original line and must lie beyond the selected free end. The first click and preview do not change geometry; commit is undoable.
- Multi-step direct editing lives in `src/sketch/direct-modification.ts`, shared by preview and committed clicks. The broader curve trim/extend and constraint-remapping work remains incomplete.
- Verification: 55 Core and 177 CAD tests pass; Core check and CAD build pass; host health HTTP200. New cases cover fixed-center/radius preservation after split and dimension edits, coincident split rejection, both free line ends, two-click UI preview/save and undo. Live browser QA remains outstanding.

## Exact sketch subdivision and expanded boundaries — 2026-09-09

- Added focused Core curve modules for parameterization, ellipse endpoint conversion, exact subdivision and line/curve intersections. Cubic subdivision preserves degree/control structure; arc and ellipse subdivision preserve their analytic geometry. Sampling is restricted to picking, not saved geometry.
- Split now works on path lines, circular arcs, ellipse segments and cubic Beziers, with preview, undo and native save/reopen. Surviving endpoint constraints are remapped. Constraints attached to the split segment still reject pending richer remapping; two-point circle split remains open.
- Straight-line trim/extend now recognizes finite arc/ellipse/Bezier boundaries as well as lines/circles. Cubic root isolation includes tangencies, and arc extent filtering avoids selecting intersections outside the drawn curve. General curved targets, curve/curve arrangements and overlap handling are not yet implemented.
- Verification: 52 Core tests and 175 CAD tests pass; Core typecheck and CAD build pass; host health HTTP200. Tests check subdivision invariance, finite-arc bounds, tangent intersections, endpoint remapping and DOM preview/save/reopen. Live browser verification remains outstanding. Full parity goal stays active.

## Sketch parity operations and maintainable modules — 2026-09-09

- Extracted drawing placement, preview, canvas rendering, picking, constraints, modification controls and contour actions into dedicated `Aether CAD/src/sketch/` modules. `sketch-workspace.ts` now coordinates the session and shared undo/commit path. Added a contributor map and extension workflow in `src/sketch/README.md`. Reformatted changed sketch modules for normal human-readable code rather than compressed multi-statement lines.
- Added exact mirror copies, two-direction linear patterns, circular patterns and numeric uniform transforms with selection, preview, commit, undo and persistence. Source drawings remain unchanged by Core operations. Copies are independent geometry; transforms reject conflicting constraints. Associative pattern/mirror relationships and interactive manipulators remain gaps.
- Added sketch points, construction drawing mode and existing-contour construction conversion. Construction curves persist and are excluded from solid-region evaluation. Added straight-line trim/extend against exact line/circle boundaries, pointer previews and undo. Curved boundaries, constrained targets and unsupported extension cases explicitly reject; they are not marked complete parity.
- Split constraints into `solver/types.ts`, `entities.ts`, `residuals.ts`, and `solve.ts`, retaining the public facade. Expanded circular-arc radius/concentricity/equal-radius/midpoint, point-on-line/circle coincidence, point-pair alignment and circle/arc internal/external tangency. Arc contact uses the analytic circle locus, without finite-arc parameter limits; general curve constraints, DOF diagnostics and other ledger gaps remain open.
- Verification: 45 Core and 174 CAD tests pass; Core typecheck and CAD production build pass. New tests cover independent-copy geometry, reflected ellipse/Bezier data, two-axis and radial patterns, atomic constraint rejection, trim reference remapping, construction exclusion from solids, patterned holes after reopen, extracted DOM flows and arc constraints. Earlier shared UI checks are not counted as rerun for this work unit. Live browser QA is still outstanding.
- Full sketch parity is the active goal; see `dev/docs/roadmap/CAD_Sketch_Parity.md`. No completion claim is made for the broader goal.

## Construction planes, tree icons and surface-fixed labels — 2026-09-09

- The Plane ribbon command now creates an actual persisted `plane` feature with a principal reference plane and signed offset in document units. It works without a body; feature editing, suppression, deletion and rollback use the existing document operations. The viewer displays active construction planes and lets a new sketch select them through the viewport, Model tree, or plane chooser. Saved sketches retain the chosen frame. Current creation scope is principal-plane offsets; sketches store a frame snapshot, not an associative dependency on later plane edits.
- Reference plane labels are mesh textures anchored at a fixed upper-left local coordinate; they rotate and foreshorten with their plane. Labels do not intercept picking. Construction planes use the same visual helper. Tree references and sketch/solid features now use shared illustrated SVG icons at tree size.
- Shared ViewCube text uses each projected face's two local basis vectors. Labels rotate, skew and invert with their faces rather than remaining camera-upright.
- Verification: 170 CAD, 33 Core, 149 shared UI tests pass (352 total); Core/UI typechecks and CAD/UI/Animation production builds pass. Tests cover plane command submission, save/reopen, empty-document evaluation, invalid offsets, sketch-on-plane frame persistence, local-plane label rotation, and 180-degree cube lettering. Browser list remains empty; no actual Safari/WebGPU visual verification claimed.

## Sketch variants and exact curve foundation — 2026-09-09

- Ribbon split menus now retain the selected Line, Rectangle, Circle, Arc or Polygon variant as their main action. Nine additions: midpoint line, center/aligned rectangles, three-point circle, center arc, inscribed/circumscribed polygons, ellipse, and cubic Bézier. The curve group exposes the implemented cubic tool and leaves fit spline disabled.
- Core owns shared preview/commit geometry. Ellipses and cubic Béziers persist as exact curve segments and evaluate through OCCT. Bézier control points are selectable and editable; existing point constraints can reference them. Invalid/degenerate placements do not change committed contours.
- Verification: 32 Core tests and 167 CAD tests pass; Core typecheck and CAD production build pass. Host health returns HTTP 200. Browser runtime has no connected browser, so no native visual validation claimed.
- Full tool/constraint parity is **not complete**. See [the acceptance ledger](../roadmap/CAD_Sketch_Parity.md) for missing tools and limits, including inferred relations, general curve constraints, associative projection, trim, import and patterns. This change does not imply those workflows exist.

## Sketch constraints, snapping and reference-plane start — 2026-09-09

- New sketch sessions temporarily show labeled Top/Front/Right reference planes. A plane can be chosen directly in the viewport, from the Model tree, or with the existing plane buttons. Clicking a planar body face during this mode uses its frame directly; nonplanar faces report why they cannot be used. Selection/Cancel restores previous plane visibility. Plane rendering still uses the shared 3D viewport.
- Core drawing profiles now persist constraints by contour/segment reference. A bounded damped least-squares solver enforces coincidence, horizontal/vertical, parallel/perpendicular, concentric/equal circles, equal line lengths, midpoint, line-circle tangency, fixed points, length/distance/radius and signed angle. Inconsistent/nonconverging edits reject without changing the drawing. Exact geometry evaluation resolves persisted dimensions before producing solids; coordinate edits preserve existing constraints.
- Sketch ribbon adds Constrain commands and enables Select. Select picks point/line/circle entities for A then B; right-side controls provide exact entity selection, values, apply/remove and point/center coordinate editing. Deleting contours removes their constraints and remaps surviving references; undo/redo includes constraints.
- Pointer snapping prioritizes origin, endpoints, straight-segment midpoints and circle centers, then horizontal/vertical alignment and optional 1mm grid. Snap feedback is included in live dimensional guides; geometry/grid snapping can be disabled separately. Placement snapping alone does not create persistent constraints.
- Verification: 26 Core tests and 164 CAD tests, Core check/CAD build pass. New coverage includes coupled systems, conflicts, circle tangency/concentricity, dimensions driving exact solids after serialization/reopen, snapping and mounted UI constraint save/reopen/plane-selection requests. Native browser/3D plane-picking visual verification remains unavailable.
- Limits: 64 constraints / 512 involved coordinates per sketch; no DOF/rank classification, arc-specific tangent/concentric constraints, trim/intersection-region decomposition, symmetry, splines or associative face references. This is a working first constraint set, not full commercial CAD parity.

## Live sketch previews — 2026-09-09

- Pointer movement now renders transient circle/rectangle/line/arc previews between placement clicks, including chained line endpoints. Circle previews display radius/diameter, rectangles width/height, lines length/angle, arcs chord length; arc midpoint placement first shows a construction guide. Numeric point entry also updates the preview.
- Preview and committed points use the same screen-to-sketch mapping, physical 1mm snap and contour-close snap. Pointer updates replace only the preview layer, not the feature list or drawing. Leaving the canvas, switching tools, Escape and committed placement clear transient geometry; previews do not enter undo or saved files.
- CAD 162 tests and production build pass, including five sketch DOM tests. New pointer-event tests cover live growth, matching committed circle geometry, chained line/rectangle/arc guides, cleanup and non-persistence. SVG screen mapping is stubbed in JSDOM; no native-browser visual confirmation is claimed.

## Viewport sizing regression corrected — 2026-09-09

- Removed sketch stylesheet's `.cad-studio-viewport { position: relative }` override. The async sketch stylesheet had overridden the shell's absolute/inset sizing and allowed the renderer container to collapse. Shell now remains sole owner of viewport geometry; sketch UI is positioned inside it.
- CAD production build passes. Actual shell/sketch CSS cascade check preserves `position:absolute; inset:0`, and compiled CSS has no relative viewport override. Browser binding list remains empty, so live rendered viewport restoration is not visually confirmed. No document data changed.

## Workspace sketch authoring — 2026-09-09

- Removed the detached floating Part features action/rollback panel; ribbon and Model tree own those commands. Sketch no longer uses the profile-entry modal. It starts a plane-selection session inside the viewport, accepts principal planes (buttons or Model references) and a selected planar face, then opens the 2D workspace and selects the Sketch ribbon.
- Enabled line chains, three-point arcs, circles and rectangles. Workspace supports numeric mm point placement, 1mm mouse snap, contour closure, undo/redo, delete, explicit hole marking, zoom and keyboard pan, Finish and Cancel. Profile status distinguishes closed contours and open paths. Editing existing profiles reopens geometry; legacy rectangle sketch edits convert the same feature ID to a drawing profile.
- Core's additive profile drawing variant persists paths/arcs/circles, holes and optional orthonormal face frames. Exact OCCT lines/arcs build closed-region solids, combine regions and subtract marked holes; open paths persist but cannot alone create a solid. Face placement is a saved frame, not an associative topology reference. No general dimensional/geometric constraint solver, trim/intersection region decomposition, splines, or automatic hole inference is claimed. Existing rectangle/polygon/circle documents remain readable.
- Verification: 21 Core and 160 CAD tests passed; Core check and CAD production build pass. New tests cover exact arc/hole extrusion on an offset frame, serialization/reopen, rejection of open-only extrusion, workspace plane selection/drawing/undo/cancel and absence of the floating panel/modal. Final panel-removal change rechecked with all three sketch DOM tests. No connected browser visual verification available.

## CAD panel routing correction — 2026-09-09

- Fixed controlled WorkspaceShell state dropping History/Version control entries on every render. Left rail now selects one Model, History or Version control view; Model retains feature/body content while hidden. Panel choices and positions survive ordinary rerenders.
- Ribbon category selection now changes tools only. Parameters, Assembly/mate controls, Inspect and Appearance have independent right-rail entries alongside Properties; selecting a property view never replaces the left Model tree. Explicit history actions reveal the left history view; reset clears supplemental panel state.
- Verification: 157 CAD tests pass, including mounted DOM click tests for Model → History → Version control → Model, ribbon tab isolation, and right-side property switching while left History stays open. Updated static shell expectations reflect the new panel composition. CAD TypeScript/production build pass. No connected-browser visual check this pass; DOM tests exercise the real shell/rail event handlers.

## Illustrated CAD ribbon — 2026-09-09

- All 180 CAD ribbon entries now use typed, shared `ToolIcon` artwork instead of text/Unicode glyphs. The collection contains 85 original 32px SVG illustrations in `core/assets/icons/tools/`: shaded blue/silver geometry, orange construction guides, and distinct modeling operations. Application branding and archived originals were not changed.
- Full-suite ribbon uses 30px illustrations, larger labeled targets, rounded selection treatments and quieter group captions. Core supplies explicit dark/light palettes; account theme selection continues to control the theme. Classic composition remains selectable. Command actions and unavailable-tool gating are unchanged.
- Shared UI gallery displays every illustration in both palettes. Per-instance gradient IDs prevent repeated icons from interfering. SVG sources and editable generator are retained in Core, with no font or raster dependency.
- Verification: 148 UI and 155 CAD tests, plus six server document-settings regression tests passed; UI/CAD checks and production builds, Animation build passed. Light/dark icon sheet rendered with librsvg and visually inspected (`/tmp/aether-tool-preview.png`). Host responds 200; static CAD build is ready on refresh. Connected browser unavailable, so full in-app layout interaction was not visually verified this pass.

## Persisted CAD document settings — 2026-09-09

- Document menu now includes Rename, Move, editable details, deleted project-workspace recovery, private Copy, Update, Units, hierarchical Properties with Apply/Save and viewport Print. Existing commands remain. See `dev/docs/reality/CAD_Document_Controls.md` for exact semantics and limits.
- Portable metadata lives in native Part JSON/canonical project graph; it survives export/copy/revision restore. Server operations enforce ownership, read-only snapshots, folder scope and optimistic revisions. Not revision managed disables new named versions without deleting saved history. Deleted Part/Assembly tabs retain stable definitions for restoration; deletion refuses live dependencies.
- Workspace update invokes the existing Core feature migration and explicitly selected linked-source updates. Units share one catalog, including mechanical families and per-family decimals; active modeling/placement/DOF fields convert into canonical mm/m/radians. Optional engineering quantities store SI; project-Part mass uses Core `mass_kg`. Workspace names and descriptions, Part/body names/descriptions/categories are persisted.
- Print captures a labeled viewport page, not a dimensioned drawing. No branch/merge or release workflow is claimed. Dialog operations preserve dirty editor work rather than reloading it.
- Verification: 52 host/workspace tests, 20 Core tests, 155 CAD tests (including six DOM interaction tests); Core/CAD typechecks, CAD production build and targeted Ruff pass. Real HTTP tests cover rename/details/units/move/copy/historical metadata/restore. Running host restarted and `/api/status` returns 200. QA data stayed isolated from production. Connected browser/native print visual verification unavailable.

## CAD document header — 2026-09-09

- Retained clickable product icon, replaced redundant Home button with a hamburger document menu, then document name, plain grey Main/current revision label and copy-link icon. Main labels the working document; it does not introduce branching semantics. Historical URLs show their revision number.
- Menu connects existing Save/Open Part/Import STEP/Export/Close commands and document details. Shared menu/link SVG icons live in Core. Clipboard success is announced; unavailable clipboard shows a selectable link. Unsaved local documents cannot share a document URL. Links preserve document/Part/Assembly/revision routing, exclude transient parameters/fragments and leave access permissions unchanged.
- 149 CAD tests and 146 shared UI tests pass; CAD build and UI typecheck/build pass. Connected browser remains unavailable, so clipboard interaction/visual review was not run in a browser this session.

## CAD full-suite default layout — 2026-09-09

- Default chrome places a Design workspace dropdown beside the expanded ribbon categories/tools. Animate/Show/Hardware remain listed with the same unavailable routing state as before; no new suite engine routing is claimed. The dark blue-grey palette is retained.
- Left rail now exposes Part, Version control and History. Feature History/Problems use a full-height sidebar instead of the bottom tray. Version control reads real saved revisions/named versions from the host and opens historical snapshots read-only in another tab; naming/restoring remains in CAD Home. Existing history commands reveal the sidebar.
- Header Theme menu saves Full suite or Classic locally. Classic preserves centered workspace tabs, the bottom History/Problems tray and floating tool mode.
- Verification: 147 CAD tests pass, including updated default layout and retained Classic assertions; TypeScript/production build pass. Isolated authenticated API checks verify revision data and read-only historical access; production status 200. Connected browser unavailable (runtime reports no browsers), so visual browser verification remains outstanding.

## Wheel Part authoring, rollback and bodies — 2026-09-09

- **Create → Part** now opens its naming dialog in the editor and starts an empty, server-saved Part rather than a seeded rectangle. Fixed the workspace screen’s early return that hid creation dialogs.
- Core owns insertion/reorder/delete, dependency-aware suppression, a persisted rollback position, stable body identities and body name/visibility metadata. Evaluation executes only the prefix before rollback; insertion keeps future features. Rectangle parameter changes preserve downstream history. Empty/sketch-only history evaluates to no bodies. New solid operations create separate bodies; add/cut and edge finishes target a chosen body. Assembly rendering handles every authored body.
- CAD projects this history into an editable tree with a draggable rollback bar, suppressed/future styling and a real Bodies list. Features support edit, move, suppress and dependency-aware deletion; body rows support rename and visibility. Rebuilds preserve the camera when an existing body is edited and no longer auto-select the new geometry.
- The profile dialog includes a snapped millimeter canvas: click circle center/radius, draw polygon vertices, drag vertices, or enter exact numeric coordinates. Selective fillet/chamfer controls operate on edges in a datum plane, alongside the existing all-edge option. These are real OCCT operations. General constrained line/arc sketches, arbitrary edge picking and Shell are not implemented.
- Updated `.acpart`/`.acad` wheel fixtures contain 14 features, including flange/web rounds and a rim chamfer. `Aether CAD/examples/Wheel-Walkthrough.md` gives a blank-Part recipe, history/body editing instructions and current limitations. Dimensions are assumed; detailed screenshot ribs/bosses are not claimed as reproduced.
- Verification: 18 Core tests, 146 CAD tests, 46 host/workspace tests; Core/CAD typechecks and production build passed. Isolated browser built the wheel from blank through the controls, inserted a fillet while rolled back, replayed future history, edited mirrored-hole coordinates, suppressed/restored a feature, renamed/hid/saved/reopened a body. A second run verified real rollback drag, pointer-drawn/dragged polygon vertices, two-click circles and two-body save/reopen. No production test accounts/documents were created. Static CAD assets are rebuilt for the running host.

## CAD Create menu — 2026-09-09

- CAD Home now has one Create dropdown: Project document, Folder, Part, Assembly and Import file. Removed separate sidebar/hero creation buttons and the duplicate folder button. Menu supports keyboard arrows, Escape and outside dismissal; folder creation from Home navigates to its library location. Studio build and browser walkthrough of all five actions passed.

## CAD projects, executable feature history and saved versions — 2026-09-09

- CAD Home creates `.acad` projects, standalone `.acpart` Parts and `.acasm` Assemblies. Legacy `.cadpart`/`.aether` remain readable. Projects and standalone Assemblies use the same canonical workspace archive/graph; authored feature documents live once under Part definitions. Project tabs add Parts/Assemblies and insert existing Parts into Assemblies. Exact authored geometry is rebuilt for Assembly instances using Core-solved transforms.
- Core Part format v3 adds dimensioned circle/polygon profiles, additive/cut extrusions, axis revolves, feature mirrors, and uniform all-edge fillet/chamfer operations. The numeric feature editor and connected ribbon operations rebuild actual OCCT geometry. Existing constrained rectangle editing remains supported; a general freehand constrained sketch editor is not claimed.
- Standalone Part links pin server file IDs/revisions and retain the selected snapshot inside the container. Explicit updates adopt a newer source revision while preserving the definition ID; linked snapshots cannot be saved through the Part editor. Standalone export forks an editable copy. `.acad`/`.acasm` exports retain current packaged dependencies; server history is retained by database backup, not exported inside each CAD archive.
- The host retains immutable saved byte snapshots (content-addressed deduplication), author/time, named versions, and restore-as-new-revision. Current file permissions apply to historical reads. Conflicting saves/restores are rejected. Existing installations receive a baseline snapshot of currently retained bytes; earlier overwritten content cannot be recovered. Saves remain explicit. Engineering release approvals, per-item released revisions, branches/merges, nested Assembly solving and live collaboration remain planned.
- Wheel fixtures: `Aether CAD/examples/Train-Cart-Wheel.acad` and `.acpart`, with explicitly assumed dimensions. Real-kernel tests verify four mirrored hole axes, changed geometry after a profile edit, wheel axial bounds, and fillet/chamfer topology. Browser tests cover project creation, wheel build/edit/save/reopen, named version and restore retaining later history, and insertion/rendering of the same Part in an Assembly. Server tests cover pinned source snapshots, explicit link updates, archive roundtrips, permissions and revision conflicts.

- Final verification: 46 host/workspace tests, 146 CAD tests, 11 Core tests; Core/CAD typechecks, Studio/CAD production builds and targeted Ruff passed. Isolated browser tests additionally verify standalone Assembly creation, pinned Part linking, read-only enforcement and standalone export. Local production host restarted successfully; public assets respond and history rejects unauthenticated same-origin requests. No test documents/accounts were added to production.

## Supplied app branding — 2026-09-09

- Fancy app-specific Studio/CAD/Animation SVG renditions are active in Core, app launchers, browser icons, setup, app cards and product headers. Simple variants and prior artwork are retained. These are vector reconstructions of the supplied design sheets. Build scripts consume the artwork instead of generating generic toolbar-glyph icons.
- Verified product builds, shared UI typecheck/build, three signed launchers, six live icon assets, browser app-card rendering and original archive hashes.

## CAD library and shared account preferences — 2026-09-08

- `/cad/` is now a product file home using the existing dark blue-grey tokens: Home, My files, Recently opened and Workspace shared; folders/breadcrumbs, search, list/grid views and selection details. Studio product cards open a separate browser context. `/cad/index.html?document=<id>` opens an editor document and retains the destination through sign-in.
- The host library persists original bytes and metadata in SQLite on the server, included in backups. CAD Part Save and canonical Assembly Save write to this library when hosted. STEP references can be imported/opened. Local standalone CAD retains file downloads. Imports currently support `.cadpart`, `.aether`, `.step`, `.stp`, up to 6 MB. Existing device downloads need importing; no migration or automatic upload of old files is claimed.
- Personal files are owner-only. Workspace-shared files can be viewed/copied by authenticated users with CAD access; only owners edit originals. Sharing can be revoked. Saves check an expected revision and reject stale writes; unsaved editor changes prompt before leaving. This is explicit Save, not background autosave or concurrent collaborative editing.
- `core/session/` supplies one host-backed name/avatar/theme/account control for Studio, CAD, Animation and the UI gallery. Account preferences persist across sessions/devices; same-browser apps sync changes, and other clients refresh on focus. Dark remains default; light/system are opt-in. PNG/JPEG avatars are limited to 256 KB.
- Verification: 29 host tests; CAD's 145 existing tests plus a new asynchronous save-failure test; 146 Core UI tests; Studio/CAD/Animation/gallery builds and targeted Ruff. Isolated browser walkthrough verifies import → open → server save → share, separate-user deep-link login/read-only protection/copy, independent-account sessions, profile pictures, themes and tablet layout. Actual second physical device/network connectivity was not tested.

## Account identity and recovery — 2026-09-08

- Setup full name and email each occupy a full-width row, so long addresses have the same space as usernames.
- Studio setup and user administration collect full name and email. Existing accounts migrate in place; username or email can be used for sign-in.
- Host-authorized setup cookies survive refresh for one hour; the manual setup-code field is removed.
- Admin Email delivery supports SMTP STARTTLS/implicit TLS and explicit test delivery. Recovery sends username plus a one-use 30-minute reset link; consuming it revokes sessions. Private SMTP credentials and recovery tokens are excluded from backups. SMTP must be configured before actual email delivery works.
- Verification: 22 host tests, targeted Ruff, Studio production build, and isolated browser walkthrough covering setup refresh, identity, email sign-in, email settings and password reset. SMTP was mocked; no external email sent.

## Current state — 2026-07-21

- **Repo:** `AnimaStudio` — open-source unified character animation
  system for AI robots (digital avatars + physical animatronics from
  one rig, one format, one authoring tool)
- **Version:** 0.1.0 (see `animacore/__init__.py`)
- **Unity front-end (`unity/AnimaStudioUnity`, self-contained package):** a
  second front-end over the same Python engine bridge the Swift app uses —
  nothing reimplemented app-side. `StudioShell.cs` is the app, mirroring the
  Swift app's workspace model with header tabs **Assets · 3D Modeling ·
  Animate · Show · Hardware**, a contextual toolbar, left navigator, right
  inspector, and dark AnimaStudio theming. **Assets**: character library
  (`examples/` + `characters/`, one-click Load), mesh library
  (`StreamingAssets/Parts` + user-imported), import-.obj toolbar. **3D
  Modeling**: parts tree (grounded/suppressed flagged), mates + relations
  lists, and engine-backed **mate authoring** — the MATE toolbar lists the
  eight kinematic types from `mate_types`; pick type → click parent part →
  click child part → `add_mate` commits in the engine and the refreshed rig
  summary re-renders; select a mate to inspect DOF or `remove_mate` it.
  **Animate**: clip list, live DOF pose sliders, bottom transport
  (play/pause/scrub). Clip playback and live posing both go through engine
  `resolve_pose` (`clip`/`time_s`/`dof_values` overrides — one request in
  flight, coalesced); parts whose `model` is an `.obj` render the real mesh,
  others render as placeholder boxes at the engine-resolved pose; suppressed
  parts hide. Show/Hardware tabs are placeholders until the engine session
  verbs land. **Standalone macOS app**: menu `AnimaStudio ▸ Build macOS App`
  (or batchmode `BuildAll`) produces `unity/AnimaStudioUnity/Builds/
  AnimaStudio.app`, which finds the repo by walking up from its own location
  or `ANIMASTUDIO_REPO`, and keeps the engine bridge alive while unfocused
  (`runInBackground`). **STEP → assembly pipeline:** the Assets toolbar
  imports a `.step`/`.stp` — `unity/Tools/step_to_obj.py` (OCCT via
  `cascadio` + `trimesh`, optional `cad` extra in `pyproject.toml`)
  tessellates every solid to a per-part OBJ and reports each part's CAD
  placement as an engine rest transform (mm→m, intrinsic-XYZ euler); the app
  commits each as a rig part via the engine's `add_part` verb, so an imported
  assembly lands positioned and ready for mate authoring; **New Assembly**
  scaffolds `characters/<name>/` with an empty character, and header **Save**
  writes the file through `serialize_character`. Verified end-to-end on a
  real 26-part robot STEP assembly. Engine side: `evaluate_pose` gained an
  optional `dof_overrides` mapping and the bridge `evaluate`/`resolve_pose`
  verbs accept an optional `dof_values` object (overrides merge over
  clip/neutral, relations still run, driven DOF stay driven, out-of-limit
  overrides are reported never clamped); new `add_part`/`remove_part`
  authoring verbs (part DTO = the `load_character` part entry shape; removal
  of a mated part refuses) plus `update_part` (same DTO, keyed by name) —
  all additive, shared with the Swift app. **Viewport interaction
  (Onshape-style, non-additive select):** left-click single-selects (cyan
  highlight); left-drag on a free (unmated, ungrounded) part moves it on
  the ground plane — or along an axis via the **move gizmo** (RGB arrows
  on the selection) — committing its rest transform via `update_part` on
  release; left-drag on empty space box-selects; grounded/mated parts
  refuse the drag with a status hint. **Mate authoring** uses an
  Onshape-style dialog (type dropdown, connector list, offset/flip/
  secondary-rotation/simulation controls from the engine's `mate_types`
  schemas, Solve = `preview_mate` shown live, ✓ = `add_mate`); clicking
  faces places **mate connectors with a live ghost XYZ triad** that snaps
  to bore/cylinder centers (Kåsa circle fit over the welded tessellation,
  primary = bore axis), flat-face centers, and vertices (Shift = raw).
  Chrome: clickable view cube with X/Y axis rails, icon ribbon with group
  captions, project-tree navigator with filter, import loading card,
  native multi-file picker; STEP/OBJ document types registered in the
  built app's Info.plist ("Open With" — receiving the open-document Apple
  Event still needs a native plugin, queued).
- **2D character pipeline (engine foundation, not yet wired to the app):**
  `animacore/canvas2d.py` models VTuber-style 2D characters — `VisualSource`
  (image/sprite/gif/video), `Surface` display windows, DOF/parameter-driven
  `SurfaceDriver`s — and `evaluate_surfaces` resolves them to renderer-neutral
  `SurfaceState` (source, frame index, transform, opacity, z-order) using the
  same evaluated-value stream the 3D rig uses. `animacore/frame_output.py` adds
  the frame hardware-node side: `LedMatrixTarget` + `downsample_canvas`
  (the 64x64 area-average/gamma/brightness math) and a `FrameOutput` protocol
  with a `SimulatorFrameOutput`. `animacore/raster/` is the host-side rasterizer:
  it turns evaluated `SurfaceState`s into actual pixels for the hardware frame
  path (and as a reference for the Swift preview renderer). The media decoders
  are **ported from Mochi** (Apache-2.0) — real, not stubs: an RGBA8 `FrameBuffer`
  and Mochi's `open`/`close`/`next_frame(t)` decoder contract, with working
  `ImageAdapter` (Pillow), `BitmapAdapter` (numpy 1-bit), `SpriteAdapter`
  (sheet-cell crop, grid-index or explicit rect), `GifAdapter` (Pillow
  ImageSequence, per-frame durations, loop), `VideoAdapter` (imageio/ffmpeg
  decode-by-index), and a `ProceduralAdapter` + parametric `SimpleFace` (eyes+mouth
  driven by the same `eye_open`/`mouth_open`/`mouth_curve`/`look_*` value stream,
  auto blink/breathing). `CanvasPlayer` opens one adapter per surface and
  alpha-composites them back-to-front (Pillow) into a `FrameBuffer`, feedable to
  `downsample_canvas`. Two more real pipelines ship beside it: `frame_serial.py`
  `SerialFrameOutput` streams frames to a physical RGB matrix over serial
  (`MM`/`BM`/`FM`, verified on a pyserial loopback), and `raster/mscript.py` is
  the ported Mscript timeline language (parser + `update(t)` WAIT/duration flow
  control + GIF/video auto-duration). Media deps are the optional `media` extra
  (pillow/imageio); the core engine never imports `animacore.raster`. 30 raster
  tests decode real generated PNG/GIF/sprite/bitmap/mp4. The `.character.anima`
  `canvas2d:` loader is still pending — design in
  `dev/docs/roadmap/2D_Character_Pipeline.md`.
- **2D character workspace (groundwork — engine + app scaffold):**
  `animacore/raster/preview.py` is a headless preview/export tool: render any
  canvas to a PNG, an animated GIF, an LED-matrix simulator image, or ASCII, plus
  a `python -m animacore.raster.preview` CLI. `animacore/bridge.py` gains a
  `canvas2d.*` verb family (`describe`/`new`/`get`/`evaluate`/`render_frame`/
  `matrix_preview`/`release`) so the app can build, evaluate, and rasterize a 2D
  character over the Studio↔AnimaCore bridge; evaluation is stdlib and only
  `render_frame`/`matrix_preview` need the optional `media` extra (returning
  `media_unavailable` if absent). In the app, a new **2D** workspace
  (`StudioWorkspaceKind.canvas2d`, ⌘8, tab after Animate), routed through every
  workspace switch, with Surfaces/Media/Faces/Output sidebar tabs. Its center is a
  **live preview**: `Canvas2DWorkspaceView` spawns an engine client, builds a
  procedural-face canvas (`canvas2d.new`), renders it (`canvas2d.render_frame` →
  decoded PNG), and drives `mouth_open`/`mouth_curve`/`eye_open`/time from sliders
  — so the app shows exactly what the engine (and hardware) produce. Persistence:
  `animacore/canvas2d_io.py` reads/writes a `canvas2d:` block in a
  `.character.anima` (one shape shared with the bridge DTO), the loader accepts it
  (a pure-2D character loads as an empty-mechanics Rig; hybrid = rig + canvas2d),
  `bridge.py` has `canvas2d.load`/`save`, and `examples/pixel_face_2d.character.anima`
  is a runnable pure-2D character. Still to come: the real surface/media/face
  editors and load-into-preview UI. Design in
  `dev/docs/roadmap/2D_Character_Workspace.md`.
- **2D asset conventions (the create ↔ play interchange, ported from Mochi):**
  AnimaStudio is the *create* method; the playback middleware consumes these.
  `animacore/asset_props.py` — the `.props.yaml` sidecar (`asset-props/v1`:
  name/mood/tags, `ideal_size`, `framing`, `playback_speed`, `loop`, `type_props`
  sprite-grid/fps), read+authored, with `visual_source_from_asset`.
  `animacore/asset_catalog.py` — `build_catalog` indexes a media folder to
  JSON. `animacore/pack.py` — packs (`pack/v1`) mapping emotion/action **slots**
  to asset files. `animacore/skin.py` + `animacore/raster/skin_compositor.py` —
  skins (`skin/v1`): a `body.png` bezel + `screen_bbox`, and `apply_skin` paints a
  frame into the cutout. `animacore/raster/mscript_runner.py` — `MscriptRunner`/
  `render_mscript` play the Mscript command stream into real frames. Bridge gains
  incremental `canvas2d.add_surface`/`update_surface`/`remove_surface`/`add_source`/
  `remove_source` verbs for editor CRUD. Stdlib + pyyaml (skin compositing +
  Mscript playback need the `media` extra). Design in
  `dev/docs/roadmap/2D_Character_Pipeline.md` §11.
- **2D media library + in-app picker:** `examples/assets/2d/` mirrors the Mochi
  project's media asset tree (png/bmps images, ~70 gifs, ~31 videos, 8×8 bitmaps,
  math/mscripts/procedural/packs/skins; ~37 MB, mostly `video/`), with `.props.yaml`
  sidecars + a built `CATALOG.json` (149 renderable assets), plus two example
  characters that use it: `examples/pixel_pet_2d.character.anima` (colorwheel image
  + procedural face) and `examples/dino_screen_2d.character.anima` (animated gif
  surface). Both render imported media end-to-end (tested). The 2D workspace
  preview gained a subject picker (Face / Pixel Pet / Dino GIF) that renders each
  live via the bridge. `SimpleFace` now draws over a faint translucent breathing
  tint (was opaque) so a face composites *over* a media background instead of
  hiding it. The media is a dev fixture — see `examples/assets/2d/README.md` on
  provenance/licensing before distributing.
- **Character types (3D / 2D / VR) + VR character workspace:** a Character now has
  a **type** (`StudioCharacterType`), chosen from a picker beside the workspace
  tabs. The second tab is **character-specific** — it routes to Rig (3D), 2D
  (`canvas2d`), or VR based on the type (replacing the fixed Rig tab):
  `visibleStages` returns one authoring tab per type. New `StudioWorkspaceKind.vr`
  "VR" workspace with a `VRCharacterWorkspaceView` — a live avatar preview
  rendered by the engine, driven by ARKit-style blendshape sliders (jaw/smile/
  blink/head) mapped to the face. Engine: `animacore/tracking.py` is the
  tracker-neutral contract — Apple's 52 ARKit blendshapes + head pose, and a
  `FaceTrackingFrame` → evaluated `values`; a tracked `jawOpen` drives an avatar
  through the *existing* `evaluate_surfaces` (so the avatar half of VR already
  works — only the tracker input is new). Face tracking on the Mac will use the
  webcam via Apple's Vision framework (the capture pipeline is the next piece).
  Also: fixed the floating expanded tool ribbon spanning full window width (its
  category strip now hugs content when floating). Design: `2026-07-24`, roadmap
  `VR_Character.md`.
- **Viewport appearance layers (Background / Environment / Object):** the CAD
  Environment panel is three sections backed by one shared model. Background:
  theme preset plus Solid or two-stop vertical Gradient with color pickers.
  Environment: floor mode None / Grid / Floor / Grid + Floor — the solid floor
  is a ground plane at Y=0 sized from model bounds that receives the model's
  soft shadow on Metal and Three.js WebGPU (raw WebGPU renders background
  colors/gradient only; it has no shadow pass). Object: a master Brightness
  slider plus per-light key/fill/rim/ambient on one perceptual contract —
  far left off, mid-slider the preset's nominal, far right 4x (overexposed)
  via `CADLightingScale` (4t²); persisted intensities keep their raw meaning,
  master multiplies at theme construction. All values stream live to the
  renderers per frame/revision. Choosing a preset restores solid background,
  nominal brightness, and clears floor/bottom color overrides. Floor state is
  two additive persisted bools (grid existing, solid new); no migration.
- **Consolidated viewport controls:** the production right sidebar is now the
  single operator surface for camera/display controls, navigation profiles and
  help, materials, lighting, background, reflections, shadows, section view,
  and viewport appearance. The spatial HUD retains only the ViewCube and Home
  action; the old floating Visualization pill and duplicate display menu have
  been removed. Material and Environment share the reusable Visualization
  panel and remain bound to the real persisted viewport/project settings.
- **Root web CAD app and exact-topology assembly proof:** `Aether CAD/`
  is the promoted TypeScript web CAD app, isolated from the production Studio
  renderer. Its native `.cadpart` v2 vertical slice starts a Sketch by choosing
  the Top, Front, or Right principal plane; edits a center rectangle in a real
  full-screen Sketch mode; persists Horizontal, Vertical, Origin Coincident,
  width, and height constraints/dimensions; reports remaining degrees of
  freedom; and renders under-defined geometry blue and fully defined geometry
  black. Finishing the Sketch extrudes it into an exact OCCT solid Body,
  exposes Sketch/Extrude/Body plus definition state in the Items tree, saves
  deterministic versioned feature history, and reopens/rebuilds that history
  through the worker. Version 1 rectangle files migrate to the equivalent
  fully defined v2 graph without changing stable IDs. A worker also
  loads STEP through
  Replicad/OpenCascade.js, treats each imported STEP document as one movable
  Part, retains each display
  triangle's exact OCCT face hash, and derives connector frames from analytic
  planes, cylinders, circular edges, curve midpoints, and vertices. Three.js
  targets WebGPU with its WebGL 2 fallback; hover resolves the hit mesh face
  back to the authoritative B-Rep entity and presents its exact candidates.
  Candidate anchors are temporary small, flat, face-aligned white CAD snap
  discs; only the hovered candidate and saved connector anchors show the exact
  Part-local red-X/green-Y/blue-Z gizmo and origin ring. The candidate set uses
  two instanced draw calls rather than one 3D marker mesh per candidate.
  Imports append to one assembly: bodies from the same STEP retain their
  shared coordinates while subsequently imported STEP documents are staged
  beside the current assembly instead of overlapping at the origin. Connector
  placement is independent from mating; an operator can create any number of
  persistent stable-ID connector anchors attached to each Part. A Fastened
  mate then references two existing connectors on different Parts and applies
  `W1new = W2 · T2 · RflipX · inverse(T1)` and explicitly rejects a Part already
  used as the moving side rather than silently over-constraining the proof.
  Analytic frame extraction uses the exact OCCT plane/cylinder axes and is
  fault-isolated per face, so one unsupported curved face cannot discard an
  otherwise renderable Part. Twenty-three deterministic document, tree,
  inference, solver, and policy tests initially shipped with the Part slice;
  the suite now has twenty-seven tests. The product shell has a compact
  document header plus functional Sketch/Create/Assembly/Inspect ribbon. A
  single left rail switches between the Items browser, editable Sketch/Extrude
  parameters, and connector/mate data. Items includes working origin and three
  principal-plane visibility controls backed by real viewport geometry. The
  top-right ViewCube follows camera orbit and its six faces select standard
  views; Home returns to a fitted isometric view.
  TypeScript check, production build, command-line STEP probes, and a real
  headless-browser flows pass: create/rebuild/save/reopen produces the same
  Sketch/Extrude/Body history and exact solid, and two STEP imports produce two
  rendered/tree Parts,
  two saved connectors, and one applied Fastened mate.
  The app and npm package are now named **Aether CAD** / `aether-cad`. Its
  semantic entry point is `src/aether-core.ts`, an app-facing facade over the
  still-embedded single OCCT/WASM implementation. The future extraction
  contract is explicit: Aether Core owns the supported OCCT build, exact
  B-Rep, parametric DAG, constraints, stable IDs, deterministic evaluation,
  and STEP/IGES contracts; Aether CAD retains browser UX and WebGPU rendering.
  No second engine exists. New Part files use the `aether-part` identity;
  provisional `open-cad-part` files migrate on open without losing stable IDs.
  The facade has a byte-stable Part round-trip test; the complete suite is now
  34 tests. TypeScript check and the production Vite build pass; the root
  clickable app has been rebuilt and ad-hoc signed with this slice.
- **Clickable Aether CAD macOS wrapper:** root `Aether CAD.app` is assembled by
  `Aether CAD/Scripts/build-macos-app.sh`. It bundles the production web assets
  and OCCT WebAssembly worker, runs a private ephemeral HTTP server restricted
  to `127.0.0.1`, and displays the product in a dedicated resizable WKWebView
  window without an address bar or Vite/npm terminal. Its project-native icon
  carries the Aether/Anima gradient family while expressing the A as a
  constrained CAD sketch. The bundle is ad-hoc signed and verified.
- **Aether CAD now opens on a traditional professional CAD baseline.** A
  product-owned catalog projects Home, Sketch, 3D Tools, Assembly, View,
  Manage, and Output ribbons with 150 discoverable operations grouped
  by workflow. Existing Part, STEP, Sketch, Assembly, mate, view, workspace,
  and export entry points execute through established typed handlers; future
  Core feature, analysis, display, and format producers stay visible but
  disabled with exact reasons. Aether suite-stage and document context sit
  above the persistent viewport. The floating viewport palette remains a
  selectable design theme, and the user's Traditional/Floating, Docked/
  Expanded/Canvas, and per-panel Dock/Float/Hide choices persist locally.
  Browser, Properties, and History/Problems panels reset together without
  changing CAD state. Runtime code, assets, command IDs, and UI text remain
  Aether-owned.
- **Standalone CAD benchmark:** `dev/Codex Bench/` builds a separate clickable
  Apple-focused `Codex Bench.app` for deciding the future CAD viewport/import
  architecture without coupling experiments to Anima Studio. Its active catalog
  now has four locally working STEP routes: Open CASCADE Technology feeding
  RealityKit (P1), raw MetalKit (P2), Three.js WebGPU in Swift WebKit (P7),
  and direct `navigator.gpu`/WGSL WebGPU in Swift WebKit (P10). P7 uses Three.js
  `WebGPURenderer`, reports the backend actually selected, and keeps its
  automatic WebGL 2 fallback. Historical pipeline IDs
  remain stable; removed P3, P4, P6, P8, and P9 are not renumbered.
  The Qt/Open CASCADE and Qt WebEngine experiments were removed from the Apple
  catalog, runtime, Settings window, automated benchmark, Swift package
  dependencies, and signed bundle after the normalized study showed their host
  and event-loop cost was not competitive for the Apple-first product. The
  `qt/` sources remain archived as implementation reference for a future
  separate non-Apple Qt application; their current AppKit/IOSurface host is
  macOS-specific and is not advertised as cross-platform product code.
  The desktop Open CASCADE OpenGL viewer, per-feature RealityKit entity graph,
  and SceneKit comparison are also absent from the active package and picker:
  they were macOS-only, resource-prohibitive, or legacy product directions.
  OpenGeometry and its WASM probe were removed completely because it could not
  import the operator STEP model. P7 now uses Three.js WebGPU; P10 uses direct
  GPU buffers, four-sample render/depth attachments, and WGSL surface/edge
  shaders without a scene framework or WebGL fallback. P5's small raw WebGL 2
  implementation was retained through the fair comparison and then removed
  from the active app after P10 matched its throughput.
  Every active renderer receives the same operator-selected STEP/STP file and
  shared Open CASCADE extraction where applicable; no app route inserts fixture
  geometry. The importer preserves assembly labels/transforms, B-Rep faces and
  feature edges, XDE colors, staged timings, and model tolerance. Shared CAD
  navigation supplies orbit/tilt, pan, roll, zoom, and fit. A standard Settings
  window owns renderer selection and complete shared themes covering background,
  material color policy, roughness/metallic response, edge display, selection,
  and key/fill/rim lighting.
  All 46 STEP files in `CAD DEMO/ARCADA001-2` pass isolated import probes
  (8,931 faces, 24,778 edges, 247,030 triangles). The historical nine-pipeline
  decision record and raw runs remain in
  `dev/Codex Bench/Reports/2026-07-19-pipeline-study/`; they identify P2 Open
  CASCADE → raw MetalKit as the production direction at 60 FPS and 19.7% median
  CPU, while documenting why the discarded routes were retired. A new retained
  catalog pass on the same 54,830-triangle part measured P1 at 50.7 FPS/70.6%
  CPU, P2 at 59.8 FPS/23.5% CPU, raw WebGL at 61.2 FPS, and direct Three.js at
  62.7 FPS. WebKit CPU/memory cover only the Swift host, so those figures are
  not directly comparable native totals; Three.js added only 6 ms over raw
  WebGL upload and remains a useful optional environment experiment. A true
  combined-assembly pass loads all 46 CAD DEMO files into one shared document
  (8,931 faces, 24,778 edges, 247,030 triangles; 230,466 compact render
  vertices, 63 material/part batches, 46 rigid parts). The first pass exposed
  P1's per-face entity graph as unusable; the follow-up retained every pipeline
  and replaced that graph with one RealityKit `LowLevelMesh`, added one shared
  renderer projection, cached STEP imports across pipeline switches, moved P2
  static buffers to GPU-private storage with a stable per-part transform table,
  triple-buffered uniforms and topology IDs, and changed P5/P7 to one compact
  binary typed-array payload. On the optimized signed build P2 delivered 59.92
  FPS at 19.71% CPU and 231.21 MB app footprint; P1 completed at 59.83
  display-link Hz, 21.29% CPU, and 378.83 MB. P5 and P7 reported 52.71/52.68
  WebGL animation frames per second, but their 254.43/227.81 MB figures omit
  system-managed WebKit content/GPU processes and are not comparable native
  totals. Roles are therefore explicit: P2 production candidate, P1 secondary
  Apple renderer, P7 optional environment renderer, and P10 browser renderer
  candidate.
  A subsequent signed-app experiment moved P7 to Three.js WebGPU and confirmed
  that this machine's `WKWebView` selected native **WebGPU**, not the fallback.
  On the same 46-file assembly, a same-build P5/P7 comparison measured raw
  WebGL 2 at 78.02 FPS/11.77% app CPU/286.61 MB and Three.js WebGPU at 65.54
  FPS/9.53% app CPU/386.46 MB, with 42/45 ms buffer upload. WebKit helper
  processes remain excluded, so this validates compatibility and relative
  behavior rather than claiming complete GPU-process totals or a universal
  WebGPU performance win.
  The direct-WebGPU follow-up compared all three browser paths on that same
  document and measured P5 raw WebGL 2 at 60.80 FPS/9.43% app CPU/376.23 MB,
  P7 Three.js WebGPU at 61.24 FPS/8.18% app CPU/422.78 MB, and P10 raw WebGPU
  at 60.78 FPS/10.23% app CPU/223.70 MB, with 41/47/42 ms buffer setup.
  Repeated isolated P10 launches ranged from 51.63 to 60.78 reported FPS while
  upload held at 41–43 ms, confirming WebKit frame-callback scheduling is too
  variable for a finer browser FPS ranking. Direct WebGPU completed the full
  workload and uses the modern API, so P10 replaces P5 in the active catalog as
  a product-direction decision rather than a claimed benchmark win. P7 retains
  an automatic WebGL 2 fallback;
  P10 reports unsupported WebGPU as an error rather than silently changing
  renderer APIs.
  Historical measurements remain in
  `dev/Codex Bench/Reports/2026-07-19-assembly-benchmark/`; the optimized run is
  in `dev/Codex Bench/Reports/2026-07-19-optimized-pipelines/`; the WebGPU run
  is in `dev/Codex Bench/Reports/2026-07-19-webgpu-pipeline/`; the direct-WebGPU
  comparison is in `dev/Codex Bench/Reports/2026-07-19-raw-webgpu/`. Sixteen Swift
  tests, recursive format lint, release packaging, deep signing, headless
  46-file probe, and all four signed-app assembly runs pass.
- **Production STEP/CAD rendering:** the retained Codex Bench architecture is
  now integrated under `app/` rather than remaining a prototype-only result.
  `AnimaCADShim` is a crash-guarded C++ boundary over Open CASCADE 7.9 XDE;
  `AnimaCAD` projects STEP/STP into one renderer-neutral document containing
  metre-space triangles, assembly labels, per-face XDE colors, exact B-Rep
  feature-edge polylines, topology IDs, transforms, tolerances, and staged load
  timings. `RealityKitModelLoader` consumes that same document, so STEP is a
  first-class picker/drop/import format and a multi-node STEP assembly can
  author rigid Parts just like a multi-node USD. Malformed STEP becomes a
  readable import error rather than allowing a native exception to abort
  Studio.

  The production renderer catalog contains only the four retained paths: Open
  CASCADE → MetalKit (preferred high-volume STEP visualization), Open CASCADE → RealityKit
  (native Studio editing/selection/media path), Open CASCADE → Three.js WebGPU
  (optional virtual-stage experiment with reported WebGL 2 fallback), and Open
  CASCADE → raw WebGPU (diagnostic WGSL path). All consume the same imported
  document; none reparses STEP or changes saved rig meaning. Settings → CAD
  Renderer owns backend selection, ten coordinated themes, XDE-color policy,
  exact-edge visibility/strength, roughness, metallic response, key/fill/rim
  intensity, and optional live telemetry. Browser-renderer assets live in
  `App/Resources/CADWeb`, so archiving Codex Bench cannot break production.
  The 3D Modeling assembly tree's Origin, Front, Top, and Right rows now own
  view-only workspace-reference visibility. `CADPipelineViewport` derives one
  bounds-scaled reference presentation from the imported document: Metal draws
  an RGB origin triad plus independent wire grids, while Three.js WebGPU draws
  the same presentation with `AxesHelper`/`GridHelper`. Each tree eye toggles
  only its matching reference on both renderers. This state is editor
  presentation only and never enters `.anima` or changes mate semantics.
  The open project owns one persistent spatial viewport layer. Switching among
  Assets, 3D Modeling, Animate, Show, Hardware, or their Table/Timeline/Graph
  center representations now covers or reveals that same layer instead of
  reconstructing it from separate SwiftUI switch branches. Imported Open
  CASCADE geometry, Metal/WebGPU resources, camera position, selection, and
  renderer telemetry therefore survive workspace-tab changes; only closing the
  project or changing the actual geometry/backend tears the session down.
  Selecting a primary Part now adds a second, part-local RGB origin triad on
  Metal and Three.js WebGPU. The shared pipeline expands the existing
  source-to-node mapping into one column-major rest-transform map using
  AnimaCore's intrinsic XYZ convention (`R = Rx · Ry · Rz`), then hands the
  same selected-origin presentation to both thin draw adapters. The Inspector
  exposes the corresponding editable values under **Part origin (in
  assembly)** with metre position and degree rotation fields; edits continue
  through the existing AnimaCore-backed rest-transform path.
  The production Metal viewport now performs real Part picking instead of
  treating a click as a no-op. On a click without a navigation drag, it
  unprojects the pointer with the exact shared camera matrix, intersects the
  nearest visible transformed triangle, and reports the existing node-plus-one
  Part ID through the same source mapping used by Three.js. Hidden Parts are
  excluded, empty space clears selection, and Shift or Command extends the
  current selection. This is presentation-only hit testing; it adds no model
  or mate meaning to the renderer.
  CAD Parts now also consume that shared transform map: Metal updates the
  already-bound `partTransformBuffer`, while Three.js sets each node mesh's
  column-major `matrix` with `matrixAutoUpdate = false`. Neither path rebuilds
  imported geometry for a transform edit. A renderer-independent selected-Part
  overlay supplies local X/Y/Z translation and rotation handles; its pointer
  deltas produce rest-transform edits through the existing guarded workspace
  setters, so the mesh, local origin, and numeric Inspector stay synchronized.
  The overlay is anchored to the selected Part or sub-assembly frame rather
  than the viewport center. Metal projects that frame with the exact shared
  render view-projection matrix, while Three.js reports its helper's projected
  world origin through the existing web bridge. The control follows camera and
  transform edits and hides when its origin is behind the camera or offscreen;
  there is no cosmetic center-screen fallback. Direct manipulation measures
  pointer deltas in the stationary viewport coordinate space, so rotating or
  moving the overlay cannot invert Y or feed its own motion back into the
  gesture. Screen-up follows the displayed green Y arrow. The web projection
  path retains its last valid anchor until the next rendered position arrives,
  preventing the control from being removed and recreated between drag frames.
  Grounded Parts now remain visibly fixed throughout that same flow. The
  pipeline expands `Part.isGrounded` through the shared source-to-node map;
  Metal consumes a retained Part-state bit and Three.js consumes the same
  grounded Part IDs to draw a blue fixed cue, with active selection still
  taking precedence. The transform overlay and Inspector identify the pinned
  state and disable editing, and the workspace rest-transform setters reject
  grounded edits so the engine-owned placement cannot be moved indirectly.
  Sub-assemblies are now first-class editor hierarchy nodes with their own
  assembly-space origin/rotation and optional parent. Both assembly trees show
  acyclic nesting. Selecting a sub-assembly highlights every descendant Part
  and displays the shared origin/transform overlay; Inspector exposes the same
  frame numerically. A group move computes one rigid assembly-space delta and
  applies it to descendant group frames and canonical Part rest transforms, so
  Metal and Three.js continue drawing the existing common Part-transform map.
  Hide acts on all descendant presentation states, and Ground batches the
  descendant engine Part states through AnimaCore before one reload. Metadata
  v6 persists the hierarchy/frame and decodes older flat groups at the identity
  frame. Group metadata does not define mate semantics or introduce a Swift
  assembly solver.
  Selection presentation now uses those same semantic descendants everywhere:
  a selected Part receives the configured CAD selection highlight, while a
  selected sub-assembly highlights every descendant Part. The local-frame
  translation/plane/rotation gizmo is placed at the center of the rendered
  selected bounds (one Part or the combined sub-assembly) rather than at an
  arbitrary stored frame origin. Gizmo edits are mapped back to the canonical
  Part/group rest transform, preserving AnimaCore coordinate-frame ownership;
  local bounds are cached once and only eight corners per Part are transformed
  while dragging.
  The CAD right rail now has four real, independent surfaces instead of routing
  every icon to the former all-in-one appearance panel: Camera & Display owns
  renderer selection, telemetry, camera home, reference geometry, edges, and
  selection colors; Environment owns the coordinated preset, background, and
  key/fill/rim lights; Part Appearance edits the selected Part's persisted
  color/PBR finish/opacity plus imported-CAD defaults; Inspector remains the
  workspace's selection-aware context panel. Selected-Part appearance metadata
  is consumed live by both MetalKit and Three.js WebGPU. Raw WebGPU remains an
  explicitly labelled diagnostic renderer and does not expose a misleading
  per-Part material editor. The imported-model fallback color also states why
  it has no visible effect when an imported STEP/XDE face color is preserved.
  The 40-Part/60-FPS target still needs an operator benchmark on production
  hardware; automated coverage proves transform identity/order and edit math,
  not a display-link frame rate.
  The root-app builder follows the linked Homebrew OCCT Mach-O dependency
  graph, copies the required dylibs into `Contents/Frameworks`, rewrites them
  to `@rpath`, and signs them with the app. The local Homebrew bottle targets
  macOS 26; a release for older supported macOS versions must build/vend OCCT
  with the product deployment target before notarization. Verification passes:
  recursive Swift format lint, 321 XCTest tests, 26 Swift Testing tests, the
  native Xcode build, root-app rebuild, strict deep signing, a scan proving no
  absolute Homebrew dylib links remain, and a clean root-app launch. Synthetic
  topology and malformed-STEP crash containment are automated; a user-supplied
  production STEP assembly remains the final manual import walkthrough because
  the prior CAD DEMO corpus is absent from the current working tree.
- **Production Studio interface:** the real Swift app under `app/` now uses one
  shared `StudioWorkspaceScaffold` for every workspace without replacing its
  AnimaCore, project, import, selection, timeline, or RealityKit behavior. The
  frame has one center and three deliberately separate authorities: the
  centered top Tool sidebar creates or modifies model content; the left
  Workspace sidebar chooses what content is being worked on; and the right View
  sidebar controls camera, environment, appearance, and inspection. Both side
  rails use one panel-stack engine and default to no selected panel. Each tab
  independently opens or closes its panel, so several panels can stack in rail
  order. Floating panel headers reorder with a panel-width insertion line or
  tear off into canvas-clamped windows; a torn-off window re-docks when returned
  near its home edge. Opening and closing stacks use mirrored edge transitions
  beneath a higher rail layer, so neither side can cover or disable its icons
  during animation. The rail remains vertically centered independently of the
  growing stack, and a persistent setting can put panels on the outer edge while
  retaining the margin. Tool and camera navigation modes are mutually exclusive,
  only one tool can be armed, and the shared prompt bar owns repeat,
  background-click commit, and Escape/cancel behavior.

  One app-global layout state drives exactly three Studio modes. Floating keeps
  the center full-bleed and overlays content-sized translucent pill sidebars,
  vertically centered at the window edges. Docked moves the same sidebar
  content into fixed-width, flat, divided, full-height in-flow side panels;
  the Tool sidebar occupies only the top of the center column and is forced to
  Expanded density. Canvas hides the floating chrome, leaves plain
  capsule handles, and uses 16-point edge hot zones plus bridged zone/sidebar
  hover tracking so reveal does not flicker. Compact, Standard, and Expanded
  tool densities share shell-wide settings. Expanded is the launch default and
  renders one captioned Fusion-style row: catalogs of up to 24 tools show all groups
  together, with horizontal overflow available in a narrow window. A
  divider-free category strip appears only when a catalog is actually larger.
  Animate therefore exposes Transport, Keyframes, Curves, Tracks, and Reference
  as bounded categories; Nodes condenses its ten source families into Canvas,
  Authoring, Logic, Data, AI + Voice, and Outputs. Standard collapses each
  family into a labelled menu. Compact shows one icon per family; selecting it
  opens an anchored visual icon-and-label tool palette without removing
  less-used commands. Sidebar
  tabs live in workspace-observable state, right presentation and camera state
  are app-wide, tool density/category is shared, and the Studio mode is global,
  so switching workspaces or view branches does not reset the shell. The
  pre-scaffold `WorkspaceToolBar`/`WorkspaceRibbonPresentation` rendering path
  has been removed; the retained `WorkspaceRibbonCatalog` is now data consumed
  only by the live shared Tool sidebar. Rig actions carry typed payloads instead
  of parsed command strings and one dispatcher now owns ribbon enablement,
  selection, and execution. The two former rail implementations are one shared
  rail, and the View sidebar edits the same persisted viewport bindings that
  drive RealityKit rather than maintaining a second display-state copy. The
  internal layout case is now named `floating` while retaining its legacy
  `"studio"` raw value for preference compatibility.

  Demo tool catalogs are imported additively through a namespaced adapter.
  Existing production commands always win a title collision; missing
  Character, Rig, Animate, Show, and Hardware concepts remain visible but
  unavailable until their real operation exists. A **Design** destination is
  explicitly labelled as a sandbox. Its six Fusion-style categories (Design,
  Sketch, Surface, Mesh, Sheet Metal, Assemble) arm typed placeholder tools;
  canvas clicks create selectable feature cards, and its
  Documents/Features/Bodies/Mates browser plus editable Part Properties use the
  same production shell. It is not a CAD kernel and does not persist geometric
  semantics.

  The condensed 54-point document header keeps project/save state at the far
  left, all eight workspace destinations in a window-centered capsule, and
  engine, preview, layout, and help controls at the right. Its regions collapse
  independently at the demo's 1320/1060/880-point breakpoints: file commands
  move into overflow first, workspace labels become icons next, and runtime
  labels compact last. Home uses a dedicated Home/New/Open/Settings header
  rather than showing document-only workspace and engine controls. A
  preference-controlled bottom status bar and non-layout walkthrough overlay
  complete the frame. The empty-Rig call to action remains centered in the
  usable viewport. UI Dev retains the actual production specimens. The shared
  Tool sidebar now has three deliberately different densities: Compact is a
  centered category capsule whose icons open anchored labelled tool menus;
  Standard is a centered primary-tool capsule with per-group overflow
  chevrons; Expanded is a captioned group ribbon that hugs its content while
  floating and becomes full-width at the top of the center column when Docked.
  The center content's safe inset follows the selected density so none of these
  presentations clips or covers its content. All 344 XCTest tests and 27 Swift
  Testing tests, recursive format lint, the native Xcode build, root-app helper
  embedding, strict deep signing, and launch pass.
  The empty-Rig call to action is centered in the usable viewport instead of
  inheriting the viewport overlay stack's top alignment.
  The project header follows the compact CAD layout used by the approved demo:
  project identity and file commands remain left, an absolutely centered stage
  capsule shows all workspace names at normal widths and switches the entire
  capsule to icons below its responsive breakpoint, while runtime plus
  Studio-mode controls remain right. The Studio-mode
  control cycles Floating, Docked, and Canvas, and the same global choice is
  available from its menu and Settings.
  The main macOS window uses full-size content with a hidden transparent title
  bar, so the native traffic-light controls share the header's continuous
  surface instead of occupying a separate dark title strip. The Window scene
  explicitly uses content-minimum resizability, preserving standard macOS edge
  and corner resize hit regions/cursors above the 1100x720 minimum. A transparent
  AppKit control area behind the custom document header restores native window
  dragging and preference-aware double-click behavior (zoom, minimize, or no
  action) without intercepting the header's SwiftUI controls.

  Home is now the demo-faithful three-column workspace inside the same app
  window. Its dedicated header carries only app identity and project actions;
  document pipeline, Live, and Preview controls do not appear before a project
  is open. The left column owns direct default-location New, native Open,
  section navigation, and disk-backed recent rows with thumbnails, relative
  time, and revision chips. Workspace-root discovery is unioned with the stored
  recent list on every appearance, unresolved entries are pruned safely, and
  representative rows are shown only when the real list is empty. The middle
  column switches among Get Started archetypes, real recents, and honest
  Character/Library availability states; Hardware Character routes to
  Character authoring, Digital Character is marked Preview, and Show Control
  routes to Show. The right column carries Open & Connected and Learn links.
  New Studio Project creates a unique plain project folder directly beneath the
  configured workspace root without a save-panel interruption.

  The setting-controlled footer is a shared 24-point status surface on Home and
  every open workspace. It reads rather than owns state: workspace name,
  selected Part, renderer-derived triangle count, active render backend,
  viewport theme, and the linked Open CASCADE kernel version. RealityKit mesh
  loading and the retained CAD pipelines publish per-Part/source triangle
  counts to the workspace; no geometry count or renderer preference was added
  to AnimaCore semantics.
- **Character-workspace shell parity:** The production Character workspace is
  split into center collection, left browser, and right import/preview content
  and supplies those pieces to the same scaffold as Rig, Animate, Show,
  Hardware, Nodes, and UI Dev. Its selection and left-tab state are model-owned
  and initialize only once, so changing Studio mode cannot reset the active
  collection or selected Part. The structured collection is intentionally not
  treated like an unbounded 3D canvas: Floating presents it as a rounded,
  content-sized document (300–520 points tall) inside safe top/left/right
  overlay insets, while Docked remains a full-height in-flow table. Canvas uses
  the broad center while its sidebars are hidden, then animates the collection
  inside the same safe boundary when an edge-revealed sidebar enters. Spatial
  3D and node canvases remain full-bleed because only structured center content
  consumes the shell's overlay-inset environment. The Character browser and
  import/preview inspector are likewise content-sized in Floating mode.
- **Timeline-workspace shell parity:** Animate and Show keep their timelines as
  center/bottom structured editors without constraining the spatial viewport
  above them. Docked timelines remain flat, full-width, and in-flow. Floating
  and Canvas render the same editors as bounded rounded windows with a broad
  default width; when a left or right overlay is present—or is temporarily
  revealed from a Canvas edge—the timeline animates inside the published safe
  boundary so transport controls, track headers, keys, and cues are never
  covered. Top-tool clearance is intentionally ignored by the bottom editor.
- **Archived interface walkthrough:** `dev/archive/CodexUI/` contains the
  separate,
  clickable `CodexUI.app`, a presentation-only exploration of a modern CAD
  animatronic authoring environment. It imports no Anima Studio or AnimaCore
  target and performs no project, engine, model, hardware, or filesystem work.
  One consistent native SwiftUI shell provides a workspace selector, three
  visual themes, and a guided previous/next walkthrough across seven
  intentionally different layouts. Its layout now follows the sibling
  AnimaStudio Demo's canvas-first panel language: one reusable browser region,
  inspector region, and workspace tool ribbon can each dock into the layout,
  float inside the app window, or hide and restore. The compact floating ribbon
  omits the workspace name already present in the centered tabs and presents
  tool groups as unboxed icon/label targets on one quiet material pill. It can
  float at the top or bottom: top popovers open below and bottom popovers open
  above, always toward the workspace center; shadow direction, structured
  content clearance, and walkthrough clearance follow the chosen edge. Its
  existing tool groups still open as popovers. Floating, Docked, and Canvas
  presets reconfigure all three regions together, and a native
  Settings window exposes the same appearance/layout contract. Docked regions
  participate in layout and reduce the center area; floating regions instead
  overlay the full-size center so the canvas can use the complete workspace,
  while hidden side panels remain recoverable. Browser and Inspector headers no
  longer duplicate pin/dock controls: the combined header layout control and
  Settings are their placement authorities; side regions have no redundant
  wrapper title bar. In Canvas mode, moving to the thin left or right edge
  temporarily reveals that hidden panel as a compact floating window; leaving
  the edge dismisses it without changing the saved Canvas layout. The floating
  ribbon retains its own edge/placement menu. The header layout control cycles
  Floating, Docked, and Canvas, while its menu exposes both presets and the
  individual region states. Floating presentation retains the strongest
  pattern from the retired Codex Spatial exploration: the full-height sidebar slab and duplicate
  outer header both disappear, and each contained panel becomes a content-sized,
  independently rounded/material-backed widget with its own border, shadow,
  spacing, and visible canvas between cards. Right-side context widgets can be
  dragged independently by their header grip. Dragging uses direct,
  animation-free state updates and temporarily replaces expensive backdrop
  material with an opaque themed surface for smooth pointer tracking. Each
  live update clamps the actual widget frame to an eight-point workspace
  margin, so cards cannot be lost beyond any window edge; material returns at
  rest. Docking clears those offsets and returns the same widgets to a flush,
  continuous, full-height column. Spatial preview cards opt into a reusable 220-point
  minimum content height, so the Assets 3D preview remains a usable viewport
  instead of collapsing like a compact property card. Floating side regions
  cap their invisible layout lane at a
  responsive 72% of the workspace height (using all available space only in a
  short window), leaving visible canvas below and making their detached state
  unmistakable. The walkthrough is a constrained,
  bottom-center in-window popup above the status bar; showing, advancing, or
  dismissing it does not change header, ribbon, or workspace layout.
  Floating-panel clearance is content-aware:
  spatial 3D and node canvases remain full-bleed underneath floating chrome;
  the Rig, Animate, and Show 3D surfaces have no generic card outline, rounded
  mask, or center gutter, so their grids visually become the workspace itself;
  Assets tables, Hardware tables/dashboards, and the UI Kit matrix inset to the
  unobstructed visible area. Animate and Show treat both preview and timeline as
  center content: each spans the full center width beneath compact floating side
  panels, while the timeline reserves only a bottom floating-ribbon clearance.
  The main Rig, Animate, and Show render views share an optional bottom-right
  performance HUD for renderer, frame rate, CPU, memory, and GPU presentation.
  A viewport gauge button and Settings toggle control it; because CodexUI has no
  live renderer backend, its values are visibly marked **Sample** and the card
  says that the real telemetry hook is pending.
  CodexUI now shares the sibling AnimaStudio Demo's restrained surface system:
  near-black/white canvas and panel layers, three-level text hierarchy,
  intentionally subtle strokes, and common accent/success/warning/danger
  colors. Settings offers Studio Blue, Teal, Indigo, Orange, Graphite, CAD
  Light, and Midnight through a visual theme picker; the UI Kit exposes the
  complete surface and semantic token set. Shared panel headers, rows,
  property fields, pills, metrics, command buttons, project save badge, and
  the compact icon-only floating ribbon inherit those rules, so every
  workspace and specimen updates from the same implementation rather than
  copied screen styling. Real light/dark SwiftUI color-scheme switching and
  hover/press/spring feedback cover shared chrome, tree rows, workspace tabs,
  panels, and ribbon tools. The
  scrolling workspace row and duplicate header dropdown have been replaced by
  one centered capsule navigator. It lists all workspaces—Character, Rig,
  Animate, Show, Hardware, Nodes, and UI Kit—with a subtle divider preserving
  the authoring/utility distinction and a spring-traveling active capsule.
  Workspace-tab labels are operator-configurable in Settings as Automatic,
  All Labels, Selected Only, or Icons Only. Automatic keeps all names when
  space permits and retains the selected workspace's name alongside icon-only
  inactive tabs in compact windows. The former global bar plus workspace bar
  is condensed into one 54-point header matching the sibling AnimaStudio
  Demo's density: 24-point icon controls and 28–30-point workspace chips keep
  the stage capsule centered without making the chrome feel oversized. The
  first upper-left element is always the open project identity: a directly
  actionable Home icon, **Atlas Animatronic**, and **SAVED**, including at
  compact widths. The Home icon returns to the project browser without needing
  a second header control. The document bar resolves explicit expanded,
  compact, and minimal densities instead of allowing SwiftUI to crush its
  contents. The editable project-name field follows the rendered name's natural
  width and only caps long names, while save state remains a single-line fixed
  capsule. The centered workspace navigator keeps a protected width, and both
  sides occupy balanced zones around it. File/history commands
  progressively fold into the document menu; at the minimum supported window
  width, Settings and project commands become one overflow menu while
  retaining every action. The centered selected tab owns the current
  workspace/mode name. Settings, project/file access, and undo/redo follow left. Compact **Live**
  status and **Preview** playback capsules remain right. The layout-mode
  control sits at the far right immediately before walkthrough Help: it is
  icon-only, cycles on primary click, retains its complete placement menu, and
  uses distinct cyan/purple/orange/green boxes for
  Floating/Docked/Canvas/Custom so its current state remains readable without
  consuming text width.
  Master Live remains available from the Live popover and Settings rather than
  consuming permanent header width.
  The CodexUI app name and mark are deliberately quiet in the footer. Theme
  and detailed layout preferences remain in the native Settings window. The
  workspaces remain:
  Character (three-column content manager), Rig (semantic tree + CAD viewport +
  mate inspector), Animate (viewport + multi-track keyframe/audio timeline),
  Show (stage preview + multimedia cues), Hardware (device/channel/safety
  dashboard), Nodes (typed visual logic canvas), and UI Kit (reusable panels,
  fields, dialogs, tabs, notifications, material controls, and states). The UI
  Kit now follows the sibling AnimaStudio Demo's living-design-system gallery:
  a 28-point title and explanatory subtitle lead uppercase named sections,
  adaptive 300-point specimen cells use consistent 16/28/30-point spacing
  inside an 1180-point review width, and app chrome, timelines, viewport, and
  Settings receive full-width specimens where their real proportions matter.
  It presents actual shared components including workspace tabs, adaptive tool
  ribbon, production timeline, viewport/performance HUD, panel/row/field/pill/
  metric/button primitives, layout contract, and Settings. A visible 21-of-21
  coverage inventory backed by `UIKitAssetCatalog` establishes the rule that
  every new reusable UI asset must also gain a UI Kit specimen and catalog
  entry. The UI Kit also preserves the useful pieces of the retired Codex
  Spatial prototype. The interactive selection rail and adaptive keyframe
  actions remain one useful grouped control without a redundant outer panel;
  the UI Kit also includes a combined
  hierarchy/revolute-mate/live-hardware stack, and a full-width four-track
  Live Follow timeline with keyframes, playhead, and audio waveform. Its Nodes
  section now renders the same reusable node card, categorized library,
  selected-node inspector, typed-port row, and connected canvas as the Nodes
  workspace. Input, logic, AI/media, and hardware cards show normal, selected,
  and warning states; a full-width graph demonstrates connections, canvas
  status, zoom, and auto-layout controls. The node graph is a full-bleed
  workspace surface like the 3D viewport: it has no generic rounded mask or
  enclosing outline, while its node cards and controls retain meaningful local
  boundaries. Twelve
  deterministic catalog/tour/layout/header-density/drag-boundary/UI-Kit-coverage tests,
  recursive Swift format lint,
  debug/release builds, deep signature verification, launch, and process-health
  verification pass. The prototype is retained as a read-only design-history
  reference after its approved system was migrated into the production app.
  Its launcher also reuses an existing
  CodexUI process rather than forcing duplicate instances. The separate
  `dev/Codex Spatial/` source and app were removed after those useful specimens
  were consolidated here.
- **JaegerOS pin:** not yet set — for now the runtime is standalone and
  Jaegers read `.anima` files natively; the `jaeger-os` dependency and
  `animation`-slot module land later (see `dev/docs/roadmap/`)
- **What works:** the native macOS foundation under `app/` builds both as a
  Swift package and as a real `Anima Studio.app`. The checked-in Xcode project
  is reproducibly generated from `project.yml`, with a thin native lifecycle
  target over the reusable `AnimaStudioUI` package, shared Debug/Release
  `.xcconfig` settings, least-privilege sandbox entitlements, localized-resource
  support, an asset-catalog app icon, a launch-level UI-test target, and Xcode
  Canvas previews for the home, complete workspace, and animation timeline.
  `app/Scripts/build-root-app.sh` assembles an ad-hoc-signed development app
  at the repository root for direct Finder launch. The root bundle now embeds
  a signed Python 3.11 helper, AnimaCore source, and PyYAML dependency; the
  helper inherits the app sandbox and requires no repository path or active
  virtual environment after the app is assembled. Packaging rewrites both the
  Homebrew framework launcher and its nested `Python.app` launcher to resolve
  only the bundled framework, explicitly re-signs that nested app, and fails the
  build if either launcher still references Homebrew. `AnimaModel` defines project
  assets, stable semantic-part IDs, box/cylinder/sphere/locator rig proxies,
  metre positions, XYZ rest rotations in radians, backward-compatible Codable
  rest transforms, joint parent/child connections, optional part-local mate
  connector frames (origin plus primary/secondary axes), connector alignment,
  joint rigs, clips, hold/linear keyframes, and Codable project round-tripping.
  `AnimaEvaluation` still provides the pre-bridge transitional preview evaluator,
  but new animation meaning belongs in the canonical Python engine rather than
  this Swift module. A dedicated `AnimaCoreClient` now owns the typed newline-JSON
  protocol, long-running helper process, handshake, character load/validation,
  frame and character-space pose evaluation, release, shutdown, engine errors, and
  channel-index decoding.
  The Assets ribbon can import a `.character.anima` document, load it through
  AnimaCore, evaluate its first clip at a deterministic preview time, and request
  the engine's per-part character-space transforms through `resolve_pose`. Studio creates
  one renderer-only proxy per engine part and applies the returned metre
  positions and real-last quaternions directly in RealityKit at the playhead;
  it no longer infers a second hierarchy, connector frame, or mate motion in
  Swift. Continuous playhead evaluation is live for imported engine clips.
  General mate/clip character mutation, scene loading/playback, and hardware
  output remain subsequent bridge packets. The SwiftUI app launches into a
  Bottango-inspired dark home screen with working New Studio Project and Open
  Project actions. Its Recent Projects section uses compact thumbnail
  cards with the project name, actual last-opened timestamp, revision badge,
  and optional milestone metadata. Records are recency-sorted, deduplicated,
  capped at twelve, and stored as versioned user-local metadata. Cards load a
  cached render path when one exists and otherwise show an honest project-type
  preview. Hovering a card reveals a top-right remove control, and the same
  forget-only action is available from **Remove from Recents** in its context
  menu; neither path touches the project folder. Recents are pruned on load
  when neither their security-scoped bookmark nor fallback path resolves to an
  existing directory, and a missing project discovered on click disappears
  immediately as well. Records carry the real project-folder path plus a
  security-scoped bookmark; clicking a card reopens the folder, reads its
  manifest, and loads its active character through AnimaCore. A standard macOS
  **Settings** scene is available from the app menu and Command-comma. It uses
  one grouped sidebar with nine complete pages: Workspace, Layout, UI,
  Renderer, Appearance, Materials & Edges, Lighting, Navigation, and
  Developer. Workspace owns the single default project root
  (`~/Documents/AnimaStudio/` initially), supports
  choosing/revealing/restoring the folder, and persists custom roots with an
  app-scoped security bookmark. New Project, Open Project, and Save As all
  create this exact root before configuring their native panels, so first run
  cannot silently fall back to the Documents parent. Because macOS App Sandbox
  does not provide a static Documents entitlement, first use presents a focused
  folder picker: the operator selects Documents once, Studio creates
  `AnimaStudio`, stores its security-scoped bookmark, and opens the project
  panel there. Later launches go straight to that root. Stored references to
  the old spaced default migrate to `AnimaStudio`, while real custom roots
  remain unchanged. Navigation embeds the existing CAD mouse profile,
  bindings, response, and reverse-wheel controls rather than presenting a
  separate sheet. Renderer, Appearance, Materials & Edges, and Lighting expose
  the existing production viewport controls without duplicating their state.
  UI owns the design preset, accent, tool density, floating chrome, and footer.
  Developer owns the live visible-zone diagnostic and independently persisted
  visibility switches for Nodes, Design, and UI Dev; hiding an optional
  workspace removes only its tab, never its implementation. A
  launch-only invalid Recent Projects SF Symbol that previously prevented
  window construction for operators with saved recents is also corrected. A
  new project now opens as a genuinely empty project in the first **Character**
  workspace rather than silently inserting the sample mechanism or jumping
  ahead to Rig. Character is now a dedicated character-management surface backed
  by `project.json`: it lists every indexed character, marks and switches the
  active character used by Rig/Animate, and gives an empty project a prominent
  first-character action. New Character validates a project-unique name and
  offers the live **3D Character** rigid-parts pipeline alongside a visibly
  disabled, honestly labeled **2D (Live2D-style) — coming later** option. On
  creation the document layer adds `characters/<name>/`, while AnimaCore
  validates and serializes the zero-part canonical character; Swift never
  hand-formats its YAML. The new character then enters an in-app 3D loading
  stage with file drop/picker controls, progress, and inline errors. The
  Assets workspace now uses the same three-column grammar as the other
  authoring workspaces: a persistent shared-`TreeView` character tree on the
  left, one context-sensitive collection surface in the center, and a compact
  import tool plus live RealityKit selection preview on the right. The current
  project name and revision appear once in a compact non-tree header;
  **Project Characters** is the sole production tree root, so the active
  project is not redundantly nested as a folder around its own contents.
  Character Library, Parts Library, their rail tab, and the Publish affordance
  are intentionally hidden for the current production-test phase; their
  underlying storage remains dormant rather than being deleted.
  The tree does not invent a parallel catalog: Parts, mates/relations/groups,
  clips, and scene scripts project the retained engine/project data, while
  material/appearance rows project the active character's `editor.json`.
  Source assets are scoped to the active character. Every center collection
  now uses the same Table/Grid component: Table is the default, collection-
  appropriate headers remain visible at zero rows, filtering is shared, and
  empty bodies consistently say **No … yet** without duplicating actions. Grid
  is an operator-selectable alternate view. The Parts table and grid use
  standard anchored selection: plain click selects one row and establishes the
  anchor, Shift-click selects every visible row in the inclusive range,
  Command-click toggles one row, and Command-Shift adds an inclusive range.
  Selecting a row gives the collection keyboard focus, so Backspace/Delete and
  Forward Delete reliably open the same confirmed bulk delete as the toolbar
  and context menu. Deletion edits the retained
  engine rig DTO, removes dependent mates, relations, outputs, and clip values,
  validates/serializes through AnimaCore, and prunes only model files no
  remaining part references. Parts show source, parent, engine state, and a
  deliberately simple app-side asset version: initial import is V1, while
  **Replace Part** or importing the same original filename again replaces the
  existing package asset and increments the integer in `editor.json`; no
  duplicate part or PDM/history system is implied. The collection surface is
  pinned to the top
  and fills the center column. The right Preview always remains a live 3D
  viewport, even before geometry is selected or imported. Dense CAD imports no
  longer crash the viewport: the CAD-selection topology (coplanar-face / edge /
  corner extraction) is skipped above a per-file triangle budget
  (`maxTopologyTriangles`, 40k), so a heavy part still loads and renders with
  whole-part selection while small parts keep face/edge selection. Model
  parsing already runs off the main thread and per-file import errors fall back
  to a placeholder body, so one bad file cannot crash an assembly load. Scaling
  further (hundreds of parts, GB workspaces) is planned in
  `dev/docs/roadmap/Loading_At_Scale.md`. A separate user-level Parts Library branch is visibly scaffolded
  for future cross-project reuse and is not stored in `.character.anima`.
  The
  workspace-model initializer accepts an alternate startup
  workspace so a future operator preference can choose it without changing
  workspace semantics. Its Bottango-inspired **Add to
  Rig** palette creates real core-backed box, cylinder, sphere, and empty-point
  proxy components with their local origin at the workspace origin, then
  creates all eight kinematic mate types through one explicit two-step
  placement flow. Orange,
  hover-reactive connector markers appear only while the mate-placement tool is
  active and expose proxy face centers, edge midpoints,
  corners, cylinder axes/circular centers, sphere cardinal points, and component
  origins. The first selection is the moving component; the second is fixed.
  For a loaded character, both connector frames are sent through AnimaCore's
  `add_mate` bridge mutation; the engine validates the full rig, returns the
  refreshed canonical DTO, and `resolve_pose` immediately supplies alignment
  and motion. A local Revolute draft remains only as an isolated no-engine test
  compatibility path and is not the production source of mate meaning.
  The two-click production flow now previews that alignment before committing:
  after the fixed connector is chosen, Studio sends the candidate joint through
  AnimaCore's non-mutating `preview_mate` verb and applies the returned
  character-space transforms. Connector flips, 90-degree secondary-axis
  reorientation, and offsets re-preview live; Cancel restores the last
  committed pose, while the green confirmation remains the only action that
  calls `add_mate`. The engine rejects cyclic candidates during preview and
  commit. STEP face, edge, vertex, and loop picks also display the inferred
  connector's complete local frame as a red-X, green-Y, blue-Z triad instead of
  a generic point marker.
  Component names, XYZ positions, XYZ rest rotations, and mate names, axis,
  parent/child
  connection, and angular limits are inspectable/editable in memory. The Rig
  ribbon presents the complete ten-type family: Fastened, Parallel, Slider,
  Revolute, Cylindrical, Pin Slot, Planar, Ball, Width, and Tangent. All ten are
  backed by the engine catalog for inspection. Fastened, Parallel, Slider,
  Revolute, Cylindrical, Pin Slot, Planar, and Ball are live engine-backed
  creation actions. Width and Tangent stay visible but disabled until their
  geometry-specific surface-selection flows are complete.
  The production mate inspector is also engine-backed: connector A/B flips,
  offset enable/XYZ/rotation axis/angle, primary-axis flip, secondary-axis
  rotation, simulation connection, and every DOF's minimum/maximum/neutral are
  editable in operator units. Apply preserves the complete engine joint DTO,
  calls `update_mate`, refreshes the canonical solved pose, and retains the
  stable mate selection; Revert restores the last engine snapshot. Invalid
  limits are caught before submission and engine errors leave the draft intact.
  The mate inspector's Type row and UI Dev lab list the same family
  with per-kind DOF summaries. The Python rig model
  carries the same eight-type kinematic family (`JointType`, including
  `parallel`: XYZ translation + Z rotation) with per-type DOF templates,
  optional per-DOF limits, and gear/rack-and-pinion/screw/linear
  relations, plus two 0-DOF **geometry-constraint** mates — `width`
  (center a tab between two faces, no offset) and `tangent` (keep two
  surfaces in contact; non-driving, deferred with no geometry kernel).
  The engine recognizes, round-trips, and catalogs the geometry pair but
  their geometry is resolved app-side (`mate_category`); `width` resolves
  like a 0-DOF fastened once the app supplies its two midplane
  connectors, `tangent` leaves its child at the parent frame. The
  mate-authoring model lives in `animacore/mates.py`: every kinematic
  mate exposes one universal `MateControls` set — two flippable
  connector frames, an as-mated offset, a whole-mate primary-axis flip,
  a 90°-step secondary-axis reorientation, and a simulation-connection
  toggle — shared identically across all eight kinds, with only the DOF
  set differing per kind, plus a stable per-mate `id` distinct from the
  editable name; `width` reuses that control set minus offset/secondary,
  and `tangent` carries a two-selection `tangent` block instead of
  connectors. Two UI hooks surface it: the `mate_types` bridge verb (now
  ten schemas, each with `category`/`drivable` — static per-kind catalog
  of label, DOF slots, control ids) and `describe_mate` (per-instance
  descriptor carried in the `load_character` joint summary, with
  `category`). The Swift bridge mirrors category, drivable state, DOF axis,
  optional connector controls, and the Tangent-specific surface payload as
  typed DTOs and requests the engine-owned catalog when it connects. The Swift
  client also exposes AnimaCore's `add_mate`, `update_mate`, and `remove_mate`
  mutations. Its live bridge test proves add → update → evaluate → remove, and
  the workspace integration test proves two connector clicks → Fastened mate →
  canonical resolved pose → serialize/reload without a second Swift solver. Imported
  engine mates are listed in the real Components navigator by their stable
  tracking id, so a zero-DOF Fastened mate remains selectable rather than
  disappearing from the rotational preview projection. Selecting one opens a
  reusable engine-driven mate inspector showing its type/name/id, parent and
  child, both connector frames and per-side flip state, offset values formatted
  in millimetres/degrees, whole-mate axis flip/reorientation, simulation
  connection, and its engine-supplied DOF rows with explicit axes. Fastened
  presents an explicit fully-bonded zero-DOF state; Width and Tangent present
  distinct non-drivable geometry-constraint states, and Tangent shows its two
  opaque surface selections plus propagation. Motors, 3D Models & Media, and Events are also
  present as clearly disabled reference groups rather than fake working
  features. The Rig ribbon also consumes AnimaCore's `relation_types` catalog
  and presents Gear, Rack and pinion, Screw, and Linear in engine order. Each
  opens one shared draft dialog whose Driver and Driven pickers are filtered by
  the engine-declared rotation/translation kinds. The dialog shows the positive
  Relation ratio or Distance per revolution field, a separate Reverse direction
  checkbox, a driven-offset field in the driven DOF's display unit, and a
  signed-native-ratio preview. Create validates distinct compatible DOFs,
  prevents a second relation from driving an occupied DOF, converts
  distance-per-revolution millimetres to the engine's metres-per-radian
  convention, and calls `add_relation`. Imported `load_character.relations`
  entries appear in the navigator with a dedicated inspector for their paths,
  ratio, offset, reverse state, and reference geometry. Magnitude, reverse, and
  driven offset are editable with Apply/Revert through `update_relation`;
  suppress and delete also use the canonical engine mutation verbs. Every
  successful mutation replaces Studio's retained full-fidelity rig from the
  engine response, refreshes `evaluate`/`resolve_pose`, and persists through
  engine serialization/reload. Selecting a relation resolves both DOF paths to
  their engine mates and highlights the two corresponding child components in
  RealityKit. Dependency ordering, coupling motion, limits, and sign meaning
  remain exclusively engine-owned. Its project
  window now uses a CAD-style two-level header: a compact global document/live
  row followed by one full-width contextual command ribbon. A fixed far-left
  dropdown switches Assets, Rig, Animate, Show, Nodes, and Hardware with Command-1…6;
  the former workspace-tab row has been removed. Each workspace replaces the
  ribbon with focused, grouped tools. The selector now keeps a readable
  228-point minimum width and uses an anchored, visually continuous workspace
  popover with large icon rows, purpose text, selected-row emphasis, and visible
  Command-1…6 shortcuts instead of the cramped detached system menu. Assets
  exposes Import, Manage, and Prepare; Animate exposes Transport, Keyframes,
  Curves, Tracks, and Reference;
  Show exposes Sequence, Clips, Events, and Sync; Hardware exposes Connection,
  Outputs, Mapping, Calibration, Safety, and Monitor. Implemented commands are
  live, while backend-dependent commands remain visibly disabled as planned.
  **Nodes** is a dedicated scene-logic planning workspace with a dark dotted
  canvas, draggable and selectable typed sample nodes, live curved flow edges,
  a searchable node library, a selection-driven inspector, structural
  validation feedback, zoom/grid/frame controls, add/delete/reset actions, and
  a compact timeline concept that explicitly presents graph and timeline as two
  views of one future scene document. Flow, performance, timing, and event
  families are available in the UI draft. The concept library now separates
  Inputs, Voice & AI, and Outputs, with placeable STT/TTS/LLM, memory, tool,
  microphone, text, event, audio, motion, screen, LED, and hardware cards.
  The library also includes FANUC-inspired structured logic concepts: IF/ELSE,
  single-line IF guards, SELECT, CALL, WAIT Until, AND/OR/XOR/NOT, input reads,
  output writes, numeric registers, flags, position registers, background
  monitors, and monitor-only End Scene. Typed ports and inspector properties
  show the intended manual scene syntax so future Visual and Script editors can
  project the same program. JMP and LBL exist only as red IMPORT ONLY reference
  cards and validation errors; Anima scenes require the structured Loop, SELECT,
  and CALL equivalents rather than irreducible jump flow.
  Typed visual ports and editable sample properties support UI review, while
  every concept stays validation-blocked from execution until its runtime
  provider ships. This surface does not
  yet load, save, compile, execute, or author connections in `.scene.anima`;
  the in-memory draft is intentionally not a second runtime model.
  A shell-level **UI Dev** workspace follows the project-authoring workspaces
  and Design sandbox in the selector without becoming saved character data. Its ribbon
  opens Windows, Interaction Labs, Controls, and Foundations galleries for the living Studio UI
  standard: action hierarchy and states, labeled/unit-aware inputs, native
  menus, reusable panel chrome, blocking dialogs, contextual popovers, and
  semantic color/geometry tokens. Canonical reusable styles now cover primary,
  secondary, quiet, destructive, selected-icon, card, and popover treatments.
  UI Dev's Agent command toggles a right-side panel constrained inside the main
  app canvas, with voice/chat/docs/ideas presentation, prompt starters, a
  composer, and an explicit close affordance. It is labeled as a UI prototype;
  microphone and Send remain disabled until an agent service is connected.
  Navigator, Inspector, Timeline, and 3D View commands now render the real
  production surfaces inside the UI Dev canvas in their operator-facing dock
  regions: Navigator on the left, Inspector on the right, Timeline below the
  viewport, and the 3D view in the center. They use an isolated sample rig and
  never create auxiliary AppKit windows. The Agent likewise remains a real
  right-side app panel. One explicitly labeled **Detached Window** is the sole
  floating UI Dev surface; it demonstrates the always-above-workspace utility
  panel pattern for compact temporary tools and reuses one saved panel instance.
  UI Dev opens on an **all-surfaces Template Matrix**: thirty-six current app
  specimens grouped into Windows & Workspaces, Timelines & Editors, Inspectors,
  Panels & Tools, Dialogs/Menus/Popovers, Buttons & Inputs, and Status & Empty
  States. Every specimen is visible together in a responsive board and names
  its intended production size. The board includes the real reusable Recent
  Projects cards, docked Agent, detached-tool template, and live scaled Mate
  Editor and triad labs alongside Navigator, viewport, timeline, appearance,
  hardware, context-menu, control, and feedback specimens. A stable catalog
  guarantees every current template ID belongs to one visible section. A
  separate **Variant Board** preserves that matrix while adding a wide,
  component-board comparison of twenty-six states across Workspace Chrome,
  Docked Panels, Inspectors, Timelines, Toolbars, Dialogs/Menus, and Status.
  Its search and family filter narrow the visible comparison without mutating
  the catalog; 50–110% density controls resize the four-column board, and any
  specimen can be focused with a visible dashed selection outline. The ribbon
  also exposes a dedicated **Reference Widgets** lab for visual patterns
  being tested before production adoption. Pack 01 implements three interactive
  SwiftUI references: a layered icon list with hierarchy disclosure, selection,
  hover, tags, and trailing state/type icons; a dismissible/restorable
  notification popup with a primary-controller choice; and a two-column layout/
  style inspector covering display mode, corner and border treatment, editable
  box-model spacing, background mode, and clipping. The same three reusable
  specimens appear in the global Template Matrix. Pack 02 adds two interactive
  tab patterns: a compact primary-command/settings panel with shortcut labels
  and a live Light/Dark segmented switch, plus a multi-document strip with
  macOS window context, tab selection and hover states, per-tab close controls,
  and new-tab creation. Both tab specimens are isolated in a dedicated source
  file and appear in the same matrix. Pack 03 adds a dedicated interactive
  Material Editor reference with a live HSB-driven preview sphere, editable
  name and surface type, native color selection, six selectable and independently
  enabled material channels, Float/Texture inputs, per-channel value and mix
  controls, locking, and explicit Node Editor/Assignment/Help feedback. It is a
  UI-only draft until renderer material, texture-asset, assignment, and document
  contracts are defined. Pack 04 adds **Timeline Design B**, an interactive
  multi-row animation lab with Dopesheet, Motion Curves, and Waypoint Lanes
  projected from one shared track/keyframe model. Operators can add rows, click
  empty row space to create sorted bounded keys, select and delete keys, add a
  key at the playhead, scrub the ruler, and switch presentations without losing
  state. Every variant draws the authored motion connection between waypoints;
  Motion Curves uses a smooth value-aware path while the other variants use
  direct readable segments. The Dopesheet is the default reference presentation
  and now follows the supplied compact editor more closely: its chrome is denser,
  the channel column is searchable, a Summary lane aggregates authored keys, the
  ruler uses 0–240 frame numbers at 30 fps, and the blue playhead reports its
  current frame in both the ruler and status footer. This remains a UI Dev
  comparison and does not
  replace the production Animate timeline yet. Pack 05 adds six reusable
  **Concept Template Cards** for rig organization, AI node-flow generation,
  tools/resources, assembly import, motion sequencing, and character outputs.
  The responsive cards provide purpose-built illustrations, title/detail/action
  hierarchy, hover and selected states, and explicit prototype-action feedback;
  they are available in both Reference Widgets and the Template Matrix. Pack 06
  adds an interactive **Icon Selector & Theme Lab** with a hover/select icon
  dock and Edit/Duplicate/Delete menu patterns. The same specimen switches
  among isolated Light, Dark, Graphite, Midnight, and Neon palette specs;
  selected-icon foreground colors are contrast checked. These palettes remain
  local to UI Dev until human review and a deliberate refactor of the app's
  dark-only appearance assumptions. None of these reference widgets is wired
  into an
  operator workflow until it is reviewed and adopted there. The separate
  **Live UI Kit** remains available with a resizable Design Inspector
  beside a production-component catalog. The inspector edits the shared Studio surface
  and semantic colors, muted/border strength, chrome and ribbon heights, panel
  radius/padding, field and control geometry, and Navigator/Inspector/Agent
  widths. Changes are range-validated, applied immediately through the same
  `StudioPalette`/`StudioMetrics` source used by the rest of the app, and saved
  automatically as a versioned user design profile. Standard, Compact, and
  High Contrast presets, destructive reset confirmation, JSON import/export,
  and copy-as-JSON are live. The adjacent kit lays out the docked window map,
  all canonical button states, production fields, menus, popovers, panel
  chrome, and direct links to the real embedded surface previews.
  A separate **Demo UI Kit** section now preserves the incoming demo vocabulary
  additively under `DemoKit*` names so no production component is overwritten.
  Its responsive gallery renders the layout rows, fields, cards, chips,
  commands, notifications, dialogs, progress/status overlays, mate/curve/
  environment/visualization inspectors, performance HUD, node cards, ViewCube,
  gizmos, document tabs, and full-width dope-sheet/feature timelines together.
  This is a living comparison surface for later consolidation, not a second
  product theme or persistence model.
  UI Dev also includes a dedicated **Nodes** tab rendering the production-sized
  node workspace in place so its library, canvas, cards, ports, edges,
  inspector, and timeline can be refined alongside the rest of the living UI
  standard.
  Its Mate Editor interaction lab uses one shared Onshape-style panel for the
  complete ten-mate family. A stable icon strip and full-width Type dropdown
  both switch that panel; the title, degrees-of-freedom readout, constrained
  translation/rotation Offset controls, and optional minimum/maximum Limits
  rows update from the selected kind. Slider exposes Z translation limits,
  Revolute exposes Z rotation limits, compound mates expose every permitted
  freedom with mm/degree units, Fastened explicitly has no motion limits, and
  Width/Tangent are labeled as 0-DOF geometry constraints.
  Connector picking, simulation-connection disclosure, accept/cancel,
  flip/reorient, preview, and solve affordances remain shared rather than
  duplicated per mate. Its Triad Manipulator lab provides a code-drawn,
  hoverable/drag-responsive center ball, XYZ translation arrows, rotation
  rings, plane pads, ghosted restricted motion, live units, and controls for
  handle scale and stroke weight. Both are explicitly design prototypes for
  refining operator readability and interaction; they do not claim the planned
  canonical authoring-mutation/DriveTarget path is shipped; only Revolute
  remains a local Rig draft action until that path lands.
  Rig preserves Structures and the complete Mate family and adds focused
  Connectors, Assemble, and Inspect groups before the planned Motors, 3D Models
  & Media, and Events groups. Its creation families stay docked in the ribbon
  rather than floating over the viewport; collapsing them restores a compact
  Rig tool row. Panel visibility
  remains independently restorable in-session for the navigator, inspector,
  and bottom editor. Assets
  centers import and hierarchy inspection; Rig centers components and mates;
  Animate owns the working timeline dock with transport, every clip motion
  track, clickable keyframes, click/drag scrubbing, adjacent-key and frame
  stepping, a real loop-preview toggle, horizontal zoom, and configurable
  24/25/30/60 fps timecode over continuous seconds. Its Dope Sheet includes
  honest empty Audio/Event capability lanes and switches to a read-only Graph
  presentation of hold/linear curves; selecting mates isolates their curves.
  Show has a distinct multi-track
  character/audio/screen/event timeline scaffold. Hardware now retains
  AnimaCore's native output endpoints and provides a real mapping table/editor:
  bounded rotational DOFs display in degrees, bounded translations in
  millimetres, and parameters as unitless values; channel numbers and 0%/100%
  endpoints can be added, edited, reversed, or removed. Every edit mutates the
  retained full-fidelity rig DTO, then passes through
  `serialize_character`/reload so AnimaCore validates the target, bounded range,
  and unique channel before it can be saved. The Hardware Outputs navigator and
  Map DOF/Range/Reverse tools open this same center surface. Driver connection,
  arming, calibration, and traffic logs visibly remain safely offline and
  editing never arms hardware. The gear settings menu stores a user-local viewport
  appearance choice with Midnight, Graphite, CAD Light, and Blueprint presets;
  each changes the RealityKit background and major/minor grid colors without
  altering project data. The viewport now provides a readable grid and a live
  view cube driven by the same camera state as RealityKit. It mirrors manual
  orbit/pan/zoom changes; its faces, edges, and corners select principal,
  two-axis, and trimetric views, while its surrounding arrows rotate the view
  in 15-degree steps. When a principal face is head-on, curved corner controls
  roll the real camera and cube together by 90 degrees clockwise or
  counterclockwise. A dedicated camera/render menu provides
  perspective/orthographic projection, 30–90° perspective field-of-view
  presets and selection framing. The lower camera toolbar now contains Home,
  Display, and Help; Front, Right, and Top shortcuts are omitted because the
  view cube owns principal, edge, and corner navigation. Display independently
  controls Shaded, Shaded with Edges, Wireframe, Unshaded, and Translucent
  surfaces, mesh-edge visibility, grid, viewport appearance, and
  Balanced/Soft/Bright/High Contrast RealityKit lighting rigs. Shaded proxies
  use physically based materials with Matte/Satin/Glossy/Metallic finishes;
  Subtle/Studio reflection modes now use selectable Neutral Softbox, Cool Rim,
  or Warm Stage generated image-based-light environments with live intensity
  and rotation. Directional shadows remain independently switchable. The
  environment panel retains Midnight/Graphite/CAD Light/Blueprint quick picks
  and adds project-persistent solid and two-color gradient backgrounds. A real
  section view converts render materials to a bundled RealityKit clip-plane
  shader and exposes X/Y/Z selection, numeric/slider position, and a colored
  draggable viewport handle; it intentionally does not yet cap or hatch the
  cut surface. Named camera views save/restore orientation, target, distance,
  and projection in character editor metadata, while Previous View swaps with
  the last completed camera interaction. High-quality rendering enables real
  4x MSAA. Lighting/environment/render-quality choices persist as user-local
  preferences; backgrounds, section state, and named views live in
  `<character>.editor.json`; none enter `.character.anima`. A lower-left
  **Visualization** control now joins the main 3D workspace.
  Its shared Material/Environment widget searches reusable Plastic, Metal, and
  Glass presets, lists deduplicated materials already assigned in the active
  Character, and applies color/PBR finish/opacity to the selected Part through
  the existing `PreviewPartAppearance` editor state. The Environment tab is a
  visual Studio browser with five live presets: Default, Transparent, Colored
  Mood, Gradient Mood, and Black and White Stage. Each card applies the real
  viewport background, generated studio environment, intensity, and rotation;
  Transparent is a true clear viewport-background mode, not a checkerboard-only
  sample. A detailed-settings button still exposes the same background,
  studio-lighting, rotation, and section-plane bindings as the Display menu.
  The production trigger and both browser tabs are also the thirty-sixth UI Dev
  specimen, so their styling remains a shared component rather than a separate
  mock. Material assignment remains renderer-only
  `<character>.editor.json` data and never changes `.character.anima` solve
  semantics. Cube face names are
  affine-projected decals:
  each label is centered in and foreshortens with its projected face quad,
  receives a readability correction rather than becoming mirrored or
  upside-down, and disappears when the face becomes an edge-on sliver. Its XYZ
  triad shares one origin, follows only the positive axis directions, and rolls
  with the same camera orientation; hovering previews the exact clickable face,
  edge, or corner. The viewport also provides trackpad pan/pinch and
  persistent Default, SolidWorks, Onshape, Fusion 360, and Custom mouse
  profiles. Default now intentionally mirrors Onshape: right drag orbits,
  middle drag or Control + right drag pans, and the wheel zooms. SolidWorks
  uses middle drag to orbit, Control + middle drag to pan, and Shift + middle
  drag for precise zoom. Fusion 360 uses Shift + middle drag to orbit, middle
  drag to pan, and Control + Shift + middle drag for precise zoom. Custom exposes
  conflict-free orbit, pan, and precise-zoom chords, including Option-based
  bindings. A dedicated Mouse & Navigation sheet opens from the camera HUD and
  follows the supplied compact control-panel reference: Scroll, Mouse, Buttons,
  Keyboard, Exceptions, and Settings icon tabs; a code-native mouse diagram;
  preset mapping summaries; Custom binding pickers; independent Slow-through-
  Very-Fast orbit/pan/zoom sliders; reverse-wheel direction; and a reset action.
  The settings persist through user-local `AppStorage` and never enter a
  project. Exception-driver integration is visibly labeled Coming later.
  Discrete wheel acceleration is normalized to one fixed notch and Standard
  speed changes distance by approximately 13%; precise wheel/trackpad deltas
  use a smaller clamped coefficient. Trackpad scroll phases still pan, pinch
  still zooms, and reverse direction applies only to wheel zoom. Right-button
  events now use one click-vs-drag router: a click opens the pointer-targeted
  Studio menu, a drag drives the active profile and suppresses the menu, and a
  double middle click returns to the framed home view. Semantic proxy geometry is
  directly selectable in the viewport and resolves to the same stable part ID
  used by the Components tree and inspector. An unmodified viewport click now
  replaces the selection, clicking empty space clears it, and Shift/Command
  explicitly extend it; a small
  cursor-adjacent badge reports multi-selection count. Empty-space drag adds
  directional CAD box selection: left-to-right is a blue solid window requiring
  full projected enclosure; right-to-left is a yellow dashed crossing selecting
  projected bounds it touches. The selected component receives
  an orange silhouette highlight plus local XYZ translation arrows and rotation
  rings at its origin; dragging them edits the core-backed rest transform, and
  connector-authored mate rotation composes through parent/child chains. During
  pointer inspection, semantic proxy bodies and imported model surfaces use a
  cyan preselection glow before left-click commit. Imported STL, OBJ, and
  ModelIO-readable USD geometry now receives a cached topology projection at
  import/reimport time: duplicate mesh vertices are welded, connected coplanar
  triangles become selectable face islands, boundary/sharp-normal edges become
  selectable polylines, and vertices where at least three feature edges meet
  become selectable corners. A hovered face gets a translucent cyan surface
  overlay; an edge or corner gets a crisp cyan overlay with zoom-adjusted pick
  thickness; committed features turn stronger orange while the owning body and
  navigator row stay selected. These mesh features use the same
  `MateConnectorCandidate` contract as proxy candidates, so selection,
  inspection, staged Escape, and two-click mate placement do not fork into a
  second state model. Normal proxy selection no longer draws face-center,
  edge-midpoint, corner, axis, or origin dots over the body; those candidate
  points are placement aids rather than permanent model decoration.
  During any inspectable selection, Studio now restores the right-side Inspector if
  the operator had hidden it. A selected semantic proxy component exposes
  **Properties** and **Appearance** tabs. Appearance provides a 40-color
  industrial palette, an RGB/ColorPicker mixer, editable six-digit hex color,
  explicit RGB values, opacity, visibility, reset, a truthful Automatic
  tessellation readout, and Matte/Satin/Glossy/Metallic PBR finishes. Color,
  finish, opacity, and visibility update proxy and imported RealityKit geometry
  immediately; locked components reject these edits. Overrides persist by
  engine part name in the active character's app-owned
  `<character>.editor.json`, never in renderer-independent `.character.anima`.
  Generated box proxies now default to a mathematically sharp `0 mm` corner
  radius instead of the former hard-coded 35 mm rounding. Their Properties
  inspector exposes an explicit Fillet Radius field in millimetres; the
  clamped view-only value saves beside appearance in editor JSON, reloads
  without changing the engine solve, and legacy metadata defaults to `0 mm`.
  A selected
  semantic component also has a Studio-owned, CAD-ordered viewport context menu. It
  identifies the body and groups property editing, attached-mate navigation,
  show/hide, reversible isolate and transparency previews, mate-guide
  visibility, select-all/clear, Zoom to Fit and Zoom to Selection, lock/unlock,
  transform reset, and Appearance. Context routing now follows the pointer:
  right-clicking the selected component or one of its feature markers opens
  that full menu, while right-clicking empty space opens a compact Show All /
  Zoom to Fit / Isometric canvas menu. Right-drag remains camera orbit rather
  than a selection gesture.
  Isolation and transparency are renderer-only overlays that leave the saved
  rig and underlying appearance override unchanged. Menu commands use the same
  model-owned lock guards as the Inspector and transform gizmo. During
  mate placement, transform handles are suppressed so connector markers own the
  click target. Outside mate placement, the focused component shows the same
  inferred face-center/edge-midpoint/corner/axis/origin candidates as quiet
  cyan markers with view-cube-style hover: pointing at one highlights the
  exact clickable feature before commit-click. Clicking a marker selects that
  feature persistently (stronger cyan treatment) and keeps the owning
  component selected; the inspector shows a read-only Feature section with
  the owning component, feature kind, and part-local origin. Clicking empty
  viewport space now deselects the feature and all components; Escape clears
  the feature first, then component selection, and feature inspection is
  allowed on locked components while locks keep guarding every edit. The
  Instances outline follows macOS file-browser
  selection conventions:
  Command/Shift select multiple, one item opens its configuration, and Escape
  or the inspector close control clears selection. Imported geometry can also
  be selected directly in the viewport, with Command/Shift extending the same
  Instances-tree selection. Viewport selection requests reveal the matching
  row and expands its ancestors; **Go to Item in List** provides the same
  behavior from row and viewport context menus. Instances and **Mate Features**
  render through one generic `TreeView`/`TreeNode` adapter and one pure,
  renderer-independent tree model. Its filter accepts names plus `:part`,
  `:mate`, `:suppressed`, `:grounded`, `:hidden`, and `:locked` tokens.
  Imported assemblies appear in a separate blue, locked **Source Model ·
  Read Only** tree; filtering preserves the ancestors of matching nodes. The
  semantic Components and Mates remain separate editable-role rows in teal and
  purple. Component disclosure groups support contextual rename, move up/down,
  move-to-group, dissolve, and lock/unlock; Mates support contextual rename,
  reorder, and lock/unlock. Every component row is now a full-width drag and
  drop target. Its upper/lower zones show a raised, animated insertion line for
  before/after placement; the center shows a bordered **+ Create Group** target and
  creates an expanded folder containing the target plus the dragged active
  multi-selection. Existing folders accept the dragged selection, while the
  Components heading returns it to top level. Groups and Mates show peer
  insertion lines. Invalid drops (self/descendant cycles, incompatible node
  kinds, or locked source/target) are rejected before feedback or mutation.
  Rows display lock, hidden, suppressed, and grounded state icons. The footer
  and selected-row context menu expose **Group
  Selected (N)** and report when locked selections will be skipped. Locked
  items reject inspector, transform, and organization edits, hide transform
  handles, and locked groups protect their members. Group membership, ordering,
  locks, and disclosure state persist in the character's `editor.json`.
  Source-node inspection explains ownership, source appearance, mapping, and
  reimport prerequisites. Shared theme metrics and
  reusable panel, text-field, picker, readout, and primary-button styles keep
  new Studio windows visually consistent. The sample Rig viewport also renders
  a mate-guide foundation: labeled local XYZ axes, a revolute DOF ring, an
  optional reference plane, and a highlighted limit arc with independent layer
  toggles on every created mate. Project and asset names are also editable in
  memory. The operator-facing import contract is deliberately closed to STEP,
  STP, USD, USDA, USDC, USDZ, STL, and OBJ models; picker and drop flows reject
  Reality, URDF, glTF/GLB, and other extensions before loading. STEP/STP passes
  through the app's Open CASCADE/XDE boundary and preserves assembly labels,
  CAD colors, B-Rep faces, and feature edges in metres. USD-family files load
  through RealityKit; ModelIO converts STL/OBJ geometry into RealityKit meshes
  after an explicit mm/cm/m prompt (STL defaults to mm). Every live model-import
  entry point — the Assets ribbon, center Import/Replace controls, right-hand
  drop-zone click, and navigator footer — calls one explicit native macOS
  `NSOpenPanel`; the Anima Character command uses a separate single-file native
  panel. This replaces competing SwiftUI importer modifiers that could accept a
  click without presenting a chooser. A single
  character-targeted staging sheet reviews the batch, makes its destination
  explicit, explains that source files become rigid Parts, and gives each
  unitless file its own mm/cm/m setting; loading remains asynchronous and
  reports the current file. The destination may be any indexed character in
  the project; Studio safely saves and switches to it before loading. Imports
  default to **Copy into Project** under `assets/models/`; the staging sheet
  also offers **Reference in Place** through a security-scoped bookmark and
  never offers Move. Stable asset IDs in character editor metadata map either
  storage mode to safe relative per-part `model` tokens in AnimaCore's full rig
  DTO. Those tokens are serialized/reloaded by the engine and
  rendered at each part's `resolve_pose` transform. A multi-node USD can create
  persistent semantic parts sharing the same model with distinct `model_node`
  paths. A multi-renderable-node USD is automatically expanded into persistent
  Parts sharing the source asset with distinct `model_node` references. On a
  successful batch Studio saves the project and remains in Assets so the
  operator can review and organize the imported assembly before moving to Rig;
  failed imports stay on Assets with a readable inline error. Unitless-file scale lives in
  `<character>.editor.json`, so save/reopen
  restores the same metre-sized rendering. The complete entity hierarchy is
  projected into value-only nodes with unique sibling paths, shown as a
  selectable Structure outline, and described in the inspector. Package tests
  include real USD hierarchy loading/projection and real STL/OBJ metre-scaling
  bounds, duplicate/unnamed entity identity coverage, hierarchy
  filtering/ancestor retention, frame timecode and stepping, adjacent-key
  navigation, and loop/non-loop playback. The Swift side also ships the
  durable document layer as a UI-free `AnimaDocument` package target.
  `AnimaDocumentStore` saves/loads the version-2 **plain folder** layout:
  `project.json` owns project id/name, dates, revision, milestone,
  character/scene indices, editor state, and an asset table;
  `characters/<name>/<name>.character.anima` and
  `scenes/<name>.scene.anima` remain separate canonical engine documents;
  the Pack-and-Go source store has typed
  `assets/{models,assemblies,audio,video,images,scripts,renders}/` directories,
  created for new projects and backfilled on open. Legacy character-local
  assets remain readable. The manifest never
  encodes the Swift rig or clips.
  The user-level `Character Library/` now stores reusable, self-contained
  Character packages outside projects. Assets distinguishes **Project
  Characters** from **Character Library**: Publish creates/updates a stable
  library UUID with a simple revision counter; Add copies the complete package
  into the Project as a pinned, portable snapshot. `project.json` records
  `source_kind`, `library_character_id`, and `library_revision` without putting
  app bookkeeping into `.character.anima`. Project-local Characters remain
  supported and older version-2 manifests decode them as `project_local`.
  This intentionally prevents a later library edit from silently changing a
  deployed show. Saves are
  atomic (staged temp directory swapped into place — a crashed save never
  corrupts an existing package) and deterministic (sorted keys, stable
  asset ordering: identical input encodes byte-identically). Assets are
  SolidWorks-assembly style: `embedded` copies the payload into the
  package, `linked` records the external absolute path plus a
  security-scoped bookmark, and resolution returns an explicit needs-relink
  state for stale/missing links instead of throwing. Save accepts canonical
  text as an opaque write only after `serialize_character`; that same atomic
  save writes app-owned appearance/tree state to `<character>.editor.json`.
  Open sends the indexed file through `load_character` and restores that editor
  metadata. Save As copies the source folder,
  applies dirty files atomically, increments revision, and retargets the open
  session without modifying the source. Native New/Open/Save/Save As controls
  are live. Successful imports autosave, and reopening through either recents
  or a chosen folder reloads the canonical Character plus its resolved model
  sources. Versioned reusable `.animasm` documents save under
  `assets/assemblies/`, migrate the demo's original assembly JSON on read,
  appear in Rig's Asset Library, and can group or recreate referenced Parts in
  the active Character. Corrupt manifests, unsupported versions, duplicate
  character/scene/asset names or IDs, missing canonical documents/payloads,
  and any path escaping the project are
  rejected with typed, user-presentable errors (traversal is validated
  before the path touches the filesystem). A live integration test proves
  engine load → engine serialize → atomic project save → project reopen →
  engine reload. The Python package skeleton also
  installs with `pip install -e ".[dev]"`. The Python runtime now implements
  the Anima Wire Protocol v0 reference host (`animacore/wire.py` — encode
  HELLO/CFG/FRM/EN/STOP/PING, parse ANIMA/OK/ERR/PONG, 3-decimal normalized
  values), an in-process simulated device (`animacore/sim.py` — handshake,
  servo CFG, device-side linear FRM interpolation on an explicit `tick(now_ms)`
  clock, E-stop, per-channel 2000 ms failsafe, spec ERR codes), and a
  normalized output-track evaluator (`animacore/tracks.py` — hold/linear,
  time and limit clamping, deterministic; explicitly not a rig evaluator —
  AnimaCore keeps rig semantics; no Bézier yet). Per review: only successfully
  parsed commands refresh the failsafe heartbeat, and duplicate CFG keys or
  duplicate FRM channels are rejected (no last-write-wins). The runtime also
  loads `.character.anima` 2.0 files (`animacore/loader.py` — version/type
  check, typed errors naming the offending path, unknown-field rejection;
  unsupported/superseded spec sections are rejected loudly, never
  silently dropped) into a mechanism-rig model (`animacore/rig.py` —
  parts plus the eight typed Onshape-style mates whose type defines the
  DOF set; a character is an assembly of rigid parts, each carrying an
  opaque per-part `model` asset-file reference (relative to the
  character's `assets/`, validated as a safe relative path — no
  absolute/`..`/empty segments) alongside its optional `model_node`
  (node within a multi-node file), round-tripped for the app and never
  parsed by the engine, so asset references are format-opaque there even though
  Studio currently admits only its documented USD-family/STL/OBJ import set;
  per-DOF limits are optional per Kinematics.md §2: an
  unlimited DOF is legal and never clamped, but mapping one to a
  bounded output channel is a load error naming the fix; per-joint
  as-mated `offset` blocks round-trip for Studio's spatial use; and
  gear / rack_pinion / screw / linear `relations` couple DOF pairs as
  `driven = ratio × driver + offset` with acyclic/single-driver/
  no-animated-driven validation. `evaluate_pose` resolves clip-driven
  DOF with neutral fallback and loop wrapping, applies relations in
  dependency order, and reports — never clamps — driven values outside
  their limits as `Pose.limit_violations`; `project_channels` (the
  target→normalized 0..1 channel seam feeding `wire.encode_frm`)
  raises `LimitViolationError` for a mapped violated DOF so hardware
  refuses to arm). `examples/six_axis_arm|rc_car|walle_style
  .character.anima` load end-to-end; rc_car exercises a steering
  rack-and-pinion relation and an unlimited free-spinning axle.
  Parts, joints, and relations carry persistent **object states** —
  `Part.suppressed` / `Part.grounded` and `Joint.suppressed` /
  `Relation.suppressed` (all default `false`, written to the file only
  when `true`, so round-trip is lossless) — that change the solve and
  survive save/quit/relaunch, distinct from app-owned hidden/lock view-state.
  Studio binds tree actions to these retained engine DTO fields, then
  serializes/reloads for engine validation; it does not duplicate suppress or
  ground as Swift-only flags. `evaluate_pose` drops a suppressed joint's DOF
  from the active solve and skips a suppressed relation; `resolve_pose`
  excludes a suppressed part (and deactivates its joints), skips a
  suppressed joint, and pins a grounded part at its authored rest transform
  overriding any incoming joint. Suppression is per-element (no cascade);
  an orphaned non-suppressed part floats to the origin. The bridge
  surfaces the states in the `load_character` rig summary (`describe_mate`
  / `describe_relation` / part entries) and round-trips them through
  `serialize_character`. Known bridge defect: if an output mapping targets a
  DOF removed by part/mate suppression, `project_channels` currently indexes
  that absent path and terminates the helper instead of omitting the inactive
  output; the Swift integration audit has handed an exact `base_yaw` repro to
  the engine lane.
  The runtime also ships the community-extension foundation
  (Extensions.md packet E1): `animacore/outputs.py` defines the
  `OutputAdapter` extension-point protocol (`open(channel_configs)` /
  `send_frame(targets, duration_ms)` / `stop()` e-stop / `close()`,
  with `ChannelConfig` mirroring the wire CFG fields) plus the
  built-in `SimulatorOutput` wrapping `SimulatedDevice` through that
  exact API, and `animacore/extensions.py` loads `<slug>.animaext`
  bundles — closed-schema `extension.yaml` manifests with typed errors
  naming offending paths, capability declarations (hardware/network/
  filesystem), `discover_extensions(search_dirs)` over caller-passed
  directories with duplicate-id rejection, and
  `entry: "module.py:ClassName"` class loading namespaced per
  extension with no `sys.path` pollution; `output_adapter` (E1) and
  `parametric_feature` (E2) contributions load, other known kinds
  parse but refuse with "not yet supported". The packaged
  `examples/extensions/udp-wire-output.animaext/` example streams
  wire lines as UDP datagrams and is tested from its real bundle path.
  Parametric features (Extensions.md packet E2 backend,
  `animacore/features.py`) are pure-data YAML templates — a
  `parametric_feature` entry must be a `.yaml` file, never Python —
  declaring typed parameters (float with explicit unit hint / int /
  bool / choice, defaults and ranges) and a body of standard
  parts/joints/relations/rig-parameters in loader shapes, with safe
  `${expr}` arithmetic substitution (no `eval`; unknown names and
  division by zero are typed errors) and nestable `repeat:` blocks
  for indexed copies. `expand_feature` validates parameter values,
  prefixes every emitted name with the instance name (two instances
  coexist), and resolves the `$parent` attachment sentinel;
  `merge_fragment` inserts the fragment into a character mapping that
  is then re-parsed by the standard loader — expansion never bypasses
  loader validation. The packaged
  `examples/extensions/parametric-linkage.animaext/` example (an
  N-link serial revolute arm with an optional prismatic end slider,
  `capabilities: []`) is tested end-to-end from its real bundle path
  through discover → load template → expand → merge → loader →
  `evaluate_pose` → `project_channels`.
  The runtime also ships the real-hardware serial bridge
  (`animacore/serial_transport.py`): `SerialWireOutput` implements
  the same `OutputAdapter` contract over pyserial (`pyserial>=3.5` is
  now a package dependency) — `serial_for_url` port opening (device
  paths like `/dev/tty.usbmodem*` or URLs like `loop://` for tests),
  HELLO handshake with protocol-version check, CFG+EN per channel,
  OK-checked FRM streaming, and best-effort idempotent STOP that
  swallows dead-port errors into `last_error` during an e-stop.
  Typed errors name what happened (`HandshakeError`,
  `ReplyTimeoutError`, `ProtocolError`, `DeviceRejectedError` carrying
  the device's ERR code/message); reply reads use pyserial timeouts
  only (0.5 s default, 2 s handshake — no polling, no sleeps), and a
  host-side timeout is the operator signal while the device failsafe
  stays the safety net. Tested over a real pyserial `loop://` port
  against the reference `SimulatedDevice` with exact-line assertions
  (no reconnect/threading yet — that lands with Studio live control).
  The runtime also executes `.scene.anima` shows headless
  (`animacore/scene.py`, the B10 offline-playback foundation):
  the execution-v1 subset of `Scene_Format.md` — `clip` (speed ratio,
  background `wait: false`, required `duration_s` for looping clips),
  one-off `pose` interpolation from captured start values, `wait`,
  `wait_for` event gates with optional timeout (`skip`/`end`), `set`/
  `if` over declared scalar variables (literals and variable copies
  only — no expressions yet), bounded and variable-gated `loop`,
  deterministic `parallel` (timestamp order, ties by track order), and
  outbound `event` emission — with the deferred spec actions (`speak`,
  `expression`, `blend_shapes`, `lights`, `ai_response`, `goto`)
  rejected loudly at load. Scene execution v2 adds the FANUC-inspired
  scripting constructs, additively within format 2.0: structured
  condition trees (`var`/`input` compare leaves with typed
  `eq/ne/lt/le/gt/ge`, `all`/`any`/`xor` (exactly two)/`not`
  combinators, unlimited nesting — data, never string expressions),
  `if: {when}` guards, `select` multi-way branches (first match, no
  fallthrough, duplicate literals rejected), `call` + top-level
  `subroutines:` (shared variable scope; recursion rejected at load
  with the cycle named), read-only externally driven `inputs:`
  (`runner.set_input` applies at the next tick boundary),
  level-triggered `wait_until` condition gates with `wait_for`-style
  timeouts, and background `monitors:` (BG-Logic interlocks scanned
  every tick before the main sequence, edge-triggered with re-arm,
  bodies restricted to `set`/`event`/the monitor-only `end_scene`,
  which e-stops the adapter and finishes with a result string such as
  `"estop"`). The `character:` path resolves relative to
  the scene file; `SceneRunner` has no wall clock (caller-driven
  `advance(now_s)` ticks plus `post_event(name)` gates and
  `set_input(name, value)` between ticks, mirroring the
  simulator's explicit-time discipline), merges active motion sources
  over held values, recomputes relation-driven DOF each frame with the
  same refuse-to-arm limit semantics, streams frames through any
  `OutputAdapter`, and reports `finished` /
  `ended_by_gate_timeout` / `stopped` / a monitor's result string,
  plus an emitted-events log.
  `examples/pick_and_wave.scene.anima` drives the six-axis arm through
  the whole v1 surface and `examples/patrol_and_greet.scene.anima`
  through the v2 surface (input-gated wait_until, select, a twice-
  called subroutine, an estop monitor).
  The runtime also exposes AnimaCore as the single canonical engine
  behind a stdio bridge (`animacore/bridge.py`, protocol
  `dev/docs/roadmap/Studio_Bridge.md`, BR1 slice): the Swift app spawns
  `python -m animacore.bridge` once per session and speaks
  newline-delimited JSON to it — `hello` handshake, `load_character`
  (returns a deterministic handle + a rig summary the app mirrors),
  `validate_character`, `evaluate` (DOF values, parameters, projected
  channels, and reported limit violations for one frame), `resolve_pose`
  (per-part world transforms — see below), `mate_types`, `add_mate`,
  `update_mate`, `remove_mate`, `relation_types` (the four relation kinds —
  Gear, Rack and pinion, Screw, Linear — as a static palette catalog),
  `add_relation`, `update_relation`, `remove_relation`, `serialize_character` /
  `serialize_scene` (the project-Save write side — see below), `release`,
  and `shutdown`. `load_character` also carries a `relations` array
  (`describe_relation` per instance: signed semantic `ratio` split into
  a display `magnitude` + `reverse` flag, plus a `ratio_field_value`
  that is the unitless ratio for gear/linear or distance-per-revolution
  in mm — `abs(ratio) × 2π × 1000` — for rack_pinion/screw). This is
  the seam that keeps the app a front end: it
  holds DTOs that mirror engine results and never redefines what a rig,
  pose, or frame means. Protocol logic is a pure
  `handle_request(session, request)` over dicts (format/protocol errors
  become typed `{ok:false,error:{code,message,path}}` envelopes, never a
  loop crash); an `evaluate` response's DOF values equal a direct
  `evaluate_pose` call, tested as a faithful passthrough. The engine also
  owns canonical **forward kinematics** (`animacore/kinematics.py`): a
  stdlib-only rigid `Transform` (unit quaternion `(x,y,z,w)`, real part
  last per RealityKit `simd_quatf`, plus a metre translation),
  `connector_frame`/`mate_motion`/`mate_offset_transform`/
  `child_in_parent`, and `resolve_pose(rig, pose)` walking the joint
  graph parents-before-children. Each mate moves the child relative to
  the parent about/along the **mate connector as the relative origin**
  per its DOF; at zero DOF/offset the child connector coincides with the
  parent connector with primary(Z) axes opposed, unless `flip_primary_axis` aligns
  them, plus a `secondary_axis_rotation_deg` twist. A part also carries a
  **rest transform** (`position_m` + `rotation_euler_rad`, its
  part-in-character location; intrinsic-XYZ Euler, degrees in the file):
  roots and grounded parts resolve at their rest transform (identity when
  unauthored), a mated child is placed by its mate instead, and
  `resolve_pose` output is character-space (Character-in-World is a
  scene-level transform, default identity — see
  `dev/docs/roadmap/Coordinate_Frames.md`). The bridge `resolve_pose` verb returns
  `{parts:{name:{position:[x,y,z], orientation:[x,y,z,w]}}}` — the
  RealityKit render hook. Studio now calls it for imports and every playhead
  update, maps the result to renderer-only part IDs, and applies it below an
  explicit character root (Character-in-World remains a separate identity
  transform while authoring one character). Free/grounded gizmo edits update
  engine `position_m` and intrinsic-XYZ `rotation_euler_rad`; save/reopen
  round-trips them. The duplicate Swift `RigPoseResolver` and
  `MateConnectorMath` implementations and their semantic tests are removed.
  The engine also owns `.anima` **writing** (`animacore/serialize.py`) — the
  project-Save contract: `serialize_character` rebuilds a `Rig` from the full
  `load_character` rig DTO and emits canonical `.character.anima` text
  (radians→degrees, metres kept, defaults omitted, deterministic);
  `serialize_scene` emits `.scene.anima` from a scene document. Both validate
  (an invalid rig/scene is a `format_error`, so the app never writes a broken
  file). Round-trip is the acceptance test — `load → serialize → load` yields
  an equal rig/scene for every `examples/` file. To keep the round-trip
  lossless the `load_character` rig summary was additively enriched (clip
  `keyframes`, output ranges, per-DOF `axis_vector`/`name`/`description`,
  joint `description`; nothing renamed or removed).
  The runtime also ships the standalone **Denavit-Hartenberg
  articulated-arm foundation** (DH1+DH2, `animacore/dh.py`): serial
  kinematic chains parameterized by the standard (distal) DH convention
  with **forward and inverse kinematics** — `DHLink` (`a`/`alpha`/`d`/`theta`
  + `joint_type` revolute/prismatic + optional `min`/`max`/`neutral`
  limits on the joint variable), `DHChain` (ordered links + optional
  `base_frame`/`tool_frame`, `dof`), `link_transform` (the standard
  `A = Rotz·Transz·Transx·Rotx` link matrix built from the shared
  `Transform` primitives), and `forward_kinematics` returning every
  cumulative link frame plus the tool pose, raising a typed `DHError`
  naming the joint index on a limit or arity violation. FK is stdlib +
  `math` + `Transform` only (no numpy — FK stays pure); verified against
  the planar-2R closed form and an independent 4x4-matrix reference for a
  6R UR5-style arm. **Inverse kinematics** (DH2) is `solve_ik(chain,
  target_pose, *, seed=None, position_tolerance_m=1e-4,
  orientation_tolerance_rad=1e-3, max_iterations=100, damping=0.05) ->
  IKResult` — damped least-squares (Levenberg-Marquardt) on the 6×N
  geometric Jacobian, clamping each joint to its limits every step and
  returning `IKResult(joint_values, reached, position_error_m,
  orientation_error_rad, iterations)`, reporting non-convergence honestly
  (`reached=False` with the final residual, no raise). This is the one path
  that uses **numpy** (added as an `animacore` dependency, `numpy>=1.26`),
  isolated below the pure-stdlib FK; verified by FK→IK→FK round-trips (the
  achieved pose matches an FK-generated target for the 2R and 6R arms),
  joint-limit respect, honest unreachable-target residuals, prismatic-slider
  IK, and determinism.
  The DH chain is now a real **articulated-arm rig type** (DH3): a `Rig`
  may carry an optional `KinematicChain` (`animacore/rig.py`) — an ordered
  list of `ChainJoint` DH links (`a_m`/`d_m` metres, `alpha_deg`/`theta_deg`
  degrees→radians, per-joint-variable `limits`/`neutral`, an optional
  `part` that rides the link frame), a `base_part` whose rest transform is
  the chain base frame in character space, an optional `tool_part`, and a
  tool offset. Declaring the top-level `kinematic_chain` block makes the
  character that type. Its joints are **drivable DOF** (`"<chain>.<joint>"`)
  that clips animate, evaluate to neutral otherwise, and may map to bounded
  output channels; `resolve_pose` places each link/tool part by **DH forward
  kinematics** (character-space, overriding the rest-transform root
  placement) while non-chain rigs are unchanged. The loader/serializer
  round-trip the block losslessly (`load → serialize → load` equal), and the
  bridge adds two verbs on a loaded arm rig's chain: `forward_kinematics
  {handle, joint_values:{joint:value}} -> {link_frames:[{position,
  orientation}...], tool_pose:{position,orientation}}` and `solve_ik
  {handle, target_pose:{position,orientation}, seed?:{joint:value}} ->
  {joint_values:{joint:value}, reached, position_error_m,
  orientation_error_rad, iterations}` (missing joints fall to neutral; no
  chain → a `no_kinematic_chain` error; FK/IK frames are character-space).
  `load_character` exposes the chain in its rig summary (null for a general
  assembly) so the app knows the rig is an arm and can drive it, and
  `rig_from_dict` reconstructs it for `serialize_character`. Example:
  `examples/six_axis_arm_dh.character.anima` (UR5-style 6R, alongside the
  mate-based `six_axis_arm.character.anima`). The Swift app now consumes that
  contract directly: a non-null chain adds a docked Articulated Arm inspector
  with one limit-bounded joint jog per axis (degrees/mm are display conversions
  only), calls `forward_kinematics` for every jog, and applies the returned
  character-space link/tool frames in RealityKit. A cyan XYZ/rotation target
  sits at the end effector; dragging it calls `solve_ik` with the current joint
  pose as seed, updates every joint and link on success, and stays orange at the
  requested pose with metre/radian residuals on honest non-convergence. No DH
  or IK math exists in Swift. The root app bundle also carries NumPy beside the
  explicit AnimaCore/PyYAML resources, so the signed helper has no virtual-env
  dependency. Live Swift bridge and workspace tests load the 6R example and
  prove decode → FK → IK → RealityKit-frame projection; 240 XCTest + 20 Swift
  Testing tests pass. Analytic per-geometry IK (DH4) is a later packet.
  1043 Python tests pass with `.venv/bin/pytest animacore/tests -q` (lint:
  `.venv/bin/ruff check .`), including end-to-end clip → FRM stream →
  simulated servo → failsafe, character file → rig evaluation →
  relation coupling → channel projection → simulated servo tests,
  rig evaluation → `OutputAdapter.send_frame` → simulated/UDP output
  tests, rig evaluation → serial bytes → simulated servo tests, and
  scene file → `SceneRunner` → simulated servo values at exact
  timestamps with logic-gate branching and monitor-driven e-stop.
- **What's stubbed:** every `*.example` file under `animacore/` —
  `module.yaml`, `config.py`, `node.py`, the module-contract test —
  these are the JaegerOS-module shape for later
- **Known gaps:** imported model hierarchies can be inspected, filtered, and
  mapped to persistent semantic parts, but still use temporary sibling-index
  paths; durable source identity, reimport reconciliation, collapse, and
  topology remapping are not implemented. Source nodes are intentionally locked,
  and semantic-part drag reparenting waits for the persistent part/undo model.
  Proxy connector inference and engine-backed two-click placement for all eight
  kinematic mates are live, including inspector editing of connector flips,
  orientation, offsets, simulation state, and DOF limits. Choosing a mate tool
  now opens its nonmodal placement panel immediately. On STEP assemblies the
  native Metal authoring path raycasts the exact Open CASCADE triangle/edge
  projection, highlights the inferred face, edge, vertex, or closed-loop axis,
  and maps its part-local connector frame back to the canonical engine Part.
  The first connector is the moving Part, the second is fixed, and the panel's
  green check sends the full connector/orientation/offset draft through
  AnimaCore before the resolved pose is rendered. Persistent named connector
  authoring, replacing an existing connector from the viewport, durable
  topology remapping after reimport, and Width/Tangent surface selection are
  not yet implemented. The shipped part transform gizmo edits semantic-part rest
  transforms outside mate placement. Sub-object selection covers inferred proxy
  candidates and cached imported-mesh face islands, feature-edge polylines, and
  3+-edge corners. Imported feature IDs are deterministic for unchanged
  topology, but durable identity remapping after a topology-changing reimport
  remains open; this is a mesh projection rather than a CAD-kernel B-rep, so
  analytic holes/cylinders and tangent curves are not inferred in generic mesh
  imports; STEP mate placement additionally recognizes closed B-Rep edge loops
  as axis candidates. Transform gizmos are currently
  world-scaled rather than screen-size-stable. Mesh Edges and Wireframe display
  triangle mesh lines, not classified CAD feature edges; hidden-line removal
  remains unimplemented. The Open CASCADE → MetalKit and Three.js/WebGPU paths
  consume live per-Part transforms; exact B-Rep edge vertices carry the same
  Part ownership as face geometry, so moving a Part no longer leaves a stale
  wireframe in either path. MetalKit is the exact STEP connector-picking
  authoring path; raw WebGPU remains an experimental diagnostic renderer, and
  media surfaces remain on the RealityKit spatial renderer. Section views and saved
  named views are now live. Typed
  All eight kinematic mate kinds can be created and edited in the canonical rig
  DTO; Width and Tangent remain pending because they require app-owned geometry
  selections rather than the shared connector-pair flow. Project folders and
  imported canonical characters persist. Rest-transform, suppress, and ground edits are projected
  into the retained DTO; transitional proxy creation/rename is not all
  canonical yet. Scene Open is deferred because the
  bridge has no `load_scene` twin. Undo/redo and live hardware controls remain
  visibly disabled; Home archetype routing is now live, while the Digital
  Character archetype is explicitly marked Preview. Studio never parses `.anima` itself:
  AnimaCore loads and serializes `.character.anima` and executes the
  `.scene.anima` v1+v2 subset; the deferred scene actions — speech, expressions,
  lights/LEDs, AI handoff, and goto — execute nowhere. There are no
  editable Bézier curves/handles, audio, screens/LEDs, Live2D, Studio Show
  workspace playback, output
  node, JaegerOS connection, or full 52-blend-shape JP01 character file (a
  minimal example head ships in `examples/`). The root app bundle is a local
  development artifact rather than a notarized distribution; release signing,
  notarization, updater/distribution packaging, and App Store policy work have
  not started. Studio is a working workspace
  foundation, not yet a complete authoring workflow.

- **Production widget/tree contract (2026-07-20):** editable navigator trees
  now share deterministic filtering, disclosure/reveal, state badges,
  lock-aware selection, reorder/group drop feedback, and atomic bulk-removal
  behavior. The Rig Instances tree exposes confirmed single/multi-part Delete;
  engine Mate and Relation rows expose confirmed semantic Delete, with mate
  removal pruning dependent relations, outputs, and keyframe values before the
  edited DTO returns to AnimaCore for validation. Workspace-sidebar tabs now
  show their actual working sets (Mates, Relations, Clips, Cues, Outputs,
  Safety) instead of repeating the generic component navigator. Fixed project
  taxonomy and imported source hierarchy remain explicitly locked reference
  trees. Production node transport controls are disabled instead of enabled
  no-ops. The complete surface-by-surface capability and honest-gap matrix is
  in `Widget_Production_Audit.md`.

- **Demo Home/footer production port (2026-07-21):** the frozen demo remained
  read-only while its merged three-column Home, Home-only header, direct
  default-root project creation, disk-discovered/stored recents union, sample
  fallback, archetype routing, connected resources, and global 24-point footer
  moved into production. The footer appears on Home and open workspaces and
  reads real selection, renderer-published triangle counts, backend, theme, and
  OCCT version. Recursive format lint, 332 XCTest tests plus 27 Swift Testing
  tests, native/root builds, embedded dependency signing, strict deep
  verification, and fresh live launch pass.

- **Center View and visible-zone production shell (2026-07-21):** Character
  exposes 3D/Gallery/Table; Rig exposes 3D/Table/Exploded; Animate exposes
  3D/Dope Sheet/Curves; Show exposes Node Graph/Table/3D; and Hardware exposes
  Servo Timeline/Table/3D through one bottom-center switcher. Spatial centers
  remain full-bleed. Structured centers consume shell-computed environment
  insets for the top tool bar, open left/right panel stacks, Canvas reveals,
  bottom switcher, and torn-off panel footprints, while Docked chrome remains
  in-flow. Settings > UI > Chrome includes a live dashed visible-zone overlay.
  Full `swift test` passes 348 XCTest plus 27 Swift Testing tests; focused
  format lint, native/root builds, strict deep signing, and live launch pass.

- **Onshape is the coordinated default CAD environment (2026-07-29):**
  fresh installs and renderer fallbacks use a near-white viewport, pale-blue
  CAD material, crisp dark B-Rep edges, orange selection, and balanced
  high-key lighting across the MetalKit and WebGPU adapters. Existing saved
  operator choices remain intact. Choosing any named CAD preset now restores
  that preset's complete material, edge, light-intensity, and color set before
  further customization, so stale saved sliders or color wells cannot reduce a
  theme to a background-only change. Full `swift test` passes 364 XCTest plus
  53 Swift Testing tests; focused format lint and diff checks, native/root
  builds, strict deep signing, and live packaged launch pass.

- **Selected-Part highlighting, gizmo, and direct placement (2026-07-29,
  corrected 2026-07-30):**
  in the native Open CASCADE → Metal authoring viewport, clicking a Part gives
  its faces and feature edges a strong orange selected-state cue and keeps the
  origin-anchored translate/rotate gizmo visible. Pressing and dragging any
  editable body with an unmodified left mouse button selects it and performs coarse
  camera-plane placement with a depth-stable scale; the existing gizmo remains
  the precise axis/rotation control. Both paths write through the same guarded
  Part rest-transform callback, so grounded/locked Parts cannot move.
  Shift/Command-click multi-selection, empty-click deselection, right-button
  orbit, and middle-button pan retain their existing behavior. Full `swift
  test` passes 364 XCTest plus 55 Swift Testing tests; focused direct-drag,
  gizmo, and picker regressions, touched format lint, native/root builds,
  strict deep signing, and packaged launch pass.

- **CAD mouse mappings and left-button intent are renderer-consistent
  (2026-07-30):** the native Metal and Three.js/WebGPU production viewports use
  the same resolved Default/Onshape, SolidWorks, Fusion 360, and Custom
  bindings. Left drag can only move an editable Part or draw a directional
  window/crossing selection box; it can never pan the camera. Plain left click
  is replacement selection by product choice, Shift/Command explicitly extend,
  and empty click clears. Clean right click opens the context menu while a
  right drag suppresses it; double middle click and `F` frame the assembly.
  Arrow keys orbit in 15-degree steps and Shift + arrows use 90-degree steps.

- **Metal CAD surfaces remain readable in the Onshape environment
  (2026-07-29):** the native Open CASCADE → Metal adapter now renders through
  an sRGB color target, uses a brighter high-key hemisphere fill, and repairs
  reversed or degenerate imported normals against the visible side of each
  surface. Selected-Part orange is composed after surface lighting, so a Part
  remains visibly selected even when its face is outside the key light.
  WebGPU already used sRGB output, double-sided materials, and emissive
  selection; the two production adapters now share the same readability
  guarantees. Full `swift test` passes 364 XCTest plus 56 Swift Testing tests;
  focused lighting regressions, touched format lint, native/root builds, and
  strict deep signing pass.

- **Selected-Part manipulator uses the real projected local frame
  (2026-07-29):** the 3D Modeling manipulator no longer draws three fixed
  screen-space directions. Metal projects the selected Part's actual local
  X/Y/Z frame with the render camera, and Three.js reports the same origin and
  axis endpoints through the web bridge. Red, green, and blue arrow drags are
  constrained to their corresponding local axes; XY, YZ, and ZX patches move
  in those local planes; and the three rings rotate about their perpendicular
  local axes. Rotation is applied as an exact local matrix delta before the
  rest transform is serialized, while the existing grounded/locked guards
  remain in force. Full `swift test` passes 364 XCTest plus 57 Swift Testing
  tests; focused manipulator regressions, touched format lint, JavaScript
  syntax/build/copy, native/root builds, strict deep signing, and packaged
  launch pass.

- **The ViewCube mirrors the live world-camera frame across CAD renderers
  (2026-07-29):** native Metal/RealityKit orbit and roll now publish their
  camera orientation into the shared workspace camera state, and Three.js
  WebGPU/raw WebGPU report the same target-to-camera direction plus roll.
  The cube's projected faces and positive X/Y/Z axes therefore rotate with the
  operator's actual view instead of remaining stuck on the last commanded
  preset. Cube face/edge/corner, nudge, and roll actions travel back to the
  active renderer only when the camera command revision changes; renderer
  reports do not echo as new commands or reset roll. The viewport stays alive
  throughout the exchange. Full `swift test`, focused camera/ViewCube
  regressions, touched Swift format lint, JavaScript syntax/bundle checks,
  native Xcode build, signed root-app rebuild, and packaged launch pass.

- **Viewport performance status has its own bottom-right HUD and right-rail
  owner (2026-07-30):** the AnimaCore evaluated-frame badge no longer occupies
  bottom-center behind the 3D/Table/Exploded switcher. A compact
  ViewCube-style Performance card now owns bottom-right, clears any open
  floating right panel, and remains independently toggleable. The right rail
  adds a dedicated Performance panel with live engine/frame status and, for
  STEP/CAD views, a separate detailed renderer-metrics toggle. When both cards
  are enabled, FPS/CPU/memory/geometry telemetry stacks above the compact
  engine card rather than overlapping it. Full `swift test` passes 365 XCTest
  plus 59 Swift Testing tests; focused HUD ownership/layout regressions,
  touched format lint, native Xcode build, signed root-app rebuild, and fresh
  packaged launch pass.

- **CAD feature edges now have real screen-space definition and the Onshape
  environment has interactive self-shadow depth (2026-07-30):** Edge
  definition no longer acts like an almost-binary one-pixel line switch.
  Native Metal expands B-Rep feature edges in screen space from 0.85–3.5 px,
  uses 4x MSAA where supported, and varies opacity with the same setting;
  Three.js WebGPU uses its native wide-line node material with the matching
  width range. The Onshape preset now balances a strong key against a restrained
  fill and hemisphere ambient, while a 2048 px soft key-light shadow map with
  3x3 percentage-closer filtering gives undersides and occluded interfaces
  visible depth. Ambient light and Contact shadows are live, persisted controls
  shared by both production adapters. This is deliberately responsive raster
  self-shadowing for authoring—not mislabeled offline path tracing. Full
  `swift test` passes 365 XCTest plus 61 Swift Testing tests, including a
  runtime GPU test that compiles the actual Metal shaders and pipelines;
  touched diff checks and JavaScript syntax checks, Swift format lint, native
  Xcode build, signed root-app rebuild, and strict deep signing pass.

- **CAD source colors and zero-light behavior are honest across production
  renderers (2026-07-30):** importing a STEP/XDE assembly no longer turns every
  Part teal because the Studio proxy color is no longer misclassified as an
  explicit per-Part appearance override. Open CASCADE face/body colors remain
  authoritative when **Preserve STEP/XDE colors** is enabled; an operator's
  explicit Part Appearance edit still wins, and uncolored geometry retains the
  importer's neutral fallback. Ambient light can now reach exactly zero in both
  Settings and the Environment panel, Three.js/WebGPU no longer inserts a
  hidden ambient minimum, and Metal key-light specular is gated by the key
  intensity. Turning all light controls off therefore produces an intentionally
  unlit result instead of a fixed green, still-highlighted surface. Full
  `swift test`, focused appearance/lighting/theme regressions, JavaScript syntax
  and bundle checks, touched Swift format lint, native Xcode build, signed
  root-app rebuild, strict deep signing, and a fresh packaged launch pass.

- **The reusable preview floor grid is now a configurable CAD display aid
  without a launch-time renderer flash (2026-07-30):** the black RealityKit
  grid seen briefly before a STEP character loaded was the same intentional
  preview environment used by the Assets inspector. The main canvas now keeps
  that preview widget available where it belongs, but shows a theme-matched
  CAD loading surface until the active character's engine-backed model sources
  resolve. MetalKit, Three.js/WebGPU, and raw WebGPU all render a distinct
  world-space XZ floor grid with red X and blue Z axes. **Camera & Display**
  and **Settings → Renderer** persist its visibility, minor spacing,
  model-relative extent, major-line interval, and opacity; the Assets preview
  consumes the same visibility preference. The display floor remains separate
  from the semantic, selectable Top Plane. Focused floor-grid regression,
  365 XCTest plus the pre-fix Swift Testing sweep, touched Swift format lint,
  Three.js build/copy, and raw/Three.js JavaScript syntax checks pass. A final
  full rerun and native packaging were blocked by the external approval usage
  limiter after compilation had already succeeded; no code failure was
  reported by that limiter.

- **2026-07-30 — missing CAD sources no longer take down the workspace.**
  STEP sources load independently: healthy Parts continue rendering when
  another file is missing or unreadable, and an all-failed assembly retains
  the usable empty CAD environment instead of replacing it with a full-canvas
  error. Loader failures map back to semantic Part IDs. 3D Modeling marks
  affected rows with an orange disconnected/relink control; Assets reports
  **Disconnected** in its normal table/grid and offers **Relink Source** inline
  and from the context menu. Relink reuses the canonical replace/import path,
  so the engine rig reference and project asset handling remain the source of
  truth. Verification: touched Swift format lint, full `swift test` (366 XCTest
  + 64 Swift Testing), native Xcode build, and signed root-app rebuild.

- **2026-07-30 — CAD lighting controls are now one live renderer contract,
  including recovery from black imported materials.** The Environment panel
  binds directly to the same ambient, key, fill, rim, shadow, and color values
  consumed by the active viewport, rather than maintaining a duplicate
  preference projection that could fail to invalidate the renderer. Coordinated
  preset changes and **Reset** restore the complete lighting rig, and disabling
  every light shows an explicit warning. Raw WebGPU now consumes the ambient
  uniform it was already receiving and gates specular with key-light intensity.
  Metal and raw WebGPU give source-black/dark dielectric CAD materials a small
  light-dependent reflectance floor so geometry remains readable when lit;
  that contribution becomes exactly zero when all lighting is zero. Full
  `swift test` (366 XCTest + 66 Swift Testing), focused runtime Metal
  shader/pipeline construction, touched Swift format lint, native Xcode build,
  signed root-app rebuild, and packaged launch pass.

- **2026-07-30 — viewport performance status now reports real renderer
  throughput instead of AnimaCore playhead time.** The compact and detailed
  HUDs share one live snapshot containing renderer FPS, GPU frame time, app CPU,
  and app memory. Metal counts command buffers only after GPU completion;
  Three.js/WebGPU and raw WebGPU report delivered frame batches with their
  measured interval. Sampling remains active during AppKit pointer tracking.
  Metal targets a stable 60 Hz, avoids unchanged per-Part state-buffer writes,
  and reuses its 2048 px shadow map until geometry, transforms, visibility, or
  lighting actually changes. A displayed zero now means no renderer frames
  were delivered during the sample—not a mislabeled animation timestamp.
  Verification: touched Swift format lint, JavaScript syntax/build/copy checks,
  full `swift test` (366 XCTest + 67 Swift Testing), native Xcode build, signed
  root-app rebuild, and packaged launch.

- **2026-07-30 — workspaces can now open as native macOS tabs or independent
  windows.** A compact window control beside the Studio layout control can open
  any applicable workspace in a new native tab or separate window, detach the
  current tab, merge all app windows, show or hide the system tab bar, and move
  between adjacent tabs. The implementation uses macOS `NSWindow` tab groups,
  so operators also inherit native tab dragging/tear-off and green-button
  Split View. Every window shares the open project lifecycle/session while
  retaining independent workspace, camera, panel, and center-view presentation
  state; tab titles identify both the project and workspace. Verification:
  focused AppShell regressions, full `swift test` (368 XCTest + 67 Swift
  Testing), touched Swift format lint, native Xcode build, signed root-app
  rebuild, and packaged launch.

- **2026-08-01 — the isolated OCCT Mate Lab now has a maintainable exact-feature
  inference layer and a functional Items tree.** OCCT surface/curve extraction,
  pure connector-frame math, semantic candidate policy, viewport appearance,
  connector visuals, mate state/solve, worker transport, and DOM shell are
  dedicated modules with an explicit dependency contract in
  `Aether CAD/ARCHITECTURE.md`. Exact trimmed cylinders and bores expose
  start/center/end axis anchors; cones use the same station model; circles,
  ellipses, spheres, and tori expose analytic centers; general edges and
  vertices inherit exact tangent-oriented frames. Coincident candidates retain
  the most meaningful analytic identity. The left Items tree groups Parts under
  each imported STEP document, keeps repeated same-name imports distinct, and
  provides working collapse, Part selection, and visibility controls. This is
  groundwork for later Sketch/Extrude/Fillet history nodes, not a claim that a
  parametric feature rebuilder exists yet. Verification: 18 Vitest cases,
  TypeScript check, production Vite build, real browser cylinder+sphere probes
  (3 cylinder stations and 3 analytic centers), and the complete 2-Part /
  2-connector / 1-Fastened-mate browser workflow.

- **2026-08-01 — Aether CAD is now a root product app with editable Part
  files.** The former dev-only Mate Lab moved to `Aether CAD/` and was
  renamed throughout its product shell/package. `.cadpart` v1 persists stable
  document/feature IDs plus a center-rectangle Sketch and New Extrude in
  millimeters; it never saves display triangles. Dedicated document, file,
  feature-tree, OCCT evaluator, geometry-projection, worker, and Items-view
  modules keep the B-Rep kernel and renderer boundaries explicit. New/Open/
  Save Part are live, parameter edits rebuild through OCCT, and the Items tree
  shows Sketch 1, Extrude 1, and Body 1. Verification: TypeScript check, 23
  Vitest cases, production Vite build, and a real headless-browser walkthrough
  that creates, revises, downloads, reopens, and rebuilds `Long-Bracket.cadpart`.

- **2026-08-01 — Aether CAD and Aether Core now have an explicit extraction
  boundary without a premature split.** The web product folder, package, title,
  and current docs use Aether CAD. UI/viewport code consumes exact semantics
  through `src/aether-core.ts`; the OCCT worker remains the sole embedded
  implementation. `AETHER_CORE_EXTRACTION.md` records the future ownership and
  parity gates, while the family architecture distinguishes headless Core,
  web CAD, and Animation/hardware responsibilities. New files use
  `aether-part`, with an explicit legacy-identity migration. TypeScript check,
  29 tests, production build, and the browser Part save/reopen + shell
  walkthrough pass.

- **2026-08-01 — Aether CAD has a standalone clickable macOS app.** The root
  app wraps the production web build in AppKit/WebKit, embeds OCCT WASM, and
  serves only over an internal loopback port. It needs no running dev server.
  A reproducible build script, native launcher sources, Info.plist, SVG icon
  source, generated ICNS, and strict signature verification are present. The
  launched app exposes a visible Aether CAD window; its HTML and WASM resources
  respond successfully from `127.0.0.1` with correct content types.

- **2026-08-01 — Aether CAD has its first persistent 2D Sketch editing
  workflow.** New Part/Sketch opens plane selection in the Items browser, then
  a dedicated orthographic Sketch surface with a visible Origin, rough
  center-rectangle corner drag, Construction toggle, Horizontal/Vertical/
  Origin Coincident constraints, width/height dimensions, keyboard shortcuts,
  and live degrees-of-freedom feedback. Blue geometry is under-defined; black
  geometry is fully defined. Finish commits the structured sketch into the
  existing Part history and the OCCT worker rebuilds Sketch 1 → Extrude 1 →
  Body 1. `.cadpart` v2 persists the constraint and dimension graph and safely
  migrates v1 rectangles. Verification: TypeScript check, 34 Vitest cases,
  production Vite build, and rebuilt/signed root `Aether CAD.app`. The installed
  in-app-browser control plugin failed during its own bootstrap, before it
  could connect to the local app, so this packet does not claim a fresh visual
  automation pass.

- **2026-08-01 — Aether CAD's product chrome is now React and follows the
  Shapr3D-style CAD layout.** React 19 renders a compact document header, the
  left Items/Modeling/Assembly browsers, floating mode and authoring rails,
  viewport HUD actions, responsive breakpoints, and a collapsible right-side
  History browser. The shell consumes the shared `@aether/ui` package while
  the existing controller remains a compatibility adapter for current CAD
  commands. Changing panels does not recreate the authoritative OCCT worker or
  the single persistent Three.js/WebGPU viewport. History rows derive from the
  real feature/import/mate state and navigate to the appropriate browser. The
  viewport's default presentation is a dark CAD stage with a subdued grid and
  feature edges. Verification: TypeScript check, 12 Vitest files / 36 tests,
  production Vite build, rebuilt and signed root `Aether CAD.app`, packaged
  launch, and native screenshot review.

- **2026-08-01 — Aether Core is now a real TypeScript package consumed by
  Aether CAD.** Root `@aether/core` owns the deterministic Part/Sketch model,
  constraint definition state, migrations and byte-stable serialization,
  geometry/worker contracts, connector-frame and topology-inference policy,
  renderer-independent homogeneous transforms and Fastened mate solve, plus
  the Replicad/OpenCascade.js WASM kernel worker, exact B-Rep topology, STEP
  import, render tessellation projection, and parametric Part evaluation.
  Aether CAD no longer declares OCCT/Replicad dependencies directly; its old
  semantic/kernel module paths are thin compatibility exports while browser
  download and Three.js conversion remain app adapters. Core is organized by
  `contracts`, `sketch`, `document`, `geometry`, `assembly`, and `kernel`; it
  has no React or Three.js dependency, and its semantic modules are DOM-free.
  The shared architecture keeps only Aether Core and Aether UI as foundations;
  future render, asset, physics, connection, and workspace capabilities are
  internal Core modules, not additional top-level products. Verification:
  8 direct Core tests + standalone type-check, all 36 Aether CAD tests,
  application type-check, and production Vite/OCCT-WASM build pass.

- **2026-08-13 — Aether CAD started the shared UI-system buildout with real
  Menu and Popover foundations.** `@aether/ui` now owns product-free,
  controlled Menu/MenuButton and Popover components on a shared
  viewport-aware overlay positioner. Menus support command, checkbox, radio,
  disabled-reason, danger, shortcut, separator, submenu, keyboard traversal,
  outside/Escape dismissal, and focus-return behavior; the gallery exercises
  the shared components from different data sets. Aether CAD's Assembly panel
  now uses the shared menu for mate actions while preserving the existing
  command bridge. Browser-panel selection is presentation state in the React
  shell, the mode and authoring rails no longer overlap, sibling foundation
  packages are available to the Vite development server, and development
  reference sources no longer leak into CAD test discovery. Verification:
  44 UI tests plus type-check/build, 36 CAD tests plus type-check/build, 8
  direct Core tests plus type-check, and an in-app-browser walkthrough with
  OCCT ready, Assembly switching, disabled-reason display, and Escape close.

- **2026-08-13 — shared authoring fields now drive Aether CAD's real Part
  rebuild flow.** `@aether/ui` owns product-free NumberField, SelectField,
  Checkbox, and FieldRow components. NumberField accepts deterministic
  arithmetic expressions, displays explicit units, validates min/max bounds,
  represents mixed values, commits on Enter/blur, cancels with Escape, steps
  from the keyboard, and optionally scrubs by pointer drag. SelectField keeps
  native selection semantics; Checkbox includes description and indeterminate
  multi-selection state; FieldRow standardizes labels, help, errors, modified
  indication, and reset actions while leaving transactions with the app. The
  gallery demonstrates feature-dimension and document-setting datasets.
  Aether CAD's Modeling browser now uses TextField/FieldRow/NumberField and the
  shared primary Button without changing the established controller IDs or
  Core document/evaluation path. Browser verification entered `30 * 2`,
  `20 + 20`, and `5 * 4`; the fields normalized to 60 × 40 × 20 mm and OCCT
  produced one six-face Body, 54 exact snaps, and preserved Sketch 1 → Extrude
  1 history. Verification: UI 57 tests/type-check/build, CAD 36 tests/type-
  check/build, Core 8 tests/type-check, plus live gallery and CAD walkthroughs.

- **2026-08-13 — shared help and workflow-state primitives are available for
  CAD recovery and long-running operations.** `@aether/ui` now owns Tooltip,
  EmptyState, ErrorState, and ProgressOverlay. Tooltip uses the common overlay
  positioner and provides delayed pointer help, immediate focus help,
  shortcuts, disabled explanations, accessible description, and Escape
  dismissal. Empty and error surfaces support compact/full presentation,
  diagnostics, announcements, and recovery actions. Progress supports
  determinate and indeterminate work, phase/detail text, cancel/background
  actions, modal focus entry/containment/return, Escape cancellation, and a
  reduced-motion fallback. The gallery demonstrates component insertion,
  rebuild failure, and a 48%-complete multi-phase assembly import whose Run in
  background action closes the overlay. Verification: UI 63 tests, TypeScript
  check, production gallery build, and live keyboard/visual browser review.

- **2026-08-13 — the shared interaction-primitives stage is complete with a
  definitive ListBox.** `@aether/ui` now provides the flat-collection
  counterpart to Tree: controlled single/multiple selection, modifier toggle
  and range selection, visible groups, roving keyboard focus, Home/End,
  type-ahead, disabled/dimmed items, badges/descriptions, activation, context
  events, non-selecting row actions, empty/loading/error states, and automatic
  fixed-row windowing for large datasets. The gallery proves the same visual
  and interaction contract with a grouped material library and a sketch-
  constraint list. Verification: 74 UI tests, TypeScript check, production
  gallery build, and live semantic, keyboard, and visual browser review.

- **2026-08-13 — the shared Tree is complete for large editable CAD
  hierarchies.** Tree v3 adds controlled inline rename; native drag signals
  with before/inside/after intent while the application retains graph mutation
  and validation; expanded child loading and error/retry rows; and automatic
  fixed-row windowing for large visible hierarchies. The existing selection,
  expansion, filtering, keyboard, activation, context, disabled/dimmed, and
  row-action contracts remain intact. The gallery includes editable lazy/error
  branches and a 1,200-component assembly that renders only 11 visible rows.
  Verification: 78 UI tests, TypeScript check, production build, downstream
  Aether Animation web build, 36 CAD tests/check/build, and live rename,
  recovery, semantic, and visual browser review.

- **2026-08-13 — shared tabular CAD surfaces now have one definitive
  DataTable.** Its generic typed columns cover controlled sorting and global
  filtering, single/multiple/range selection, keyboard row navigation,
  double-click inline editing, resize and reorder intent, sticky pinned
  columns, row commands, empty/loading/error states, and fixed-row windowing.
  The gallery uses it for both a 140-row editable bill of materials and a
  compact Problems list; only 11 BOM data rows render at once. Live review
  sorted quantity ascending and renamed the first row to `Bearing mount`.
  Verification: 89 UI tests, TypeScript check, production build, semantic and
  visual browser review.

- **2026-08-13 — CAD inspectors now share a schema-driven PropertyGrid.**
  Product schemas provide sections and editors while the common component owns
  controlled or internal collapse, property filtering, modified-only
  projection, mixed multi-selection indicators, read-only presentation, and
  FieldRow-based help, validation, modified, and reset composition. Gallery
  examples cover a searchable Body inspector and a two-component mixed-value
  inspector; live Modified only review projected the Body grid to Width alone.
  Verification: 94 UI tests, TypeScript check, production build, and live
  semantic/visual browser review.

- **2026-08-13 — the shared definitive data-and-layout stage is complete.**
  `SplitPane` provides horizontal or vertical pointer resizing, accessible
  keyboard resizing, min/max bounds, controlled persistence signals, and
  collapse/restore behavior. `BottomPanel` provides keyboard-accessible tabs,
  badges, header actions, active tab panels, and compact collapse/restore for
  Problems, History, Console, BOM, and Tasks. The gallery combines an assembly
  navigator, persistent viewport, and all five bottom tools; live review resized
  the navigator from 240 to 250 px, selected History, and collapsed the content
  while preserving its active tab. Verification: 102 UI tests, TypeScript
  check, production build, semantic and visual browser review.

- **2026-08-13 — Aether CAD now has one typed command registry.** Visible
  header, floating toolbar, viewport, keyboard, modeling, and mate-menu actions
  subscribe to the same command IDs and execute registered handlers directly;
  enabled and active state flow back through immutable registry snapshots.
  The React shell no longer finds hidden command buttons, mirrors their disabled
  attributes with a MutationObserver, or bubbles commands into DOM query/click
  delegation. File-picker commands remain centralized handlers that open their
  native inputs. Live browser verification ran New Part → Top Plane → apply
  dimensions → Finish through the registry and produced Part 1 with one Body,
  six faces, 54 exact snaps, enabled Save/Fit, and the normal OCCT status.
  Verification: 39 CAD tests, TypeScript check, production build, live OCCT
  command flow, and clean diff/source-name checks.

- **2026-08-13 — Aether CAD's Items and History browsers are React-owned
  shared data surfaces.** A typed workspace projection/store now carries
  reference geometry, authored Part features, imported document/Part rows,
  selection, expansion, visibility actions, counts, and history entries from
  the imperative controller to React. Shared Tree replaces reference/item
  `innerHTML` and DOM filtering; shared ListBox replaces generated history rows.
  Typed actions return selection, document expansion, visibility, reference-
  plane choice, and history navigation to the existing viewer/controller, so
  no geometry or feature truth moved into the UI. Live verification used the
  shared Tree for New Part → Top Plane, rebuilt Part 1 through OCCT, projected
  Sketch/Extrude/Body plus two History rows, filtered to Extrude while retaining
  its ancestor, and navigated History back to Modeling with the correct status.
  Result: one Body, six faces, 54 exact snaps. Verification: 43 CAD tests,
  TypeScript check, production build, and live semantic/visual browser review.

- **2026-08-13 — Aether CAD's Assembly browser is React-owned shared data.**
  The workspace projection now publishes connector and fastened-mate ListBox
  items, counts, and selected connector state. Shared ListBox instances replace
  generated connector/mate HTML; selection, mate-pick, and connector deletion
  travel back through typed controller actions while the command registry
  remains the source of enabled/active state. Live review covered the empty
  Assembly browser, OCCT Part creation, exact planar-face connector placement,
  ListBox selection, and deletion. The authored model retained one Body, six
  faces, and 54 exact snaps. Verification: 43 CAD tests, TypeScript check,
  production build, and live semantic/visual browser review.

- **2026-08-13 — Aether CAD workflow presentation is React-owned.** A typed
  presentation store now projects the active browser, history collapse,
  document/backend/status/metrics, connector and mate guidance, sketch-plane
  prompt, topology hover details, and long-running operation state. React
  renders those surfaces and the shared ProgressOverlay; typed actions return
  panel, collapse, and cancel intent to the controller. The controller no
  longer changes workflow cards and labels through generated HTML, query-based
  class toggles, or text mutation. The Three.js/WebGPU viewport and ViewCube
  remain persistent imperative adapters. Live sketch→OCCT Part, collapse/
  restore, connector activation/cancel, and viewport review retained one Body,
  six faces, and 54 exact snaps. Verification: 46 CAD tests, TypeScript check,
  production build, and clean diff/source-name quarantine.

- **2026-08-13 — Aether CAD's viewport command rails use the shared UI
  contract.** Rail and RailButton now forward standard container/button
  attributes, including disabled state and command data, while retaining their
  accessible label and pressed contract. The mode, authoring, and navigation
  rails consume them with the existing wide icon+label and compact icon-only
  breakpoints. Registry active/disabled state and typed panel dispatch remain
  authoritative. The obsolete generated-HTML toolbar renderer and non-React
  fallback shell have been removed. Verification: 102 shared UI tests/check/
  build, 46 CAD tests/check/build, downstream Animation build, live semantic/
  visual review, and clean diff/source-name checks.

- **2026-08-13 — Aether CAD's shared-shell migration is complete.** The last
  unreferenced string renderers for authored Items, imported assembly rows, and
  reference geometry plus their dead toolbar/tree/connector/mate/history CSS
  are removed. React and the shared UI system now own all CAD shell
  presentation through typed command, workspace, and presentation stores. The
  remaining imperative sketch canvas and ViewCube are specialized persistent
  viewport adapters, not alternate list/menu/form implementations. Existing
  Part, Sketch, STEP, connector, mate, visibility, camera, save, and open paths
  remain connected. Verification: 45 CAD tests, TypeScript check, production
  build, live visual/sketch-entry review, and clean diff/source-name/dead-code
  audit.

- **2026-08-13 — Aether CAD has a real Home/New/Import/Recovery entry
  workbench.** Home overlays the still-mounted persistent viewport and exposes
  New workspace, Open Part, Import STEP, workspace-type availability, recent
  empty state, and Recovery. Shared Dialog/FieldRow/TextField/SelectField/
  Button/EmptyState components define consistent interactions. New Part
  collects a deterministic name, fixed supported template, and explicit mm
  units; its typed action enters the existing plane-select/sketch/Core path.
  Assembly and Drawing starters are disabled with visible dependency reasons.
  Recovery truthfully reports that no autosave subsystem exists yet, while
  Import explains exact B-Rep behavior before invoking the registry file
  command. Live `Drive Bracket` → Top Plane → finish produced one OCCT Body,
  six faces, and 54 exact snaps. Verification: 46 CAD tests, TypeScript check,
  production build, full live entry-flow review, and clean diff/source-name
  quarantine.

- **2026-08-13 — Aether CAD has a functional, honest Export center.** The
  previously inert Share control is now Export and is disabled until a Part is
  active. Its shared Dialog/FieldRow/SelectField/Checkbox/Button composition
  identifies the target Part, exact editable native classification, feature-
  history inclusion, dependency closure, and expected result. Saving the native
  `.cadpart` executes the established registry command. STEP, mesh, and drawing
  outputs remain visible but disabled with precise Core/projection dependency
  reasons. This completes the first UI-4 Home/New/Import/Export/Recovery packet.
  Live review used a real OCCT Part with one Body, six faces, and 54 exact snaps.
  Verification: 47 CAD tests, TypeScript check, production build, live semantic/
  visual review, and clean diff/source-name quarantine.

- **2026-08-13 — Aether CAD has a traditional Part inspector and rebuild
  workbench.** A renderer-free projection supplies Part identity, feature
  dimensions, canonical sketch definition state and remaining DOF, exact OCCT
  face/snap metrics, connector count, and mate count. The right dock renders it
  through shared PropertyGrid. Shared BottomPanel now owns History and Problems
  below the persistent viewport; typed actions select tabs and collapse/
  restore, and the viewport History button restores the History tab. An under-
  defined Sketch appears as a warning derived from Core's DOF result rather
  than UI inference. Live empty/authored/Problems/collapse/restore review showed
  two remaining DOF, six faces, and 54 exact snaps. Verification: 47 CAD tests,
  TypeScript check, production build, and clean diff/source-name quarantine.

- **2026-08-13 — Aether CAD Settings and Help are functional utility
  screens.** Shared Dialog surfaces replace the previously inert icon buttons.
  Preferences reports the actual dark theme, CAD navigation preset, mm units,
  0.01 mm display precision, and system reduced-motion behavior; unsupported
  light/high-contrast overrides and per-workspace persistence are clearly
  unavailable instead of pretending to save. Help documents the working Part
  and connector-first Assembly flows plus F/R/Escape and viewport controls.
  Escape closes and returns focus to the opener. The unused Items footer folder
  and overflow buttons are disabled with dependency reasons. Verification: 48
  CAD tests, TypeScript check, production build, live keyboard/focus/visual
  review, and clean diff/source-name quarantine.

- **2026-08-13 — Aether CAD Search and Visualization commands are truthful.**
  Search now dispatches typed presentation intent, selects the Items browser,
  and focuses its real filter without an imperative controller DOM query.
  Visualization no longer becomes enabled merely because Fit View is enabled;
  it remains disabled and exposes the missing appearance/display-style
  workbench reason. Live review started in Assembly and confirmed Search moved
  focus to Filter Items, while Visualization remained semantically disabled.
  Verification: 48 CAD tests, TypeScript check, production build, and clean
  diff/source-name quarantine.

- **2026-08-14 — Aether CAD now has an exact Inspect workbench.** Inspect is a
  first-class shared-rail browser alongside Modeling, Items, and Assembly. It
  reuses the renderer-free PropertyGrid projection for Part identity, feature
  parameters, sketch definition/remaining DOF, and exact OCCT topology rather
  than introducing a second model. Fit current model executes the typed command
  registry. Measure, mass properties, section analysis, and curvature are
  disabled with their missing Core-contract reasons. This completes UI-4's
  Part/Sketch/Inspect/Rebuild screen packet. Verification: 49 CAD tests,
  TypeScript check, production build, and live empty/authored/keyboard review
  with two features, six faces, 54 exact snaps, enabled Fit, and four disabled
  analysis capabilities.

- **2026-08-14 — Aether CAD's product shell has explicit accessibility and
  compact-layout behavior.** Home, CAD workspace, 3D viewport, backend state,
  workspace status, and metrics now have stable accessible names/roles; backend
  and command status changes use polite atomic live regions. App-local controls
  have visible keyboard focus, the shell honors reduced-motion and forced-color
  environments, and a 620 px compact rule complements the existing 820/1120 px
  dock breakpoints. Superseded local UI removal is also closed in UI-5.
  Verification: 50 CAD tests, TypeScript check, production build, live desktop
  semantic/keyboard/focus-ring review, compact/media-rule source audit, and
  clean diff/source-name quarantine.

- **2026-08-14 — Aether CAD has a working Visualization appearance
  workbench.** A typed session appearance store is the single source for the
  React screen and mounted Three.js renderer. Shared fields control Graphite/
  Midnight/Slate backgrounds, construction grid, exact feature edges, Matte/
  Satin/Gloss Body finish, and 0–200% environment intensity without rebuilding
  the viewport or changing CAD semantics. Reset restores the documented
  defaults. Light/adaptive presentation and persistent per-face assignments
  remain disabled with dependency reasons. Live testing also found and fixed a
  physical rail overlap between the fifth mode command and Search.
  Verification: 53 CAD tests, TypeScript check, production build, live WebGPU
  create-Part/appearance/reset review retaining one Body/six faces/54 snaps,
  and clean diff/source-name quarantine.

- **2026-08-14 — Aether CAD STEP batches are observable, backgroundable, and
  cooperatively cancellable.** Shared ProgressOverlay now reports determinate
  file N-of-M progress. Backgrounding keeps the exact import running and adds a
  footer action to restore the task; cancellation waits for the non-abortable
  current OCCT call, discards its result, and stops remaining files. Concurrent
  STEP insertion is disabled during the task. Product projection tests cover
  1,200 imported Parts grouped beneath 12 source documents, complementing the
  shared Tree/DataTable virtualization pins. The CLI STEP smoke harness now
  resolves OCCT through shared Core ownership after the dependency extraction.
  Verification: 55 CAD tests, TypeScript check, production build, exact STEP
  smoke with 95 faces/396,635 triangles/1,247 inferred candidates, semantic
  foreground/background task pins, and clean diff/source-name quarantine.

- **2026-08-14 — Aether CAD has one persistent Docked/Expanded/Canvas layout
  contract.** A typed session setting selected through shared Menu keeps one
  mounted viewport across all layouts. Docked is the traditional three-pane
  CAD workbench. Expanded places browser, Properties, and History/Problems in
  floating docks over the full canvas while relocating every tool rail,
  navigation command, and ViewCube around them. Canvas hides docks only; all
  viewport commands and layout recovery remain available. Compact 620/820/1120
  rules preserve the same command paths. Live testing found and fixed both a
  floating-dock rail occlusion and a covered ViewCube. Verification: 56 CAD
  tests, TypeScript check, production build, live three-mode review retaining
  one viewport/one Body/six faces/54 snaps, and clean diff/source-name
  quarantine. UI-5's layout-convergence item is complete.

- **2026-08-14 — Aether CAD UI-5 convergence and accessibility hardening is
  complete.** The final audit confirms named workspace/viewport/status
  landmarks, polite atomic live updates, visible keyboard focus, Preferences
  focus trapping, Escape dismissal, and focus return to Settings. The live
  desktop surface has no horizontal overflow, while explicit 620/820/1120
  scaling rules retain layout/menu/modeling/navigation recovery. Scoped
  reduced-motion and forced-colors rules cover the product shell and preserve
  canvas rendering. Verification: 56 CAD tests, TypeScript check, production
  build, live semantic/keyboard/focus-return/overflow review, media/layout
  source audit, and clean diff/source-name quarantine.

- **2026-08-14 — Aether CAD has a canonical-ready Assembly/Mate/BOM
  workbench shell.** The Assembly browser now uses shared tabs for Structure,
  Mates, and BOM. A typed presentation store covers unavailable, loading,
  ready, and error states plus filter/selection/expansion state. When a decoded
  Core projection is published, Structure renders the shared Tree, connectors/
  mates/relations use shared ListBox instances, BOM uses the shared DataTable,
  and the Properties dock shows the canonical read-only inspector projection.
  Until the persistent Core workspace producer lands, Structure and BOM state
  that dependency explicitly while the existing connector placement and
  Fastened preview remain available under Mates as a clearly labeled
  session-only Part proof. This does **not** claim persistent Assembly save or
  solve. Verification: 71 CAD tests, TypeScript check, production build, live
  keyboard/visual review, and clean diff/source-name quarantine.

- **2026-08-14 — Aether CAD has a truthful routed Drawing workspace.** The
  shared workspace-mode rail now opens a full-workbench Drawing route in
  Docked, Expanded, or Canvas layout and provides keyboard-operable return to
  the 3D model. The existing WebGPU viewport remains mounted but inert and
  hidden beneath the route. Today the route states that exact sheets are
  waiting for the canonical Core producer; its typed store automatically
  supports loading, error, and decoded-ready states without product fixture
  data. The ready workbench composes shared Tabs, Tree, ListBox, DataTable,
  PropertyGrid, fields, buttons, and menus with the exact sheet-space SVG
  renderer. Drawing mutation/export commands remain transport-disabled until
  the real controller is connected. This does **not** claim Drawing creation,
  rebuild, persistence, or export. Verification: 95 CAD tests, TypeScript
  check, production build, live Docked/Expanded/Canvas and 680 px overflow
  review, keyboard route recovery, one persistent viewport, no browser errors,
  and clean diff/source-name quarantine.

- **2026-08-14 — shared SearchField and Breadcrumbs are shipped and adopted
  by Aether CAD.** SearchField supports controlled/uncontrolled queries,
  immediate state plus delayed search intent, Enter flush, Escape/clear,
  optional scope, accessible result counts, disabled state, and a cross-package
  focus-ref hook. Breadcrumbs provides stable path IDs, current-page semantics,
  disabled locations, and long-path overflow through the definitive shared
  Menu. The gallery shows two distinct datasets for each. CAD now uses the
  shared search in Items, canonical Assembly structure, and Drawing browsers;
  the header shows a Modeling/Drawing workspace path and preserves typed Search
  focus routing. Verification: 108 UI tests/type-check/gallery build, 95 CAD
  tests/type-check/production build, live gallery search/scope/clear/overflow,
  live CAD filter/focus/path checks, 1280/680 px no-overflow, and no CAD browser
  warnings or errors.

- **2026-08-14 — the shared field family is complete.** Product-free
  `RadioGroup`, `SegmentedControl`, `Slider`, `ColorField`, and `FileField`
  implementations now join the existing text, number, select, checkbox, and
  field-row controls. They provide controlled/uncontrolled state, native form
  semantics, common labels/help/errors/disabled/focus treatment, arrow and
  Home/End choice navigation, explicit range units, synchronized validated hex
  input, and bounded browse/drop file lists. The gallery demonstrates every
  widget with both CAD/drawing and animation/hardware data and wraps cleanly at
  compact width. Verification: 121 UI tests, type-check and production build;
  95 CAD tests/check/build; Animation production build; live desktop/680 px
  keyboard, validation, visual, and fresh-session zero-console review.

- **2026-08-14 — shared CommandPalette v1 is shipped.** It consumes product-
  supplied command availability and emits stable command IDs plus optional
  argument text; execution remains in each application's registry. Ranked
  exact/prefix/substring/subsequence search covers labels, descriptions,
  categories, and keywords. Recents, category groups, icons, descriptions,
  shortcuts, disabled reasons, no-results state, display-order arrow/Home/End
  navigation, Enter/Escape, focus containment/return, and required argument
  follow-up are complete. Modeling and animation gallery datasets prove the
  same surface. Verification: 126 UI tests/type-check/build, 95 CAD tests/
  check/build, Animation build, and live desktop/680 px fuzzy/keyboard/
  argument/focus review with zero browser warnings or errors.

- **2026-08-14 — shared DocumentTabs v1 is shipped.** The controlled strip
  presents active, dirty, pinned, preview, and disabled document states and
  emits close, pin, stable-ID reorder, overflow selection, and horizontal/
  vertical split intent without owning document lifecycle or pane layout.
  Arrow/Home/End navigation skips disabled tabs; bounded strips retain the
  active document and use the shared Menu for hidden documents. CAD and
  animation gallery datasets cover the full and overflow variants.
  Verification: 130 UI tests/type-check/build, 95 CAD tests/check/build,
  Animation build, and live desktop/680 px keyboard/overflow/visual review
  with zero browser warnings or errors.

- **2026-08-14 — shared Toast and NotificationCenter v1 are shipped.** One
  product-free model covers success, warning, error, and determinate progress
  notifications. Toasts use named polite status or assertive error live
  regions and expose optional stable-ID actions, dismiss, and persistence.
  NotificationCenter presents controlled persistent read/unread history with
  timestamps, progress, mark-read/open, item action, removal, clear-all, and a
  named empty state. CAD and animation histories plus switchable toast stacks
  prove the same components. This completes the planned shared-widget expansion
  in the UI roadmap. Verification: 134 UI tests/type-check/build, 95 CAD tests/
  check/build, Animation build, and live desktop/680 px action/read/clear/
  progress review with zero browser warnings or errors.

- **2026-08-14 — Aether CAD uses the shared CommandPalette over its typed
  registry.** The header Commands button and Cmd/Ctrl+K expose ten existing
  command IDs with categories, fuzzy keywords, shortcuts, recent ordering,
  live enabled state, and exact unavailable reasons. Selection executes only
  through `cadCommands`; no second handler or CAD meaning was introduced.
  Verification: 96 CAD tests/check/build, UI and Animation builds, and live
  New Part execution, disabled mate explanation, fuzzy compact layout, Escape/
  focus return, and zero browser warnings/errors.

- **2026-08-14 — Aether CAD Visualization uses the completed shared field
  family.** Body finish is a keyboard-operable three-way SegmentedControl and
  bounded environment intensity is a native Slider with percent output. Both
  continue to dispatch the existing `cadAppearance` actions and update the
  same renderer-only session state; no persistence or CAD meaning changed.
  Verification: 96 CAD tests/check/build, UI and Animation builds, live Gloss/
  Reset/compact visual review, and zero browser warnings/errors.

- **2026-08-14 — the Aether CAD frontend-independent roadmap is complete and
  its remaining blocker is explicit.** UI-0 inventory/isolation, the complete
  shared-widget matrix, shell migration, Part/Sketch/Inspect/Rebuild, all three
  layouts, accessibility/scale/task hardening, canonical-ready Assembly and
  exact Drawing consumers, and their truthful dependency routes are shipped.
  The final inert-control audit added semantic nonselectable ListBox collections
  for read-only mates/problems and removed Export's no-op select callback.
  At the time of that audit, backend source contained neither frozen Assembly
  nor Drawing producer/RPC. The Assembly producer is now shipped in the next
  entry; product-controller wiring and exact Drawing creation/rebuild/export
  remain open UI-4 work. Verification: 135 UI tests/type-check/build, 96 CAD
  tests/check/build, Animation build, live read-only collection semantics, no
  browser warnings/errors, clean diff, and runtime/source-name quarantine.

- **2026-08-14 — AnimaCore ships the canonical persistent Assembly/Mate/BOM
  producer.** One renderer-free `AetherWorkspace` graph now owns stable IDs,
  opaque monotonic revisions, Part definitions, Assembly instances, normalized
  Part-local connector frames, fastened/revolute/prismatic mates and native-
  unit DOF, relations, grounding, suppression, deterministic tree solving,
  typed limit diagnostics, and hierarchical/flattened derived BOM data. Every
  semantic mutation is revision-checked, atomic, and returns one coherent
  Assembly/solution/BOM refresh; mate preview is non-mutating. `new_workspace`,
  describe/mutate/solve/BOM, deterministic `save_workspace`, release, and
  `load_workspace` use the existing direct and HTTP `/rpc` envelope. `.aether`
  ZIPs contain checksummed canonical graph JSON with byte-stable entries;
  semantic state reopens unchanged when disposable cache data is missing or
  invalid. This unblocks the existing canonical-ready Assembly workbench, but
  does not claim that its product controller or Drawing producer is connected.
  Verification: 1,195 AnimaCore tests pass (3 optional-media skips), including
  17 focused direct/HTTP producer gates and a real HTTP subprocess; claimed
  Python files are ruff-clean; Aether CAD 96 tests, TypeScript check, and
  production build pass. Repo-wide ruff is still polluted by the separately
  imported read-only CAD reference corpus and pre-existing example style
  errors; no files in that corpus were changed.

- **2026-08-14 — Aether CAD now opens, presents, and saves the canonical
  Assembly workspace.** One modular controller owns the active Core handle and
  accepts only revision-coherent Assembly/solution/BOM refreshes. New Assembly,
  browser/native `.aether` open, Core-owned byte save, Structure/Mates/BOM tabs,
  stable selection, and the read-only inspector now run against real `/rpc`
  data; the browser never parses or assembles the ZIP. The existing Part/STEP
  viewport session remains a separate transitional source. Vite proxies `/rpc`
  for development, while the rebuilt clickable macOS app supervises the same
  AnimaCore HTTP process and serves its bundled UI same-origin. The obsolete
  static-only launcher server was removed. Verification: 101 CAD tests plus
  TypeScript check/build, 19 focused Core/HTTP tests, claimed Python ruff,
  Swift launcher type-check, signed root app build, packaged `hello` RPC, and a
  live New Assembly → solved revision 1 → Structure/Mates/BOM → Core save flow
  with zero browser warnings/errors. The remaining traditional-toolbar and
  full CAD tool-surface expansion is tracked separately; exact Drawing still
  lacks its canonical producer.

- **2026-08-14 — Aether CAD's camera and 3D environment now meet the shared
  Studio viewport baseline.** The orbit-synchronized ViewCube retains its six
  face and Home actions and adds deterministic 15-degree up/down/left/right
  nudges plus 90-degree roll in either direction. Top, Front, Right, and
  Isometric are live registry commands. Shaded, Shaded with Edges, Wireframe,
  Hidden Line, and Ghost share one renderer policy; Studio, Softbox, Daylight,
  Dark Room, contact shadows, and None/Grid/Floor/Both ground modes share one
  renderer-only appearance snapshot with the Visualization browser. The
  traditional ribbon and command palette expose the same 24 connected command
  IDs and active state; no display choice changes exact CAD state. Verification:
  115 CAD tests, TypeScript check, production build, live WebGPU ViewCube/view/
  display/lighting/shadow review, and rebuilt signed root macOS app pass.

- **2026-08-14 — Aether CAD now has one cross-surface CAD selection system.**
  Auto, Component, Body, Face, Edge, and Vertex filters share one typed
  renderer/UI snapshot with hover preselection, stable selected entity IDs,
  Shift/Command extension, empty-click clearing, and F6 cycling. Exact face,
  edge-midpoint, and vertex candidates come from the existing OCCT topology
  projection. Left-to-right Window box selection requires projected
  containment; right-to-left Crossing selects projected intersections. The
  authored Body or imported Part remains selected in the shared Items tree
  when a sub-element is selected. Home ribbon, command palette, floating tools,
  lower-right filter HUD, viewport highlights, and status all consume the same
  state; no CAD semantics moved into Three.js. Verification: 118 CAD tests,
  TypeScript check, production build, live authored-Part Body/Face/Edge/F6/tree
  review, deterministic Window/Crossing policy tests, and rebuilt signed root
  macOS app pass.

- **2026-08-15 — The shared Aether workspace shell preserves one live viewport
  across every layout theme.** Docked, Floating, and Canvas now rearrange
  chrome around one stable center React subtree instead of replacing the
  canvas. Three.js/WebGPU renderer state, camera state, and loaded scene stay
  mounted while rails, panel stacks, floating chrome, and canvas hot zones
  change. A regression pin verifies one mount through all three presets and one
  teardown only when the workspace closes. Verification: 136 shared UI tests,
  UI type-check/build, Aether CAD check/build, and Aether Animation build pass.

- **2026-08-15 — ViewCube navigation is now shared Aether UI rather than
  CAD-owned HTML.** The controlled, product-free `ViewportNavigationCube`
  renders quaternion orientation and emits accessible Front/Back/Left/Right/
  Top/Bottom, fit-isometric, 15-degree nudge, and quarter-turn roll intent.
  Aether CAD consumes it through an isolated camera presentation store; the
  existing viewer still owns camera basis math and updates, so orbit changes
  rerender only the cube rather than the application shell. Live Top and Roll
  actions changed the real camera/cube, reported accurate status, and produced
  zero browser warnings/errors. Verification: 138 UI tests/type/build, 120 CAD
  tests/check/build, Animation build, signed root app rebuild, and diff/name
  quarantine pass.

- **2026-08-15 — Panel placement now has one shared suite contract.** A new
  product-free `PanelPlacementMenu` supplies consistent Dock/Float/Hide radio
  behavior, focus handling, and popup presentation while emitting placement
  only. `WorkspaceShell` now accepts controlled or uncontrolled stable-ID
  panel state, including floating coordinates, so applications can persist
  layout without duplicating shell behavior. Aether CAD's Browser, Properties,
  and History/Problems menus consume the shared control while its presentation
  store remains preference authority. Live Browser Dock → Float → Dock → Hide
  plus global Reset produced exact placement state and zero browser errors.
  Verification: 140 UI tests/type/build, 120 CAD tests/check/build, Animation
  build, and rebuilt signed root app pass.

- **2026-08-15 — Aether CAD now exposes the complete principal standard-view
  command set.** Top, Bottom, Front, Back, Right, Left, and Isometric route
  through the existing typed command registry and viewer camera path. The
  traditional View ribbon, shared command palette, and shared ViewCube now
  present one coherent set; no camera math or document state was duplicated in
  React. Live Back, palette Bottom, and ribbon Left each changed the real camera
  and cube orientation, reported the exact status, and produced zero browser
  warnings/errors. Verification: 120 CAD tests, TypeScript check, production
  build, and rebuilt signed root app pass.

- **2026-08-15 — The traditional CAD View workspace now exposes the complete
  shipped discrete appearance surface.** Graphite/Midnight/Slate backgrounds,
  Matte/Satin/Gloss body finishes, exact feature edges, None/Grid/Floor/Both
  ground modes, and appearance reset join display, lighting, and shadows in the
  typed command registry. The traditional ribbon, shared command palette, and
  Visualization panel project one renderer-owned session state; no exact model
  or document meaning was added. Live ribbon and palette changes synchronized
  across all three surfaces, Reset restored defaults, and browser logs stayed
  empty. Verification: 120 CAD tests, TypeScript check, production build, and
  rebuilt signed root app pass.

- **2026-08-15 — Persistent Assembly instances now have their first canonical
  edit controls in Aether CAD.** Ground/Float, Suppress/Restore, and Remove
  Component are typed ribbon and command-palette actions enabled only for one
  selected instance when Core reports instance editing is available. The
  controller forwards the current handle, expected revision, Assembly ID, and
  stable instance ID; Core remains the only owner of grounding, suppression,
  solve, and BOM meaning. Rejected edits retain selection; successful removal
  clears it through the refreshed projection. A real HTTP producer cycle moved
  a populated workspace through grounded revision 4, suppressed revision 5
  with BOM exclusion, and removed revision 6 with zero instances/BOM rows,
  while the live empty Assembly kept all three actions disabled and logged no
  browser errors. Verification: 122 CAD tests, TypeScript check, production
  build, and rebuilt signed root app pass.

- **2026-08-15 — The persistent Assembly BOM now supports both canonical
  projection modes.** The BOM workbench switches between Hierarchical and
  Flattened by requesting `project_bom` from Core and publishing the returned
  revision-coherent rows. React does not group, flatten, or filter semantic BOM
  structure. The controller preserves the chosen mode across later instance
  mutations by re-requesting that projection, falling back only to the coherent
  mutation response if the extra projection cannot be fetched. Live toggles
  returned exact `BOM view: flattened` and `BOM view: hierarchical` status with
  no browser warnings/errors. Verification: 124 CAD tests, TypeScript check,
  production build, and rebuilt signed root app pass.

- **2026-08-16 — Persistent Assemblies can now author and insert a Part
  component from the traditional CAD workbench.** Insert Component is
  available from the Assembly ribbon, Assembly actions menu, and shared
  command palette only while Core reports instance editing is available. The
  shared-field dialog captures Part and instance identity, source label,
  optional Part number, mass in kilograms, rest position in meters, and
  grounding. The controller first asks Core to create the Part definition,
  reads its returned stable ID, and then creates the instance at the next
  expected revision. A rejected second mutation triggers a compensating Core
  removal of the unused definition; React never owns a parallel Assembly graph
  or groups the returned BOM. A live bridge flow advanced an empty Assembly
  from revision 1 to revision 3, projected grounded `Bracket:1` in Structure,
  projected `BR-100 · Bracket · 1` in the hierarchical BOM, and saved the
  resulting `.aether` archive through Core with no browser warnings/errors.
  Verification: 129 CAD tests, TypeScript/production build, rebuilt signed root
  app, diff/whitespace checks, and integration-name quarantine pass.

- **2026-08-16 — Persistent Assemblies can now author manual mate connectors
  on selected components.** Selecting exactly one instance enables Connector
  in the Assembly ribbon, Assembly actions menu, and shared command palette
  when Core permits connector editing. The dialog captures a connector name,
  optional datum label, Part-local origin in meters, and two nonparallel signed
  axis presets. The controller targets the selected instance's Core-owned Part
  definition and submits `add_connector`; Core normalizes the right-handed
  frame, assigns the stable ID, returns the next coherent Assembly/solve/BOM
  revision, and the UI selects that returned connector for inspection. This is
  explicitly manual authoring and does not claim viewport snapping or exact-
  feature provenance. A live flow advanced the populated Assembly to revision
  4, showed `Shaft axis · Bracket · Datum A` in the canonical connector list,
  inspected origin `0.1, 0, 0 m`, primary `0, -1, 0`, and secondary `0, 0, 1`,
  then saved through Core with no browser warnings/errors. Verification: 133
  CAD tests, TypeScript/production build, rebuilt signed root app, diff/
  whitespace checks, and integration-name quarantine pass.

- **2026-08-17 — Persistent Assembly mate preview and commit are now live.**
  The traditional Assembly Mate tool, Assembly actions menu, and shared
  command palette enable only when two active instances expose persistent
  connector endpoints. One shared-field dialog authors Fastened, Revolute, or
  Prismatic mates and invalidates its solve preview after every edit. Preview
  calls Core without changing the Assembly revision; Apply remains disabled
  until the current draft solves, then `add_mate` advances the canonical graph,
  selects Core's returned stable mate ID, and republishes solve and BOM data.
  The older Part-local session proof remains isolated. A live two-component
  flow held revision 8 through solved revolute and prismatic previews (one free
  DOF each) and a solved fastened preview (zero free DOF), advanced only the
  fastened commit to revision 9, projected the selected satisfied mate, and
  saved the `.aether` workspace through Core. Verification: 139 CAD tests,
  TypeScript/production build, rebuilt signed root app, diff/whitespace checks,
  and integration-name quarantine pass.

- **2026-08-17 — Selected persistent mates now have a complete lifecycle.**
  Suppress/Restore and Remove Mate are selection- and capability-aware typed
  commands in the traditional Assembly ribbon, Assembly actions menu, and
  shared command palette. The UI serializes the full selected Core mate
  projection for revisioned `update_mate`, changing only suppression state;
  removal sends the stable mate ID through `remove_mate`. Rejected dependency
  edits retain selection and report Core's error, while successful removal
  clears selection only after the coherent projection returns. A live flow
  retained the selected fastened mate through suppressed revision 10 and
  restored revision 11, removed it at revision 12, projected zero mates, and
  saved the resulting `.aether` workspace through Core. Verification: 140 CAD
  tests, TypeScript/production build, rebuilt signed root app, diff/whitespace
  checks, and integration-name quarantine pass.

- **2026-08-17 — Free persistent mate DOFs now expose value and limit
  authoring.** Selecting an active revolute or prismatic mate enables Set DOF
  Value and Edit DOF Limits across the traditional Assembly ribbon, Assembly
  actions menu, and shared command palette. The shared numeric dialogs present
  revolute values in degrees and prismatic values in meters; typed payload
  helpers convert rotation to radians at the Core boundary. `set_dof_value`
  owns posing, revisioned `update_mate` owns paired minimum/maximum limits, and
  the inspector projects Core's value, state, and limits. Suppressed or
  relation-dependent DOFs stay gated. Core reports out-of-range values as
  warnings rather than the UI silently clamping them. Live verification set a
  revolute mate to 45° with −30°…60° limits, observed the expected warning at
  90°, then set a prismatic mate to 0.025 m with −0.05…0.1 m limits. Suppress
  disabled both editors; restore and Core save passed at revision 18.
  Verification: 142 CAD tests, TypeScript/production build, rebuilt signed root
  app, diff/whitespace checks, and integration-name quarantine pass.

- **2026-08-17 — Persistent DOF relation authoring is now live.** A typed
  Create Relation workflow exposes Gear, Rack and Pinion, Screw, and Linear
  pairings from compatible free Core DOFs. The dialog captures stable driver
  and driven identities, a positive magnitude plus reverse direction, and an
  offset in the driven DOF's unit family; rotation offsets convert from degrees
  to radians at the boundary, translation offsets remain meters, and mixed
  ratios are explicitly labeled m/rad. Core owns pairing validation,
  dependency order, stable relation identity, and the solved dependent value.
  The inspector now resolves relation endpoints to mate/DOF names and displays
  Core's solved value for dependent DOFs. Live verification created a reversed
  2:1 gear relation with a 10° offset, set its driver to 30°, projected the
  driven DOF as dependent at −50°, disabled direct dependent editing, and
  saved the revision-15 workspace through Core. Verification: 145 CAD tests,
  TypeScript/production build, rebuilt signed root app, diff/whitespace checks,
  and integration-name quarantine pass.

## How to update this file

1. Ship a behavior change.
2. In the same commit, add or edit a line above reflecting the new truth.
3. If something moves from "planned" to "shipped," delete it from
   `../roadmap/` (or mark it done there) — don't leave the same fact
   living in two docs, per `CONVENTIONS.md` law 1.

## Standalone CAD UI mockup — 2026-09-08

`onshape mockup/` now contains an isolated React 19 + TypeScript/Vite + Tailwind
frontend with compact Onshape-style document/ribbon/tree/viewport/tab chrome.
Three.js renders a procedural mounting bracket and bore insert with real
OrbitControls, reference planes, axes, clickable ViewCube, projection switching,
display modes and section clipping. Local editor interactions cover sketch
commit/cancel, floating parameter editing, feature undo/redo and context menus,
rollback, part visibility/isolation, appearance, configuration width, assembly
ribbon switching, and prototype JSON export/import. This is a frontend fixture,
not an OCCT B-Rep loader, constraint solver or engine-backed CAD authoring path;
advanced modeling, drawing, collaboration and exact properties remain labeled
placeholders. All tab data is currently session-local and shares the fixture.
Verification: 6 component interaction tests, lint, TypeScript and production
build pass. No browser connection was available; visual/pointer QA is pending.

## Standalone CAD adaptive docking — 2026-09-08

Phase 2 in `onshape mockup/` adds the requested five-panel `PanelState` and
`LayoutTheme` contract with a global React external layout store. The header
switches between Onshape docked lanes and a Shapr3D floating workspace. Parts,
feature history, commands, navigation cube and element tabs independently dock
on any edge, float, or hide. Drag grips support edge docking and keyboard movement;
a layout menu restores hidden panels and resets the current preset. Validated
versioned device-local preferences retain each preset's custom placements.

Dock/float bounds derive from the store and measured workspace; resize clamps
floating panels to reachable coordinates. Stable panel parents and a permanent
cube portal preserve editor contents, the main scene canvas, the navigation
canvas and both renderer lifetimes across mode changes. Feature/engine semantics
remain outside the layout store. Verification: 13 tests (including actual viewport
component lifecycle with stubbed GPU), lint, TypeScript and production build pass.
No connected browser was available; visual/GPU/pointer-ergonomics QA is pending.


## Aether Studio suite identity — 2026-09-08

The local checkout is now `Aether Studio/`, with `AnimaStudio` retained as a
compatibility symlink for existing development paths. The root README and
contributor guidance now identify Aether Studio as the suite and Aether Animation
as the already-renamed web animation product. GitHub remote and engine/format
identifiers are unchanged. Source review confirms CAD and Animation already use
React/TypeScript; the Onshape mockup remains a fixture prototype. The unified
installer, package manager and cross-device host remain planned in
`../roadmap/Aether_Studio_Suite.md`. Verification: directory/link resolution,
Python engine import, documentation links and diff whitespace; no application
behavior changed and no runtime product tests were rerun.


## Shared core directory — 2026-09-08

Moved shared packages intact from `aether-core/` and `aether-ui/` to
`core/engine/` and `core/ui/`. Import identities remain `@aether/core` and
`@aether/ui`; engine modules stay UI-independent. Updated CAD/Animation local
package dependencies and locks, CAD Vite allowlist and STEP smoke script, CI,
gallery launcher paths/root calculation, ignore comment, and current contributor,
package and suite docs. Added `core/README.md`. Existing widget edits were carried
intact; the active CAD chrome claim continues at the new paths. Product directories,
Python semantics, historical handoffs and archive sources were not reorganized.

Verification: Core 8 tests/check, UI 143 tests/typecheck/build, CAD 145 tests/check/
build and Animation build pass. UI launcher Swift typecheck, shell syntax and
signed app rebuild pass; installed package links, doc links and diff checks pass.
UI tests emit React act warnings; CAD/Animation builds emit bundle-size warnings.
No visible UI behavior changed; no GUI walkthrough performed.


## Native Studio shared web chrome — 2026-09-08

The native StudioDesignProfile structural palette, system font and 54px header
now feed the shared theme. CAD consumes the same WorkspaceShell as Animation;
its private ribbon, ViewCube and field skins were removed. Animation uses the
shared ViewportNavigationCube with live camera face/Home/nudge/roll adapters.
Both products retain their tool sets and engine authority. Shared shell additions:
retained panel DOM/input state, validated per-preset preferences (Animation),
keyboard float movement, resize clamping and compact rail-revealed side panels.

Rebuilt and opened `Aether Animation.app` and `Aether CAD.app`; both serve HTTP
200 and accept protocol-v1 hello. Moved the old root `Anima Studio.app` into
`aether-animation/archive/` as a reference. It is preserved, not deleted.
The mockup is also retained pending all-edge docking and independent toolbar/
ViewCube/tab placement integration. Full native-to-web workflow parity is not
complete: Assets/library, editable keyframes/curves, Show/Hardware and 2D/VR
remain tracked in `../roadmap/Aether_Studio_UI_Convergence.md`.

Validation: 145 shared UI tests/typecheck/build and 145 CAD tests/check/build;
Animation production build and signed native launcher builds pass. Isolated
local Chromium checks show zero page errors, identical computed header height/
background and ViewCube background/border in both apps, responsive 1440/780px
layouts, camera cube response, retained canvas across all presets and retained
CAD input draft followed by a real OCCT Part rebuild. The in-app browser was
unavailable; screenshots were inspected from the isolated local browser instead.
React act warnings and production bundle-size warnings remain nonfatal.


## Shared vector artwork — 2026-09-08

Added `core/assets/icons/` with 42 canonical SVG files exposed as 43 semantic
icon names (model aliases design), plus `core/assets/branding/aether-cad.svg`.
`AetherIcon` is now a thin renderer over those static sources; CAD's `CadIcon`
is a vocabulary adapter with no private geometry. Animation's main toolbar,
mate tools and panel/tree icons now use the shared vectors. The CAD native icon
build reads its moved shared branding source. Vite allowlists include shared
assets for UI gallery, CAD and Animation development. The shared gallery renders
all 43 names. Root contributor guidance and `core/assets/README.md` define SVG,
color, sizing, attribution and project-media boundaries.

Validation: 146 UI tests and 145 CAD tests pass, UI/CAD type checks and all three
web builds pass; focused icon tests/typecheck also pass after alias deduplication.
All three native launcher builds pass. Isolated local Chromium verifies the dev
gallery loads all 43 SVGs with zero page errors; its contact sheet was visually
inspected and a grid-width issue fixed. Diff whitespace check passes. Existing
React act and bundle-size warnings remain. Remaining legacy text glyphs in older
product tool catalogs/shared controls are explicitly recorded; this does not
claim every icon in the suite has already been migrated.

### 2026-09-08 — Shared launcher window treatment

CAD, Animation and UI now compile `core/ui/native/StudioWindowChrome.swift`: full-size web content, hidden transparent macOS titlebar and common header dragging. Core DocumentBar reserves native controls space only in the wrapper; embedded previews opt out. UI gallery now uses DocumentBar/WorkspaceShell/StatusBar with Library navigation and internal scrolling, removing the white body gutter. All three launchers rebuilt and signatures verified. Core UI 146 tests, typecheck/build, all product builds, browser header geometry/navigation checks and an AppKit configuration check passed. Existing open native windows need reopening to load the new executable.

User subsequently selected Safari Add to Dock as the preferred delivery direction. Current wrappers remain transitional: they still own their local servers. An independently running suite host and installed browser shortcuts have not yet been implemented.

### 2026-09-08 — Independent Studio host, administration and guided installation

`core/host/` now serves `studio/`, CAD, Animation and UI from one authenticated
origin. The installed macOS per-user LaunchAgent runs independently of browser
windows and starts at login; all four root .app shortcuts open browser URLs.
The default address is http://localhost:8780. Shared SVG-derived app/Dock icons
live under Core assets. Existing native wrappers are no longer the build target.

Studio uses the user's charcoal/blue sidebar reference, Core controls and a
shared home theme. Admin pages perform real bundled-app enablement, local user
creation/disable/roles/password reset/session revocation, team application grants,
scoped expiring service tokens, manual backups/download, offline restore,
network/TLS settings with explicit restart, and activity review. Community
plugins are an explicitly planned page, with no installer or execution backend.

The double-click installation command checks Python/Node prerequisites and
shows numbered engine/build/service/shortcut/browser stages. First-run browser
setup uses the supplied split-panel reference and shared SVG illustration:
Welcome → Workspace → Administrator → Applications → Review → completion.
Backtracking preserves drafts. Workspace name, first account and selected apps
are validated and saved together at Finish setup. Later visits to `/` show the
normal app-launching home with Sign in; direct `/cad/` and `/animation/` links
round-trip through sign-in to the requested application. Admin links remain
hidden and server-denied for other roles.

Auth uses salted scrypt, hashed session/service tokens, HTTP-only same-site
cookies, origin/host checks, rate-limited login and private user/app engine
sessions/storage. Animation text saves reject stale content revisions. Untrusted
workspace files are served as attachments, not executable same-origin HTML.
Network changes are validated, ports preflighted, and failed runtime listener
changes fall back to the prior listener. Actual deployment remains local-only
until HTTPS is configured; a physical second device was not tested.

Verification: 16 focused host integration tests; previous full engine+host run
1,212 passed / 3 skipped before the additional atomic-setup test; CAD 145 tests;
Core UI 146 tests; all four web builds and app signatures pass. Isolated browser
walkthroughs exercised setup/mismatch/backtracking/atomic app choices/completion,
public home/direct-link sign-in, admin users/teams/services/backups/settings,
member password change and denied admin access, app gating, three product routes,
and host restart/reconnect. Prerequisite check and script syntax pass; the actual
LaunchAgent is running and setup was opened without creating a real user account.
Targeted host/engine lint passes. Repo-wide lint still reports 233 existing
reference/example findings, left untouched.

Limits: installed-checkout distribution and a per-user login service; no SSO,
MFA, email recovery, organization tenancy, scheduled backups, team-shared
projects, universal CAD project migration or collaborative editing. Browser-local
unsaved projects and TLS files are outside host backups. See `core/host/README.md`
for supported setup, network, storage and recovery behavior.

## 2026-09-09 — Aether CAD: in-world sketch editing (Onshape-style)

Sketch editing now happens inside the 3D viewport instead of a separate 2D
overlay world. On plane/face selection the sketch SVG mounts as a
world-anchored, perspective-correct plane card (Three.js CSS3DRenderer) at
the sketch frame; the camera aligns square-on to the plane (sketch y up) and
normal navigation stays live throughout — middle-drag pans, right-drag
orbits, wheel zooms, ViewCube works. Left input routes from the viewport
canvas to the existing sketch machinery through a plane-raycast bridge
(`aether-sketch-surface` event: viewer supplies `toSketch`, `scaleAt`,
`updateBounds`), so all drawing tools, snapping, constraints, and gestures
operate on true plane coordinates from any camera angle. The plane card
grows automatically as the drawing expands. With no viewer present (tests,
gallery) the workspace falls back to the legacy flat overlay unchanged.
Verified: 433 CAD tests (2 new in-world DOM tests pinning the frame handoff,
raycast drawing, bounds growth, fallback, and surface teardown), typecheck,
production build.

Limits: the sketch card composites above the WebGL scene, so bodies in front
of the sketch plane do not occlude sketch curves during editing (upgrade
path: native WebGL sketch curve rendering); dimension-label drag, text-box
placement, and DXF placement still convert pointer positions with flat-
screen math and drift when the camera is orbited off-normal (they are exact
square-on); camera alignment is instant rather than animated.

## 2026-09-09 — Aether CAD: boot-crash fix + in-world sketch verified in Chrome

Fixed a startup crash that disabled sketching entirely: boot registered
`sketch-constraint-pattern` while the command registry's seed list filtered
"pattern" out, so `register()` crashed mid-`main.ts` and every command wired
after it (including the ribbon Sketch tool) stayed dead. The filtered list
is now exported once as `sketchConstraintCommandKinds` and used by both the
seed and boot registration (one copy of truth), with a registry test pinning
that every boot-registered constraint id is seeded. Also fixed the in-world
sketch surface swallowing viewport input: CSS3DObject's constructor forces
`pointerEvents:"auto"` on its element, which blocked the canvas beneath —
now reset to "none" after construction.

Verified end-to-end in real Chrome (puppeteer + Metal WebGPU) against the
built app: New Part → Sketch → Top (XY) opens in-world; two clicks draw an
open line contour on the plane; right-drag orbits mid-sketch and a third
click still lands on true plane coordinates; zero console errors. 434 CAD
tests (registry seed test added), typecheck, production build pass.

## 2026-09-09 — Aether CAD: compact floating sketch window (Anima Studio chrome)

Per Jonathan: the sketch inspector was an overloaded fixed sidebar; sketch,
plane and mate authoring should reuse the small focused windows built for
Anima Studio. The sketch workspace panel is now a compact draggable floating
window using the shared `aui-float-panel` chrome from `@aether/ui` (drag by
header, scrollable body, top-right default clear of the ViewCube).
Progressive disclosure replaces the always-visible control pile: the full
constraint editor collapses behind one "Sketch constraints" disclosure that
auto-opens when an entity is picked on canvas or a ribbon constraint command
runs, and every entity-target helper now appears only when the sketch
contains that entity type (arc/ellipse centers, ellipse axes, spline
handles, polygon sides, point/origin targets) — an empty or line-only
sketch shows none of them. All controls keep their identities; 434 CAD
tests, typecheck, production build pass; real-Chrome walkthrough
re-verified (in-world draw, orbit mid-sketch, draw again).

Next: plane and mate dialogs adopt the same floating-window chrome; tool
option fields (Arc direction / Polygon sides / Secondary radius) could gate
tighter per active tool.

## 2026-09-09 — Aether CAD: empty sketches are valid

Per Jonathan: finishing a sketch without drawing is allowed — selecting the
plane alone defines the sketch. Removed the app-side "Draw a contour before
finishing" gate; Core already stores contour-less sketches and skips them
during solid evaluation. Pinned by a workspace DOM test (finish empty →
feature saved with zero contours). 435 CAD tests, typecheck, build pass.

## 2026-09-09 — Aether CAD: instant plane creation with a floating window

Per Jonathan: clicking the Plane tool must create the feature immediately —
no modal, no forced naming. The Plane command now inserts an auto-named
construction plane (Plane N, XY, 10 mm) instantly and opens a compact
draggable floating window (shared panel chrome) with just Reference plane
and Offset; Apply commits edits, ✕ discards a freshly created plane
(editing an existing plane, ✕ only closes). Behavior pins updated: instant
create + window edit + discard. 436 CAD tests, typecheck, build pass.

## 2026-09-10 — Aether CAD: entity-based plane definitions (Offset, Mid plane)

Per Jonathan: the plane window must be an entities list plus a method
dropdown, not a hardcoded XY/XZ/YZ choice. Core owns the new semantics in a
dedicated module (`core/engine/src/document/construction-planes.ts`):
`PlaneReference` (principal or earlier plane feature), `PlaneDefinition`
(`offset` with distance, `mid` between two parallel planes), recursive
frame resolution, and validation (references must be earlier construction
planes; non-parallel mid planes reject at resolve). Legacy planes without a
definition still resolve as principal+offset — no migration needed; the
definition round-trips through `.acpart` serialization. The plane window
(dedicated `Aether CAD/src/plane-window.ts`, extracted from
feature-authoring) shows the method dropdown, a removable-entities list,
and an add-reference picker offering principals and earlier planes; Apply
builds the definition (legacy fields stay synced for principal offsets).
5 new Core tests + 2 plane-window DOM tests + updated pins: 703 Core /
438 CAD tests, typechecks, build pass.

Limits: references are planes only (no faces/edges/points yet), so Plane
point / Line angle / Three point / Tangent methods remain future work;
entity adding is via the window's picker, not viewport clicking; no live
3D preview while editing.

## 2026-09-10 — Aether CAD: standard feature window (Onshape anatomy)

Per Jonathan: the feature window is the standard design for many features
and must copy Onshape's widget exactly, re-themed dark macOS. New dedicated
module `Aether CAD/src/feature-window.ts`: draggable header with title +
green ✓ accept + red ✕ discard, Enter anywhere commits, captioned bordered
Entities box with per-row ×, inline parameter rows, status line, and a
universal window-opacity slider footer. `plane-window.ts` rebuilt on it:
Entities first (added by clicking planes in the viewport or Items tree —
the picker widget is gone; window enables plane-select mode while open),
then the method dropdown (Offset / Mid plane), an "Offset distance … mm ⇅"
row (⇅ flips the offset sign), and a Flip normal checkbox backed by a new
`flip` flag in Core plane definitions (negates the resolved normal;
round-trips; tested). Tree clicks on plane features route through a new
`aether-plane-feature-picked` event in main.ts. Verified in real Chrome:
instant Plane 1 + window with Top plane entity, zero console errors.
710 Core / 438 CAD tests, typechecks, build pass.

Not copied from Onshape (features we don't have yet): the "Final" feature-
state button and help icon; the slider maps to window opacity per Jonathan.

## 2026-09-10 — FeatureWindow promoted to Aether UI + all CAD feature dialogs converted + gallery section

The standard feature window moved into the shared design system:
`core/ui/src/FeatureWindow.ts` (`openFeatureWindow`, `aui-feature-*`
classes in widgets.css, WIDGETS.md row) — imperative DOM, product-free,
consumed by Aether CAD via `@aether/ui`. Every remaining CAD feature
dialog (extrude, revolve, mirror, fillet, chamfer, legacy profile)
dropped its modal `<dialog>` and now mounts in the standard window
(✓ = Apply and rebuild, ✕ = Cancel; Enter defers to native form submission
inside forms). The Aether UI gallery gained a "Feature windows" section
showing Plane, Extrude, and Mate windows side by side; the mate demo is
faithful to the archived Anima Studio MatePlacementOverlay anatomy
(Moving/Fixed connector chips, kind picker, flip primary axis, reorient
secondary 0/90/180/270°, offset XYZ) per the Swift-archive inventory.
Verified: 153 core/ui tests, 439 CAD tests, 710 core/engine tests,
typechecks, builds; gallery section screenshotted live.

Swift-archive inventory findings (dev/briefings handoff has details):
extrude/sketch windows never existed natively — they are web-first and now
standard-window based. NOT yet on web: the full mate EDIT inspector
(connector flip, offset XYZ + rotate-about, DOF neutral/min/max limits,
simulation connection), relation creation/editor windows, import-units
sheet, per-part appearance editor. These are the next faithful-import
targets.

## 2026-09-10 — Aether UI: seven-window reference set in the gallery

Per Jonathan's Onshape reference of seven feature windows: FeatureWindow
gained a segmented `tabs()` primitive (Solid/Surface/Thin and
New/Add/Remove/Intersect rows) and empty entity boxes read as hint fields.
The gallery "Feature windows" section now shows nine standard windows side
by side — Sketch, Extrude (full reference anatomy: tabs, end-type
dropdown, depth, direction/offset/symmetric/draft/second-end rows),
Revolve (axis box + full-revolve), Sweep (path box, profile control,
twist/scale), Loft (profiles, end conditions, guides/path/isocurves),
Thicken (mid plane, thickness 1/2, keep tools), Enclose, plus the earlier
Plane and Mate windows. These are design-system specimens; wiring the real
extrude/revolve editors to the reference anatomy (end-type semantics,
direction/draft) is Core work queued behind them. 153 UI tests, typecheck,
build pass; live gallery screenshot verified.

## 2026-09-10 — Suite settings window (Anima Studio import) + CAD settings

The Anima Studio Settings window is now the suite-standard per-app
settings shell: `core/ui/src/SettingsWindow.tsx` (+SettingsCard/
SettingsRow) with macOS anatomy — traffic-light close, grouped sidebar
(General / Viewport / Advanced), centered title, card-based panes,
Escape/scrim close; gallery specimen section added. Aether CAD's existing
header gear now opens `CADSettingsWindow` (dedicated file) replacing the
old Preferences dialog, with the Swift pane structure: Workspace, Layout,
UI, Renderer, Appearance, Materials & Edges, Lighting, Navigation,
Developer. Wired today: toolbars traditional/floating, window chrome
suite/classic, reset panel placements, display style, background, ground,
contact shadows, reset appearance, material finish, feature edges,
lighting preset, environment intensity, backend/kernel readouts.
Everything the web app cannot honor yet is present but greyed out and
disabled, faithful to the Swift originals per the archive inventory
(project location/Change…, unitless import units, autosave, frame rate,
design preset/accent/density, render engine picker, coordinated CAD
themes, reflections, environment rotation, roughness/metallic/edge
definition, light rig, navigation profiles/speeds, developer toggles).
156 UI / 443 CAD tests, typechecks, builds pass; live Chrome screenshot
verified with zero console errors.

## 2026-09-10 — Aether CAD: Commands and Help moved into the settings tray

Per Jonathan: the header keeps only Settings (plus Export/account); the
Commands and Help icon buttons are gone. The settings sidebar gained a
"Reference" section with two panes. Commands: an "Open command palette"
row (⌘K still works globally) plus a filterable, category-grouped list of
the full command catalog with shortcuts and Run buttons — disabled
commands grey out with their reason. Help: the former help dialog content
restyled as settings cards (Part workflow, Assembly workflow, keyboard/
viewport rows, notice card). `show-help` now opens the settings tray on
the Help pane; the old Preferences/Help dialogs and UtilityDialogs are
removed. Settings icon asset fixed from a sun glyph to a real gear
(shared core/assets icon, all apps rebuilt). 443 CAD tests, typecheck,
build pass; live Chrome screenshots verified.

## 2026-09-10 — Settings window: faithful macOS rendering pass

Per Jonathan against the Anima Studio reference: sidebar pane items now
carry icons (nine new shared stroke icons — sidebar, cube, palette,
layers, lighting, mouse, hammer, plus existing folder/layout/commands/
help; settings gear fixed earlier). SettingsCard renders the Anima Studio
section header (accent icon + bold title + muted caption); SettingsRow
gained icon/value/stacked variants — stacked renders the full-width
slider row with a right-aligned value label ("Orbit speed — Standard");
checkboxes replaced by a macOS pill switch (`input.aui-switch`).
Navigation pane is now faithful: Navigation Profile card, Motion Response
card (orbit/pan/zoom sliders + reverse-wheel switch, disabled until input
mapping lands), Keyboard card. 156 UI / 443 CAD tests, builds pass;
live screenshot matches the reference anatomy.

## 2026-09-10 — Aether CAD home: Get started cards + OneDrive-style recents

Per Jonathan's OneDrive reference: the CAD library home (studio
LibraryHome, served at /cad/) keeps its hero and gains a "Get started"
row of file-type cards — Part, Assembly, Drawing, Project — using four
new colored tile icons added to the shared icon library (file-part,
file-assembly, file-drawing, file-project). Part/Assembly/Project cards
run the same create flows as the sidebar Create menu; Drawing is a
disabled placeholder (sheets are created inside an open document). The
recents list gained OneDrive anatomy: type filter chips (All / Parts /
Assemblies / Drawings / Projects), a right-aligned "Filter by name or
person" field, and table rows with the colored type tile plus a
"My files / Workspace shared" subline under the name; columns are now
Name / Opened / Owner. Grid view uses the same type tiles. File types
derive from extensions (.acpart/.cadpart → Part, .acasm/.aether →
Assembly, .acad → Project, .acdraw reserved for Drawing). Studio build
passes; the page is sign-in protected so review is in-browser after
refresh.

## 2026-09-10 — CAD home: right-click menu + OneDrive table controls

The library's middle section now has an OneDrive-style right-click menu
(new studio/src/ContextMenu.tsx): empty space shows "Add New ▸"
(Part / Assembly / Project / Folder / Import file…, wired to the same
create flows) plus Details; right-clicking a row selects it and offers
Open / Details. Submenu, Escape/outside-click dismissal, shadows through
theme tokens (build's color-literal guard enforced). The list heading
gained the OneDrive control cluster right of the search: Sort dropdown
(Opened / Name / Owner) with an ascending/descending toggle applied to
the visible list, the list/grid switch, and a Details button that shows
or hides the right details rail. Studio build green.

## 2026-09-10 — Library file management: selection command bar + collapsing details rail

Selecting a file swaps the control row's left side into a OneDrive-style
command bar of borderless tools — Open, Rename (writable), Download,
Duplicate, Share/Make private (writable), History, and a disabled Delete
placeholder (recycle-bin backend not wired) — with an "✕ 1 selected"
clear chip joining the right cluster. The details rail no longer wastes
its column when closed: it stays mounted and the root grid animates
grid-template-columns 255px ↔ 0 (0.25s), so the workspace expands and
shrinks smoothly with the Details toggle. Studio build green.

## 2026-09-10 — Studio: redundant page-title bars removed

The admin workspace's top bar (page title duplicating the sidebar's
active item, "Aether Studio" caption duplicating the brand, lone refresh
button) is gone; the refresh control now sits beside the Online badge in
the Home page heading. The public home's equivalent bar (title + a
Sign-in button the sidebar already provides) is removed too. The library
header (brand · search · account) is functional and stays. Studio build
and color guard green.

## 2026-09-10 — Library home is app-parameterized; Aether Animation gets its home

The library sidebar dropped its footer note ("Saved on your server…") and
the "← Aether Studio" back link (the brand icon already links home).
LibraryHome is now config-driven per app (brand, app icon, hero copy,
accepted extensions, file types with tile icons, Create-menu choices,
Get-started cards, deep-link URLs); CreateMenu accepts a choices list.
/animation/ now serves the identical home page (host router carve-out +
studio route): Aether Animation branding, Get started cards — Character
(creates via /animation/index.html?new=character), Clip / Show / Project
as honest disabled placeholders — recents/filters/commands identical,
with new file-character / file-clip / file-show tile icons in the shared
library. Types: .anima → Character, .aether → Workspace, .show reserved.
40 host tests, studio/ui builds, ruff pass; host restarted healthy
(/animation/ now 302s to sign-in like /cad/).

Known gap (animation app lane): the Animation app does not yet read
?document= or ?new=character deep links — Open/Create land in the app but
load the default character until the app wires host-library documents.

## 2026-09-10 — Aether CAD: per-document-type ribbon layouts (Parts first)

The ribbon now renders a layout keyed by the open document type
(dedicated `cad-toolbar-layouts.ts`; the shared tool catalog remains the
single definition of every tool — layouts only select and filter).
"Project" (and the Start screen) preserves the complete legacy
arrangement. The first refinement is Parts: the Assembly tab is dropped
and assembly-scoped Home tools (New Assembly, Component selection) are
filtered out; excluded active tabs fall back to Home. The shell derives
the type live: canonical Assembly ready → assembly; Part open → part;
otherwise project. Assembly and Drawing layouts intentionally keep the
full set until their own passes. 4 layout pins + 447 CAD tests,
typecheck, build; live Chrome check confirms the tab switch with zero
console errors.

## 2026-09-10 — Aether CAD: Fusion-style Part ribbon

Part documents now mirror Fusion's Design workspace. Tabs: Solid,
Surface, Mesh, Sheet Metal, Plastic, Manage, Utilities. Each tab is
sections in the Fusion anatomy — prominent tools above a "Create ▾ /
Modify ▾ / Construct ▾ / Inspect ▾ / Insert ▾ / Select ▾" label that
drops the section's complete tool list (overflow tools live only in the
menu). All entries reference the shared tool catalog by id (one
definition per tool; unimplemented ones stay honestly disabled with
their producer reasons). Editing a sketch appends a contextual Sketch
tab (catalog sketch tools as sections), auto-activates it, and shows a
green "✓ Finish Sketch" that finishes via a new aether-sketch-finish
event; on finish the tab reverts to Solid. The Design ▾ workspace
switcher is re-themed to app tokens and lists Fusion's modes —
Generative Design, Render, Animation, Simulation, Manufacture, Drawing,
Electronics — all disabled with honest reasons until built. Project (and
Start screen) keep the legacy ribbon unchanged; assembly/drawing types
still pending their passes. 9 new pins (452 CAD total), typecheck,
build; live Chrome run verified tabs, contextual sketch flow, finish,
and revert with zero console errors.

## 2026-09-10 — Ribbon polish, toolbar density, boot-crash guard

Fusion ribbon polish per Jonathan: the floating toolbar card border is
gone (dividers only), section labels ("Create ▾" …) dropped to the
header-tab type size, tool icons enlarged. New toolbar density setting:
right-click the ribbon for a Density menu — Compact (icons only, larger)
or Standard (icons and labels) — persisted per browser; applies to both
the Fusion and legacy ribbons. Boot hardening: the command-palette
builder now degrades unseeded catalog ids to disabled entries instead of
crashing the shell at boot (this exact class hit twice: the
sketch-constraint-pattern incident and today's background-slate registry
refactor landing mid-write during parallel agent work). Live Chrome:
boot clean, density menu applies compact, zero console errors. Note:
two AetherCADShell test pins (palette count, Visualization strings) are
transiently red from Codex's in-flight claim — its lane to settle.

## 2026-09-10 — Aether CAD: spacebar orientation snap

Pressing Space in the viewport (outside text fields and sketch editing)
snaps to the isometric view and zooms to fit the model — the
SolidWorks-style "cube view around the object". Routed through the
existing view-isometric and fit-view commands. 452 CAD tests, build,
live check pass. Codex's two transient shell pins settled green in the
same run.

## 2026-09-10 — Aether CAD: spacebar orientation box (SolidWorks-style)

Space now toggles a real-3D orientation box in the scene: a translucent
cube sized to engulf the rendered bodies (minimum side when the part is
empty — the earlier silent behavior came from fit-view being a no-op on
empty parts), camera pulled back so the whole box is visible. Hovering a
face highlights it; clicking snaps the camera to that side (Right/Left/
Top/Bottom/Front/Back via the standard view definitions) and closes the
box; Space again or Esc dismisses. Viewport picking is suspended while
the box is open. Live-verified: box appears on Space, face click landed
"Right view", zero console errors. 452 CAD tests, build pass.

## 2026-09-10 — Orientation box restyled to SolidWorks paddles; camera stays live

The orientation box is now six rounded translucent paddles floating just
off each face of the model bounds (grey, accent-highlight on hover, edge
outlines), replacing the plain blue cube. While open, orbit / pan / zoom
work normally and the paddles persist — only a stationary left click
acts (orbit-drag releases no longer dismissed or reoriented the view);
left-click on a paddle snaps to that side, left-click on empty space,
Space, or Esc closes. Live-verified: box survives orbit, paddle click
landed "Top view", zero console errors.

## 2026-09-10 — Orientation box: edge and corner paddles

Added to the face paddles (unchanged): 12 rounded edge strips and 8
corner squares floating at the bounds' edge and corner diagonals. Faces
keep their standard-view snaps; edges and corners orient the camera
along their diagonal via a new arbitrary-direction camera helper (up
vector handled for near-vertical directions). Same hover highlight,
same stationary-left-click rule, same dismissal. 26 pickable plates
total; live check green (orbit survival + snap, zero console errors).

## 2026-09-10 — Orientation envelope: true filleted-box construction

Rebuilt per Jonathan: the orientation box is now a single continuous
filleted envelope — bounding box offset outward, flat faces inset by the
fillet radius, quarter-cylinder edge fillets, sphere-patch corners, all
tangent with seam outlines (canonical octant/quadrant geometry mirrored
by sign). Same interaction contract (hover tint, stationary-left-click
snap: faces → standard views, edges/corners → diagonal directions;
orbit-safe; Space/Esc/click-off closes). Live green.

## 2026-09-10 — Aether CAD: Environment panel + viewport themes

New Environment panel in the workspace shell (dedicated
CADEnvironmentPanel.tsx, Anima Studio demo anatomy on the shared
settings-card components): Environment card — theme picker, ground
segmented control (None/Grid/Floor/Both), background preset, live grid
opacity slider, disabled grid spacing/extent placeholders; Object card —
lighting preset, live brightness, contact-shadow and feature-edge
switches, disabled key/fill/rim sliders, reset. The appearance store
gained named environment themes: "Aether" (today's exact defaults) and
"Onshape" (new near-white background preset, no ground, daylight
lighting, no contact shadows — matches the reference render); manual
tweaks mark the theme "custom", and themes re-apply as bundles. Grid
opacity multiplies the per-preset baked opacity in the viewer. 453 CAD
tests (bundle/custom/reset reducer pins), typecheck, build; live-verified
theme switch to a clean white viewport with zero console errors.

## 2026-09-11 — Environment controls merged into the Appearance rail panel

Correction after review: the standalone Environment panel was removed —
its controls merged into the existing right-rail Appearance
(Visualization) panel where Jonathan expected them: Environment theme
picker (Aether / Onshape / Custom) at the top of DISPLAY, Onshape added
to the background Theme options, Grid opacity slider under Ground. The
duplicate CADEnvironmentPanel file and its dockable-panel entry were
deleted (one representation only). 453 CAD tests, build, live check
green (theme select present, Onshape switch verified).

## 2026-09-11 — Three-surface tool law codified and enforced

Per Jonathan, now CONVENTIONS.md law 4: every tool launches from exactly
one of the left sidebar, right sidebar, or top ribbon; floating editor
windows are ribbon tools; properties-style inspectors are right-sidebar
tools; the header carries only app chrome. Compliance audit: left rail =
Feature tree/Versions/History/Comments/Notes/Tasks; right rail =
Properties/Parameters/Assembly/Inspect/Appearance (environment lives
there); ribbon = all modeling tools and their floating feature windows.
The header's duplicate Export launcher was removed (Utilities → Export
Center is its home); Settings gear, theme toggle, window/layout menus,
and account remain as chrome. 453 CAD tests, build green.

## 2026-09-11 — Onshape theme: reference-plane presentation

Reference-plane visuals now follow the render environment (separate from
the UI theme): plane-visual accepts fill/border/label styling, the
viewer carries per-background plane styles, and switching backgrounds
rebuilds the principal planes in place (visibility preserved) and styles
custom plane features on creation. The Onshape environment renders
Onshape's look — pale translucent blue fills, light-blue borders, blue
label text on the near-white background — verified live during plane
selection with zero console errors. Label color is theme-driven today; a
user-adjustable plane/label color control in the Appearance panel is the
noted follow-up. 453 CAD tests, build green.

## 2026-09-11 — Origin as a point, axes split out; Anima right-rail tools imported

Origin/axes (per Jonathan): the origin renders as a point in space (small
sphere) instead of the three coloured lines; those lines are now separate
"Axes" reference geometry, hidden and listed disabled in the tree until
the camera/display tool owns them.

Right rail imports from the archived Anima Studio "view sidebar"
(inventory: View, Environment, Appearance, Performance, Inspector):
- **View** (new CADViewPanel.tsx) — the camera + display tool, deliberately
  separate from the render environment. CAMERA: projection (perspective;
  orthographic disabled), field of view (wired through the camera store to
  the live camera), frame-selection / isometric buttons, named views
  (disabled), orientation-box hint. DISPLAY: surface style, edges, grid,
  **Origin toggle** (new toggle-origin command reflecting reference
  visibility), plus disabled Axes / Section view / High quality rows.
- **Performance** (new CADPerformancePanel.tsx) — renderer/kernel/document
  status; frame-timing HUD disabled pending renderer counters.
- Environment and Appearance remain the existing Visualization panel;
  Inspector remains Properties. Consolidation is Jonathan's next pass.

Onshape is now the shipped default environment (white background, no
ground, daylight lighting, no contact shadows); the previous look is the
"Aether" bundle, selectable from the Appearance panel. Verified live:
default boot renders the Onshape environment, View panel opens with FOV
42°, Origin row present, disabled rows greyed, zero console errors.
Claude-lane suites green (registry/reference/projection/appearance/
camera/shell = 38 pins); the sketch DOM suites are transiently red from
Codex's in-flight sketch-workspace rewrite (its lane, untouched).

## 2026-09-11 — Performance panel made functional (live metrics + overlay)

Correction after review: the imported Performance panel was a stub. It
now publishes and displays measured values from a dedicated
`cad-viewport-metrics-store.ts`: the renderer samples every frame and
rolls FPS, mean frame time, and render-budget share into the store twice
a second, plus JS heap (Chromium), and republishes geometry counts
(bodies, faces, edge segments, triangles) with the last upload duration
whenever parts are added or removed. The panel shows LIVE STATUS and
GEOMETRY sections, and "Show detailed CAD metrics" pins Anima's
monospace metrics card over the viewport (persisted per browser). Figures
the browser cannot expose (process CPU, true GPU frame timing) read
"Unavailable" instead of fabricating numbers. Rail icon changed to a new
shared gauge icon. Live-verified: 60.0 fps / 16.66 ms / 2.5% budget /
10.9 MB heap, overlay renders, zero console errors. 456 CAD tests
(2 new store pins), typecheck, build green.

## 2026-09-11 — 3D transform gizmo: Core semantics + Aether UI demo

Imported the Anima Studio CAD transform gizmo (archive inventory:
CADTransformGizmoOverlay + CADToolGeometry.gizmoLineVertices). Meaning
lives in Core as a new renderer-neutral module
(`core/engine/src/transform/`, exported as `@aether/core/transform`):
handle kinds (axis / plane / ring), ray-based handle picking with
tolerances, drag begin/update returning a total delta from the anchor
(translation in millimetres, rotation in radians about the handle axis),
optional translation/rotation snapping, and Rodrigues delta application
about a pivot. No renderer types — Three.js/WebGPU adapters supply rays
and draw handles. 6 deterministic pins.

Aether UI gallery gained a live "3D transform gizmo" demo
(`gallery/TransformGizmoDemo.tsx`, Three.js via new gallery-only
devDependencies): all nine handles live at once like the native gizmo —
axis arrows (X #F24336, Y #4DD963, Z #408CFF), rotation rings at 0.82 ·
arm, plane tabs (XY yellow, YZ cyan, ZX purple) — screen-constant ~72 px
sizing, orange hover highlight (the unshipped Anima lab's intent), an
optional snap toggle (10 mm / 15°), and a live mm/degree readout (the
"intended-but-missing" feature in the native build). Verified live in the
gallery: handles render, dragging moves the body (−76 mm reported), zero
console errors. 719 Core / 163 UI tests, typechecks, builds green.

Deliberate deviations from the native build, all documented: ray/plane
math instead of screen-delta projection (equivalent result, robust under
perspective), plus snapping and the readout which the native gizmo never
shipped. Not yet built: CAD/Animation wiring (selection pivot at the AABB
centre, the locked/grounded grey state, and the debounced part-transform
commit path) — that is the next packet.

## 2026-09-11 — Transform gizmo restyled: Onshape/Anima hybrid

The gallery gizmo now blends Onshape's triad with the Anima anatomy:
thin outline artwork (axis lines, open triangular arrowheads, small tip
circles as the per-axis rotation handles, diamond plane handles, centre
pivot dot) carrying Anima's axis colours (X red, Y green, Z blue) and
plane colours. Picking rides invisible solids beneath the artwork — the
same visible-lines/hit-layer split the native gizmo used — and hover
tints the artwork by handle. Handles render over the model
(depthTest off, high render order) so they never disappear inside a
body, and stay screen-constant (~96 px arm). Snap and the mm/degree
readout remain. Verified live: drag reported −46.3 mm, zero console
errors.

## 2026-09-11 — Aether UI: workspace shell demo aligned with Aether CAD

The gallery's workspace-shell specimen now mirrors the CAD app instead of
the retired Animation arrangement: CAD app icon with document name/branch/
saved state, a Create/Modify ribbon of real tool icons (Sketch, Extrude,
Revolve, Fillet, Chamfer), a left Feature tree carrying CAD's actual
structure (Reference Geometry with Origin plus the disabled Axes row, Part
features with a suppressed fillet, Bodies), a Version control panel, right
Properties / Appearance / Performance panels, and the CAD status line.
The document bar's centre control is now the studio layout modes —
Docked / Floating / Hidden — driving the shell preset directly (the
duplicate layout-preset button was removed, per the one-launcher rule).
Verified live: tabs read Docked/Floating/Hidden, switching to Floating
re-lays the shell and the status line follows, zero console errors.
163 UI tests, typecheck, build green.

## 2026-09-11 — Feature windows: real validation, no opacity slider, distinct accept

Per Jonathan, the gallery's feature windows are now functional demos of
the pipeline the apps run, not static specimens. The Sketch and Extrude
demos build a real `PartDocument` and run Core's own
`validatePartDocument`: removing the sketch plane from the Entities box
puts the window in the error state with the engine's actual message
("Sketch plane or offset is invalid.") and disables accept. The other
windows (Revolve, Sweep, Loft, Thicken, Enclose, Plane, Mate) validate
their own reference requirements the same way, and every window starts
valid so the error state is something the reviewer produces. Shared
FeatureWindow changes: the universal window-opacity slider is removed
(it dimmed the whole editor — unwanted), and the accept control is now a
distinct green "✓ OK" button with a bordered ✕ discard, plus a new
`setError()` API that reddens the title/border and blocks accept.
163 UI / 458 CAD tests (plane-window pin updated for the removed
slider), typechecks, builds; live-verified in the gallery with zero
console errors.

## 2026-09-11 — Feature window: one control system, consistent widths

Per Jonathan: the entities box is the reference width, and every control
now follows it. Body-level controls (the method pickers — "Blind",
"Offset", mate kind) span the full body width so they line up exactly
with the entities box above them; in-row controls share fixed tracks
(text/number inputs 104 px right-aligned, selects 132 px) so every row
lines up down the window and shrinks gracefully on narrow panels. All
inputs and selects share one visual system — 26 px height, the shared
border/radius/background tokens, and the shared type ramp — replacing the
undersized, differently-styled dropdown. Applies everywhere the standard
window is used: verified in the gallery (Extrude: entities box 274 px,
method select 274 px, depth input 104 px) and in Aether CAD's plane
window. 163 UI / 458 CAD tests, builds green.

## 2026-09-11 — Feature windows: Onshape ordering restored, accept/discard final

Correction after review: the functional rewrite had reordered Extrude
(selection box ahead of the body-type/boolean tabs) and dropped rows.
The demo builder now lets each feature place its selection box where the
Onshape feature does, and the control sets are complete again: Extrude
runs Solid/Surface/Thin → New/Add/Remove/Intersect → selection → end
type → Depth → Direction / Starting offset / Symmetric / Draft / Second
end position; Revolve lists regions before the axis; Sweep regained
Scale; Loft regained Guides and continuity / Path / Connections / Show
isocurves; Thicken regained Keep tools. Accept is now a compact filled
green ✓ (the "OK" label removed) and discard is a plain unboxed red ✕.
163 UI / 458 CAD tests, builds, live check green.

## 2026-09-11 — Feature windows: nested sub-settings driven by the parent

Per Jonathan: settings that belong to another setting now nest, and the
end type decides which sub-settings exist. The shared FeatureWindow gained
`subsection(label, {kind})` — a checkbox or disclosure row whose children
indent beneath it behind a rule, the way Onshape nests dependent options.
The Extrude demo now behaves like the real feature: Blind/Symmetric show
Depth, the "Up to …" types swap Depth for an "Up to entity" selection box,
Through all shows neither; Draft reveals a nested Draft angle; Direction
(disclosure) reveals Flip direction and Direction reference; Starting
offset reveals Offset distance and Opposite direction; Second end position
reveals its own end type and depth, and disappears entirely for Symmetric
and Through all. Also fixed a real CSS bug found while verifying: the
window's `display` rules were overriding the UA `[hidden]` rule, so
"hidden" rows and closed sub-settings still rendered. Order stays
Onshape's: body type → boolean → selection → end type → parameters.
163 UI / 459 CAD tests, builds, live check green.

## 2026-09-11 — Feature windows: anchored dropdowns, expanded sub-settings

Native `<select>` popups overlay their own control on macOS (the current
value is centred under the pointer), which read as misaligned inside a
feature window. The shared FeatureWindow gained `picker()` — a dropdown
whose popup opens directly beneath its field, left-aligned and exactly
the field's width, with a check on the active option, outside-click and
Escape dismissal. Measured live: 0 px left offset, 0 px width difference,
4 px below the trigger. Every feature-window dropdown now uses it — the
gallery demos and Aether CAD's plane window (its DOM pins updated to
drive the picker). Also per review: disclosure sub-settings now start
expanded (checkbox groups still follow their box), and the disclosure
chevron is larger and full-contrast. 163 UI / 461 CAD tests, typechecks,
builds green.

## 2026-09-11 — Dropdown chevron enlarged

The picker chevron was still the small faint glyph; it is now full-size
and full-contrast, matching the enlarged disclosure arrow. Applies to
every feature-window dropdown in the gallery and Aether CAD.

## 2026-09-11 — Feature properties live in a card footer

Per Jonathan: a feature's id is a property (it names the title card), not
a setting, so it no longer sits among the controls. The shared
FeatureWindow gained `meta(label, value)` — a muted, monospaced footer
pinned to the bottom of the card, separated by a rule — and the Sketch
demo reports its Feature id and Feature type there. Any feature editor
can now surface revision, owner, or source metadata the same way without
mixing it into the settings list. 163 UI / 461 CAD tests, builds green.

## 2026-09-11 — Feature editors split into one file per feature

Per Jonathan's organisation standard (CONVENTIONS law 3), the nine
feature editors no longer live inside gallery/main.tsx. They now sit in
`core/ui/gallery/features/` — `sketch.ts`, `extrude.ts`, `revolve.ts`,
`sweep.ts`, `loft.ts`, `thicken.ts`, `enclose.ts`, `plane.ts`, `mate.ts`,
each owning that feature's layout, controls, dependent sub-settings and
validation — with `shared.ts` for the common plumbing, `index.ts` for
re-export, and a README stating the pattern. main.tsx dropped ~340 lines
and now imports them. Each editor is built from exactly two shared
pieces: `@aether/ui`'s openFeatureWindow (chrome) and `@aether/core`
(types + validators). 163 UI tests, typecheck, build, live check green.

Honest state: these are gallery reference implementations, not yet the
app's editors. `Aether CAD/src/plane-window.ts` is the first app-side
editor on the same window API; porting the rest into
`Aether CAD/src/features/` is the follow-up packet.

## 2026-09-11 — Backend blockers fixed: atomic mutations, real diagnostics, BOM integrity

The three defects the 2026-09-09 review verified by execution are fixed in
`animacore/aether_workspace.py`, each with a regression test that fails on
the old behaviour:

- **A1 — failed mutations committed.** `mutate()` swapped the draft into
  canonical state before validating the target, so a rejected call still
  advanced the revision and the client's retry hit a spurious
  `revision_conflict`. The draft is now validated and projected first;
  nothing commits unless both succeed.
- **A2 — diagnostics never surfaced.** `_current_issues` excluded exactly
  the diagnostics the solve had just produced (identical inputs hash to
  identical ids), so `projection.issues` was always empty while
  `solution.diagnostic_ids` referenced entries that existed nowhere.
  `solve()` now publishes the diagnostic objects it already builds and the
  projection merges them, deduplicated — limit violations and
  `solve_unconverged` both reach clients, and every published id resolves.
- **B1 — dangling BOM parents.** Rows referenced `instance:<id>` for
  parents that filtering had removed (suppressed or non-part). Parent
  links now resolve only against rows present in the same BOM.

Verified: 1200 animacore tests (3 new pins), ruff clean, 41 host tests.

Still open from that review: B2 (instance parent cycles accepted), B3
(unconverged mates project "satisfied"), B4 (no numeric ground-truth
kinematics tests), B5 (BOM material_name always null), and the C/D items
(single mutation discipline for `aether_project`, `/rpc` CORS exposure,
host slowloris + shared-IP lockout).

## 2026-09-11 — Feature property footer removed

Per Jonathan the id/type footer is gone from the feature cards; the
window now ends at its settings. The unused meta() API and its styles
were deleted with it rather than left as dead code. 163 UI tests,
typecheck, build green.

## 2026-09-11 — Correction: the app is the richer implementation

Measurement corrects an earlier plan of mine. Aether CAD's
feature-authoring.ts already presents the full Onshape feature anatomy
wired to real documents; the gallery feature files are design specs with
demo controls. Promoting gallery files into the app would have been a
downgrade. The correct direction is to split feature-authoring.ts into
one file per feature under Aether CAD/src/features/ keeping the real
wiring, move sketch/plane/mate editors alongside them, and have the
gallery import those real editors instead of its duplicates. Sweep, loft,
thicken and enclose have no engine support (no SolidFeature members, no
evaluator path) and stay designs until the engine can build them.
Ownership handed to Codex; feature-authoring.ts is unclaimed by Claude.

## 2026-09-11 — Gallery fixed after the engine move

The engine's move to Aether CAD/engine broke the gallery: npm's symlink
resolves, but the target sits outside the gallery project root so Vite
could not resolve @aether/core subpaths. core/ui/vite.config.ts now
aliases @aether/core (and its subpaths) straight to the engine source and
allows the dev server to read from it. Gallery typecheck, 163 tests,
build and live checks (feature-window validation, transform gizmo drag)
all pass again.

## 2026-09-11 — Feature tree: collapsible groups, divided Bodies, header, chevrons

Reference Geometry and Bodies now collapse (the projection was hardcoding
Reference Geometry expanded, and the toggle handler only routed folder/
ids). Bodies is separated from the feature history by its own divider, the
way Onshape pins Parts below the feature list. The Feature tree header
groups its icon and title instead of spreading them across the panel
(title 126px to 80px). The shared Tree disclosure chevron is larger and
full-contrast, matching the enlarged feature-window disclosure. 488 CAD
tests (2 pins updated, 1 added) and 163 UI tests green.

Open: the rollback bar cannot be dropped past the last feature (canMove
rejects non-feature targets; the handler resolves -1 for them) — handed to
Codex with the diagnosis since both files are in its active split. Also
queued: multi-select actions in the tree; the shared Tree already reports
single/toggle/range selection, the app wiring is what is missing.

## 2026-09-11 — Bodies section and rollback latch

Bodies are now their own pinned section below the feature history, like
Onshape's Parts pane: the projection publishes bodyNodes separately and
the shell renders them in their own bordered, scrollable tree with its own
expander. This also removed the accidental second rollback-looking bar
(the divider row) and restored the rollback bar's drop path — with the
bodies rows gone from the feature list, the last row is a feature again.
The drop handler was hardened besides: a drop resolving to no feature now
means end-of-list rather than index -1, and rollbackIndex is clamped.
490 CAD tests, typecheck and build green.

Open: multi-select and delete in the feature tree. The shared Tree already
reports single/toggle/range selection; the app still tracks a single
selectedFeatureID, so the work is app-side state plus delete/suppress
acting on a set.

## 2026-09-11 — Items panel: sections scroll independently

The items panel was display:block, so the flex:1 on the feature list never
applied — a long history simply pushed Bodies and the footer off the
bottom. The panel is now a flex column: the feature list scrolls inside
its own area, Bodies keeps its own box (max 38 percent, own scroll), and
the footer stays pinned. 490 CAD tests and build green.

Open in this area, both verified as still-broken:
- Panel height to the bottom edge is fixed as of 2026-09-12 (above).
- Multi-select and delete in the feature tree shipped 2026-09-11 (above).

## 2026-09-12 — FreeCAD inheritance: PlaneGCS spiked against the real corpus

Jonathan's direction: keep our design, inherit the engine. Plan and verified
findings are in `dev/docs/roadmap/FreeCAD_Inheritance.md`.

Measured cause of the slow feature-by-feature grind: the OCCT-backed kernel
binding is 893 lines, while our hand-rolled `sketch/` is 15,389 — 2,599 of
them a constraint solver. The hardest part of CAD is our smallest module
because we borrowed it.

- **PlaneGCS (FreeCAD's Sketcher solver, WASM, LGPL) is viable.** A spike maps
  our drawing model behind the existing `solveDrawingConstraints` seam, and a
  harness ran the existing corpus — 539 tests, 1,878 real solves — through
  both solvers. Of the 1,287 solves carrying constraints: 202 agreed to 1e-6,
  26 disagreed, 163 hit spike mapping bugs, 867 were geometry or constructs
  the spike deliberately does not map. **Fifteen of our twenty-seven
  constraint kinds produced identical geometry** (horizontal, vertical, fix,
  radius, diameter, length, distance, angle, coincident, concentric, parallel,
  perpendicular, equal, tangent, symmetric). Nothing failed because planegcs
  could not express it.
- The 26 disagreements are *different valid solutions* (10–16 mm drift on
  under-determined systems, with `fix` unimplemented in the spike), so a
  migration re-settles existing sketches and re-pins their tests. That is the
  real cost, and it is the only one found.
- **OCCT hidden-line removal is already in the WASM build we ship** —
  `HLRBRep_Algo` (23 refs) and `HLRAlgo_Projector` (14) in
  `replicad-opencascadejs`, plus `BRepMesh_IncrementalMesh`,
  `BRepOffsetAPI_MakeOffset`, `GeomAPI_Interpolate`, `ShapeUpgrade` and
  `STEPControl_Writer`. The queued Drawing packet currently assigns
  hidden-line classification to hand-written Core code; it should call HLR
  instead. `IGESControl_Reader` is **not** exposed.

The spike is instrumentation, not a migration: the default solver is
unchanged, the comparison runs only when a harness registers a `globalThis`
hook, and nothing is imported from production code — verified by 733 engine
tests, 519 CAD tests, engine typecheck and a CAD production build in which
`planegcs` appears in no built asset.

## 2026-09-12 — B3 closed, plus a hole in the mate-cycle guard

- **B3 — unconverged mates projected `satisfied`.** The solve already
  reported `status: "unconverged"` and named the mates it could not place
  in a `solve_unconverged` diagnostic, but `_mate_projection` derived
  `solve_state` from limit violations alone, so a mate whose instance
  never moved showed as green. Those mates now project `failed` and carry
  the diagnostic id, so the reason is reachable from the mate. No contract
  change: `solve_state: "satisfied" | "warning" | "failed" | "suppressed"`
  was already frozen and `Aether CAD/src/cad-assembly-bridge.ts` already
  validates and renders `failed` — the producer was simply never honest.
- **Found while testing it: the cycle guard could be fooled by a second
  child.** `_validate_mate_tree` walked parent to child through a
  `dict[parent] = child`, so a parent with two children kept only its last
  edge. Adding arm2→arm1, then arm2→arm3, then arm1→arm2 was accepted
  even though the first and last form a cycle — and the resulting graph is
  exactly what makes an unconverged solve reachable. The walk now goes
  child to parent, which is complete because one incoming mate per
  instance is already enforced, so a child's parent is unique.

1245 Python tests (2 added: the guard rejection leaves graph and revision
untouched; the projection reports `failed` for both mates of a cycle built
in state, while a solvable mate still reads `satisfied`) and ruff clean.

Still open from the 2026-09-09 review: B4 (numeric kinematics ground-truth
tests), D1 (pre-auth slowloris on the host lock), C1/C3 (decisions).

## 2026-09-12 — Docked panels reach the bottom edge

The Feature tree stopped ~430 px short in a 900 px window. Two causes, both
measured in a real browser rather than reasoned about:

- `.studio-shell .aui-shell-panel-body { max-height: 65vh }` in the CAD
  stylesheet clamped every panel body to 585 px — exactly the measured
  height. The earlier CAD-side `height: 100%` override could never win:
  `max-height` clamps a resolved height. The clamp is now scoped to
  floating panels (`.aui-float`), which is what it was for; torn-off
  panels keep their own `.aui-float-panel { max-height: 70% }` bound.
- `WorkspaceShell`'s preserved-content host was an unclassed
  `document.createElement("div")` between the panel slot and the app's own
  panel, so the `height: 100%` chain broke there. It is now
  `.aui-shell-panel-host`, and @aether/ui owns the docked chain:
  `.aui-shell-stack > .aui-shell-panel { flex: 1 1 auto }`, a growing
  panel body, and both portal links passing the definite height down. The
  redundant CAD overrides are deleted.

Measured at 1440x900, docked Feature tree: panel body 585 to 817 px, items
panel 339 to 817, feature list 188 to 666, footer bottom 395 to 873 — the
bottom of the shell area, where the status bar begins. Both rails report
817. Verification: core/ui 163 tests + typecheck + build, 514 CAD tests +
typecheck + build, animation web build, plus live measurement of the CAD
app and the @aether/ui gallery (gallery panels fill their embedded shell,
no horizontal overflow).

Layout cannot be tested in jsdom, so this was verified by driving
Playwright's cached headless shell over CDP with Node's built-in
WebSocket — no new dependency. Script: `dev/measure-layout.mjs`.

## 2026-09-11 — Feature tree: multi-select, suppress and delete on a set

Shift/Cmd-click now selects several features in the Feature tree, and
suppress and delete act on the whole selection in one undoable commit.
The shared Tree already reported single/toggle/range selection; the app
kept a single `selectedFeatureID`, so every reported id but the first was
dropped. main.ts now holds a set, the projection takes the set, and the
shell forwards every reported row plus the mode. Only feature rows carry a
set — a modified click on reference geometry, a body or an imported part
behaves like a plain click rather than growing a second selection model.

Delete also reaches the tree for the first time (it existed only as a
button inside a feature's edit dialog): context-menu **Delete** plus the
Delete/Backspace key over the tree, one confirmation naming the count and
any dependent features, and a row being renamed keeps its own Backspace.
A clicked row outside the current selection acts on itself alone, matching
Onshape. Suppress derives its target state from the clicked row, so a
mixed selection lands on one state instead of toggling each row.

511 CAD tests (5 added), typecheck and production build green. The
feature-authoring dom test had to mount once: each mount adds a window
listener for the file's lifetime, and the second listener re-handled the
same event against the document the first had just committed, toggling
suppression straight back.

## 2026-09-11 — Review items closed: B2, B5, D2

- **B2 — instance parent cycles.** move_instance only rejected a self-parent,
  so A to B to A was accepted, both instances dropped out of the root list,
  and the cycle survived save/reload. Parenting into your own subtree is now
  rejected by walking the ancestor chain. Regression test asserts the reject
  and that the tree and revision are untouched.
- **B5 — BOM material_name.** Rows always reported null though the part
  definition carries material_id; the row now reports it.
- **D2 — shared-address lockout.** Sign-in failures counted against the
  address, and a success cleared only the username counter, so on a local
  install (every browser is loopback) ten typos locked out every user.
  Loopback no longer counts as a shared bucket, and a success clears every
  counter it was throttled by. Regression test proves a second local user
  signs in while the throttled account stays locked.

1243 Python tests (animacore + host) and ruff clean for the product code;
the 11 remaining ruff findings are pre-existing style debt in examples/.

Still open: B4 (numeric kinematics ground-truth tests), D1 (pre-auth
slowloris on the host lock), C1/C3 (single mutation discipline, /rpc
CORS). B3 closed 2026-09-12.
