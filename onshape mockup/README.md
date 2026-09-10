# Onshape-style CAD workspace mockup

React 19, TypeScript, Vite 8, Tailwind CSS 4, lucide-react, and Three.js with OrbitControls. A standalone frontend prototype; no OCCT or AnimaCore connection is required.

```sh
npm install
npm run dev       # http://localhost:5179
npm test
npm run build     # TypeScript + client and Worker bundles
```

## Initial component structure

```text
app/
  main.tsx                   React entry point
  globals.css                Compact CAD theme and responsive workspace layout
components/cad/
  CADWorkspace.tsx            Local editor state, history, commands, header and tabs
  CommandRibbon.tsx           Part, sketch and assembly tool catalogs
  FeatureTree.tsx             Independent feature-history and parts panels
  CADViewport.tsx             Three.js scene, selection, OrbitControls and ViewCube
  FeatureDialog.tsx           Floating feature parameter editor
  AuxiliaryPanel.tsx          Appearance, measure, configuration and properties
  types.ts                   Renderer-neutral UI projection types
components/layout/
  layout-store.ts             Global typed layout store and validated preferences
  layout-geometry.ts          Dock lanes, floating bounds and edge-drop projection
  AdaptiveLayout.tsx          Stable panel slots and persistent viewport host
  LayoutControls.tsx          Preset switch, panel placement and reset controls
components/ui/
  button.tsx, input.tsx       Shared accessible Base UI / shadcn primitives
lib/utils.ts                 Class composition helper
tests/                      Editor, layout and renderer-lifecycle tests
```

## Working interactions

- Sketch entry highlights Top, snaps the camera, and swaps the toolbar. Finish appends a uniquely numbered sketch; cancel adds nothing. Existing sketches reopen without duplication.
- Double-click a feature to edit. The Extrude dialog offers Blind/Symmetric/Up to face, depth validation, direction and draft controls. Depth changes the sample upright's extrusion; other parameters are UI drafts awaiting the kernel.
- Feature context menu supports edit, rename, suppress and delete. Undo/redo restores feature history. Rollback controls the mock part visibility.
- P toggles construction planes; F fits the model; Alt+C opens command search; Ctrl/Cmd+Z and Ctrl+Y redo history. Q and D select construction/dimension in sketch mode. Shortcuts ignore text fields.
- Orbit/pan/zoom, ViewCube faces/corners, named orthogonal views and projection selection operate the real camera. Display styles and section clipping affect the sample mesh.
- Select, hide, isolate and recolor parts. Appearance changes are local; configuration width scales the sample plate.
- Element tabs switch part/assembly command ribbons. Add, rename, duplicate and delete tabs. Export/import uses explicitly marked prototype JSON.

## Integration boundary and limits

This is a visual and interaction foundation, not a CAD kernel. The bracket and bore insert are procedurally triangulated Three.js fixtures, not imported B-Rep. Modeling tools beyond the depth preview expose parameter UI only; sketch entities and geometric constraints are not solved. Draft/end-condition/direction controls are local form state. Tabs currently share the fixture and feature history. Drawing, mates, exact measurement, mass properties, cloud saving and collaboration are placeholders clearly identified in the UI. Editor changes are session-local unless exported.

For OCCT integration, replace fixture creation in `CADViewport` with a mesh projection adapter and route accepted feature drafts to a geometry service. Keep authoritative feature identity, topology, validation, regeneration and assembly solving in the engine. The viewport consumes returned geometry and stable selection IDs; it must not become a second CAD model.

## Adaptive layout (Phase 2)

The header switches instantly between **Onshape** and **Shapr3D**. Onshape docks
commands at the top, features and parts on the left, and elements below the
viewport. Shapr3D gives the viewport the full working area with floating commands,
ViewCube and element tabs; Parts and Feature history start hidden and can be
restored through **Layout settings**.

The exported `PanelId`, `PanelState` and `LayoutTheme` interfaces match the Phase 2
contract. `layoutStore` is a global external store subscribed through React's
`useSyncExternalStore`; it owns each panel's mode, dock edge and floating position.
It provides `setPreset`, `setPanelMode`, `dockPanel`, `movePanel`, `restorePanel`,
`resetPreset`, and `resetAll`. Each preset remembers its own custom placement.
Versioned, validated preferences persist in device-local storage; unavailable or
malformed storage falls back to a usable default layout.

- Drag a panel by its labeled grip to reposition it. Drop within 24 px of a
  workspace edge to dock; a highlighted edge shows the drop destination.
- Use arrow keys on a focused grip to move by 10 px, or Shift+arrow for 40 px.
- The pin control toggles dock/float, and X hides a panel. Layout settings restores
  hidden panels and offers all four dock edges for every panel.
- Reset affects only the active preset. Feature edits, selections and camera state
  are separate from layout preferences.

Positions are CSS pixels relative to the workspace below the document header.
`computeLayout` derives dock lanes and the remaining viewport rectangle from the
store. Floating panels are clamped to the available area on resize; hidden and
floating panels reserve no dock space. Every panel keeps a stable React parent and
key. The main canvas stays in one viewport host, and the navigation cube uses a
portal into one permanent panel slot. Preset changes do not reconstruct either
Three.js renderer, the scene, or camera controls.

## Verification

13 tests cover the original editor flows plus per-preset state, preference
validation, dock bounds, keyboard/drag placement, panel visibility and persistent
DOM identity. A renderer-lifecycle test runs the actual viewport component with a
stubbed GPU boundary: the same scene and cube canvases survive layout transitions,
and both renderers dispose only on workspace teardown. Lint, TypeScript and the
production build also pass. No connected browser was available, so visual/GPU and
pointer ergonomics still need a browser walkthrough.
