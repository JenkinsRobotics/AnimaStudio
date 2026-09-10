# CAD document controls

The hamburger beside the CAD app icon opens document controls. These operations use the signed-in host library. Save pending editor changes before changing document settings; a failed request keeps the dialog and current edits open. Historical and shared read-only documents can be copied but cannot be edited in place.

| Control | Behavior |
| --- | --- |
| Rename document | Renames the server file and the native document title, preserving its CAD extension. |
| Move to | Browse owned folders in the same private/shared location, navigate breadcrumbs, create a folder, and move the document. Moving does not alter its sharing scope. |
| Document details | Save a description up to 10,000 characters. **Not revision managed** disables creation of new named versions; saved snapshots, recovery and existing named versions remain intact. |
| Restore deleted workspaces | Restore deleted Part/Assembly tabs inside a project, keeping their identities. Delete these from Workspace properties. Referenced items must first be detached; at least one Assembly remains. This is project-item recovery, not Git branch recovery. |
| Copy workspace | Create a private copy of the selected saved snapshot in an owned folder. Current Parts, Assemblies and pinned dependencies stay packaged. The original server history stays with the source. Historical snapshots can also be copied. |
| Update workspace | Check for authored feature-format upgrades and newer linked-Part snapshots. Format upgrades use the existing Aether Core migration. Select link updates explicitly; inaccessible sources remain unavailable. Prior snapshots remain in saved history. |
| Workspace units | Length, linear acceleration, angle, angular velocity, mass, density, force, frequency, moment, pressure and energy; 0–8 display decimals per family. |
| Workspace properties | Select the workspace, a Part, a body, or an Assembly. Edit name, description and applicable category. **Apply** saves without closing; **Save** closes and reloads. Optional engineering quantities are entered in the selected units and stored in SI. Project-Part mass uses the canonical `mass_kg` field, not a separate mass model. |
| Print | Capture the current viewport and open a printable page with document title and a “not to scale” label. The system print dialog can print or save PDF. This is not a dimensioned manufacturing drawing. |

Save, Open Part, Import STEP, Export and Close remain available. The app icon returns to CAD Home. Copy-link preserves the selected project item and historical revision, and does not grant access.

## Persistence and units

Portable `document_settings` metadata lives in standalone Part JSON or the canonical project graph, so it travels with exports, copies and history snapshots. Server mutations check ownership and the expected saved revision. Part properties and body names remain in their canonical records. Deleted project definitions are retained inside the saved document for recovery.

Unit choices are presentation preferences. Geometry remains millimeters in authored Part features and meters/radians in Assembly contracts. Profile/revolve/extrude/finish controls, legacy rectangle inputs, Assembly placement/mass, manual connector origins and mate DOF fields convert at their boundaries. Sketch-canvas snapping remains physically 1 mm. Optional engineering properties use the same shared unit catalog; quantities without an active CAD solver are manually entered metadata, not calculated physical results.

The current workspace can be named (Main by default). These controls do not add branching/merging or engineering release-approval workflows.

## Verification

52 host/workspace tests and real HTTP roundtrips cover metadata persistence, permissions, conflicts, move, copy, history/restore, format upgrades and linked updates. Core unit tests roundtrip every supported unit and verify inch, pound and angle conversions. CAD DOM interaction tests cover units, folder navigation, recovery, dirty-session protection, Apply/Close and printable-page creation. The existing CAD suite and production build also pass. Connected browser/native print-dialog visual verification was unavailable in this session; DOM tests do not claim to verify physical print output.
