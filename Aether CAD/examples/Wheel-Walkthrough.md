# Make the train-cart wheel

This exercise uses assumed dimensions, not measurements from Jonathan’s screenshot. Units are millimeters. The supplied `.acpart` and `.acad` examples contain the finished, editable 14-feature wheel; the project also includes an Assembly instance of the Part.

## Start and save

Sign in to Aether CAD. In CAD Home, choose **Create → Part**, enter a name, and choose **Create Part**. This creates an empty server document. Alternatively, create a **Project document** and open its Part tab to keep Parts and Assemblies together.

The empty Part has no body yet. Use the **Part feature authoring** controls at the right of the viewport. Every **Apply and rebuild** evaluates real OCCT geometry. Use **Save Part** to commit the current document to the server. Keep the host running to open it from another signed-in device.

## Build the wheel

| Step | Tool / name | Inputs |
| --- | --- | --- |
| 1 | Sketch profile / Wheel section | Plane **XZ**, offset **0**, profile **polygon**. Points: `0,0; 40,0; 40,3; 34,3; 34,18; 30,18; 30,6; 0,6`. Choose **Fit sketch** to inspect it. |
| 2 | Revolve / Revolve wheel | Profile **Wheel section**, axis **Z**, angle **360**, operation **new**. |
| 3 | Fillet / Flange round | Size **0.6**, edges **plane**, edge plane **XY**, offset **3**. |
| 4 | Chamfer / Rim chamfer | Size **0.3**, edges **plane**, edge plane **XY**, offset **18**. |
| 5 | Fillet / Web round | Size **0.6**, edges **plane**, edge plane **XY**, offset **6**. |
| 6 | Sketch profile / Hub circle | Circle radius **12**, center **0,0**, plane **XY**, offset **6**. |
| 7 | Extrude / Extrude hub | Profile **Hub circle**, distance **3**, operation **add**, target the wheel body. |
| 8 | Sketch profile / Axle bore | Circle radius **5**, center **0,0**, plane **XY**, offset **−1**. |
| 9 | Extrude / Cut axle bore | Profile **Axle bore**, distance **22**, operation **cut**. |
| 10 | Sketch profile / Mounting hole | Circle radius **2.5**, center **16,8**, plane **XY**, offset **−1**. |
| 11 | Extrude / Cut mounting hole | Profile **Mounting hole**, distance **22**, operation **cut**. |
| 12 | Mirror / Mirror hole left | Feature **Cut mounting hole**, mirror plane **YZ**, offset **0**, operation **cut**. |
| 13 | Mirror / Mirror hole below | Feature **Cut mounting hole**, mirror plane **XZ**, offset **0**, operation **cut**. |
| 14 | Mirror / Mirror fourth hole | Feature **Mirror hole left**, mirror plane **XZ**, offset **0**, operation **cut**. |

The result has an 80 mm flange, 68 mm tread diameter, 18 mm width, recessed web, central hub and bore, and four mounting holes. It is one body. The polygon sketch can also be drawn by clicking points on the sketch canvas; drag vertices to adjust them. Circle drawing uses two clicks: center, then radius. Numeric fields provide exact dimensions.

## Edit the history

- Double-click a feature, press Enter on it, or use its **Edit** action. Changing the mounting-hole center to `18,9` rebuilds the three mirrored cuts too.
- Drag the rollback bar between features, use a feature’s **Roll back before** action, or use the right-side rollback slider. Later features remain in the document and appear dimmed.
- Add a feature while rolled back to insert it at that position. **Roll forward to end** replays the remaining history.
- Suppressing a sketch or body producer also suppresses features that depend on it. Unsuppressing a feature restores its prerequisites; other suppressed features remain suppressed.
- Move a feature using drag/drop or its edit dialog. Invalid dependency order is rejected. Deleting a feature asks before removing its dependents.
- The **Bodies** list comes from the current history. Rename or hide/show a body with its row actions. An extrusion/revolve with operation **new** creates another body; **add** and **cut** modify the chosen target body.

## Revision history

Save, return to CAD Home, select the file, and open its history. Saved revisions retain the feature document, rollback position and body properties. Named versions identify milestones. Opening an older revision is read-only; restoring it appends a new revision rather than deleting later history. Project Part changes belong to the project’s revision history. A standalone Part has its own history. Exported files contain the current snapshot; full server history belongs in the server backup.

## Current limits

This is a working wheel-authoring path, not full Onshape parity. The new profile editor supports circles and closed straight-sided polygons, with numeric dimensions and snapping; it does not yet provide a general constrained line/arc sketch solver. Fillet/chamfer selection is all edges or edges lying on a chosen datum plane, not arbitrary viewport-picked edge sets. Shell, feature patterns, branching/merging and release approval workflows are not implemented. The screenshot’s detailed internal boss/rib shapes require dimensions and additional profiles; this example uses a circular hub.
