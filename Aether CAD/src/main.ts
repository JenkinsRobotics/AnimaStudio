import { registerSketchTextCommand } from "./sketch/text-command";
import { registerSketchImportCommand } from "./sketch/import-command";
import { contextualDrawingTools } from "./sketch/tangent-arc-tool";
import { directModificationTools,modificationTools } from "./sketch/tool-instructions";
import { constructionPlaneFrame } from "@aether/core/document";
import { sketchProfilePolylines, sketchVariantTools } from "@aether/core/sketch";
import { principalFrame, rollbackPosition } from "@aether/core/document";
import { sketchConstraintCommandKinds } from "./cad-command-registry";
import { unitChoice } from "@aether/core/units";
import { documentUnits, subscribeDocumentUnits } from "./document-preferences";
import { configureDocumentPrint } from "./document-print";
import {mountFeatureAuthoring,mountProjectTabs} from "./feature-authoring";
import {createEmptyPartDocument,isPartFile,isProjectFile,validatePartDocument} from "@aether/core/document";
import "./style.css";
import {
  createEmbeddedAetherCoreClient,
  createRectanglePartDocument,
  parsePartDocument,
  rectanglePartParameters,
  reviseRectanglePartDocument,
  type AppliedMate,
  type PartDocument,
  type SketchPlane,
} from "./aether-core";
import { savePartDocument, serializePartDocument } from "./part-file";
import { hostedCAD, loadHostedFile, saveHostedFile, detachHostedFile, markHostedDirty, markHostedClean, configureAutosave, flushAutosaveNow, commitHosted } from "./host-library";
import {
  sketchPlaneForReference,
  parseReferenceVisibility,
  type ReferenceGeometryId,
} from "./reference-geometry";
import { SketchEditor } from "./sketch-editor";
import { MateViewport, type AuthoringTool } from "./viewer";
import { cadCommands } from "./cad-command-registry";
import { buildCADWorkspaceProjection } from "./cad-workspace-projection";
import { cadWorkspace } from "./cad-workspace-store";
import {
  cadPresentation,
  parseCADPresentationPreferences,
  serializeCADPresentationPreferences,
  type CADBrowserPanel,
  type CADStatusTone,
} from "./cad-presentation-store";
import { cadAppearance } from "./cad-appearance-store";
import type {
  CADBackgroundPreset,
  CADDisplayStyle,
  CADFloorMode,
  CADLightingPreset,
  CADMaterialFinish,
} from "./cad-appearance-store";
import { cadSelection, selectionFilters, type CADSelectionFilter } from "./cad-selection-store";
import { CADAssemblyController } from "./cad-assembly-controller";
import { cadAssemblyWorkspace } from "./cad-assembly-workspace-store";
import { cadCameraPresentation } from "./cad-camera-presentation-store";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("Missing #app root");
if (!app.querySelector(".shapr-shell")) throw new Error("React CAD shell did not mount");

const viewportElement = document.querySelector<HTMLElement>("#viewport")!;
const picker = document.querySelector<HTMLInputElement>("#step-picker")!;
const partPicker = document.querySelector<HTMLInputElement>("#part-picker")!;
const assemblyPicker = document.querySelector<HTMLInputElement>("#assembly-picker")!;
const partNameInput = document.querySelector<HTMLInputElement>("#part-name")!;
const partWidthInput = document.querySelector<HTMLInputElement>("#part-width")!;
const partHeightInput = document.querySelector<HTMLInputElement>("#part-height")!;
const partDepthInput = document.querySelector<HTMLInputElement>("#part-depth")!;
const mates: AppliedMate[] = [];
const expandedDocuments = new Set<string>();
const collapsedFolders = new Set<string>();
const knownDocuments = new Set<string>();
let activePartDocument: PartDocument | null = null;
const selectedFeatureIDs=new Set<string>();
let untitledPartNumber = 1;
let awaitingSketchPlane = false;
let pendingPartName: string | null = null;
let selectedSketchPlane: SketchPlane | null = null;
let sketchEditor: SketchEditor | null = null;
let cancelSTEPImportRequested = false;
let activeWorkspaceKind: "part" | "assembly" = "part";
const referenceVisibility: Record<ReferenceGeometryId, boolean> = {
  origin: false,
  axes: false,
  "top-plane": false,
  "front-plane": false,
  "right-plane": false,
};
// Show/hide of reference geometry is a workspace preference, not document data:
// it must survive a reload, like the panel layout next to it.
const referenceVisibilityKey = "aether-cad.reference-visibility.v1";
let sketchPlaneVisibilityBefore: typeof referenceVisibility | null = null;
try {
  Object.assign(referenceVisibility, parseReferenceVisibility(localStorage.getItem(referenceVisibilityKey)));
} catch {
  // Storage is an optional presentation convenience, never a CAD dependency.
}
function persistReferenceVisibility(): void {
  try {
    localStorage.setItem(referenceVisibilityKey, JSON.stringify(referenceVisibility));
  } catch {
    // Storage is an optional presentation convenience, never a CAD dependency.
  }
}
const presentationPreferenceKey = "aether-cad.presentation.v1";

try {
  const preferences = parseCADPresentationPreferences(localStorage.getItem(presentationPreferenceKey));
  if (preferences) cadPresentation.patch(preferences);
} catch {
  // The standalone app can run with storage disabled; session state still works.
}

function persistPresentationPreferences(): void {
  try {
    localStorage.setItem(
      presentationPreferenceKey,
      serializeCADPresentationPreferences(cadPresentation.snapshot()),
    );
  } catch {
    // Storage is an optional presentation convenience, never a CAD dependency.
  }
}

function setStatus(
  message: string,
  tone: CADStatusTone = "normal",
): void {
  cadPresentation.patch({ statusMessage: message, statusTone: tone });
}

const assemblyController = new CADAssemblyController({
  ...(hostedCAD ? { saveFile: saveHostedFile } : {}),
  onDocumentChanged(document) {
    if (hostedCAD && document) markHostedDirty();
    if (!document) return;
    activeWorkspaceKind = "assembly";
    activePartDocument=null;
    void renderCanonicalAssembly();
    cadPresentation.patch({
      documentName: document.name,
      activePanel: "mates",
      workspaceMode: "modeling",
      startScreen: "workspace",
      startDialog: null,
    });
  },
  onStatus: setStatus,
});
let matePreviewSerial = 0;

function syncAssemblyCommands(): void {
  const instance = assemblyController.selectedInstance;
  const mate = assemblyController.selectedMate;
  const enabled = assemblyController.canEditSelectedInstance;
  const mateEnabled = assemblyController.canEditSelectedMate;
  cadCommands.setEnabled("assembly-insert-component", assemblyController.canEditInstances);
  cadCommands.setEnabled("assembly-add-connector", assemblyController.canAddConnector);
  cadCommands.setEnabled("assembly-create-mate", assemblyController.canAddMate);
  cadCommands.setEnabled("assembly-set-mate-dof-value", assemblyController.canEditSelectedMateDOF);
  cadCommands.setEnabled("assembly-edit-mate-dof-limits", assemblyController.canEditSelectedMateDOF);
  cadCommands.setEnabled("assembly-create-relation", assemblyController.canAddRelation);
  cadCommands.setEnabled("assembly-toggle-grounded", enabled);
  cadCommands.setEnabled("assembly-toggle-suppressed", enabled);
  cadCommands.setEnabled("assembly-remove-instance", enabled);
  cadCommands.setEnabled("assembly-toggle-mate-suppressed", mateEnabled);
  cadCommands.setEnabled("assembly-remove-mate", mateEnabled);
  cadCommands.setActive("assembly-toggle-grounded", Boolean(enabled && instance?.grounded));
  cadCommands.setActive("assembly-toggle-suppressed", Boolean(enabled && instance?.suppressed));
  cadCommands.setActive("assembly-toggle-mate-suppressed", Boolean(mateEnabled && mate?.suppressed));
}

