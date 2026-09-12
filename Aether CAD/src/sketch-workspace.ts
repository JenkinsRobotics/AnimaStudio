import { mountSketchClipboard } from "./sketch/clipboard";
import { mountSketchVariables } from "./sketch/variables";
import { mountTextPanel } from "./sketch/text-panel";
import { bindDimensionLabelUnits } from "./sketch/dimension-label-units";
import { snapSemicircle, snapEllipticalArcGuide } from "@aether/core/sketch";
import { mountEllipticalRadiusControl } from "./sketch/elliptical-radius-control";
import { mountArcDirectionControl } from "./sketch/arc-direction-control";
import { pickSelectableSketchEntity, selectPickedReference } from "./sketch/projected-picking";
import { projectionAuthoring } from "./sketch/projection-authoring";
import { isDirectModificationTool } from "./sketch/tool-instructions";
import { mountSelectionConstraintStatus } from "./sketch/selection-constraint-status";
import { mountDimensionLabelDrag } from "./sketch/dimension-label-drag";
import { mountFitSplineTool } from "./sketch/fit-spline-tool";
import { mountDxfImportPanel } from "./sketch/dxf-import-panel";
import { inferDrawingPlacement } from "./sketch/drawing-inference";
import { bindSelectionDrag } from "./sketch/selection-drag";
import { createSketchHistory } from "./sketch/history";
import { mountRecentCurveSizing } from "./sketch/recent-curve-sizing";
import { bindEndpointDragGesture } from "./sketch/endpoint-drag-gesture";
import { arcChordStart, arcChordPoints } from "./sketch/arc-chord-tool";
import { placeTangentArc } from "./sketch/tangent-arc-tool";
import { renderSketchSelection } from "./sketch/selection-renderer";
import { openFeatureWindow } from "@aether/ui";
import { cadCommands, isCADCommandID } from "./cad-command-registry";
import type { SketchEntityRef } from "@aether/core/sketch";
import { bindTrimGesture } from "./sketch/trim-gesture";
import { directModification } from "./sketch/direct-modification";
import { renderContourList } from "./sketch/contour-list";
import { renderSketchCanvas } from "./sketch/canvas-renderer";
import { renderConstraintMarks, renderHoveredConstraints } from "./sketch/constraint-marks";
import { placeDrawingPoint } from "./sketch/drawing-tool";

import { mountConstraintPanel } from "./sketch/constraint-panel";
import { mountModificationPanel } from "./sketch/modification-panel";
import {
  modificationTools,
  type ModificationTool,
} from "./sketch/tool-instructions";
import { instructions } from "./sketch/tool-instructions";

