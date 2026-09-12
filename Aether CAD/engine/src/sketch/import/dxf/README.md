# ASCII DXF sketch import

`tags.ts` reads paired group codes without tokenizing values. `entities.ts`
converts model-space XY primitives into native millimeter geometry. `index.ts`
handles sections, source units and atomic validation. CAD owns file reading,
preview and commit in `sketch/dxf-import-panel.ts`; `import-command.ts` wires the
ribbon command. No file-system/browser dependencies belong in Core.

Supported: LINE, POINT, CIRCLE, ARC, LWPOLYLINE and planar unfitted legacy
POLYLINE/VERTEX sequences, including signed bulges and closure. Embedded planar
BLOCK/INSERT references expand nested transforms, arrays and inherited layers.
Nonuniformly scaled circles become editable ellipses. ELLIPSE imports
full and trimmed rotated geometry from its true parameters. Header INSUNITS
supplies common engineering scales; explicit millimeters-per-unit overrides
missing/unsupported units. Paper-space entities and complete polyline sequences
are excluded. Unsupported model-space entities reject the whole import.

Not yet supported: binary DXF, DWG, block attributes/external references, fitted/3D POLYLINE, higher-degree/unequal-weight rational/fit-only SPLINE,
text/hatches, tilted/non-XY OCS transforms and elevation, wide polylines, layer style properties and editable layer management,
interior intersections.
CAD supports numeric position/rotation/uniform scale and canvas origin placement
through `sketch/dxf-placement.ts`, reusing Core similarity transforms.

References:
- https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-748FC305-F3F2-4F74-825A-61F04D757A50.htm
- https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-0B14D8F1-0EBA-44BF-9108-57D8CE614BC8.htm
- https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-Core/files/GUID-A58A87BB-482B-4042-A00A-EEF55A2B4FD8.htm

Ellipse and vertex definitions:
- https://help.autodesk.com/cloudhelp/2023/ENU/AutoCAD-DXF/files/GUID-107CB04F-AD4D-4D2F-8EC9-AC90888063AB.htm
- https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-0741E831-599E-4CBF-91E1-8ADBCFD6556D.htm

Endpoint joining defaults on after unit conversion (`joinConnected: false` disables).
`../join-contours.ts` preserves exact segment types and reverses their orientation
when needed. It stops at branches and keeps construction/hole groups separate.
Default tolerance is 1e-7 mm; `toleranceMillimeters` overrides it. Matched endpoints
may move up to that distance. Entity count reports the source entities, not joined
contours. Constrained topology cannot use this operation without reference remapping.

Closed, disjoint loops are classified by containment depth into solid/hole/island regions by default. Set `classifyHoles: false` to preserve raw region flags. Touching or intersecting loops reject automatic classification and require manual region selection.

SPLINE control nets of degree 1–3 convert into native polynomial Bézier spans
(or lines for degree 1), using `../../curves/bspline.ts`. DXF-specific validation
lives in `spline.ts`. Equal positive weights are supported; unequal rational
weights reject rather than losing shape. Closed/periodic flags require actual
endpoint closure. Converted spans retain geometry, but source B-spline knot/control
editing and associative continuity between spans remain future work.

Spline field reference:
- https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-E1F884F8-AA90-4864-A215-3182D47A9C74.htm

`records.ts` owns structural model-space iteration, including complete legacy polyline sequences. `layers.ts` inventories used layers via common group code 8; `includedLayers` filters before entity decoding. Excluded unsupported geometry does not block a selected supported layer; malformed file structure still rejects. Layer choices are import filters, not persisted CAD layers or styling. CAD `dxf-layer-control.ts` owns selection UI.

Layer-name reference: https://help.autodesk.com/cloudhelp/2023/ENU/AutoCAD-DXF/files/GUID-3610039E-27D1-4E23-B6D3-7E60B22BB5BD.htm

`coordinates.ts` distinguishes OCS entities from WCS positions. Planar negative-Z
CIRCLE/ARC/LWPOLYLINE/legacy POLYLINE use the arbitrary-axis -X,+Y mapping.
LINE/POINT/SPLINE coordinates remain WCS. ELLIPSE retains its WCS center/major
axis while its minor-axis direction and sweep follow the normal. Nonzero elevation,
thickness and tilted OCS still reject; there is no silent spatial flattening.

Coordinate references:
- https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-D99F1509-E4E4-47A3-8691-92EA07DC88F5.htm
- https://help.autodesk.com/cloudhelp/2015/ENU/AutoCAD-DXF/files/GUID-E19E5B42-0CC7-4EBA-B29F-5E1D595149EE.htm

`blocks.ts` expands embedded planar BLOCK/INSERT records structurally, preserving effective layer names and deferring legacy-polyline conversion until after filtering. It handles nested transforms, independent XY scaling, negative-Z OCS reflection and arrays; cycles/depth/record limits reject. `mapSketchDrawing` reuses exact projection conic math for affine geometry; unit conversion happens after block-local mapping. Attributes/xrefs/tilted geometry remain explicit errors. Output is editable geometry, not parametric block instances.

Reference: [Autodesk INSERT codes](https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-28FA4CFB-9D5E-4880-9F11-36C97578252F.htm) and [BLOCK base point](https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-66D32572-005A-4E23-8B8B-8726E8C14302.htm).

DXF imports attach `SketchContour.sourceLayer` to each decoded contour after block expansion. This optional native provenance survives placement/persistence, projection and circle-to-arc Split/Trim conversion; it does not change geometry semantics or visibility. Endpoint joining respects layer boundaries. The CAD selection status exposes the label as plain text. Layer colors/linetypes and editable layer membership are not implemented.

`filled-face.ts` decodes planar SOLID/TRACE strip corners into closed editable line boundaries (0,1,3,2 order). A repeated third/fourth corner yields a triangle. Simple concave boundaries are accepted; crossing or degenerate boundaries reject. Source fill appearance is not imported. The common coordinate layer validates all four corner Z values and applies planar OCS reflection; layer filtering, block transforms, placement, undo and persistence use the existing import pipeline.

References: [Autodesk SOLID](https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-E0C5F04E-D0C5-48F5-AC09-32733E8848F2.htm), [Autodesk TRACE](https://help.autodesk.com/cloudhelp/2018/ENU/AutoCAD-DXF/files/GUID-EA6FBCA8-1AD6-4FB2-B149-770313E93511.htm).