cadCommands.register("assembly-insert-component", () => {
  cadPresentation.dispatch({ type: "show-start-dialog", dialog: "insert-component" });
});
cadCommands.register("assembly-add-connector", () => {
  cadPresentation.dispatch({ type: "show-start-dialog", dialog: "add-connector" });
});
cadCommands.register("assembly-create-mate", () => {
  matePreviewSerial += 1;
  cadPresentation.patch({ matePreview: null });
  cadPresentation.dispatch({ type: "show-start-dialog", dialog: "create-mate" });
});
cadCommands.register("assembly-set-mate-dof-value", () => {
  cadPresentation.dispatch({ type: "show-start-dialog", dialog: "set-mate-dof-value" });
});
cadCommands.register("assembly-edit-mate-dof-limits", () => {
  cadPresentation.dispatch({ type: "show-start-dialog", dialog: "edit-mate-dof-limits" });
});
cadCommands.register("assembly-create-relation", () => {
  cadPresentation.dispatch({ type: "show-start-dialog", dialog: "create-relation" });
});
cadCommands.register("assembly-toggle-grounded", () => {
  void assemblyController.toggleSelectedInstanceGrounded().catch(() => undefined);
});
cadCommands.register("assembly-toggle-suppressed", () => {
  void assemblyController.toggleSelectedInstanceSuppressed().catch(() => undefined);
});
cadCommands.register("assembly-remove-instance", () => {
  void assemblyController.removeSelectedInstance().catch(() => undefined);
});
cadCommands.register("assembly-toggle-mate-suppressed", () => {
  void assemblyController.toggleSelectedMateSuppressed().catch(() => undefined);
});
cadCommands.register("assembly-remove-mate", () => {
  void assemblyController.removeSelectedMate().catch(() => undefined);
});
cadAssemblyWorkspace.subscribe(syncAssemblyCommands);
syncAssemblyCommands();

function syncToolUI(): void {
  const tool = viewer.activeTool;
  cadCommands.setActive("connector", tool === "connector");
  cadCommands.setActive("fastened", tool === "fastened");
  cadCommands.setActive(
    "sketch",
    awaitingSketchPlane || Boolean(sketchEditor?.active),
  );
  cadPresentation.patch({
    activeTool: tool,
    awaitingSketchPlane,
    hover: tool === "none" ? null : cadPresentation.snapshot().hover,
  });
}

function showBrowserPanel(panel: CADBrowserPanel): void {
  const presentation = cadPresentation.snapshot();
  cadPresentation.patch({
    activePanel: panel,
    workspaceMode: "modeling",
    panelPlacements: panel === "items" && presentation.panelPlacements.browser === "hidden"
      ? Object.freeze({ ...presentation.panelPlacements, browser: "docked" })
      : presentation.panelPlacements,
  });
}

function syncRibbonAvailability(): void {
  const rows = viewer.getPartRows();
  const connectors = viewer.getConnectorRows();
  cadCommands.setEnabled("save-part", activePartDocument !== null);
  cadCommands.setEnabled("commit-part", activePartDocument !== null && hostedCAD);
  cadCommands.setEnabled("connector", rows.length > 0);
  cadCommands.setEnabled("fastened", connectors.length >= 2);
  cadCommands.setEnabled("fit-view", rows.length > 0);
  cadCommands.setEnabled("clear-mates", mates.length > 0);
}

// Draft feature being authored (declared before updateLists reads it).
let draftSketch: { id: string; name: string; hasPlane: boolean; existing: boolean } | null = null;
function updateLists(): void {
  viewer.setConstructionPlanes(activePartDocument);
  // Finished sketches stay visible in the viewport (native parity): every
  // unsuppressed sketch before the rollback line renders its curves.
  viewer.setSketchCurves(
    activePartDocument
      ? activePartDocument.features
          .slice(0, rollbackPosition(activePartDocument))
          .filter((feature) => (feature.type === "sketch" || feature.type === "profile") && !feature.suppressed)
          .map((feature) => ({
            id: feature.id,
            frame:
              ("frame" in feature && feature.frame) ||
              principalFrame(("plane" in feature ? feature.plane : "XY") as "XY" | "XZ" | "YZ"),
            polylines: "profile" in feature ? sketchProfilePolylines(feature.profile) : [],
          }))
      : [],
  );
  window.dispatchEvent(new Event("aether-part-updated"));
  const rows = viewer.getPartRows();
  const importedRows = activePartDocument
    ? rows.filter((row) => row.sourceDocumentId !== activePartDocument?.documentId)
    : rows;
  const connectors = viewer.getConnectorRows();
  const topology = viewer.getTopologyInferenceSummary();
  const first = viewer.firstMateConnector;
  rows.forEach((row) => {
    if (knownDocuments.has(row.sourceDocumentId)) return;
    knownDocuments.add(row.sourceDocumentId);
    expandedDocuments.add(row.sourceDocumentId);
  });
  cadWorkspace.publish(
    buildCADWorkspaceProjection(
      activePartDocument,
      importedRows,
      expandedDocuments,
      referenceVisibility,
      selectedSketchPlane,
      connectors,
      mates,
      first?.id ?? null,
      topology,
      new Set(rows.filter((row) => row.selected).map((row) => row.id)),
      selectedFeatureIDs,
      collapsedFolders,
      draftSketch && !draftSketch.existing ? draftSketch : null,
    ),
  );

  cadPresentation.patch({
    documentName: activeWorkspaceKind === "assembly"
      ? assemblyController.document?.name ?? "Untitled Assembly"
      : activePartDocument?.name ?? "Untitled Part",
    partOpen: activePartDocument !== null,
    metricsText: `${activePartDocument?.name ?? "No Part open"} · ${rows.length} bodies · ${topology.faceCount} faces · ${topology.candidateCount} exact snaps · ${connectors.length} connectors · ${mates.length} mates`,
    cylinderAxisCandidates: topology.candidatesByKind["cylinder-axis"],
    analyticCenterCandidates:
      topology.candidatesByKind["circle-center"] +
      topology.candidatesByKind["ellipse-center"] +
      topology.candidatesByKind["sphere-center"] +
      topology.candidatesByKind["torus-center"],
    movingPick: first
      ? `${first.name} · ${first.partName}`
      : "Select a saved connector",
    targetPick: first
      ? "Choose a connector on another Part"
      : "Waiting for first connector",
  });
  syncToolUI();
  syncRibbonAvailability();
}

