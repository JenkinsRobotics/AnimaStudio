# PDM: commits, branches, and the path to simultaneous editing

Direction (Jonathan, 2026-09-10): Onshape/Git-grade product data management is
critical. Continuous saving replaces the manual save button; **commits** are
explicit, named, annotated checkpoints; designs can **branch**; simultaneous
editing arrives on top of this model, not instead of it.

## The model (host `core/host/history.py` + `library.py`)

Already Git-like at the storage layer: content-addressed SHA-256 blobs
(`library_blobs`), an immutable per-document revision log
(`library_history`), named checkpoints (`library_versions`), and optimistic
`expected_revision` guards on every mutation.

- **Autosave revision** — every continuous save records a revision (the
  Git "working history"). Cheap: blobs dedupe by hash.
- **Commit** — an annotated marker on a revision: name + message + author
  (`library_versions.message`). The CAD Save action becomes Commit.
- **Branch** — a named lineage in `library_branches` with a moving
  `head_revision`; revisions carry `branch` and `parent_revision`, forming a
  DAG. `Main` is implicit (head = the library row's revision). v1 supports
  create/list/read/edit for standalone documents; project-package branching
  follows once the `.aether` workspace contract lands.
- **Merge** — deferred: requires engine-level feature-list merge (the
  `.aether` per-mutation projections are the stepping stone). Until then,
  branch content can be restored/copied across lineages explicitly.

## Simultaneous editing path

1. (shipped) Optimistic revisions — no silent overwrites, 409 on stale saves.
2. (next) Advisory editing leases — presence: "Jonathan is editing".
3. Branch-per-editor sessions: concurrent editors autosave to private
   lineages and commit/merge explicitly — safe multi-user without live merge.
4. Live co-editing: engine-mediated operation streaming with feature-level
   merge (Onshape-grade; a roadmap program gated on the engine contract).

## Client behavior

- Continuous saving: the existing `markHostedDirty` hook debounces into a
  background save; failures surface loudly, success is quiet. The tray
  status shows save state.
- Commit: flushes pending autosave, then prompts for name + message and
  records the annotated version. Ribbon "Save Part" is relabeled Commit.
