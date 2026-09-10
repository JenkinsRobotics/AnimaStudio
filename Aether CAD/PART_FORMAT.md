# `.cadpart` format v2 (shipped transitional Part projection)

`.cadpart` is UTF-8 JSON containing editable, deterministic Part feature
history. It is not STEP and it is not a cached render mesh.

The long-term native container is the planned unified `.aether` workspace,
where Part, Assembly, and Drawing are views over one Aether Core graph. This
plain JSON format remains the shipped Part-authoring slice and will migrate as
a Part-rooted subgraph; it must never become an independently editable copy of
the same open `.aether` Part.

```json
{
  "format": "aether-part",
  "formatVersion": 2,
  "documentId": "stable-document-id",
  "name": "Bracket",
  "units": "millimeter",
  "features": [
    {
      "id": "stable-sketch-id",
      "type": "sketch",
      "name": "Sketch 1",
      "plane": "XY",
      "profile": {
        "type": "center-rectangle",
        "widthMillimeters": 60,
        "heightMillimeters": 40,
        "centerXMillimeters": 0,
        "centerYMillimeters": 0,
        "construction": false
      },
      "constraints": [
        { "id": "stable-sketch-id:constraint:horizontal", "type": "horizontal", "target": "center-rectangle" },
        { "id": "stable-sketch-id:constraint:vertical", "type": "vertical", "target": "center-rectangle" },
        { "id": "stable-sketch-id:constraint:coincident-origin", "type": "coincident-origin", "target": "center-rectangle" }
      ],
      "dimensions": [
        { "id": "stable-sketch-id:dimension:width", "type": "width", "target": "center-rectangle", "valueMillimeters": 60 },
        { "id": "stable-sketch-id:dimension:height", "type": "height", "target": "center-rectangle", "valueMillimeters": 40 }
      ],
      "suppressed": false
    },
    {
      "id": "stable-extrude-id",
      "type": "extrude",
      "name": "Extrude 1",
      "profileFeatureId": "stable-sketch-id",
      "distanceMillimeters": 12,
      "operation": "new",
      "suppressed": false
    }
  ]
}
```

The `units` field records the source/display convention for this v2 slice.
Contract values are already explicit in their names (`widthMillimeters`,
`heightMillimeters`, `distanceMillimeters`); no bare number inherits semantic
units from `units`. The planned cross-language graph uses `_mm`, `_m`, `_rad`,
and similar suffixes.

## Version 2 limits

- one center-rectangle Sketch;
- one of the three principal planes (`XY`, `XZ`, or `YZ`);
- Horizontal, Vertical, and center-to-Origin Coincident constraints;
- explicit width and height dimensions;
- one positive-distance New Extrude;
- one resulting solid Body;
- millimeters only.

The sketch editor reports remaining degrees of freedom and uses blue geometry
for an under-defined rectangle and black geometry for a fully defined one.
Version 1 center rectangles migrate on open into the equivalent fully defined
version 2 constraint and dimension graph without changing document or feature
IDs. The schema uses stable IDs so later versions can add general sketch
entities, richer constraint graphs, feature references, booleans, fillets,
suppression, diagnostics, migrations, and stable topology naming.

## Rebuild rule

Opening a file validates the complete feature list, evaluates it in order in
the OCCT worker, extracts authoritative B-Rep topology, and then generates a
disposable display mesh. Invalid history fails before replacing the visible
Body.

Files created under the provisional `open-cad-part` identity remain readable;
opening one migrates its identity in memory, and the next save writes
`aether-part` without changing its stable document or feature IDs.
