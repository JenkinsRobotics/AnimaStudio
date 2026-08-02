import { StrictMode, useState } from "react";
import { createRoot } from "react-dom/client";
import "../tokens/tokens.css";
import "../src/widgets.css";
import {
  Button,
  Dialog,
  DockPanel,
  IconButton,
  PanelHeading,
  Rail,
  RailButton,
  Ribbon,
  RibbonGroup,
  RibbonTool,
  StatusBar,
  StatusDot,
  Tabs,
  TextField,
  Tree,
  ViewportCanvas,
} from "../src/index";
import type { TreeNode } from "../src/index";

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

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ display: "grid", gap: 10 }}>
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
      <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-start", gap: 12 }}>
        {children}
      </div>
    </section>
  );
}

function Gallery() {
  const [activeTab, setActiveTab] = useState("modeling");
  const [armedTool, setArmedTool] = useState<string | null>("revolute");
  const [activeRail, setActiveRail] = useState("tree");
  const [selection, setSelection] = useState<ReadonlySet<string>>(new Set(["yoke"]));
  const [treeFilter, setTreeFilter] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("my_robot");

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "var(--aether-color-bg-app)",
        color: "var(--aether-color-text)",
        fontFamily: "var(--aether-font-family)",
        padding: 24,
        display: "grid",
        gap: 26,
        alignContent: "start",
      }}
    >
      <header style={{ display: "grid", gap: 4 }}>
        <strong style={{ fontSize: 16 }}>Aether UI</strong>
        <span style={{ color: "var(--aether-color-text-dim)", fontSize: 11 }}>
          Shared widget gallery — tokens baseline: Aether CAD. One widget per
          file; product-free by rule.
        </span>
      </header>

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
              nodes={sampleTree}
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
              onAction={(node, action) => console.log("action", node, action)}
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

      <Section title="Fields + Dialog">
        <TextField
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Assembly name"
          style={{ width: 200 }}
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

      <Section title="Status bar">
        <div style={{ width: 420 }}>
          <StatusBar>
            <StatusDot kind="ok" />
            Engine ready · 26 parts · 0 mates
          </StatusBar>
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

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Gallery />
  </StrictMode>
);
