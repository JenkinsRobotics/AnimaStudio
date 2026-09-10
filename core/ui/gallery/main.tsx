import { StrictMode, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import "../tokens/tokens.css";
import "../src/widgets.css";
import "./gallery.css";
import {
  ToolIcon,
  toolIconNames,
  AetherIcon,
  aetherIconNames,
  Button,
  BottomPanel,
  Breadcrumbs,
  Checkbox,
  ColorField,
  CommandPalette,
  DataTable,
  Dialog,
  DockPanel,
  DocumentBar,
  DocumentTabs,
  EmptyState,
  ErrorState,
  FieldRow,
  FileField,
  IconButton,
  LayoutPresetButton,
  ListBox,
  MenuButton,
  NumberField,
  NotificationCenter,
  PanelPlacementMenu,
  PanelHeading,
  Popover,
  ProgressOverlay,
  PropertyGrid,
  RadioGroup,
  Rail,
  RailButton,
  Ribbon,
  RibbonGroup,
  RibbonTool,
  SelectField,
  SearchField,
  SegmentedControl,
  Slider,
  SplitPane,
  StatusBar,
  StatusDot,
  Tabs,
  TextField,
  Timeline,
  ToastStack,
  Tooltip,
  Tree,
  ViewportCanvas,
  ViewportNavigationCube,
  WorkspaceShell,
} from "../src/index";
import type {
  DataTableColumn,
  DataTableSort,
  DocumentTab,
  LayoutPreset,
  ListBoxItem,
  NotificationItem,
  PanelPlacement,
  TreeNode,
} from "../src/index";

// The UIDev-style widget gallery: every shared widget on one page, with
// live state, so design changes are reviewed here before any app ships
// them. `npm run gallery` serves it.

const sampleTree: TreeNode[] = [
  {
    id: "instances",
    label: "Instances",
    badge: "3",
    icon: "▣",
    children: [
      {
        id: "base", label: "base", icon: "▫",
        actions: [{ id: "hide", label: "Hide", icon: "👁" }],
      },
      { id: "yoke", label: "yoke", icon: "▫" },
      { id: "head", label: "head (suppressed)", icon: "▫", dimmed: true },
    ],
  },
  {
    id: "mates",
    label: "Mate features",
    badge: "2",
    icon: "⛓",
    children: [
      { id: "pan", label: "pan · revolute", icon: "↻" },
      { id: "tilt", label: "tilt · revolute", icon: "↻" },
    ],
  },
];

const sampleMaterials: ListBoxItem[] = [
  { id: "al-6061", label: "Aluminum 6061", description: "2.70 g/cm³", icon: "◆", group: "Metals", badge: "Used" },
  { id: "steel", label: "Mild steel", description: "7.85 g/cm³", icon: "◆", group: "Metals" },
  { id: "titanium", label: "Titanium", description: "Library unavailable", icon: "◆", group: "Metals", disabled: true },
  { id: "abs", label: "ABS", description: "Injection molded", icon: "◇", group: "Polymers" },
  { id: "nylon", label: "Nylon", description: "Suppressed override", icon: "◇", group: "Polymers", dimmed: true },
];

const sampleConstraints: ListBoxItem[] = [
  { id: "coincident-1", label: "Coincident", description: "Point 1 · Origin", icon: "●", badge: "Fixed" },
  { id: "horizontal-1", label: "Horizontal", description: "Line 1", icon: "—" },
  {
    id: "distance-1",
    label: "Distance · 60 mm",
    description: "Line 1",
    icon: "↔",
    actions: [{ id: "edit", label: "Edit dimension", icon: "✎" }],
  },
];

const galleryTreeInitial: TreeNode[] = [
  ...sampleTree.map((node) =>
    node.id !== "instances"
      ? node
      : {
          ...node,
          children: node.children?.map((child) =>
            child.id === "yoke"
              ? {
                  ...child,
                  actions: [{ id: "rename", label: "Rename", icon: "✎" }],
                }
              : child
          ),
        }
  ),
  { id: "linked", label: "Linked components", icon: "↗", childrenLoading: true },
  { id: "unavailable", label: "Offline library", icon: "◇", childrenError: "Connection unavailable" },
];

const largeAssemblyTree: TreeNode[] = Array.from({ length: 1200 }, (_, index) => ({
  id: `assembly-node-${index}`,
  label: `Component ${String(index + 1).padStart(4, "0")}`,
  icon: "▫",
}));

function renameTreeNode(
  nodes: readonly TreeNode[],
  id: string,
  label: string
): TreeNode[] {
  return nodes.map((node) => ({
    ...node,
    label: node.id === id ? label : node.label,
    children: node.children ? renameTreeNode(node.children, id, label) : undefined,
  }));
}

interface BomRow { id: string; item: string; quantity: number; material: string }
const initialBomRows: BomRow[] = Array.from({ length: 140 }, (_, index) => ({
  id: `bom-${index}`,
  item: index === 0 ? "Yoke bracket" : `Component ${String(index + 1).padStart(3, "0")}`,
  quantity: (index % 4) + 1,
  material: index % 3 === 0 ? "Aluminum 6061" : index % 3 === 1 ? "ABS" : "Steel",
}));
const bomColumns: DataTableColumn<BomRow>[] = [
  { id: "item", header: "Item", cell: (row) => row.item, sortValue: (row) => row.item, editValue: (row) => row.item, editable: true, sortable: true, resizable: true, reorderable: true, pinned: true, width: 170 },
  { id: "quantity", header: "Qty", cell: (row) => row.quantity, sortValue: (row) => row.quantity, sortable: true, resizable: true, reorderable: true, width: 65, align: "end" },
  { id: "material", header: "Material", cell: (row) => row.material, sortValue: (row) => row.material, sortable: true, resizable: true, reorderable: true, width: 130 },
];

interface ProblemRow { id: string; severity: string; message: string }
const problemRows: ProblemRow[] = [
  { id: "p1", severity: "Error", message: "Extrude profile is unavailable" },
  { id: "p2", severity: "Warning", message: "Linked component is out of date" },
  { id: "p3", severity: "Info", message: "3 suppressed constraints" },
];
const problemColumns: DataTableColumn<ProblemRow>[] = [
  { id: "severity", header: "Level", cell: (row) => row.severity, sortValue: (row) => row.severity, sortable: true, width: 80 },
  { id: "message", header: "Message", cell: (row) => row.message, sortValue: (row) => row.message, sortable: true, width: 240 },
];

const modelCommands = [
  { id: "new-sketch", label: "New sketch", category: "Create", description: "Start on the selected plane", shortcut: "S", recent: true, icon: "⌁" },
  { id: "extrude", label: "Extrude profile", category: "Create", keywords: ["push pull solid"], shortcut: "E", icon: "▰" },
  { id: "rename", label: "Rename component", category: "Edit", argument: { label: "Component name", placeholder: "New name", required: true, submitLabel: "Rename", help: "Names are unique within the parent assembly." }, icon: "✎" },
  { id: "measure", label: "Measure selection", category: "Inspect", disabled: true, disabledReason: "Select two geometric entities.", shortcut: "M", icon: "↔" },
  { id: "fit", label: "Fit view", category: "View", shortcut: "F", recent: true, icon: "⌖" },
] as const;

const animationCommands = [
  { id: "add-key", label: "Add keyframe", category: "Animate", shortcut: "K", recent: true, icon: "◆" },
  { id: "select-track", label: "Select track", category: "Navigate", keywords: ["channel joint"], argument: { label: "Track name", placeholder: "Search tracks", required: true, submitLabel: "Select" }, icon: "≡" },
  { id: "loop", label: "Toggle loop playback", category: "Transport", shortcut: "L", icon: "↻" },
  { id: "send", label: "Send to hardware", category: "Output", disabled: true, disabledReason: "Connect and arm an output device.", icon: "⇢" },
  { id: "play", label: "Play or pause", category: "Transport", shortcut: "Space", recent: true, icon: "▶" },
] as const;

const cadDocuments: DocumentTab[] = [
  { id: "assembly", label: "Atlas Assembly", pinned: true },
  { id: "bracket", label: "Jaw Bracket", dirty: true },
  { id: "drawing", label: "Head Layout", preview: true },
  { id: "reference", label: "Imported Reference", disabled: true },
];
const animationDocuments: DocumentTab[] = [
  { id: "scene", label: "Main Scene", dirty: true },
  { id: "walk", label: "Walk Cycle" },
  { id: "jaw", label: "Jaw Performance", preview: true },
  { id: "output", label: "Output Mapping" },
  { id: "diagnostics", label: "Diagnostics" },
];
const initialCadNotifications: NotificationItem[] = [
  { id: "cad-save", kind: "success", title: "Part saved", message: "Jaw Bracket is current.", timestamp: "Now", actionLabel: "Show" },
  { id: "cad-link", kind: "warning", title: "Linked source changed", message: "Review before rebuilding.", timestamp: "1 min", persistent: true },
  { id: "cad-import", kind: "progress", title: "Importing assembly", message: "Resolving exact topology.", progress: 58, timestamp: "Now", persistent: true },
];
const initialAnimationNotifications: NotificationItem[] = [
  { id: "anim-output", kind: "error", title: "Output disconnected", message: "Playback remains in preview.", timestamp: "Now", actionLabel: "Reconnect" },
  { id: "anim-bake", kind: "success", title: "Clip baked", message: "240 evaluated frames are ready.", timestamp: "4 min", read: true },
];

function reorderDocuments<T extends { id: string }>(items: readonly T[], sourceID: string, targetID: string): T[] {
  const source = items.findIndex((item) => item.id === sourceID);
  const target = items.findIndex((item) => item.id === targetID);
  if (source < 0 || target < 0) return [...items];
  const next = [...items];
  const [moved] = next.splice(source, 1);
  if (moved) next.splice(target, 0, moved);
  return next;
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section data-gallery-section={title} style={{ display: "grid", gap: 10, minWidth: 0, maxWidth: "calc(100vw - 48px)" }}>
      <h2
        style={{
          margin: 0,
          color: "var(--aether-color-text-dim)",
          font: "750 11px var(--aether-font-family)",
          letterSpacing: "var(--aether-font-letter-caps)",
          textTransform: "uppercase",
        }}
      >
        {title}
      </h2>
      <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-start", gap: 12, minWidth: 0, maxWidth: "100%" }}>
        {children}
      </div>
    </section>
  );
}

