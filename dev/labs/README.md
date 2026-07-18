# dev/labs — the CAD-pipeline benchmark

One app now: **Unified Bench** (harvests the best of the three demo apps).
Everything else here supports it or is archived.

```
dev/labs/
  UnifiedBench/            THE benchmark app (self-contained)
    Package.swift, Sources/
    pipelines/             the external pipelines the app drives
      qt/                  Qt6 + Open CASCADE viewer (separate window)
      opengeometry/        OpenGeometry WASM page (loaded in a WKWebView)
      unity/               STEP→OBJ converter + Unity project
    README.md              what was harvested from Codex/Claude/Gemini
  apps/                    built app bundle (gitignored) — UnifiedBench.app
  archive/                 superseded standalone experiments (dead code):
                             OldClaudeBench, StlViewer, rustbench, kernel_test
  build.sh                 builds Unified Bench + the Qt pipeline
```

## Run it

```bash
./build.sh                                   # first time / after changes
open apps/UnifiedBench.app                    # launch
```

8 pipelines, one workspace, one file — compare, then cull. See
`UnifiedBench/README.md` for the pipeline list and the harvest provenance.