const viewer = new MateViewport(viewportElement, {
  onHover(target) {
    cadPresentation.patch({
      hover: target
        ? { partName: target.partName, label: target.label, detail: target.detail }
        : null,
    });
  },
  onStatus: setStatus,
  onStateChanged: updateLists,
  onMateApplied(mate) {
    mates.push(mate);
    updateLists();
  },
  onCameraChanged(orientation) {
    cadCameraPresentation.setOrientation(orientation);
  },
});
cadCameraPresentation.registerActionHandler((action) => {
  switch (action.type) {
    case "select-view":
      viewer.setCameraView(action.view);
      break;
    case "fit-isometric":
      viewer.frameAll();
      viewer.setCameraView("isometric");
      break;
    case "nudge":
      viewer.nudgeCamera(action.horizontalSteps, action.verticalSteps);
      break;
    case "roll":
      viewer.rollCamera(action.quarterTurns);
      break;
    case "set-field-of-view":
      viewer.setFieldOfView(action.degrees);
      cadCameraPresentation.setFieldOfView(action.degrees);
      break;
  }
});
let appearanceInitialized = false;
cadAppearance.registerApplyHandler((appearance) => {
  viewer.setAppearance(appearance);
  const displayCommands = {
    shaded: "display-shaded",
    "shaded-edges": "display-shaded-edges",
    wireframe: "display-wireframe",
    "hidden-line": "display-hidden-line",
    ghost: "display-ghost",
  } as const;
  Object.entries(displayCommands).forEach(([style, command]) => {
    cadCommands.setActive(command, appearance.displayStyle === style);
  });
  const lightingCommands = {
    studio: "lighting-studio",
    softbox: "lighting-softbox",
    daylight: "lighting-daylight",
    "dark-room": "lighting-dark-room",
  } as const;
  Object.entries(lightingCommands).forEach(([preset, command]) => {
    cadCommands.setActive(command, appearance.lightingPreset === preset);
  });
  const backgroundCommands = {
    graphite: "background-graphite",
    midnight: "background-midnight",
    "cad-light": "background-cad-light",
    blueprint: "background-blueprint",
  } as const;
  Object.entries(backgroundCommands).forEach(([background, command]) => {
    cadCommands.setActive(command, appearance.background === background);
  });
  const finishCommands = {
    matte: "finish-matte",
    satin: "finish-satin",
    gloss: "finish-gloss",
  } as const;
  Object.entries(finishCommands).forEach(([finish, command]) => {
    cadCommands.setActive(command, appearance.materialFinish === finish);
  });
  const groundCommands = {
    none: "ground-none",
    grid: "ground-grid",
    floor: "ground-floor",
    both: "ground-both",
  } as const;
  Object.entries(groundCommands).forEach(([mode, command]) => {
    cadCommands.setActive(command, appearance.floorMode === mode);
  });
  cadCommands.setActive("toggle-contact-shadows", appearance.contactShadowsVisible);
  cadCommands.setActive("toggle-feature-edges", appearance.edgesVisible);
  if (appearanceInitialized) {
    setStatus("Viewport appearance updated for this session.");
  }
  appearanceInitialized = true;
});
const selectionCommands = {
  auto: "selection-auto",
  component: "selection-component",
  body: "selection-body",
  face: "selection-face",
  edge: "selection-edge",
  vertex: "selection-vertex",
} as const;
const syncSelectionPresentation = (): void => {
  viewer.refreshSelectionAppearance();
  const activeFilter = cadSelection.snapshot().filter;
  Object.entries(selectionCommands).forEach(([filter, command]) => {
    cadCommands.setActive(command, activeFilter === filter);
  });
};
cadSelection.subscribe(syncSelectionPresentation);
sketchEditor = new SketchEditor(viewportElement, {
  async onCommit(document) {
    const wasNew = activePartDocument === null;
    sketchEditor?.close();
    viewportElement.classList.remove("sketching");
    await evaluateAndShowPart(
      document,
      wasNew ? `Created ${document.name}.` : `Rebuilt ${document.name}.`,
    );
    selectedSketchPlane = null;
    updateLists();
  },
  onCancel() {
    viewportElement.classList.remove("sketching");
    selectedSketchPlane = null;
    setStatus("Sketch edit cancelled.");
    updateLists();
  },
  onStatus: setStatus,
});
function toggleReferenceVisibility(id: ReferenceGeometryId): void {
  referenceVisibility[id] = !referenceVisibility[id];
  viewer.setReferenceGeometryVisibility(id, referenceVisibility[id]);
  persistReferenceVisibility();
  // Picking a sketch plane force-shows the planes and restores the previous
  // state on exit. Toggling during that window is the user overriding it, so it
  // becomes the state to restore — otherwise finishing the sketch undoes it.
  if (sketchPlaneVisibilityBefore) sketchPlaneVisibilityBefore[id] = referenceVisibility[id];
  if (id === "origin") cadCommands.setActive("toggle-origin", referenceVisibility.origin);
  updateLists();
}

function selectReference(id: ReferenceGeometryId): void {
  const plane = sketchPlaneForReference(id);
  if (plane && document.querySelector(".cad-sketch-workspace.choosing-plane")) {
    window.dispatchEvent(new CustomEvent("aether-sketch-plane", { detail: plane }));
    return;
  }
  if (awaitingSketchPlane && plane) {
    awaitingSketchPlane = false;
    selectedSketchPlane = plane;
    const name = pendingPartName ?? `Part ${untitledPartNumber++}`;
    pendingPartName = null;
    const document = createRectanglePartDocument(
      name,
      readPartParameters(),
      undefined,
      { plane, fullyDefinedSketch: false },
    );
    viewportElement.classList.add("sketching");
    sketchEditor?.open(document);
    updateLists();
    return;
  }
  toggleReferenceVisibility(id);
}