import { renderSketchPreview } from "./sketch/preview";
import { constructionPlaneFrame } from "@aether/core/document";
import { rollbackPosition } from "@aether/core/document";
import { snapSketchPoint } from "./sketch-snapping";
import { solveDrawingConstraints } from "@aether/core/sketch";
import {
  sketchConstraintState,
  contourClosed,
  validateSketchDrawing,
  type SketchDrawing,
  type SketchPoint,
  type SketchFrame,
} from "@aether/core/sketch";
import { updatePartDocumentVariables, type PartDocument } from "@aether/core/document";
import type { ProfileFeature } from "@aether/core/document";
import { cadSelection } from "./cad-selection-store";
import "./sketch-workspace.css";
export function openSketchWorkspace(
  getDocument: () => PartDocument | null,
  apply: (doc: PartDocument) => Promise<void>,
  existing?: ProfileFeature,
) {
  if (document.querySelector(".cad-sketch-workspace")) return;
  const source = getDocument();
  if (!source) return;
  // A feature is created the moment the tool is clicked: it gets its id and
  // name immediately, appears in the tree, and is invalid (red) until it has
  // a plane — matching Onshape.
  const featureID = existing?.id ?? crypto.randomUUID();
  const featureName =
    existing?.name ??
    `Sketch ${source.features.filter((f) => f.type === "profile" || f.type === "sketch").length + 1}`;
  const announceDraft = (hasPlane: boolean) =>
    window.dispatchEvent(
      new CustomEvent("aether-sketch-editing", {
        detail: { id: featureID, name: featureName, hasPlane, existing: Boolean(existing) },
      }),
    );
  let variables = structuredClone(source.variables);
  const projected = projectionAuthoring(source, existing);
  const viewport = document.querySelector<HTMLElement>(".cad-studio-viewport");
  if (!viewport) return;
  const offscreenControls = document.createElement("div");
  offscreenControls.className = "cad-header-committed";
  const root = document.createElement("section");
  root.className = "cad-sketch-workspace choosing-plane";
  root.setAttribute("aria-label", "Sketch workspace");
  // The sketch window IS the shared gallery feature widget — the whole point
  // of the gallery is that products pull these, never re-build them.
  let commitSketch = () => {};
  let discardSketch = () => {};
  const win = openFeatureWindow({
    viewport,
    className: "cad-sketch-window",
    title: featureName,
    acceptLabel: "Finish sketch",
    discardLabel: "Cancel sketch",
    onAccept: () => commitSketch(),
    onDiscard: () => discardSketch(),
  });
  const sidebar = win.body;
  // Keep the window inside the workspace section so sketch chrome lives and
  // dies together (and stays queryable as one unit).
  root.append(win.panel);
  // The sketch window shows NO running narration. Tool state, profile counts
  // and constraint hints belong in a status bar, not in a feature dialog —
  // Onshape's Sketch panel carries none of it, and neither does the gallery's.
  // This element keeps the existing reporting wired (tests read it, and it is
  // an aria-live region for assistive tech) while staying out of the window.
  // Anything the user MUST act on goes through fail() -> win.setError instead.
  const message = document.createElement("p");
  message.setAttribute("role", "status");
  message.className = "cad-header-committed";
  // First in document order: the window's own (empty) status element would
  // otherwise be what `[role="status"]` finds.
  root.prepend(message);
  /** A real failure: shown in the window's error block and disables commit. */
  const fail = (text: string) => {
    message.textContent = text;
    win.setError(text || null);
  };
  const constraintStatus = document.createElement("p");
  constraintStatus.className = "sketch-constraint-state";
  constraintStatus.setAttribute("aria-label", "Sketch constraint state");
  let updateSelectionConstraintStatus: ReturnType<typeof mountSelectionConstraintStatus>;
  const planeChoices = document.createElement("div");
  sidebar.append(planeChoices);
  let plane: "XY" | "XZ" | "YZ" = existing?.plane ?? "XY",
    frame: SketchFrame | undefined = existing?.frame;
  let started = false,
    // Placing the plane must not arm a drawing tool — the first viewport click
    // belongs to selection until a tool is picked from the ribbon.
    tool = "select",
    pending: SketchPoint[] = [],
    activePath = -1,
    busy = false;
  let cursor: SketchPoint | null = null;
  let selectedEntity: SketchEntityRef | null = null,
    activeTool = "";
  let construction = false;
  /** Onshape draws the applied relationships on the geometry; the Show
   *  constraints row turns them off. Dimensions are separate annotations. */
  let showConstraints = true;
  /** The entity under the pointer, for the hover constraint readout. */
  let hoveredEntity: SketchEntityRef | null = null;
  let snapLabel = "",
    gridSnap = true,
    geometrySnap = true,
    pickEntityB = false;
  const previousFilter = cadSelection.snapshot().filter;
  let drawing: SketchDrawing =
    existing?.profile.type === "drawing"
      ? structuredClone(existing.profile)
      : projected?.drawing ?? { type: "drawing", contours: [] };
  if (existing?.profile.type === "circle")
    drawing.contours.push({
      type: "circle",
      center: existing.profile.centerMillimeters,
      radius: existing.profile.radiusMillimeters,
    });
  if (existing?.profile.type === "polygon") {
    const p = existing.profile.pointsMillimeters;
    drawing.contours.push({
      type: "path",
      start: p[0],
      segments: [...p.slice(1), p[0]].map((end) => ({ type: "line", end })),
    });
  }
  let dimensionPositions: Record<string,SketchPoint> = structuredClone(existing ? source.sketchPresentation?.[existing.id]?.dimensionLabelPositionsMillimeters ?? {} : {});
  const history = createSketchHistory();
  const checkpoint = () => { recentSizing.clear(); history.checkpoint({ drawing, activePath, dimensionPositions, variables }); };
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("aria-label", "2D sketch canvas");
  svg.setAttribute("tabindex", "0");
  svg.classList.add("cad-sketch-canvas");
  // The renderer draws the Onshape-style plane card and needs the sketch name;
  // carried on the element so it survives being reparented into the CSS3D layer.
  svg.dataset.sketchName = featureName;
  root.prepend(svg);
  // The view opens framed on the whole sketch-plane square with a margin, so the
  // plane reads as a drawn object you can see the edges of.
  let bounds = { x: -100, y: -100, width: 200, height: 200 };
  // In-world mode: the 3D viewer hosts the svg on the sketch plane and owns
  // navigation; this bridge supplies plane raycasts and scale. Null = legacy
  // flat overlay (tests, gallery, no viewer present).
  type SurfaceBridge = {
    toSketch(clientX: number, clientY: number): SketchPoint | null;
    scaleAt(clientX?: number, clientY?: number): number | null;
    updateBounds(next: typeof bounds): void;
  };
  let surface: SurfaceBridge | null = null;
  // Grow (never shrink) the viewBox to hold the drawing; keeps the in-world
  // plane card under the whole sketch. ponytail: arc bulges/ellipse extremes
  // beyond their control points can still clip visually; widen per-type if it
  // shows up in practice.
  const fitBoundsToContent = (): boolean => {
    const pts: SketchPoint[] = [...pending];
    for (const c of drawing.contours) {
      if (c.type === "circle")
        pts.push(
          [c.center[0] - c.radius, c.center[1] - c.radius],
          [c.center[0] + c.radius, c.center[1] + c.radius],
        );
      else if (c.type === "path") {
        pts.push(c.start);
        for (const s of c.segments) {
          pts.push(s.end);
          const extra = s as { controls?: SketchPoint[]; through?: SketchPoint; center?: SketchPoint };
          if (extra.controls) pts.push(...extra.controls);
          if (extra.through) pts.push(extra.through);
          if (extra.center) pts.push(extra.center);
        }
      }
    }
    if (!pts.length) return false;
    const pad = 25;
    const xs = pts.map((p) => p[0]);
    const vys = pts.map((p) => -p[1]);
    const minX = Math.min(bounds.x, Math.min(...xs) - pad);
    const maxX = Math.max(bounds.x + bounds.width, Math.max(...xs) + pad);
    const minY = Math.min(bounds.y, Math.min(...vys) - pad);
    const maxY = Math.max(bounds.y + bounds.height, Math.max(...vys) + pad);
    if (minX === bounds.x && minY === bounds.y && maxX === bounds.x + bounds.width && maxY === bounds.y + bounds.height)
      return false;
    bounds = { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
    return true;
  };
  const controls = document.createElement("div");
  controls.className = "sketch-edit-controls";
  sidebar.append(controls);
  const button = (
    text: string,
    run: () => void,
    parent: HTMLElement = controls,
  ) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.onclick = run;
    parent.append(b);
    return b;
  };
  // "Is the sketch asking for a plane?" — one switch, because the class and the
  // event must always move together. They lived at six separate sites, and the
  // one that cleared the plane moved the class without the event, so the viewer
  // stayed out of picking mode and only the first pick ever committed.
  const setChoosingPlane = (choosing: boolean) => {
    root.classList.toggle("choosing-plane", choosing);
    window.dispatchEvent(
      new CustomEvent("aether-sketch-plane-selection", { detail: choosing }),
    );
  };
  let renderSketchPlaneChip: ((label: string) => void) | undefined;
  const start = (p: typeof plane, f?: SketchFrame) => {
    setChoosingPlane(false);
    plane = p;
    frame = f;
    started = true;
    planeChoices.hidden = true;
    controls.hidden = false;
    renderSketchPlaneChip?.(f ? "Selected plane" : `${p} plane`);
    pending = [];
    window.dispatchEvent(
      new CustomEvent("aether-sketch-mode", { detail: true }),
    );
    announceDraft(true);
    setActiveTool("select");
    win.panel.removeAttribute("data-feature-state");
    fitBoundsToContent();
    window.dispatchEvent(
      new CustomEvent("aether-sketch-surface", {
        detail: {
          svg,
          frame:
            f ??
            constructionPlaneFrame({
              id: "",
              name: "",
              type: "plane",
              plane: p,
              offsetMillimeters: 0,
              suppressed: false,
            }),
          bounds,
          connect: (bridge: SurfaceBridge) => {
            surface = bridge;
            root.classList.add("in-world");
            window.addEventListener("keydown", globalKey);
          },
        },
      }),
    );
    render();
  };
  for (const [label, p] of [
    ["Top (XY)", "XY"],
    ["Front (XZ)", "XZ"],
    ["Right (YZ)", "YZ"],
  ] as const)
    button(label, () => start(p), planeChoices);
  const priorFeatures = source.features.slice(0, rollbackPosition(source));
  priorFeatures.forEach((feature, featureIndex) => {
    if (feature.type === "plane" && !feature.suppressed)
      button(
        feature.name,
        () => start(feature.plane, constructionPlaneFrame(feature, priorFeatures.slice(0, featureIndex))),
        planeChoices,
      );
  });
  button(
    "Use selected planar face",
    () => window.dispatchEvent(new CustomEvent("aether-sketch-face-request")),
    planeChoices,
  );
  const face = (event: Event) => {
    if (started) return;
    const detail = (event as CustomEvent).detail;
    if (detail?.frame) start("XY", detail.frame);
    else
      message.textContent =
        detail?.error ?? "Select a flat face in the model first.";
  };
  window.addEventListener("aether-sketch-face", face);
  const reference = (event: Event) => {
    if (!started) start((event as CustomEvent).detail);
  };
  window.addEventListener("aether-sketch-plane", reference);
  const setActiveTool = (name: string) => {
    const previous = `sketch-${activeTool}`,
      next = `sketch-${name}`;
    if (isCADCommandID(previous)) cadCommands.setActive(previous, false);
    activeTool = name;
    if (isCADCommandID(next)) cadCommands.setActive(next, true);
  };
  const chooseTool = (name: string) => {
    recentSizing.clear();
    endpointGesture.cancel();
    selectionDrag.cancel();
    selectedEntity = null;
    setActiveTool(name);
    modifications.close();
    pickEntityB = false;
    tool = name;
    pending = [];
    cursor = null;
    if (name !== "line" && name !== "arc") activePath = -1;
    render();
  };
  const toolEvent = (event: Event) => {
    if (started) {
      const name = (event as CustomEvent).detail;
      if (name === activeTool && name !== "select") {
        chooseTool("select");
        return;
      }
      if (modificationTools.includes(name)) {
        chooseTool("select");
        modifications.open(name as ModificationTool);
        setActiveTool(name);
      } else chooseTool(name);
    }
  };
  window.addEventListener("aether-sketch-tool", toolEvent);
  button("New contour", () => {
    recentSizing.clear();
    endpointGesture.cancel();
    activePath = -1;
    pending = [];
    render();
  });
  button("Close contour", () => {
    const c = drawing.contours[activePath];
    if (c?.type === "path" && c.segments.length && !contourClosed(c)) {
      checkpoint();
      c.segments.push({ type: "line", end: [...c.start] });
      activePath = -1;
      pending = [];
      render();
    }
  });
  button("Undo", () => {
    recentSizing.clear();
    endpointGesture.cancel();
    const previous = history.undo({ drawing, activePath, dimensionPositions, variables });
    if (previous) {
      drawing = previous.drawing;
      variables = previous.variables;
      dimensionPositions = previous.dimensionPositions ?? {};
      activePath = previous.activePath;
      pending = [];
      render();
    }
  });
  button("Redo", () => {
    recentSizing.clear();
    endpointGesture.cancel();
    const next = history.redo({ drawing, activePath, dimensionPositions, variables });
    if (next) {
      drawing = next.drawing;
      variables = next.variables;
      dimensionPositions = next.dimensionPositions ?? {};
      activePath = next.activePath;
      pending = [];
      render();
    }
  });
  const modifications = mountModificationPanel({
    finished: () => setActiveTool("select"),
    parent: controls,
    svg,
    drawing: () => drawing,
    commit: (next) => {
      checkpoint();
      drawing = next;
      pending = [];
      cursor = null;
      activePath = -1;
      render();
    },
    report: (text) => {
      message.textContent = text;
    },
  });
  const recentSizing = mountRecentCurveSizing({
    parent: controls,
    drawing: () => drawing,
    commit: next => { checkpoint(); drawing = next; render(); },
    report: text => { message.textContent = text; },
    focusCanvas: () => svg.focus(),
  });
  const coordinate = document.createElement("div");
  controls.append(coordinate);
  const numeric = (label: string, value: string) => {
    const l = document.createElement("label");
    l.textContent = label;
    const input = document.createElement("input");
    input.type = "number";
    input.step = "any";
    input.value = value;
    input.setAttribute("aria-label", label);
    l.append(input);
    coordinate.append(l);
    return input;
  };
  const x = numeric("X (mm)", "0"),
    y = numeric("Y (mm)", "0");
  const ellipseRadius = mountEllipticalRadiusControl(coordinate, () => renderPreview());
  const arcDirection = mountArcDirectionControl(coordinate, () => renderPreview());
  const sides = numeric("Polygon sides", "6");
  sides.min = "3";
  sides.max = "100";
  sides.step = "1";
  sides.addEventListener("input", () => renderPreview());
  button("Place point", () => {
    const p: SketchPoint = [Number(x.value), Number(y.value)];
    if (p.every(Number.isFinite)) place(p);
  });
  for (const [label, update] of [
    ["Construction geometry", (v: boolean) => (construction = v)],
    ["Snap to geometry", (v: boolean) => (geometrySnap = v)],
    ["Snap to grid", (v: boolean) => (gridSnap = v)],
  ] as const) {
    const l = document.createElement("label");
    const check = document.createElement("input");
    check.type = "checkbox";
    check.checked = label !== "Construction geometry";
    check.onchange = () => update(check.checked);
    l.append(check, document.createTextNode(label));
    controls.append(l);
  }
  const fitSpline = mountFitSplineTool(controls,root,{
    state:()=>({tool,pending,drawing,construction,busy}),
    commit:next=>{checkpoint();drawing=next;pending=[];cursor=null;activePath=-1;render();},
    error:text=>{fail(text);},
  });
  const variablePanel = mountSketchVariables(controls,()=>({drawing,variables}),(next,definitions)=>{
    checkpoint();drawing=next;variables=definitions;pending=[];cursor=null;activePath=-1;render();
  });
  const clipboard = mountSketchClipboard(controls,svg,()=>({drawing,variables}),()=>selectedEntity?.contour,()=>started&&!busy,(next,definitions)=>{
    checkpoint();drawing=next;variables=definitions;pending=[];cursor=null;activePath=-1;render();
  },()=>chooseTool("select"));
  const textPanel = mountTextPanel(controls,svg,()=>drawing,next=>{
    checkpoint();drawing=next;pending=[];cursor=null;activePath=-1;render();
  },()=>variables);
  const dxfImport = mountDxfImportPanel(controls,svg,()=>drawing,next=>{
    checkpoint();drawing=next;pending=[];cursor=null;activePath=-1;render();
  });
  const constraints = mountConstraintPanel({
    getVariables: () => variables,
    parent: controls,
    svg,
    getDrawing: () => drawing,
    commit: (next) => {
      checkpoint();
      drawing = next;
      pending = [];
      cursor = null;
      render();
    },
    coordinates: () => [Number(x.value), Number(y.value)],
    chooseTool,
    message,
  });
  const { entityA, entityB, kind, hints } = constraints;
  const list = document.createElement("div");
  list.className = "sketch-contours";
  controls.append(list);
  const actions = document.createElement("div");
  sidebar.append(actions);
  const disposeDimensionUnits = bindDimensionLabelUnits(svg);
  const cleanup = () => {
    disposeDimensionUnits();
    recentSizing.dispose();
    modifications.close();
    constraints.dispose();
    dimensionLabelDrag.dispose();
    dxfImport.dispose();
    textPanel.dispose();
    variablePanel.dispose();
    clipboard.dispose();
    fitSpline.dispose();
    setChoosingPlane(false);
    if (surface) {
      surface = null;
      window.dispatchEvent(new CustomEvent("aether-sketch-surface-end"));
    }
    window.removeEventListener("keydown", globalKey);
    window.removeEventListener("aether-sketch-finish", finishEvent);
    win.close();
    root.remove();
    window.removeEventListener("aether-sketch-tool", toolEvent);
    window.removeEventListener("aether-sketch-plane", reference);
    window.removeEventListener("aether-sketch-face", face);
    cadSelection.dispatch({ type: "set-filter", filter: previousFilter });
    window.dispatchEvent(
      new CustomEvent("aether-sketch-mode", { detail: false }),
    );
    window.dispatchEvent(new CustomEvent("aether-sketch-editing", { detail: null }));
  };
  const finish = button(
    "Finish sketch",
    async () => {
      if (!started || busy) return;
      try {
        if (clipboard.pending()) throw Error("Apply or cancel the paste preview before finishing the sketch.");
        if (variablePanel.pending()) throw Error("Apply pending variable edits before finishing the sketch.");
        if(tool === "fit-spline" && pending.length) throw Error("Finish spline or cancel the unfinished curve before finishing the sketch.");
        drawing = solveDrawingConstraints(drawing);
        validateSketchDrawing(drawing);
        // An empty sketch is valid — the plane choice alone defines it, and
        // Core keeps sketches without contours (they just can't drive solids).
        if (getDocument() !== source)
          throw new Error(
            "The document changed while sketching. Cancel and reopen to avoid overwriting it.",
          );
        busy = true;
        finish.disabled = true;
        const feature: ProfileFeature = {
          id: featureID,
          type: "profile",
          name: featureName,
          suppressed: existing?.suppressed ?? false,
          plane,
          offsetMillimeters: existing?.offsetMillimeters ?? 0,
          profile: projected?.save(drawing) ?? structuredClone(drawing),
          ...(frame ? { frame } : {}),
        };
        const draftSnapshot = JSON.stringify({drawing,variables,dimensionPositions});
        const next = await updatePartDocumentVariables(source, variables, feature);
        if (draftSnapshot !== JSON.stringify({drawing,variables,dimensionPositions}) || variablePanel.pending() || clipboard.pending()) throw Error("The sketch changed while preparing it. Review and finish again.");
        if (getDocument() !== source) throw Error("The document changed while preparing the sketch. Cancel and reopen.");
        next.sketchPresentation = {...source.sketchPresentation, [feature.id]: {dimensionLabelPositionsMillimeters: Object.fromEntries(Object.entries(dimensionPositions).filter(([id])=>drawing.constraints?.some(c=>c.id===id)))}};
        await apply(next);
        cleanup();
      } catch (error) {
        fail((error as Error).message);
      } finally {
        busy = false;
        finish.disabled = false;
      }
    },
    actions,
  );
  const cancelButton = button(
    "Cancel",
    () => {
      if (!busy) cleanup();
    },
    actions,
  );
  // --- Gallery Sketch anatomy: plane entities box + display rows only ----
  commitSketch = () => finish.click();
  discardSketch = () => cancelButton.click();
  finish.classList.add("cad-header-committed");
  cancelButton.classList.add("cad-header-committed");
  // Tool parameters and edit drawers live in the sketch toolbar strip —
  // the feature window describes the sketch (its plane), nothing else.
  // No sketch options window (Jonathan, 2026-09-11): drawing tools and their
  // commands live in the ribbon; the feature window describes the plane.
  // These controls stay attached but never render — they remain the wiring
  // behind ribbon commands and keyboard/canvas interaction.
  offscreenControls.append(controls, actions);
  root.append(offscreenControls);
  // Planes are picked by clicking them in the viewport or the Model tree;
  // the legacy buttons stay in the DOM for the test harness only.
  planeChoices.classList.add("cad-header-committed");
  const planeBox = win.entitiesBox("Sketch plane");
  const renderPlaneChip = (label: string) => {
    planeBox.render([
      {
        label,
        onRemove: () => {
          if (drawing.contours.length || drawing.textItems?.length) {
            message.textContent =
              "This sketch has geometry — cancel and start a new sketch to draw on another plane.";
            return;
          }
          started = false;
          win.panel.setAttribute("data-feature-state", "invalid");
          announceDraft(false);
          planeBox.render([]);
          setChoosingPlane(true);
          message.textContent = "";
          if (surface) {
            surface = null;
            window.dispatchEvent(new CustomEvent("aether-sketch-surface-end"));
          }
        },
      },
    ]);
  };
  {
    const displayRow = (label: string, wire?: (input: HTMLInputElement) => void) => {
      const input = document.createElement("input");
      input.type = "checkbox";
      input.setAttribute("aria-label", label);
      if (wire) wire(input);
      else {
        input.disabled = true;
        input.title = "Planned — not functional yet.";
      }
      win.row(label, input);
    };
    displayRow("Disable imprinting");
    displayRow("Show constraints", (input) => {
      // On by default, as in Onshape: you should see the relationships holding
      // the sketch together without asking for them.
      input.checked = showConstraints;
      input.onchange = () => {
        showConstraints = input.checked;
        render();
      };
    });
    displayRow("Show expressions");
    displayRow("Show errors", (input) => {
      input.checked = true;
      input.onchange = () => {
        constraintStatus.hidden = !input.checked;
      };
    });
  }
  // Window body = the gallery Sketch card exactly: plane entities box, the
  // four display rows, and the widget's own status slot. CAD's additional
  // live regions (constraint state, selection constraints) stay attached
  // off-view so behavior and tests are unchanged.
  offscreenControls.append(constraintStatus);
  updateSelectionConstraintStatus = mountSelectionConstraintStatus(offscreenControls);
  renderSketchPlaneChip = renderPlaneChip;
  if (!existing) {
    win.panel.setAttribute("data-feature-state", "invalid");
    announceDraft(false);
  }
  
  // Preview is presentation-only: no feature/undo mutation until a point is placed.
  const effectivePoint = (p: SketchPoint): SketchPoint => {
    const c = drawing.contours[activePath];
    if (
      (tool === "line" || (tool === "arc" && pending.length < 2)) &&
      c?.type === "path" &&
      !contourClosed(c) &&
      Math.hypot(c.start[0] - p[0], c.start[1] - p[1]) < bounds.width / 100
    )
      return [...c.start];
    return p;
  };
  function renderPreview() {
    ellipseRadius.observe(tool, pending, cursor ? effectivePoint(cursor) : null);
    renderSketchPreview(svg, {
      started,
      busy,
      cursor,
      tool,
      drawing,
      activePath,
      pending,
      bounds,
      snapLabel,
      sides: Number(sides.value),
      clockwise: arcDirection.clockwise(),
      secondaryRadiusMillimeters: ellipseRadius.value(),
      rememberedRadiusMillimeters: ellipseRadius.remembered(),
      effectivePoint,
    });
  }
  function renderSelection() {
    renderSketchSelection(svg, drawing, selectedEntity, bounds.width / 150);
    updateSelectionConstraintStatus(drawing, selectedEntity);
  }
  function render() {
    if (surface && fitBoundsToContent()) surface.updateBounds(bounds);
    variablePanel.sync();
    textPanel.sync();
    controls.hidden = !started;
    finish.disabled = !started;
    svg.style.visibility = started ? "visible" : "hidden";
    if (!started) {
      // No prompt text: the empty "Sketch plane" box is the instruction, exactly
      // as in the gallery's Sketch window.
      message.textContent = "";
      return;
    }
    sides.parentElement!.hidden = !tool.endsWith("polygon");
    arcDirection.update(tool);
    ellipseRadius.update(tool);
    const state = sketchConstraintState(drawing);
    constraintStatus.dataset.state = state.state;
    svg.dataset.constraintState = state.state;
    const labels = {
      empty: "Empty sketch",
      "under-constrained": "Under-constrained",
      "fully-constrained": "Fully constrained",
      "over-constrained": "Over-constrained",
      invalid: "Constraint analysis unavailable",
    };
    constraintStatus.textContent =
      labels[state.state] +
      (state.degreesOfFreedom !== null
        ? ` · ${state.degreesOfFreedom} degrees of freedom`
        : "") +
      (state.redundantEquations
        ? ` · ${state.redundantEquations} redundant equations`
        : "") +
      (state.message ? ` · ${state.message}` : "");
    const profiles = drawing.contours.filter(c => !c.construction);
    const closed = profiles.filter(contourClosed).length;
    message.textContent = `${frame ? "Planar face" : plane} · ${tool} · ${closed} closed / ${profiles.length - closed} open profiles. ${instructions[tool] ?? ""}`;
    renderSketchCanvas(svg, drawing, bounds, pending, dimensionPositions);
    if (showConstraints) renderConstraintMarks(svg, drawing, bounds);
    if (hoveredEntity && cursor)
      renderHoveredConstraints(svg, drawing, hoveredEntity, cursor, bounds);
    projected?.render(svg);
    renderPreview();
    renderSelection();
    fitSpline.refresh();
    modifications.refresh();
    constraints.refresh();
    renderContourList(list, drawing, (next) => {
      checkpoint();
      drawing = next;
      activePath = -1;
      pending = [];
      render();
    });
    clipboard.sync();
  }
  function place(p: SketchPoint, inferPoints = false) {
    if (!started || busy) return;
    recentSizing.clear();
    if (modifications.pickCorner(p, bounds.width / 60)) return;
    if (isDirectModificationTool(tool)) {
      try {
        const result = directModification(
          drawing,
          tool,
          p,
          pending,
          bounds.width / 60,
        );
        if (!result.drawing) {
          pending = result.pending;
          cursor = null;
          render();
          message.textContent = result.message ?? "";
          return;
        }
        const next = result.drawing;
        checkpoint();
        drawing = next;
        pending = [];
        cursor = null;
        activePath = -1;
        render();
        if (result.message) message.textContent = result.message;
      } catch (error) {
        fail((error as Error).message);
      }
      return;
    }
    if (tool === "select") {
      const picked = pickSelectableSketchEntity(drawing, p);
      if (picked && picked.d < bounds.width / 60) {
        if (JSON.stringify(selectedEntity) === JSON.stringify(picked.ref)) {
          selectedEntity = null;
          pickEntityB = false;
          renderSelection();
          message.textContent = "Selection cleared.";
          return;
        }
        selectedEntity = picked.ref;
        renderSelection();
        const selector = pickEntityB ? entityB : entityA;
        selectPickedReference(selector, picked);
        selector.closest("details")?.toggleAttribute("open", true);
        message.textContent = `${pickEntityB ? "Entity B" : "Entity A"}: ${picked.label}. ${hints[kind.value]}`;
        pickEntityB = !pickEntityB;
      } else {
        selectedEntity = null;
        pickEntityB = false;
        renderSelection();
        message.textContent = "Selection cleared.";
      }
      return;
    }
    try {
      const previousContourCount = drawing.contours.length;
      const result = placeDrawingPoint(
        { drawing, pending, activePath },
        effectivePoint(p),
        {
          tool,
          sides: Number(sides.value),
          inferQuadrants: geometrySnap,
          inferSemicircles: geometrySnap,
          clockwise: arcDirection.clockwise(),
          secondaryRadiusMillimeters: ellipseRadius.value(),
          rememberedRadiusMillimeters: ellipseRadius.remembered(),
          construction,
          closeTolerance: bounds.width / 100,
        },
      );
      const inferred = result.committed && geometrySnap
        ? inferDrawingPlacement(drawing, result.drawing, {pointer: inferPoints, tool, placedPoints: [...pending,effectivePoint(p)]})
        : result.drawing;
      if (result.committed) checkpoint();
      drawing = inferred;
      pending = result.pending;
      activePath = result.activePath;
      cursor = null;
      render();
      if (result.committed) recentSizing.offer(tool, previousContourCount, activePath);
    } catch (error) {
      fail((error as Error).message);
    }
  }
  const pointerPoint = (e: MouseEvent): SketchPoint | null => {
    let raw: SketchPoint;
    if (surface) {
      const hit = surface.toSketch(e.clientX, e.clientY);
      if (!hit) return null;
      raw = hit;
    } else {
      const point = svg.createSVGPoint();
      point.x = e.clientX;
      point.y = e.clientY;
      const matrix = svg.getScreenCTM();
      if (!matrix) return null;
      const p = point.matrixTransform(matrix.inverse());
      raw = [p.x, -p.y];
    }
    if (isDirectModificationTool(tool)) return raw;
    const contour = drawing.contours[activePath];
    const anchor =
      pending[0] ??
      (contour?.type === "path" ? contour.segments.at(-1)?.end : undefined);
    const tolerance = surface
      ? 8 * (surface.scaleAt(e.clientX, e.clientY) ?? bounds.width / 100)
      : (bounds.width * 8) / Math.max(svg.getBoundingClientRect().width, 800);
    const snapped = geometrySnap
      ? snapSketchPoint(raw, drawing, anchor, tolerance, gridSnap)
      : {
          point: gridSnap
            ? ([Math.round(raw[0]), Math.round(raw[1])] as SketchPoint)
            : raw,
          label: gridSnap ? "Grid · 1 mm" : "",
        };
    if (geometrySnap && tool === "arc" && pending.length === 2) {
      const semicircle = snapSemicircle(pending[0], pending[1], raw, tolerance);
      if (semicircle) { snapLabel = "Semicircle"; return semicircle; }
    }
    if (geometrySnap && tool === "elliptical-arc") {
      const guide = snapEllipticalArcGuide(pending, raw, tolerance, {secondaryRadiusMillimeters:ellipseRadius.value(),rememberedRadiusMillimeters:ellipseRadius.remembered()});
      if (guide) { snapLabel = "Ellipse quadrant"; return guide.point; }
    }
    snapLabel = snapped.label;
    return snapped.point;
  };
  const endpointGesture = bindEndpointDragGesture({
    svg,
    enabled: () => started && !busy && (tool === "tangent-arc" || tool === "arc"),
    hasPending: () => pending.length > 0,
    point: pointerPoint,
    begin: p => tool === "arc" ? arcChordStart(drawing, activePath, p, bounds.width / 100)
      : placeTangentArc(drawing, [], p, bounds.width / 100, construction).pending[0],
    preview: (start, end) => { recentSizing.clear(); pending = [start]; cursor = end; renderPreview(); },
    clear: () => { pending = []; cursor = null; renderPreview(); },
    commit: (start, end) => {
      if (tool === "arc") {
        pending = arcChordPoints(start, end); cursor = null; render();
        return;
      }
      const result = placeTangentArc(drawing, [start], end, bounds.width / 100, construction);
      const previousContourCount = drawing.contours.length;
      checkpoint(); drawing = result.drawing; activePath = result.activePath;
      pending = []; cursor = null; render();
      recentSizing.offer(tool, previousContourCount, activePath);
    },
    report: text => { message.textContent = text; },
  });
  const trimGesture = bindTrimGesture(svg, {
    enabled: () => started && !busy && tool === "trim",
    point: pointerPoint,
    drawing: () => drawing,
    pointTolerance: () => {
      if (surface) {
        const scale = surface.scaleAt();
        if (scale) return 6 * scale;
      }
      const matrix = svg.getScreenCTM();
      const scale = matrix ? Math.hypot(matrix.a, matrix.b) : NaN;
      return Number.isFinite(scale) && scale > 0
        ? 6 / scale
        : (bounds.width * 6) / (svg.getBoundingClientRect().width || 800);
    },
    preview: (next) => {
      drawing = next;
      cursor = null;
      render();
    },
    commit: (original, next) => {
      drawing = next;
      if (next !== original) {
        history.checkpoint({ drawing: original, activePath, dimensionPositions, variables });
      }
      cursor = null;
      render();
    },
    error: (text) => {
      message.textContent = text;
    },
  });
  const selectionDrag = bindSelectionDrag({
    svg,
    enabled: () => started && !busy && activeTool === "select",
    point: pointerPoint,
    drawing: () => drawing,
    tolerance: () => bounds.width / 60,
    select: (ref) => {
      selectedEntity = ref;
    },
    preview: (next) => {
      drawing = next;
      render();
    },
    commit: (before, next) => {
      drawing = next;
      if (JSON.stringify(before) !== JSON.stringify(next)) {
        history.checkpoint({ drawing: before, activePath, dimensionPositions, variables });
      }
      render();
    },
    report: (text) => {
      message.textContent = text;
    },
  });
  const dimensionLabelDrag = mountDimensionLabelDrag(svg,(id,point)=>{
    if(busy)return;checkpoint();dimensionPositions={...dimensionPositions,[id]:point};render();
  });
  svg.addEventListener("pointermove", (e) => {
    if (endpointGesture.active() || trimGesture.active() || selectionDrag.active()) return;
    cursor = pointerPoint(e);
    // Onshape reveals what constrains an entity as soon as you point at it,
    // whether or not constraint display is switched on.
    hoveredEntity = cursor ? (pickSelectableSketchEntity(drawing, cursor)?.ref ?? null) : null;
    renderPreview();
  });
  svg.addEventListener("pointerleave", () => {
    cursor = null;
    hoveredEntity = null;
    renderPreview();
  });
  svg.addEventListener("click", (e) => {
    if (endpointGesture.consumeClick() || trimGesture.consumeClick() || selectionDrag.consumeClick()) return;
    const p = pointerPoint(e);
    if (p) place(p, true);
  });
  for (const input of [x, y])
    input.addEventListener("input", () => {
      const p: SketchPoint = [Number(x.value), Number(y.value)];
      cursor = p.every(Number.isFinite) ? p : null;
      renderPreview();
    });
  svg.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const factor = e.deltaY > 0 ? 1.15 : 1 / 1.15;
      if (bounds.width * factor < 5 || bounds.width * factor > 10000) return;
      bounds = {
        x: bounds.x + (bounds.width * (1 - factor)) / 2,
        y: bounds.y + (bounds.height * (1 - factor)) / 2,
        width: bounds.width * factor,
        height: bounds.height * factor,
      };
      render();
    },
    { passive: false },
  );
  const workspaceKey = (e: KeyboardEvent) => {
    recentSizing.key(e);
    if (e.key === "Escape") {
      e.preventDefault();
      chooseTool("select");
      message.textContent =
        "Select sketch edges or vertices. Click empty space to deselect.";
      return;
    }
    if (!surface && e.target !== svg) return;
    if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(e.key)) {
      if (surface) return; // in-world: the 3D camera owns panning
      e.preventDefault();
      bounds.x +=
        ((e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0) *
          bounds.width) /
        10;
      bounds.y +=
        ((e.key === "ArrowDown" ? 1 : e.key === "ArrowUp" ? -1 : 0) *
          bounds.height) /
        10;
      render();
    }
  };
  const finishEvent = () => finish.click();
  window.addEventListener("aether-sketch-finish", finishEvent);
  root.addEventListener("keydown", workspaceKey);
  svg.addEventListener("keydown", (e) => {
    if (!e.bubbles) workspaceKey(e);
  });
  // In-world mode the svg cannot take focus (pointer-events:none in the CSS3D
  // layer), so keyboard shortcuts listen globally, skipping sidebar-focused events
  // that the root listener already handles.
  const globalKey = (e: KeyboardEvent) => {
    if (root.contains(e.target as Node)) return;
    workspaceKey(e);
  };
  cadSelection.dispatch({ type: "set-filter", filter: "face" });
  viewport.append(root);
  if (existing) start(plane, frame);
  else {
    setChoosingPlane(true);
    render();
  }
}
