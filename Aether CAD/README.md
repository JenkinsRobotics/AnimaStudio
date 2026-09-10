# Aether CAD

Aether CAD is Aether's web-native parametric solid modeler and 2D constraint
sketcher. It authors physical Parts, 3D mechanical assemblies, topological
surface features, and ultimately STEP/IGES exports. Its current working slice
grew from the OCCT Mate Lab proof; the editable `.cadpart` contract remains
named around the CAD domain rather than a renderer or kernel implementation.

## First working vertical slice

The app can now:

1. Start a Sketch and choose the Top, Front, or Right principal plane.
2. Rough in a center rectangle by dragging its corner, then apply Horizontal,
   Vertical, Origin Coincident, width, and height constraints/dimensions.
3. See blue under-defined geometry become black when the Sketch reaches zero
   remaining degrees of freedom.
4. Finish the Sketch and extrude it into an exact Open CASCADE solid Body.
5. Reopen Sketch 1, change its constraints or dimensions, and rebuild the Body.
6. Show `Sketch 1 → Extrude 1 → Body 1` in the Items tree, including definition
   state.
7. Save a versioned, editable `.cadpart` file and reopen it deterministically.
8. Import STEP reference Parts, infer exact B-Rep connector anchors, and create
   connector-first Fastened mates using the existing assembly proof.
9. Work through a CAD shell with a grouped modeling ribbon, Items/Sketch/Mates
   browser, real origin/principal-plane visibility, and an orbit-synchronized
   clickable ViewCube.

The saved Part contains feature history and parameters—not tessellated GPU
triangles. See [`PART_FORMAT.md`](PART_FORMAT.md).

## Run

```bash
npm install
npm run dev
```

Open the printed localhost address. All geometry processing is local.

### Clickable macOS app

Build the self-contained WebKit wrapper and place `Aether CAD.app` at the
repository root:

```bash
./Scripts/build-macos-app.sh
```

The wrapper bundles the production site and serves it from an internal local
port so the OCCT WebAssembly worker behaves exactly as it does in a browser.
It does not require an npm/Vite terminal after launch and has no address bar.

Verification:

```bash
npm run check
npm test
npm run build

# With Chrome exposing a DevTools endpoint on port 9222:
E2E_PART=1 APP_URL=http://127.0.0.1:5173/ npm run smoke:browser
E2E_PART=1 E2E_SHELL=1 APP_URL=http://127.0.0.1:5173/ npm run smoke:browser
E2E_MATE=1 APP_URL=http://127.0.0.1:5173/ \
  npm run smoke:browser -- first.step second.step
```

## Current geometry stack

- **Exact kernel:** Open CASCADE Technology compiled to WebAssembly through
  OpenCascade.js/Replicad.
- **CAD authoring API:** Replicad, backed by the same OCCT instance.
- **Renderer:** Three.js WebGPU, with Three.js WebGL 2 fallback.
- **Authority:** OCCT B-Rep and `.cadpart` feature history. Tessellation is a
  disposable display projection.

There is no Rust B-Rep kernel in the app today. Truck is a credible research
candidate, but adding it now would create two geometric authorities and make
topology naming, tolerance behavior, STEP parity, and save compatibility much
harder. Keep OCCT authoritative; benchmark a Rust kernel later behind the same
worker DTO only if a measured bottleneck justifies it.

## STEP assembly proof retained

Repeated STEP imports append to one assembly. Each imported STEP document is
one independently movable Part; bodies inside that document retain shared
source coordinates. Import separate STEP files for components that must move
independently.

**Place Connector** creates persistent Part-local anchors from analytic OCCT
planes, circles/ellipses, cylinders/bores, cones, spheres, tori, edge
midpoints, and vertices. **Fastened Mate** selects two saved connectors and
applies `W1new = W2 · T2 · RflipX · inverse(T1)`.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for module boundaries and the next
product stages.

## Native workspace direction

The shipped `.cadpart` file is intentionally a small, readable Part slice. The
planned native format is one `.aether` workspace containing Part, Assembly,
and Drawing views over the same Aether Core graph—not three independent files
that can drift. Exact B-Rep snapshots, render meshes, and thumbnails will be
disposable caches; the deterministic semantic graph remains authoritative.
See
[`Aether_Workspace_Format.md`](../dev/docs/roadmap/Aether_Workspace_Format.md).

## Future Aether Core

The exact engine remains embedded for now. Application code consumes it through
the `AetherCoreClient` facade in `src/aether-core.ts`; no separate engine or
duplicate evaluator has been created. The future extraction ownership and
acceptance rules are documented in
[`AETHER_CORE_EXTRACTION.md`](AETHER_CORE_EXTRACTION.md).