cadWorkspace.registerActionHandler((action) => {
  if(action.type==="move-item"||action.type==="create-folder"||action.type==="rollback-to"||(action.type==="item-action"&&["edit-feature","suppress-feature","rollback-before","rollback-start","rollback-end","body-visibility","body-rename","folder-rename","folder-delete","folder-unnest","rollback-back","rollback-forward","rename-feature","delete-feature"].includes(action.actionID))){
    window.dispatchEvent(new CustomEvent('aether-feature-action',{detail:{...action,selectedFeatureIDs:[...selectedFeatureIDs]}}));return;
  }

  if (action.type === "toggle-item"
      && (action.id === "reference-folder" || action.id.startsWith("bodies/"))) {
    if (collapsedFolders.has(action.id)) collapsedFolders.delete(action.id);
    else collapsedFolders.add(action.id);
    updateLists();
    return;
  }
  if (action.type === "toggle-item" && action.id.startsWith("folder/")) {
    if (collapsedFolders.has(action.id)) collapsedFolders.delete(action.id);
    else collapsedFolders.add(action.id);
    updateLists();
    return;
  }
  if (action.type === "toggle-item" && action.id.startsWith("document/")) {
    const id = action.id.slice("document/".length);
    if (expandedDocuments.has(id)) expandedDocuments.delete(id);
    else expandedDocuments.add(id);
    updateLists();
    return;
  }
  if (action.type === "select-item") {
    const mode = action.mode ?? "single";
    const rowFeatureIDs = (action.ids ?? [action.id])
      .filter((id) => id.startsWith("feature/") && !id.startsWith("feature/body/"))
      .map((id) => id.split("/").slice(2).join("/"))
      .filter((id) => activePartDocument?.features.some((feature) => feature.id === id));
    // ponytail: only feature rows multi-select; a modified click anywhere else
    // behaves like a plain click rather than growing a second selection model.
    if (rowFeatureIDs.length && (mode !== "single" || rowFeatureIDs.length > 1)) {
      if (mode === "range" || mode === "single") {
        selectedFeatureIDs.clear();
        rowFeatureIDs.forEach((id) => selectedFeatureIDs.add(id));
      } else
        rowFeatureIDs.forEach((id) =>
          selectedFeatureIDs.has(id) ? selectedFeatureIDs.delete(id) : selectedFeatureIDs.add(id),
        );
      cadSelection.dispatch({type:"replace",items:[]});
      setStatus(selectedFeatureIDs.size === 1
        ? `1 feature selected.`
        : `${selectedFeatureIDs.size} features selected.`);
      updateLists();
      return;
    }
    selectedFeatureIDs.clear();
    if (action.id.startsWith("reference/")) {
      selectReference(action.id.slice("reference/".length) as ReferenceGeometryId);
    } else if (action.id.startsWith("part/")) {
      viewer.selectPart(action.id.slice("part/".length));
    } else if (action.id.startsWith("feature/") && activePartDocument) {
      const [, kind, ...idParts] = action.id.split("/");
      const featureID = idParts.join("/");
      if (kind === "body") viewer.selectPart(featureID);
      else {
        const feature = activePartDocument.features.find((item) => item.id === featureID);
        if (feature?.type==='plane' && !feature.suppressed && document.querySelector('.cad-plane-window') && activePartDocument.features.indexOf(feature)<(activePartDocument.rollbackIndex??activePartDocument.features.length)){
          window.dispatchEvent(new CustomEvent('aether-plane-feature-picked',{detail:{featureId:feature.id}}));return;
        }
        if (feature?.type==='plane' && !feature.suppressed && document.querySelector('.cad-sketch-workspace.choosing-plane') && activePartDocument.features.indexOf(feature)<(activePartDocument.rollbackIndex??activePartDocument.features.length)){
          window.dispatchEvent(new CustomEvent('aether-sketch-face',{detail:{frame:constructionPlaneFrame(feature,activePartDocument.features.slice(0,activePartDocument.features.indexOf(feature)))}}));return;
        }
        if (feature) {selectedFeatureIDs.add(feature.id);cadSelection.dispatch({type:"replace",items:[]});setStatus(`${feature.name} selected. Double-click or press Enter to edit.`);updateLists();}
      }
    }
    return;
  }
  if (action.type === "item-action" && action.actionID === "toggle-visibility") {
    if (action.id.startsWith("reference/")) {
      toggleReferenceVisibility(action.id.slice("reference/".length) as ReferenceGeometryId);
    } else if (action.id.startsWith("part/")) {
      const id = action.id.slice("part/".length);
      const row = viewer.getPartRows().find((part) => part.id === id);
      if (row) viewer.setPartVisibility(id, !row.visible);
    }
    return;
  }
  if (action.type === "activate-history") {
    if (action.id.startsWith("history/feature/")) {
      showBrowserPanel("parameters");
      const id = action.id.slice("history/feature/".length);
      const feature = activePartDocument?.features.find((item) => item.id === id);
      if (feature)window.dispatchEvent(new CustomEvent("aether-feature-action",{detail:{type:"item-action",id:`feature/${feature.type}/${feature.id}`,actionID:"edit-feature"}}));
    } else if (action.id.startsWith("history/document/")) {
      showBrowserPanel("items");
    } else if (action.id.startsWith("history/mate/")) {
      showBrowserPanel("mates");
    }
    return;
  }
  if (action.type === "select-connector") {
    viewer.selectConnectorForMate(action.id.slice("connector/".length));
    return;
  }
  if (action.type === "connector-action") {
    const id = action.id.slice("connector/".length);
    if (action.actionID === "pick") viewer.selectConnectorForMate(id);
    if (action.actionID === "delete") viewer.removeConnector(id);
  }
});