function WorkspaceDemo() {
  // Deep link for design review: gallery/#layout=floating|docked|canvas
  const [preset, setPreset] = useState<LayoutPreset>(() => {
    const requested = new URLSearchParams(location.hash.slice(1)).get("layout");
    return requested === "floating" || requested === "canvas"
      ? requested
      : "docked";
  });
  const [tab, setTab] = useState("modeling");
  const [tool, setTool] = useState<string | null>("revolute");
  const [selection, setSelection] = useState<ReadonlySet<string>>(new Set(["yoke"]));

  const toolbar = (
    <Ribbon>
      <RibbonGroup label="Mate">
        {["fastened", "revolute", "slider"].map((id) => (
          <RibbonTool
            key={id}
            icon={id === "revolute" ? "↻" : id === "slider" ? "↔" : "▣"}
            label={id[0].toUpperCase() + id.slice(1)}
            active={tool === id}
            onClick={() => setTool(tool === id ? null : id)}
          />
        ))}
      </RibbonGroup>
    </Ribbon>
  );

  return (
    <div
      style={{
        width: "100%",
        height: 620,
        border: "1px solid var(--aether-color-border)",
        borderRadius: 8,
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
      }}
    >
      <DocumentBar windowChrome={false}
        leading={
          <>
            <IconButton label="Home">⌂</IconButton>
            <strong style={{ fontSize: 12 }}>demo_project</strong>
            <span style={{ color: "var(--aether-color-ok)", fontSize: 10 }}>
              SAVED
            </span>
          </>
        }
        center={
          <Tabs
            tabs={[
              { id: "assets", label: "Assets" },
              { id: "modeling", label: "3D Modeling" },
              { id: "animate", label: "Animate" },
            ]}
            activeID={tab}
            onSelect={setTab}
          />
        }
        trailing={<><LayoutPresetButton preset={preset} onChange={setPreset} /><div data-aether-account="" /></>}
      />
      <WorkspaceShell
        preset={preset}
        style={{ flex: 1, minHeight: 0 }}
        toolbar={toolbar}
        leftPanels={[
          {
            id: "parts",
            title: "Parts",
            icon: "▣",
            content: (
              <Tree
                nodes={sampleTree}
                selectedIDs={selection}
                onSelect={(ids) => setSelection(new Set(ids))}
              />
            ),
          },
          {
            id: "mates",
            title: "Mates",
            icon: "⛓",
            content: (
              <div style={{ padding: 12, fontSize: 11, color: "var(--aether-color-text-dim)" }}>
                pan · revolute
                <br />
                tilt · revolute
              </div>
            ),
          },
        ]}
        rightPanels={[
          {
            id: "inspector",
            title: "Inspector",
            icon: "☰",
            content: (
              <div style={{ display: "grid", gap: 8, padding: 12 }}>
                <TextField unit="mm" defaultValue="12.5" />
                <TextField unit="deg" defaultValue="30" />
              </div>
            ),
          },
        ]}
        defaultOpenLeft={["parts"]}
        defaultOpenRight={["inspector"]}
        statusBar={
          <StatusBar>
            <StatusDot kind="ok" />
            Engine ready · layout: {preset}
          </StatusBar>
        }
      >
        <div
          style={{
            display: "grid",
            placeItems: "center",
            height: "100%",
            color: "var(--aether-color-text-faint)",
            fontSize: 12,
          }}
        >
          viewport canvas — flip the layout with the ❏/▥/⛶ button above
        </div>
      </WorkspaceShell>
    </div>
  );
}

