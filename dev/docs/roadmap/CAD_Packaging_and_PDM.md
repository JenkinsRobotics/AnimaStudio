# CAD packaging and PDM

User direction, 2026-09-09: choose a bundled project or standalone documents without separate modeling implementations.

## Implemented foundation

- `.acad`: project container, Parts and Assemblies under stable IDs in the canonical Aether workspace graph.
- `.acpart`: standalone editable Part feature document. `.cadpart` remains readable.
- `.acasm`: standalone Assembly using the same workspace graph/archive code, including its Part snapshots. Legacy `.aether` remains readable.
- An authored Part is represented once under its canonical Part definition. Project tabs and the geometry kernel consume that document. Assembly instances reference the definition by stable ID.
- An external Part link pins a server file ID and saved revision; the selected Part snapshot is also packaged, making exports self-contained. Source updates require explicit adoption and preserve the linked definition ID. A linked snapshot is read-only; export a standalone copy to fork it.
- Saved revisions belong to the containing server document. Each save retains immutable bytes, author, timestamp and a content hash. Named versions point to those snapshots. Restore appends a new revision and preserves subsequent history. Optimistic revision checks prevent lost updates. Current document permissions govern access to all historical snapshots.
- Export includes the current graph/dependencies, not the server's full history. Database backup retains histories and versions.

## Important distinction

Packaging is not the engineering release boundary. Onshape document versions capture tabs together, while Parts, Assemblies and Drawings can be individually revisioned/released. Cross-document references can target versions. Sources verified 2026-09-09:

- https://cad.onshape.com/help/Content/Document/documents.htm
- https://cad.onshape.com/help/Content/Document/linking_documents.htm
- https://cad.onshape.com/help/Content/Document/document_management.htm

## Still planned

Item-level engineering release revisions, approval workflows, lifecycle states, branch/merge, multi-author live collaboration, project-to-project external Assembly references, automatic background saving, persistent topological naming through arbitrary feature edits, nested Assembly solving, general constrained sketch editing beyond the existing rectangle solver and dimensioned circle/polygon profiles. These are not implied by the saved-history implementation.