cadPresentation.registerActionHandler((action) => {
  if (action.type === "show-start-screen") {
    if (hostedCAD && action.screen === "home") { location.assign("/cad/"); return; }
    cadPresentation.patch({ startScreen: action.screen, startDialog: null });
    return;
  }
  if (action.type === "show-start-dialog") {
    cadPresentation.patch({ startDialog: action.dialog });
    return;
  }
  if (action.type === "create-part-workspace") {
    if (hostedCAD) detachHostedFile();
    activeWorkspaceKind = "part";
    cadPresentation.patch({ startScreen: "workspace", startDialog: null, workspaceMode: "modeling" });
    void createBlankPart(action.name);
    return;
  }
  if (action.type === "create-assembly-workspace") {
    if (hostedCAD) detachHostedFile();
    cadPresentation.patch({
      startScreen: "workspace",
      startDialog: null,
      workspaceMode: "modeling",
      activePanel: "mates",
    });
    void assemblyController.newWorkspace(action.name).catch(() => undefined);
    return;
  }
  if (action.type === "insert-assembly-component") {
    void assemblyController.insertComponent(action.draft)
      .then(() => cadPresentation.patch({ startDialog: null, activePanel: "mates" }))
      .catch(() => undefined);
    return;
  }
  if (action.type === "add-assembly-connector") {
    void assemblyController.addConnector(action.draft)
      .then(() => cadPresentation.patch({ startDialog: null, activePanel: "mates" }))
      .catch(() => undefined);
    return;
  }
  if (action.type === "clear-assembly-mate-preview") {
    matePreviewSerial += 1;
    cadPresentation.patch({ matePreview: null });
    return;
  }
  if (action.type === "preview-assembly-mate") {
    const previewSerial = ++matePreviewSerial;
    cadPresentation.patch({ matePreview: { state: "loading", message: "Solving non-mutating Core preview…" } });
    void assemblyController.previewMate(action.draft)
      .then((preview) => {
        if (previewSerial !== matePreviewSerial) return;
        cadPresentation.patch({
          matePreview: {
            state: "ready",
            revision: preview.revision,
            solveStatus: preview.solution.status,
            remainingFreeDOFCount: preview.solution.remaining_free_dof_count,
            residual: preview.solution.residual,
            diagnosticMessages: preview.diagnostics.map(({ message }) => message),
          },
        });
      })
      .catch((error: unknown) => {
        if (previewSerial !== matePreviewSerial) return;
        cadPresentation.patch({
          matePreview: {
            state: "error",
            message: error instanceof Error ? error.message : String(error),
          },
        });
      });
    return;
  }
  if (action.type === "commit-assembly-mate") {
    matePreviewSerial += 1;
    void assemblyController.addMate(action.draft)
      .then(() => cadPresentation.patch({ startDialog: null, matePreview: null, activePanel: "mates" }))
      .catch(() => undefined);
    return;
  }
  if (action.type === "set-assembly-mate-dof-value") {
    void assemblyController.setSelectedMateDOFValue(action.draft)
      .then(() => cadPresentation.patch({ startDialog: null, activePanel: "mates" }))
      .catch(() => undefined);
    return;
  }
  if (action.type === "update-assembly-mate-dof-limits") {
    void assemblyController.updateSelectedMateDOFLimits(action.draft)
      .then(() => cadPresentation.patch({ startDialog: null, activePanel: "mates" }))
      .catch(() => undefined);
    return;
  }
  if (action.type === "create-assembly-relation") {
    void assemblyController.addRelation(action.draft)
      .then(() => cadPresentation.patch({ startDialog: null, activePanel: "mates" }))
      .catch(() => undefined);
    return;
  }
  if (action.type === "open-assembly-workspace") {
    assemblyPicker.click();
    return;
  }
  if (action.type === "save-assembly-workspace") {
    void assemblyController.save().catch(() => undefined);
    return;
  }
  if (action.type === "select-panel") {
    showBrowserPanel(action.panel);
    return;
  }
  if (action.type === "select-workspace-mode") {
    cadPresentation.patch({ workspaceMode: action.mode, startScreen: "workspace" });
    setStatus(action.mode === "drawing"
      ? "Drawing workspace opened; exact sheets are waiting for the canonical Core producer."
      : "3D modeling workspace opened.");
    return;
  }
  if (action.type === "select-layout") {
    cadPresentation.patch({ workspaceLayout: action.layout });
    persistPresentationPreferences();
    setStatus(`${action.layout[0].toUpperCase()}${action.layout.slice(1)} workspace layout.`);
    return;
  }
  if (action.type === "select-toolbar-mode") {
    cadPresentation.patch({ toolbarMode: action.mode });
    persistPresentationPreferences();
    setStatus(action.mode === "traditional" ? "Traditional CAD ribbon enabled." : "Floating viewport tools enabled.");
    return;
  }
  if (action.type === "set-panel-placement") {
    cadPresentation.patch({
      panelPlacements: Object.freeze({
        ...cadPresentation.snapshot().panelPlacements,
        [action.panel]: action.placement,
      }),
    });
    persistPresentationPreferences();
    setStatus(`${action.panel[0].toUpperCase()}${action.panel.slice(1)} panel ${action.placement}.`);
    return;
  }
  if (action.type === "reset-panel-placements") {
    cadPresentation.patch({
      workspaceLayout: "docked",
      panelPlacements: Object.freeze({ browser: "docked", inspector: "docked", bottom: "docked" }),
    });
    persistPresentationPreferences();
    setStatus("Panel placements reset to the docked workbench.");
    return;
  }
  if (action.type === "cancel-loading") {
    const loading = cadPresentation.snapshot().loading;
    if (!loading?.canCancel) return;
    cancelSTEPImportRequested = true;
    cadPresentation.patch({
      loading: {
        ...loading,
        canCancel: false,
        backgrounded: false,
        detail: "Stopping after the current OCCT operation…",
      },
    });
    return;
  }
  if (action.type === "background-loading") {
    const loading = cadPresentation.snapshot().loading;
    if (!loading?.canBackground) return;
    cadPresentation.patch({ loading: { ...loading, backgrounded: true } });
    setStatus("STEP import continues in the background.");
    return;
  }
  if (action.type === "show-loading") {
    const loading = cadPresentation.snapshot().loading;
    if (loading) cadPresentation.patch({ loading: { ...loading, backgrounded: false } });
    return;
  }
  if (action.type === "focus-items-filter") {
    cadPresentation.patch({
      activePanel: "items",
      workspaceMode: "modeling",
      itemFilterFocusSerial: cadPresentation.snapshot().itemFilterFocusSerial + 1,
    });
    return;
  }
  if (action.type === "toggle-history") {
    const presentation = cadPresentation.snapshot();
    cadPresentation.patch({
      bottomPanelActiveID: "history",
      panelPlacements: presentation.panelPlacements.bottom === "hidden"
        ? Object.freeze({ ...presentation.panelPlacements, bottom: "docked" })
        : presentation.panelPlacements,
      bottomPanelCollapsed:
        presentation.panelPlacements.bottom === "hidden"
          ? false
          : presentation.bottomPanelActiveID === "history"
          ? !presentation.bottomPanelCollapsed
          : false,
    });
    return;
  }
  if (action.type === "select-bottom-panel") {
    cadPresentation.patch({ bottomPanelActiveID: action.id });
    return;
  }
  if (action.type === "set-bottom-panel-collapsed") {
    cadPresentation.patch({ bottomPanelCollapsed: action.collapsed });
    return;
  }
  if (action.type === "cancel-sketch-plane") {
    cancelPlaneSelection();
    return;
  }
  if (action.type === "cancel-tool") {
    viewer.setTool("none");
    updateLists();
  }
});

const worker = createEmbeddedAetherCoreClient();
worker.ready
  .then(() => {
    cadPresentation.patch({
      backendLabel: `${viewer.backendLabel} · OCCT ready`,
      backendState: "ready",
    });
    setStatus("Create a Part, open an .acpart file, or add STEP reference geometry.");
  })
  .catch((error: unknown) => {
    cadPresentation.patch({ backendState: "failed" });
    setStatus(error instanceof Error ? error.message : String(error), "error");
  });

picker.addEventListener("change", async () => {
  const files = [...(picker.files ?? [])];
  if (files.length === 0) return;
  cadPresentation.patch({
    loading: {
      label: "Extracting B-Rep topology",
      detail: "Reading STEP…",
      canCancel: true,
      canBackground: true,
      backgrounded: false,
      phase: `0 of ${files.length}`,
      value: 0,
      max: files.length,
    },
  });
  cadCommands.setEnabled("insert-step", false);
  cancelSTEPImportRequested = false;
  let imported = 0;
  let elapsed = 0;
  let cancelled = false;
  try {
    for (const [index, file] of files.entries()) {
      if (cancelSTEPImportRequested) {
        cancelled = true;
        break;
      }
      const currentLoading = cadPresentation.snapshot().loading;
      cadPresentation.patch({
        loading: {
          ...currentLoading,
          label: "Extracting B-Rep topology",
          detail: `${file.name} · analytic faces and edges`,
          phase: `${index + 1} of ${files.length}`,
          value: index,
          max: files.length,
        },
      });
      const model = await worker.importSTEP(file);
      if (cancelSTEPImportRequested) {
        cancelled = true;
        break;
      }
      viewer.addModel(model.parts);
      imported += model.parts.length;
      elapsed += model.parseMilliseconds;
      const completedLoading = cadPresentation.snapshot().loading;
      if (completedLoading) {
        cadPresentation.patch({
          loading: { ...completedLoading, value: index + 1 },
        });
      }
    }
    if (imported > 0) viewer.frameAll();
    if (cancelled) {
      setStatus(
        imported > 0
          ? `STEP import stopped after adding ${imported} Part${imported === 1 ? "" : "s"}.`
          : "STEP import cancelled; existing geometry was unchanged.",
      );
    } else {
      setStatus(
        `Added ${imported} Part${imported === 1 ? "" : "s"}; OCCT topology + tessellation took ${elapsed.toFixed(1)} ms.`,
        "success",
      );
    }
  } catch (error) {
    setStatus(error instanceof Error ? error.message : String(error), "error");
  } finally {
    cadPresentation.patch({ loading: null });
    cadCommands.setEnabled("insert-step", true);
    cancelSTEPImportRequested = false;
    picker.value = "";
    updateLists();
  }
});

