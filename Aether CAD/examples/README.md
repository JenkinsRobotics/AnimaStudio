# CAD test documents

- `Train-Cart-Wheel.acad`: self-contained CAD project, one authored wheel Part and an Assembly instance referencing that Part.
- `Train-Cart-Wheel.acpart`: the same editable wheel as a standalone Part.
- `Bracket.cadpart`: retained legacy Part compatibility example.

Import through CAD Home. The wheel uses assumed dimensions: flange diameter 80 mm, tread diameter 68 mm, total width 18 mm, flange thickness 3 mm, recess radius 30 mm, web thickness 6 mm, hub radius 12 mm and height 3 mm, bore diameter 10 mm, four mounting holes of diameter 5 mm at (±16, ±8) mm. It is a functional approximation of the supplied screenshot, not a dimensionally exact reproduction. The 14-feature history contains a revolved polygon section, selective flange/web fillets and a rim chamfer, circular profiles, additive and subtractive extrusions, and three mirrored cuts. Follow [Wheel-Walkthrough.md](Wheel-Walkthrough.md) to build it from an empty Part. Edit these features and rebuild with the Core OCCT engine.

Exports contain the current document snapshot and its packaged Part dependencies. Server revision history and named versions remain in the host database and its backup; importing an export starts a new server history.