function TimelineDemo() {
  const [timeS, setTimeS] = useState(0.8);
  const [playing, setPlaying] = useState(false);
  const [selected, setSelected] = useState<{ trackID: string; index: number } | null>(null);
  return (
    <div style={{ width: 640, border: "1px solid var(--aether-color-border)", borderRadius: 8, overflow: "hidden" }}>
      <Timeline
        tracks={[
          { id: "pan", label: "pan.rotation", keyframes: [{ timeS: 0 }, { timeS: 1 }, { timeS: 2 }] },
          { id: "tilt", label: "tilt.rotation", keyframes: [{ timeS: 0 }, { timeS: 0.5 }, { timeS: 2 }] },
          { id: "jaw", label: "jaw.open", keyframes: [{ timeS: 0.25 }, { timeS: 1.4 }] },
        ]}
        durationS={2}
        timeS={timeS}
        onSeek={setTimeS}
        playing={playing}
        onTogglePlay={() => setPlaying((current) => !current)}
        selected={selected}
        onSelectKeyframe={(trackID, index) => setSelected({ trackID, index })}
      />
    </div>
  );
}

function Gallery() {
  const [activeTab, setActiveTab] = useState("modeling");
  const [armedTool, setArmedTool] = useState<string | null>("revolute");
  const [activeRail, setActiveRail] = useState("tree");
  const [selection, setSelection] = useState<ReadonlySet<string>>(new Set(["yoke"]));
  const [galleryTreeNodes, setGalleryTreeNodes] = useState<readonly TreeNode[]>(galleryTreeInitial);
  const [renamingTreeID, setRenamingTreeID] = useState<string | null>(null);
  const [materialSelection, setMaterialSelection] = useState<ReadonlySet<string>>(new Set(["al-6061"]));
  const [constraintSelection, setConstraintSelection] = useState<ReadonlySet<string>>(new Set(["distance-1"]));
  const [bomRows, setBomRows] = useState<readonly BomRow[]>(initialBomRows);
  const [bomSelection, setBomSelection] = useState<ReadonlySet<string>>(new Set(["bom-0"]));
  const [bomSort, setBomSort] = useState<DataTableSort | null>({ columnID: "item", direction: "ascending" });
  const [bomFilter, setBomFilter] = useState("");
  const [problemSelection, setProblemSelection] = useState<ReadonlySet<string>>(new Set(["p1"]));
  const [propertyFilter, setPropertyFilter] = useState("");
  const [modifiedOnly, setModifiedOnly] = useState(false);
  const [splitSize, setSplitSize] = useState(240);
  const [splitCollapsed, setSplitCollapsed] = useState(false);
  const [bottomTab, setBottomTab] = useState("problems");
  const [bottomCollapsed, setBottomCollapsed] = useState(false);
  const [treeFilter, setTreeFilter] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [popoverOpen, setPopoverOpen] = useState(false);
  const [panelPlacement, setPanelPlacement] = useState<PanelPlacement>("docked");
  const [name, setName] = useState("my_robot");
  const [draftAngle, setDraftAngle] = useState(3);
  const [progressOpen, setProgressOpen] = useState(false);
  const [stateMessage, setStateMessage] = useState("No components yet");
  const [modelSearch, setModelSearch] = useState("");
  const [librarySearch, setLibrarySearch] = useState("aluminum");
  const [libraryScope, setLibraryScope] = useState("all");
  const [projectionStandard, setProjectionStandard] = useState("third");
  const [displayStyle, setDisplayStyle] = useState("shaded");
  const [environmentIntensity, setEnvironmentIntensity] = useState(70);
  const [bodyColor, setBodyColor] = useState("#2b9cf3");
  const [modelFiles, setModelFiles] = useState<readonly File[]>([]);
  const [channelMode, setChannelMode] = useState("position");
  const [interpolation, setInterpolation] = useState("smooth");
  const [cueIntensity, setCueIntensity] = useState(45);
  const [cueColor, setCueColor] = useState("#f59e0b");
  const [cueFiles, setCueFiles] = useState<readonly File[]>([]);
  const [modelPaletteOpen, setModelPaletteOpen] = useState(false);
  const [animationPaletteOpen, setAnimationPaletteOpen] = useState(false);
  const [paletteResult, setPaletteResult] = useState("No command chosen");
  const [cadTabs, setCadTabs] = useState(cadDocuments);
  const [cadActiveTab, setCadActiveTab] = useState("bracket");
  const [animationTabs, setAnimationTabs] = useState(animationDocuments);
  const [animationActiveTab, setAnimationActiveTab] = useState("scene");
  const [cadNotifications, setCadNotifications] = useState(initialCadNotifications);
  const [animationNotifications, setAnimationNotifications] = useState(initialAnimationNotifications);
  const [toastItems, setToastItems] = useState<readonly NotificationItem[]>([]);
  const popoverAnchorRef = useRef<HTMLButtonElement>(null);

  return (
    <main
      style={{
        minHeight: "100%",
        background: "var(--aether-color-bg-app)",
        color: "var(--aether-color-text)",
        fontFamily: "var(--aether-font-family)",
        padding: 24,
        display: "grid",
        gap: 26,
        alignContent: "start",
      }}
    >
      <Section title="Workspace shell — document bar, sidebars, floating panels, layout presets">
        <WorkspaceDemo />
      </Section>

      <Section title="Illustrated ribbon tools — Core assets">
        {(["dark", "light"] as const).map(theme => <div key={theme} data-aether-theme={theme}
          style={{background: theme === "light" ? "#f5f7fa" : "#202832", color: theme === "light" ? "#283949" : "#e1ebf4", padding: 16, borderRadius: 8, marginBottom: 12}}>
          <strong>{theme === "light" ? "Light" : "Dark"} palette</strong>
          <div style={{display: "flex", flexWrap: "wrap", gap: 16, marginTop: 12}}>
            {toolIconNames.map(name => <div key={name} style={{display: "grid", justifyItems: "center", gap: 6, width: 75, fontSize: 10}}>
              <ToolIcon name={name} /><span>{name}</span>
            </div>)}
          </div>
        </div>)}
      </Section>
      <Section title="Shared vector icons — core/assets/icons">
        <div style={{ display: "grid", width: "100%", gridTemplateColumns: "repeat(auto-fill, minmax(110px, 1fr))", gap: 12 }}>
          {aetherIconNames.map((name) => <div key={name} style={{ display: "grid", justifyItems: "center", gap: 8, padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 7 }}>
            <AetherIcon name={name} width={24} height={24} />
            <span style={{ color: "var(--aether-color-text-dim)", fontSize: 10 }}>{name}</span>
          </div>)}
        </div>
      </Section>
      <Section title="Buttons">
        <Button>Default</Button>
        <Button primary>Primary</Button>
        <Button active>Active</Button>
        <Button disabled>Disabled</Button>
        <IconButton label="Save">💾</IconButton>
        <IconButton label="Disabled" disabled>
          ⚙
        </IconButton>
      </Section>

      <Section title="Tabs">
        <Tabs
          tabs={[
            { id: "assets", label: "Assets" },
            { id: "modeling", label: "3D Modeling" },
            { id: "animate", label: "Animate" },
          ]}
          activeID={activeTab}
          onSelect={setActiveTab}
        />
      </Section>

      <Section title="Ribbon">
        <Ribbon>
          <RibbonGroup label="Mate">
            {["fastened", "revolute", "slider"].map((tool) => (
              <RibbonTool
                key={tool}
                icon={tool === "revolute" ? "↻" : tool === "slider" ? "↔" : "▣"}
                label={tool[0].toUpperCase() + tool.slice(1)}
                active={armedTool === tool}
                onClick={() => setArmedTool(armedTool === tool ? null : tool)}
              />
            ))}
          </RibbonGroup>
          <RibbonGroup label="Edit">
            <RibbonTool icon="✕" label="Remove" disabled onClick={() => {}} />
          </RibbonGroup>
        </Ribbon>
      </Section>

      <Section title="Rail + Dock panel + Tree">
        <div
          style={{
            display: "flex",
            height: 280,
            border: "1px solid var(--aether-color-border)",
            borderRadius: 8,
            overflow: "hidden",
          }}
        >
          <Rail>
            {[
              { id: "tree", glyph: "☰" },
              { id: "layers", glyph: "▤" },
            ].map((item) => (
              <RailButton
                key={item.id}
                label={item.id}
                active={activeRail === item.id}
                onClick={() => setActiveRail(item.id)}
              >
                {item.glyph}
              </RailButton>
            ))}
          </Rail>
          <DockPanel title="Items" width={230}>
            <div style={{ padding: "8px 10px" }}>
              <TextField
                placeholder="Filter"
                value={treeFilter}
                onChange={(event) => setTreeFilter(event.target.value)}
              />
            </div>
            <Tree
              nodes={galleryTreeNodes}
              selectedIDs={selection}
              filter={treeFilter}
              onSelect={(ids, mode) =>
                setSelection((current) => {
                  if (mode === "single") return new Set(ids);
                  if (mode === "range") return new Set(ids);
                  const next = new Set(current);
                  for (const id of ids) {
                    if (next.has(id)) next.delete(id);
                    else next.add(id);
                  }
                  return next;
                })
              }
              renamingID={renamingTreeID}
              onRename={(id, label) => {
                setGalleryTreeNodes((current) => renameTreeNode(current, id, label));
                setRenamingTreeID(null);
              }}
              onCancelRename={() => setRenamingTreeID(null)}
              onAction={(node, action) => {
                if (action === "rename") setRenamingTreeID(node);
              }}
              onMove={(source, target, position) =>
                setStateMessage(`Move requested: ${source} ${position} ${target}`)
              }
              onRetryChildren={(id) => setStateMessage(`Retry requested: ${id}`)}
              onActivate={(id) => console.log("activate", id)}
              onContextMenu={(id, x, y) => console.log("context", id, x, y)}
              emptyState="no matches"
            />
          </DockPanel>
          <div style={{ flex: 1, background: "var(--aether-color-bg-shell)" }}>
            <PanelHeading>Viewport placeholder</PanelHeading>
          </div>
        </div>
      </Section>

      <Section title="Large hierarchy windowing">
        <div style={{ width: 300, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <Tree
            ariaLabel="Large assembly"
            nodes={largeAssemblyTree}
            selectedIDs={selection}
            onSelect={(ids) => setSelection(new Set(ids))}
            virtualizeThreshold={1000}
            height={150}
          />
        </div>
      </Section>

      <Section title="Search fields + breadcrumbs">
        <div style={{ display: "grid", gap: 10, width: 360 }}>
          <Breadcrumbs
            ariaLabel="Assembly path"
            items={[{ id: "atlas", label: "Atlas" }, { id: "head", label: "Head Assembly" }, { id: "jaw", label: "Jaw Bracket" }]}
            onNavigate={(id) => setStateMessage(`Navigate to ${id}`)}
          />
          <SearchField
            value={modelSearch}
            onQueryChange={setModelSearch}
            ariaLabel="Search model"
            placeholder="Features, bodies, sketches"
            resultCount={galleryTreeNodes.filter((node) => node.label.toLocaleLowerCase().includes(modelSearch.toLocaleLowerCase())).length}
          />
        </div>
        <div style={{ display: "grid", gap: 10, width: 420 }}>
          <Breadcrumbs
            ariaLabel="Linked component path"
            maxVisible={3}
            items={[{ id: "workspace", label: "Atlas" }, { id: "robot", label: "Robot" }, { id: "head", label: "Head" }, { id: "jaw", label: "Jaw" }, { id: "bracket", label: "Bracket" }]}
            onNavigate={(id) => setStateMessage(`Navigate to ${id}`)}
          />
          <SearchField
            value={librarySearch}
            onQueryChange={setLibrarySearch}
            ariaLabel="Search library"
            scopes={[{ id: "all", label: "All" }, { id: "materials", label: "Materials" }, { id: "parts", label: "Parts" }]}
            scopeID={libraryScope}
            onScopeChange={setLibraryScope}
            resultCount={sampleMaterials.filter((item) => item.label.toLocaleLowerCase().includes(librarySearch.toLocaleLowerCase())).length}
          />
        </div>
      </Section>

      <Section title="Fields + Dialog">
        <TextField
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Assembly name"
          style={{ width: 200 }}
        />
        <TextField unit="mm" defaultValue="12.5" style={{ width: 110 }} />
        <TextField
          unit="deg"
          defaultValue="400"
          invalid
          title="Invalid: exceeds the joint limit"
          style={{ width: 110 }}
        />
        <Button primary onClick={() => setDialogOpen(true)}>
          Open dialog
        </Button>
        <Dialog
          open={dialogOpen}
          title="New assembly"
          onClose={() => setDialogOpen(false)}
          actions={
            <>
              <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
              <Button primary onClick={() => setDialogOpen(false)}>
                Create
              </Button>
            </>
          }
        >
          Name: {name || "(untitled)"}
        </Dialog>
      </Section>

      <Section title="Flat collections">
        <div style={{ width: 300, height: 230, overflow: "auto", border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <ListBox
            ariaLabel="Material library"
            items={sampleMaterials}
            selectedIDs={materialSelection}
            onSelect={(ids, mode) =>
              setMaterialSelection((current) => {
                if (mode !== "toggle") return new Set(ids);
                const next = new Set(current);
                for (const id of ids) next.has(id) ? next.delete(id) : next.add(id);
                return next;
              })
            }
            selectionMode="multiple"
          />
        </div>
        <div style={{ width: 300, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <ListBox
            ariaLabel="Sketch constraints"
            items={sampleConstraints}
            selectedIDs={constraintSelection}
            onSelect={(ids) => setConstraintSelection(new Set(ids))}
            onAction={(itemID, actionID) => console.log("constraint action", itemID, actionID)}
          />
        </div>
      </Section>

      <Section title="Authoring fields">
        <div style={{ display: "grid", gap: 10, width: 250, padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <strong style={{ fontSize: 11 }}>Feature dimensions</strong>
          <FieldRow label="Width" htmlFor="gallery-width" help="Expressions commit on Enter or blur.">
            <NumberField id="gallery-width" defaultValue={60} min={0.001} step={1} unit="mm" scrubLabel="Width" />
          </FieldRow>
          <FieldRow label="Draft angle" htmlFor="gallery-angle" modified={draftAngle !== 0} onReset={() => setDraftAngle(0)}>
            <NumberField id="gallery-angle" value={draftAngle} onCommit={setDraftAngle} min={-89} max={89} step={0.5} unit="deg" />
          </FieldRow>
        </div>
        <div style={{ display: "grid", gap: 10, width: 250, padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <strong style={{ fontSize: 11 }}>Document settings</strong>
          <FieldRow label="Display units" htmlFor="gallery-units">
            <SelectField
              id="gallery-units"
              defaultValue="mm"
              options={[
                { value: "mm", label: "Millimeters" },
                { value: "cm", label: "Centimeters" },
                { value: "in", label: "Inches" },
              ]}
            />
          </FieldRow>
          <Checkbox label="Construction" description="Exclude from solid profiles" />
          <Checkbox label="Visible across selection" indeterminate />
        </div>
      </Section>

      <Section title="Extended field family">
        <div style={{ display: "grid", flex: "0 0 330px", gap: 12, width: 330, maxWidth: "100%", padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <strong style={{ fontSize: 11 }}>Model and drawing properties</strong>
          <RadioGroup
            label="Projection standard"
            orientation="horizontal"
            options={[{ id: "first", label: "First angle" }, { id: "third", label: "Third angle", description: "ASME default" }]}
            value={projectionStandard}
            onChange={setProjectionStandard}
          />
          <FieldRow label="Display style">
            <SegmentedControl ariaLabel="Display style" options={[{ id: "shaded", label: "Shaded" }, { id: "edges", label: "Edges" }, { id: "wire", label: "Wire" }]} value={displayStyle} onChange={setDisplayStyle} />
          </FieldRow>
          <FieldRow label="Environment intensity">
            <Slider ariaLabel="Environment intensity" min={0} max={200} step={5} unit="%" value={environmentIntensity} onChange={setEnvironmentIntensity} />
          </FieldRow>
          <FieldRow label="Body color">
            <ColorField ariaLabel="Body color" value={bodyColor} onChange={setBodyColor} />
          </FieldRow>
          <FileField label="Model sources" accept=".step,.stp,.iges,.igs" multiple files={modelFiles} onFilesChange={setModelFiles} help="Exact CAD sources remain local until import is requested." />
        </div>
        <div style={{ display: "grid", flex: "0 0 330px", gap: 12, width: 330, maxWidth: "100%", padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <strong style={{ fontSize: 11 }}>Animation and hardware cue</strong>
          <RadioGroup
            label="Channel mode"
            options={[{ id: "position", label: "Position", description: "Evaluated target" }, { id: "velocity", label: "Velocity" }, { id: "disabled", label: "Unavailable input", disabled: true }]}
            value={channelMode}
            onChange={setChannelMode}
          />
          <FieldRow label="Interpolation">
            <SegmentedControl ariaLabel="Interpolation" options={[{ id: "step", label: "Step" }, { id: "linear", label: "Linear" }, { id: "smooth", label: "Smooth" }]} value={interpolation} onChange={setInterpolation} />
          </FieldRow>
          <FieldRow label="Cue intensity">
            <Slider ariaLabel="Cue intensity" min={0} max={100} unit="%" value={cueIntensity} onChange={setCueIntensity} />
          </FieldRow>
          <FieldRow label="Cue color">
            <ColorField ariaLabel="Cue color" value={cueColor} onChange={setCueColor} />
          </FieldRow>
          <FileField label="Cue sources" accept="audio/*,.csv" multiple files={cueFiles} onFilesChange={setCueFiles} help="Audio and channel maps use the same field behavior." />
        </div>
      </Section>

      <Section title="Tabular data">
        <div style={{ display: "grid", gap: 8, width: 440 }}>
          <TextField placeholder="Filter bill of materials" value={bomFilter} onChange={(event) => setBomFilter(event.target.value)} />
          <DataTable
            ariaLabel="Bill of materials"
            rows={bomRows}
            rowID={(row) => row.id}
            columns={bomColumns}
            selectedIDs={bomSelection}
            onSelect={(ids) => setBomSelection(new Set(ids))}
            sort={bomSort}
            onSortChange={setBomSort}
            filter={bomFilter}
            filterText={(row) => `${row.item} ${row.material}`}
            onEdit={(id, column, value) => {
              if (column === "item") setBomRows((current) => current.map((row) => row.id === id ? { ...row, item: value } : row));
            }}
            onColumnReorder={(source, target) => setStateMessage(`Column move requested: ${source} before ${target}`)}
            rowActions={() => [{ id: "open", label: "Open component", icon: "↗" }]}
            onRowAction={(id) => setStateMessage(`Open requested: ${id}`)}
            virtualizeThreshold={100}
            height={210}
          />
        </div>
        <div style={{ width: 360 }}>
          <DataTable
            ariaLabel="Problems"
            rows={problemRows}
            rowID={(row) => row.id}
            columns={problemColumns}
            selectedIDs={problemSelection}
            onSelect={(ids) => setProblemSelection(new Set(ids))}
            rowActions={() => [{ id: "reveal", label: "Reveal source", icon: "⌖" }]}
            onRowAction={(id) => setStateMessage(`Reveal requested: ${id}`)}
          />
        </div>
      </Section>

      <Section title="Property inspectors">
        <div style={{ display: "grid", gap: 8, width: 300, border: "1px solid var(--aether-color-border)", borderRadius: 8, overflow: "hidden" }}>
          <div style={{ display: "grid", gap: 6, padding: 8 }}>
            <TextField placeholder="Filter properties" value={propertyFilter} onChange={(event) => setPropertyFilter(event.target.value)} />
            <Checkbox label="Modified only" checked={modifiedOnly} onChange={(event) => setModifiedOnly(event.target.checked)} />
          </div>
          <PropertyGrid
            ariaLabel="Body inspector"
            filter={propertyFilter}
            modifiedOnly={modifiedOnly}
            sections={[
              {
                id: "dimensions",
                label: "Dimensions",
                badge: "3",
                properties: [
                  { id: "width", label: "Width", editor: <NumberField value={60} unit="mm" />, modified: true, onReset: () => {} },
                  { id: "height", label: "Height", editor: <NumberField value={40} unit="mm" /> },
                  { id: "depth", label: "Depth", editor: <NumberField value={20} unit="mm" />, help: "Normal to sketch plane" },
                ],
              },
              {
                id: "appearance",
                label: "Appearance",
                properties: [
                  { id: "material", label: "Material", editor: <SelectField defaultValue="al" options={[{ value: "al", label: "Aluminum 6061" }]} disabled />, readOnly: true },
                ],
              },
            ]}
          />
        </div>
        <div style={{ width: 300, border: "1px solid var(--aether-color-border)", borderRadius: 8, overflow: "hidden" }}>
          <PropertyGrid
            ariaLabel="Multi-selection inspector"
            sections={[
              {
                id: "selection",
                label: "2 selected components",
                properties: [
                  { id: "visibility", label: "Visible", editor: <Checkbox label="" indeterminate />, mixed: true },
                  { id: "material", label: "Material", editor: <SelectField placeholder="Multiple values" options={[]} />, mixed: true },
                  { id: "source", label: "Source", editor: "Linked definition", readOnly: true },
                ],
              },
            ]}
          />
        </div>
      </Section>

      <Section title="Resizable workspace + bottom panel">
        <div style={{ display: "grid", gridTemplateRows: "250px minmax(0, 1fr)", width: 780, height: 430, border: "1px solid var(--aether-color-border)", borderRadius: 8, overflow: "hidden" }}>
          <SplitPane
            primary={
              <div style={{ height: "100%", background: "var(--aether-color-bg-panel)" }}>
                <PanelHeading>Assembly navigator</PanelHeading>
                <Tree nodes={sampleTree} selectedIDs={selection} onSelect={(ids) => setSelection(new Set(ids))} />
              </div>
            }
            secondary={
              <div style={{ display: "grid", placeItems: "center", height: "100%", background: "var(--aether-color-bg-shell)", color: "var(--aether-color-text-faint)" }}>
                Persistent viewport
              </div>
            }
            primarySize={splitSize}
            onResize={setSplitSize}
            collapsed={splitCollapsed}
            onCollapsedChange={setSplitCollapsed}
            collapseSide="primary"
            separatorLabel="Resize assembly navigator"
          />
          <BottomPanel
            tabs={[
              { id: "problems", label: "Problems", badge: 3, content: <DataTable ariaLabel="Bottom problems" rows={problemRows} rowID={(row) => row.id} columns={problemColumns} selectedIDs={problemSelection} onSelect={(ids) => setProblemSelection(new Set(ids))} /> },
              { id: "history", label: "History", content: <ListBox ariaLabel="Rebuild history" items={[{ id: "h1", label: "Sketch 1" }, { id: "h2", label: "Extrude 1" }, { id: "h3", label: "Fillet 1", dimmed: true }]} selectedIDs={new Set(["h2"])} onSelect={() => {}} /> },
              { id: "console", label: "Console", badge: "•", content: <pre style={{ margin: 0, padding: 12, color: "var(--aether-color-text-dim)" }}>Kernel ready · exact topology cache warm</pre> },
              { id: "bom", label: "BOM", badge: 140, content: <div style={{ padding: 12 }}>140 component rows</div> },
              { id: "tasks", label: "Tasks", content: <EmptyState compact title="No background tasks" /> },
            ]}
            activeID={bottomTab}
            onSelect={setBottomTab}
            collapsed={bottomCollapsed}
            onCollapsedChange={setBottomCollapsed}
            actions={<Button onClick={() => setStateMessage("Panel content cleared")}>Clear</Button>}
          />
        </div>
      </Section>

      <Section title="Help + workflow states">
        <Tooltip content="Measure between selected geometric entities." shortcut="M">
          <Button>Measure</Button>
        </Tooltip>
        <div style={{ width: 280, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <EmptyState
            compact
            title={stateMessage}
            description="Insert a component or open a linked definition."
            icon="◇"
            primaryAction={<Button primary onClick={() => setStateMessage("Component insertion requested")}>Insert component</Button>}
          />
        </div>
        <div style={{ width: 280, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <ErrorState
            compact
            title="Rebuild failed"
            description="The selected profile is missing."
            detail="Extrude 3 · profile reference unavailable"
            retryAction={<Button onClick={() => setStateMessage("Rebuild retry requested")}>Retry</Button>}
          />
        </div>
        <Button onClick={() => setProgressOpen(true)}>Show import progress</Button>
        <ProgressOverlay
          open={progressOpen}
          label="Importing assembly"
          detail="Resolving exact topology and linked components."
          phase="2 of 4"
          value={48}
          onCancel={() => setProgressOpen(false)}
          onBackground={() => setProgressOpen(false)}
        />
      </Section>

      <Section title="Menus + Popover">
        <PanelPlacementMenu
          label="Inspector"
          placement={panelPlacement}
          onChange={(placement) => {
            setPanelPlacement(placement);
            setStateMessage(`Inspector placement: ${placement}`);
          }}
        />
        <MenuButton
          label="Object actions"
          items={[
            { id: "open", label: "Open", icon: "↗", shortcut: "↩" },
            { id: "rename", label: "Rename", icon: "✎", shortcut: "F2" },
            { id: "locked", label: "Delete", icon: "×", disabled: true, disabledReason: "The object is locked." },
            {
              id: "export",
              label: "Export",
              icon: "⇧",
              separatorBefore: true,
              children: [
                { id: "step", label: "STEP" },
                { id: "mesh", label: "Mesh" },
              ],
            },
          ]}
          onSelect={(id) => console.log("object command", id)}
        >
          Object •••
        </MenuButton>
        <MenuButton
          label="Viewport display"
          items={[
            { id: "edges", label: "Show edges", kind: "checkbox", checked: true },
            { id: "grid", label: "Show grid", kind: "checkbox", checked: false },
            { id: "reset", label: "Reset display", danger: true, separatorBefore: true },
          ]}
          onSelect={(id) => console.log("view command", id)}
        >
          View •••
        </MenuButton>
        <button
          ref={popoverAnchorRef}
          className="aui-button"
          type="button"
          onClick={() => setPopoverOpen((current) => !current)}
        >
          Quick properties
        </button>
        <Popover
          open={popoverOpen}
          anchor={popoverAnchorRef.current}
          onClose={() => setPopoverOpen(false)}
          ariaLabel="Quick properties"
          focus="first"
        >
          <div style={{ display: "grid", gap: 8, width: 220 }}>
            <strong>Placement</strong>
            <TextField unit="mm" defaultValue="12.5" />
            <Button onClick={() => setPopoverOpen(false)}>Apply</Button>
          </div>
        </Popover>
      </Section>

      <Section title="Command palettes">
        <div style={{ display: "grid", gap: 8, width: 280, padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <strong style={{ fontSize: 11 }}>Modeling commands</strong>
          <span style={{ color: "var(--aether-color-text-faint)", fontSize: 10 }}>Recents, categories, shortcuts, disabled reasons, and rename follow-up.</span>
          <Button onClick={() => setModelPaletteOpen(true)}>Open model commands…</Button>
        </div>
        <div style={{ display: "grid", gap: 8, width: 280, padding: 12, border: "1px solid var(--aether-color-border)", borderRadius: 8 }}>
          <strong style={{ fontSize: 11 }}>Animation commands</strong>
          <span style={{ color: "var(--aether-color-text-faint)", fontSize: 10 }}>A separate product dataset using the identical command surface.</span>
          <Button onClick={() => setAnimationPaletteOpen(true)}>Open animation commands…</Button>
        </div>
        <span style={{ alignSelf: "center", color: "var(--aether-color-text-dim)", fontSize: 10 }}>{paletteResult}</span>
        <CommandPalette
          open={modelPaletteOpen}
          commands={modelCommands}
          onClose={() => setModelPaletteOpen(false)}
          onSelect={(id, argument) => setPaletteResult(`Model command: ${id}${argument ? ` · ${argument}` : ""}`)}
          title="Model commands"
          placeholder="Search model commands"
        />
        <CommandPalette
          open={animationPaletteOpen}
          commands={animationCommands}
          onClose={() => setAnimationPaletteOpen(false)}
          onSelect={(id, argument) => setPaletteResult(`Animation command: ${id}${argument ? ` · ${argument}` : ""}`)}
          title="Animation commands"
          placeholder="Search animation commands"
        />
      </Section>

      <Section title="Document tabs">
        <div style={{ display: "grid", gap: 8, width: 760, maxWidth: "100%" }}>
          <strong style={{ fontSize: 11 }}>CAD documents</strong>
          <DocumentTabs
            tabs={cadTabs}
            activeID={cadActiveTab}
            onSelect={setCadActiveTab}
            onClose={(id) => setStateMessage(`Close requested: ${id}`)}
            onPinToggle={(id, pinned) => setCadTabs((current) => current.map((tab) => tab.id === id ? { ...tab, pinned } : tab))}
            onReorder={(source, target) => setCadTabs((current) => reorderDocuments(current, source, target))}
            onSplit={(id, direction) => setStateMessage(`Split requested: ${id} ${direction}`)}
          />
        </div>
        <div style={{ display: "grid", gap: 8, width: 520, maxWidth: "100%" }}>
          <strong style={{ fontSize: 11 }}>Animation documents with overflow</strong>
          <DocumentTabs
            tabs={animationTabs}
            activeID={animationActiveTab}
            maxVisible={3}
            onSelect={setAnimationActiveTab}
            onClose={(id) => setStateMessage(`Close requested: ${id}`)}
            onReorder={(source, target) => setAnimationTabs((current) => reorderDocuments(current, source, target))}
            onSplit={(id, direction) => setStateMessage(`Split requested: ${id} ${direction}`)}
          />
        </div>
      </Section>

      <Section title="Toasts + notification history">
        <div style={{ display: "grid", gap: 8, width: 430, maxWidth: "100%" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}><strong style={{ fontSize: 11 }}>CAD activity</strong><Button onClick={() => setToastItems(initialCadNotifications)}>Show CAD toasts</Button></div>
          <NotificationCenter
            items={cadNotifications}
            ariaLabel="CAD notification history"
            onAction={(id) => setStateMessage(`Notification action: ${id}`)}
            onMarkRead={(id) => setCadNotifications((current) => current.map((item) => item.id === id ? { ...item, read: true } : item))}
            onDismiss={(id) => setCadNotifications((current) => current.filter((item) => item.id !== id))}
            onClear={() => setCadNotifications([])}
          />
        </div>
        <div style={{ display: "grid", gap: 8, width: 430, maxWidth: "100%" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}><strong style={{ fontSize: 11 }}>Animation activity</strong><Button onClick={() => setToastItems(initialAnimationNotifications)}>Show animation toasts</Button></div>
          <NotificationCenter
            items={animationNotifications}
            ariaLabel="Animation notification history"
            onAction={(id) => setStateMessage(`Notification action: ${id}`)}
            onMarkRead={(id) => setAnimationNotifications((current) => current.map((item) => item.id === id ? { ...item, read: true } : item))}
            onDismiss={(id) => setAnimationNotifications((current) => current.filter((item) => item.id !== id))}
            onClear={() => setAnimationNotifications([])}
          />
        </div>
        <ToastStack
          items={toastItems}
          onAction={(id) => setStateMessage(`Toast action: ${id}`)}
          onDismiss={(id) => setToastItems((current) => current.filter((item) => item.id !== id))}
        />
      </Section>

      <Section title="Timeline (dope sheet)">
        <TimelineDemo />
      </Section>

      <Section title="Status bar">
        <div style={{ width: 420 }}>
          <StatusBar>
            <StatusDot kind="ok" />
            Engine ready · 26 parts · 0 mates
          </StatusBar>
        </div>
      </Section>

      <Section title="Viewport navigation cube">
        <div
          style={{
            position: "relative",
            width: 420,
            height: 190,
            maxWidth: "100%",
            borderRadius: 8,
            overflow: "hidden",
            background: "var(--aether-color-bg-shell)",
          }}
        >
          <ViewportNavigationCube
            orientation={[0.12, 0.34, 0.04, 0.93]}
            onSelectView={(view) => setStateMessage(`Standard view: ${view}`)}
            onFit={() => setStateMessage("Fit isometric view")}
            onNudge={(horizontal, vertical) =>
              setStateMessage(`Nudge view: ${horizontal}, ${vertical}`)
            }
            onRoll={(quarterTurns) =>
              setStateMessage(`Roll view: ${quarterTurns} quarter turn`)
            }
          />
        </div>
      </Section>

      <Section title="Viewport canvas (imperative mount)">
        <ViewportCanvas
          style={{ width: 420, height: 140 }}
          onMount={(canvas) => {
            const context = canvas.getContext("2d");
            let frame = 0;
            let running = true;
            const draw = () => {
              if (!running || !context) return;
              const { width, height } = canvas.getBoundingClientRect();
              canvas.width = width;
              canvas.height = height;
              context.fillStyle = "#14181e";
              context.fillRect(0, 0, width, height);
              context.strokeStyle = "#3abaf3";
              context.beginPath();
              for (let x = 0; x < width; x++) {
                const y =
                  height / 2 + Math.sin(x / 24 + frame / 20) * height * 0.3;
                x === 0 ? context.moveTo(x, y) : context.lineTo(x, y);
              }
              context.stroke();
              frame += 1;
              requestAnimationFrame(draw);
            };
            draw();
            return () => {
              running = false;
            };
          }}
        />
      </Section>
    </main>
  );
}

function GalleryApplication() {
  const [preset, setPreset] = useState<LayoutPreset>("docked");
  const [category, setCategory] = useState("components");
  const [selected, setSelected] = useState("Buttons");
  const content = useRef<HTMLDivElement>(null);
  const sections = {
    components: ["Buttons", "Tabs", "Ribbon", "Fields + Dialog", "Flat collections", "Authoring fields", "Tabular data", "Property inspectors", "Timeline (dope sheet)"],
    icons: ["Shared vector icons — core/assets/icons"],
    workspace: ["Workspace shell — document bar, sidebars, floating panels, layout presets", "Rail + Dock panel + Tree", "Resizable workspace + bottom panel", "Viewport navigation cube"],
  };
  const navigate = (title: string) => {
    setSelected(title);
    const section = Array.from(content.current?.querySelectorAll<HTMLElement>("[data-gallery-section]") ?? [])
      .find((element) => element.dataset.gallerySection === title);
    if (section && content.current) content.current.scrollTop += section.getBoundingClientRect().top - content.current.getBoundingClientRect().top - 24;
  };
  return <div className="gallery-application">
    <DocumentBar
      leading={<>{window.location.pathname.startsWith("/ui/") && <a href="/" aria-label="Aether Studio" style={{ display: "inline-flex", color: "inherit" }}><AetherIcon name="aether" /></a>}<AetherIcon name="design" /><strong>Aether UI</strong></>}
      center={<Tabs tabs={[{ id: "components", label: "Components" }, { id: "icons", label: "Icons" }, { id: "workspace", label: "Workspaces" }]} activeID={category} onSelect={(id) => { setCategory(id); navigate(sections[id as keyof typeof sections][0]); }} />}
      trailing={<LayoutPresetButton preset={preset} onChange={setPreset} />}
    />
    <WorkspaceShell preset={preset} preservePanelContent style={{ flex: 1, minHeight: 0 }}
      leftPanels={[{ id: "library", title: "Library", icon: <AetherIcon name="design" />, content: <ListBox ariaLabel="Component library" items={sections[category as keyof typeof sections].map((title) => ({ id: title, label: title.split(" — ")[0] }))} selectedIDs={new Set([selected])} onSelect={(ids) => { if (ids[0]) navigate(ids[0]); }} /> }]}
      statusBar={<StatusBar><span>Shared Aether components</span><span>Core UI · {preset}</span></StatusBar>}
    ><div className="gallery-content" ref={content}><Gallery /></div></WorkspaceShell>
  </div>;
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <GalleryApplication />
  </StrictMode>
);