function readPartParameters(): {
  widthMillimeters: number;
  heightMillimeters: number;
  depthMillimeters: number;
} {
  return {
    widthMillimeters: Number(partWidthInput.value) * (unitChoice(documentUnits(), "length").factor/0.001),
    heightMillimeters: Number(partHeightInput.value) * (unitChoice(documentUnits(), "length").factor/0.001),
    depthMillimeters: Number(partDepthInput.value) * (unitChoice(documentUnits(), "length").factor/0.001),
  };
}

subscribeDocumentUnits(() => {
  if (activePartDocument?.features.some(f=>f.type==="sketch")) updatePartEditor(activePartDocument);
  else {const factor=unitChoice(documentUnits(),"length").factor/0.001;partWidthInput.value=String(60/factor);partHeightInput.value=String(40/factor);partDepthInput.value=String(20/factor);}
});

function updatePartEditor(document: PartDocument): void {
  partNameInput.value = document.name;
  if (!document.features.some(feature => feature.type === "sketch")) return;
  const parameters = rectanglePartParameters(document);
  partWidthInput.value = String(parameters.widthMillimeters / (unitChoice(documentUnits(), "length").factor/0.001));
  partHeightInput.value = String(parameters.heightMillimeters / (unitChoice(documentUnits(), "length").factor/0.001));
  partDepthInput.value = String(parameters.depthMillimeters / (unitChoice(documentUnits(), "length").factor/0.001));
}

async function evaluateAndShowPart(
  document: PartDocument,
  successMessage: string,
): Promise<void> {
  cadPresentation.patch({
    loading: {
      label: "Rebuilding exact feature history",
      detail: document.name,
    },
  });
  try {
    validatePartDocument(document);
    const shouldFrame = activePartDocument?.documentId !== document.documentId || !viewer.getPartRows().some(row => row.sourceDocumentId === document.documentId);
    const result = await worker.evaluatePart(document);
    for(const row of viewer.getPartRows())if(row.sourceDocumentId===activePartDocument?.documentId)viewer.removeAuthoredPart(row.id);
    for(const body of result.parts) {
      viewer.replaceAuthoredPart(body);
      if(document.bodyProperties?.[body.id]?.visible===false)viewer.setPartVisibility(body.id,false);
    }
    cadSelection.dispatch({type: "replace", items: []});
    activePartDocument = document;
    if (hostedCAD) markHostedDirty();
    expandedDocuments.add(document.documentId);
    updatePartEditor(document);
    if (shouldFrame && result.parts.length) viewer.frameAll();
    setStatus(
      `${successMessage} OCCT rebuilt ${document.features.length} features in ${result.parseMilliseconds.toFixed(1)} ms.`,
      "success",
    );
  } catch (error) {
    setStatus(error instanceof Error ? error.message : String(error), "error");
  } finally {
    cadPresentation.patch({ loading: null });
    updateLists();
  }
}

function cancelPlaneSelection(): void {
  awaitingSketchPlane = false;
  pendingPartName = null;
  selectedSketchPlane = null;
  setStatus("Sketch creation cancelled.");
  updateLists();
}

async function createBlankPart(name:string):Promise<void>{
 try{
  if(hostedCAD)detachHostedFile();activeWorkspaceKind='part';cadPresentation.patch({startScreen:'workspace',startDialog:null,workspaceMode:'modeling'});
  const doc=createEmptyPartDocument(name);await evaluateAndShowPart(doc,'Created an empty Part. Add a sketch profile to begin.');
  if(activePartDocument!==doc)throw new Error(cadPresentation.snapshot().statusMessage);
  if(hostedCAD){await saveHostedFile(doc.name+'.acpart',new TextEncoder().encode(serializePartDocument(doc)));setStatus('Created '+doc.name+' on your server. Add a sketch profile to begin.','success');}
 }catch(e){setStatus((e as Error).message,'error');}
}

cadCommands.register("new-part", () => createBlankPart(`Part ${untitledPartNumber++}`));
cadCommands.register("open-part", () => hostedCAD ? location.assign("/cad/") : partPicker.click());
cadCommands.register("insert-step", () => picker.click());
cadCommands.register("sketch", () => { cadCommands.execute("feature-profile"); });

cadCommands.register("rebuild-part", async () => {
  try {
    if(activePartDocument && !activePartDocument.features.some(f=>f.type==="sketch")){await evaluateAndShowPart(activePartDocument,"Rebuilt feature history.");return;}
    const document = activePartDocument
      ? reviseRectanglePartDocument(
          activePartDocument,
          partNameInput.value,
          readPartParameters(),
        )
      : createRectanglePartDocument(partNameInput.value, readPartParameters());
    await evaluateAndShowPart(
      document,
      activePartDocument ? `Rebuilt ${document.name}.` : `Created ${document.name}.`,
    );
  } catch (error) {
    setStatus(error instanceof Error ? error.message : String(error), "error");
  }
});

partPicker.addEventListener("change", async () => {
  const file = partPicker.files?.[0];
  if (!file) return;
  try {
    activeWorkspaceKind = "part";
    const document = parsePartDocument(await file.text());
    if (hostedCAD) detachHostedFile();
    await evaluateAndShowPart(document, `Opened ${file.name}.`);
  } catch (error) {
    setStatus(error instanceof Error ? error.message : String(error), "error");
  } finally {
    partPicker.value = "";
  }
});

assemblyPicker.addEventListener("change", async () => {
  const file = assemblyPicker.files?.[0];
  if (!file) return;
  try {
    await assemblyController.openFile(file);
  } catch {
    // The controller publishes the typed Core error to the shared status surface.
  } finally {
    assemblyPicker.value = "";
  }
});

configureDocumentPrint(() => viewer.capturePrintImage());

// Continuous saving: every edit autosaves as a revision. The command is a
// PDM Commit — it flushes the autosave and names an annotated checkpoint.
if (hostedCAD) configureAutosave(async () => {
  if (!activePartDocument) return;
  try {
    await saveHostedFile(`${activePartDocument.name}.acpart`, new TextEncoder().encode(serializePartDocument(activePartDocument)));
    setStatus("All changes saved.");
  } catch (error) {
    setStatus(error instanceof Error ? error.message : String(error), "error");
  }
});
cadCommands.register("save-part", async () => {
  // Save persists the working state (VS Code ⌘S); it never prompts. Commits
  // are the separate, deliberate checkpoints.
  if (!activePartDocument) return;
  try {
    const fileName = `${activePartDocument.name}.acpart`;
    if (hostedCAD) await saveHostedFile(fileName, new TextEncoder().encode(serializePartDocument(activePartDocument)));
    else await savePartDocument(activePartDocument);
    setStatus(`Saved ${fileName}${hostedCAD ? " to your server" : ""}; editable feature history preserved.`, "success");
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") return;
    setStatus(error instanceof Error ? error.message : String(error), "error");
  }
});
cadCommands.register("commit-part", async () => {
  if (!activePartDocument || !hostedCAD) return;
  try {
    await flushAutosaveNow();
    const name = prompt("Commit name", `${activePartDocument.name} — ${new Date().toLocaleDateString()}`);
    if (!name?.trim()) return;
    const message = prompt("Commit message (optional)", "") ?? "";
    await commitHosted(name.trim(), message.trim());
    setStatus(`Committed "${name.trim()}"; the checkpoint is listed in Version control.`, "success");
  } catch (error) {
    setStatus(error instanceof Error ? error.message : String(error), "error");
  }
});

function toggleTool(tool: AuthoringTool): void {
  viewer.setTool(viewer.activeTool === tool ? "none" : tool);
  updateLists();
}

cadCommands.register("connector", () => toggleTool("connector"));
cadCommands.register("fastened", () => toggleTool("fastened"));
cadCommands.register("fit-view", () => viewer.frameAll());
cadCommands.register("view-top", () => viewer.setCameraView("top"));
cadCommands.register("view-bottom", () => viewer.setCameraView("bottom"));
cadCommands.register("view-front", () => viewer.setCameraView("front"));
cadCommands.register("view-back", () => viewer.setCameraView("back"));
cadCommands.register("view-right", () => viewer.setCameraView("right"));
cadCommands.register("view-left", () => viewer.setCameraView("left"));
cadCommands.register("view-isometric", () => viewer.setCameraView("isometric"));
const registerDisplayStyle = (command: Parameters<typeof cadCommands.register>[0], style: CADDisplayStyle) =>
  cadCommands.register(command, () => cadAppearance.dispatch({ type: "set-display-style", style }));
registerDisplayStyle("display-shaded", "shaded");
registerDisplayStyle("display-shaded-edges", "shaded-edges");
registerDisplayStyle("display-wireframe", "wireframe");
registerDisplayStyle("display-hidden-line", "hidden-line");
registerDisplayStyle("display-ghost", "ghost");
const registerLightingPreset = (command: Parameters<typeof cadCommands.register>[0], preset: CADLightingPreset) =>
  cadCommands.register(command, () => cadAppearance.dispatch({ type: "set-lighting-preset", preset }));
registerLightingPreset("lighting-studio", "studio");
registerLightingPreset("lighting-softbox", "softbox");
registerLightingPreset("lighting-daylight", "daylight");
registerLightingPreset("lighting-dark-room", "dark-room");
const registerBackground = (command: Parameters<typeof cadCommands.register>[0], background: CADBackgroundPreset) =>
  cadCommands.register(command, () => cadAppearance.dispatch({ type: "set-background", background }));
registerBackground("background-graphite", "graphite");
registerBackground("background-midnight", "midnight");
registerBackground("background-cad-light", "cad-light");
registerBackground("background-blueprint", "blueprint");
const registerMaterialFinish = (command: Parameters<typeof cadCommands.register>[0], finish: CADMaterialFinish) =>
  cadCommands.register(command, () => cadAppearance.dispatch({ type: "set-material-finish", finish }));
registerMaterialFinish("finish-matte", "matte");
registerMaterialFinish("finish-satin", "satin");
registerMaterialFinish("finish-gloss", "gloss");
const registerGroundMode = (command: Parameters<typeof cadCommands.register>[0], mode: CADFloorMode) =>
  cadCommands.register(command, () => cadAppearance.dispatch({ type: "set-floor-mode", mode }));
registerGroundMode("ground-none", "none");
registerGroundMode("ground-grid", "grid");
registerGroundMode("ground-floor", "floor");
registerGroundMode("ground-both", "both");
cadCommands.register("toggle-contact-shadows", () => {
  cadAppearance.dispatch({
    type: "set-contact-shadows-visible",
    visible: !cadAppearance.snapshot().contactShadowsVisible,
  });
});
cadCommands.register("toggle-feature-edges", () => {
  cadAppearance.dispatch({
    type: "set-edges-visible",
    visible: !cadAppearance.snapshot().edgesVisible,
  });
});
cadCommands.register("reset-appearance", () => cadAppearance.dispatch({ type: "reset" }));
const registerSelectionFilter = (command: Parameters<typeof cadCommands.register>[0], filter: CADSelectionFilter) =>
  cadCommands.register(command, () => cadSelection.dispatch({ type: "set-filter", filter }));
registerSelectionFilter("selection-auto", "auto");
registerSelectionFilter("selection-component", "component");
registerSelectionFilter("selection-body", "body");
registerSelectionFilter("selection-face", "face");
registerSelectionFilter("selection-edge", "edge");
registerSelectionFilter("selection-vertex", "vertex");
cadCommands.register("selection-next-filter", () => {
  const index = selectionFilters.indexOf(cadSelection.snapshot().filter);
  const filter = selectionFilters[(index + 1) % selectionFilters.length];
  cadSelection.dispatch({ type: "set-filter", filter });
  setStatus(`Selection filter: ${filter}.`);
});
syncSelectionPresentation();
cadCommands.register("clear-mates", () => {
  mates.splice(0);
  viewer.clearMates();
  updateLists();
});
window.addEventListener("keydown", (event) => {
  const target = event.target as HTMLElement | null;
  const isEditingText =
    target instanceof HTMLInputElement ||
    target instanceof HTMLTextAreaElement ||
    target?.isContentEditable === true;
  if (isEditingText) return;
  if (event.key === "F6") {
    event.preventDefault();
    cadCommands.execute("selection-next-filter");
  }
  if (event.key.toLowerCase() === "f") cadCommands.execute("fit-view");
  if (event.key === " " && !document.querySelector(".cad-sketch-workspace")) {
    // Spacebar: SolidWorks-style orientation box around the bodies —
    // click a face to look from that side. Space again or Esc closes.
    event.preventDefault();
    viewer.toggleOrientationBox();
  }
  if (event.key === "Escape") viewer.hideOrientationBox();
  if (event.key.toLowerCase() === "r" && !sketchEditor?.active) {
    event.preventDefault();
    cadCommands.execute("sketch");
  }
  if (event.key === "Escape" && awaitingSketchPlane) cancelPlaneSelection();
  if (event.key === "Escape" && viewer.activeTool !== "none") viewer.setTool("none");
});

updateLists();

// A library URL opens its document only after the CAD worker is ready.
if (hostedCAD) {
  void worker.ready.then(async () => {
    const file = await loadHostedFile();
    if (file) {
      cadPresentation.patch({ startScreen: "workspace", startDialog: null });
      if (isPartFile(file.name)) {
        activeWorkspaceKind = "part";
        await evaluateAndShowPart(parsePartDocument(await file.text()), `Opened ${file.name} from your server.`);
      } else if (isProjectFile(file.name)) {
        await assemblyController.openFile(file);
        const assemblyId=new URLSearchParams(location.search).get("assembly");
        if(assemblyId)await assemblyController.selectProjectAssembly(assemblyId);
      } else if (/\.(step|stp)$/i.test(file.name)) {
        const transfer = new DataTransfer(); transfer.items.add(file);
        picker.files = transfer.files; picker.dispatchEvent(new Event("change"));
      } else throw new Error("This file type cannot be opened in CAD.");
      markHostedClean();
      mountProjectTabs();

    } else if (new URLSearchParams(location.search).get("new") === "part") {
      cadPresentation.patch({ startScreen: "workspace", startDialog: "new-workspace" });
    }
  }).catch(error => setStatus(error instanceof Error ? error.message : String(error), "error"));
}

let assemblyRenderSerial=0;
async function renderCanonicalAssembly():Promise<void>{
 const serial=++assemblyRenderSerial;
 const projection=assemblyController.geometryProjection;if(!projection)return;
 try{
  const bodies=[];
  for(const instance of projection.instances){
   if(instance.suppressed||!instance.visible)continue;
   const definition=projection.part_definitions.find(p=>p.id===instance.definition_id);
   if(!definition?.feature_document)continue;
   const doc=parsePartDocument(JSON.stringify(definition.feature_document));
   if(!doc.features.some(f=>f.type==='extrude'||f.type==='revolve'))continue;
   const model=await worker.evaluatePart(doc);const transform=instance.solved_world_transform;
   for(const body of model.parts)if(doc.bodyProperties?.[body.id]?.visible!==false)bodies.push({data:{...body,id:'assembly:'+instance.id+':'+body.id,name:instance.name+' · '+body.name},positionMillimeters:transform.position_m.map(v=>v*1000),quaternion:transform.rotation_quaternion_xyzw});
  }
  if(serial!==assemblyRenderSerial)return;
  viewer.replaceAssemblyBodies(bodies);viewer.frameAll();
 }catch(e){setStatus('Assembly geometry: '+(e as Error).message,'error');}
}

mountFeatureAuthoring(()=>activePartDocument,async doc=>{
 await evaluateAndShowPart(doc,"Feature history updated.");
 if(activePartDocument!==doc)throw new Error(cadPresentation.snapshot().statusMessage);
});

// Point and edge picks for the plane methods that need them (Three point,
// Angle). Selection already produces vertex/edge items; this hands back their
// exact topology geometry so a feature can store the reference.
window.addEventListener("aether-plane-geometry-request", () => {
  window.dispatchEvent(new CustomEvent("aether-plane-geometry", {
    detail: { points: viewer.selectedPoints(), axis: viewer.selectedAxis() },
  }));
});

window.addEventListener("aether-sketch-face-request", () => {
  const frame = viewer.selectedSketchFrame();
  // Carry WHICH face was picked, not only its frame: a sketch needs the frame,
  // but a plane feature stores the reference so the tree can name it.
  const face = viewer.selectedFaceIdentity();
  window.dispatchEvent(new CustomEvent("aether-sketch-face", {detail: frame ? {frame, ...face} : {error:"Select a flat face first. Curved surfaces cannot support a planar sketch."}}));
});
for (const tool of ["select", "line", "arc", "circle", "rectangle", ...sketchVariantTools, ...contextualDrawingTools, ...modificationTools,...directModificationTools] as const) {
  cadCommands.register(`sketch-${tool}`, () => { window.dispatchEvent(new CustomEvent("aether-sketch-tool", {detail:tool})); });
  cadCommands.setEnabled(`sketch-${tool}`, false);
}
window.addEventListener("aether-sketch-editing", event => {
  const detail = (event as CustomEvent).detail as typeof draftSketch;
  draftSketch = detail;
  viewer.setEditingSketch(detail?.id ?? null);
  updateLists();
});
window.addEventListener("aether-sketch-mode", event => {
  const active=Boolean((event as CustomEvent).detail);
  for(const tool of ["select", "line", "arc", "circle", "rectangle", ...sketchVariantTools, ...contextualDrawingTools, ...modificationTools,...directModificationTools] as const) cadCommands.setEnabled(`sketch-${tool}`, active);
});

window.addEventListener("aether-sketch-surface", event => {
  const detail = (event as CustomEvent).detail;
  if (!detail?.svg || !detail.frame || typeof detail.connect !== "function") return;
  viewer.beginSketchSurface(detail.frame, detail.svg, detail.bounds);
  detail.connect({
    toSketch: (clientX: number, clientY: number) => viewer.sketchPointFromClient(clientX, clientY),
    scaleAt: (clientX?: number, clientY?: number) => viewer.sketchScaleAt(clientX, clientY),
    updateBounds: (bounds: { x: number; y: number; width: number; height: number }) =>
      viewer.updateSketchSurfaceBounds(bounds),
  });
});
window.addEventListener("aether-sketch-surface-end", () => viewer.endSketchSurface());

// Live plane preview: the plane feature already exists in the document, so its
// window moves the real construction plane as references are picked instead of
// leaving the viewport showing the seeded definition until commit.
// Orange = selected, everywhere. A feature window says what it is using; the
// viewport highlights exactly that.
window.addEventListener("aether-plane-highlight", event => {
  const detail = (event as CustomEvent).detail;
  if (Array.isArray(detail?.references)) viewer.setHighlightedPlanes(detail.references);
});
window.addEventListener("aether-plane-preview", event => {
  const detail = (event as CustomEvent).detail;
  if (typeof detail?.featureId !== "string") return;
  viewer.setConstructionPlanePreview(detail.featureId, detail.frame ?? null);
});

window.addEventListener("aether-sketch-plane-selection", event => {
  const selecting=Boolean((event as CustomEvent).detail);
  viewer.setSketchPlaneSelection(selecting);
  if(selecting && !sketchPlaneVisibilityBefore){
    sketchPlaneVisibilityBefore={...referenceVisibility};
    for(const id of ["top-plane","front-plane","right-plane"] as const){referenceVisibility[id]=true;viewer.setReferenceGeometryVisibility(id,true);}
  }else if(!selecting && sketchPlaneVisibilityBefore){
    for(const id of ["top-plane","front-plane","right-plane"] as const){referenceVisibility[id]=sketchPlaneVisibilityBefore[id];viewer.setReferenceGeometryVisibility(id,referenceVisibility[id]);}
    sketchPlaneVisibilityBefore=null;
    persistReferenceVisibility();
  }
  updateLists();
});

for(const kind of sketchConstraintCommandKinds){
  cadCommands.register(`sketch-constraint-${kind}`,()=>{window.dispatchEvent(new CustomEvent("aether-sketch-constraint",{detail:kind}));});
  cadCommands.setEnabled(`sketch-constraint-${kind}`,false);
}
window.addEventListener("aether-sketch-mode",event=>{
  for(const kind of sketchConstraintCommandKinds)cadCommands.setEnabled(`sketch-constraint-${kind}`,Boolean((event as CustomEvent).detail));
});

// Reference-geometry visibility as commands: the camera + display panel
// toggles them and reads their state from the registry.
cadCommands.register("toggle-origin", () => toggleReferenceVisibility("origin"));
cadCommands.setActive("toggle-origin", referenceVisibility.origin);
// Push the restored preference into the viewer, which starts everything hidden.
for (const id of Object.keys(referenceVisibility) as ReferenceGeometryId[])
  viewer.setReferenceGeometryVisibility(id, referenceVisibility[id]);
cadCommands.register("toggle-axes", () => {});
cadCommands.setEnabled("toggle-axes", false);

registerSketchImportCommand();
registerSketchTextCommand();
