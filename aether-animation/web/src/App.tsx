import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Button,
  AppIcon,
  AetherIcon,
  IconButton,
  DocumentBar,
  LayoutPresetButton,
  Ribbon,
  RibbonGroup,
  RibbonTool,
  StatusBar,
  StatusDot,
  Tabs,
  Tree,
  ViewportCanvas,
  ViewportNavigationCube,
  type ViewportOrientation,
  type AetherIconName,
  WorkspaceShell,
} from "@aether/ui";
import type { LayoutPreset, StatusKind, TreeNode, WorkspacePanel } from "@aether/ui";
import {
  addMate,
  fetchCharacterText,
  loadCharacter,
  mateTypes,
  removeMate,
  resolvePose,
  saveFile,
  serializeCharacter,
} from "./engine";
import type {
  ClipSummary,
  ConnectorDTO,
  MateTypeSchema,
  RigSummary,
} from "./engine";
import { previewMate } from "./engine";
import { AnimationViewport } from "./viewport";
import { MateDialog, draftToJoint } from "./MateDialog";
import type { MateDraft } from "./MateDialog";
import { TimelinePanel } from "./TimelinePanel";
import { PosePanel } from "./PosePanel";
import type { DofState } from "./PosePanel";

const DEFAULT_CHARACTER = "examples/pan_tilt_head.character.anima";
const PRESET_KEY = "aether.layoutPreset";

const TOOL_ICONS: Record<string, AetherIconName> = {
  fastened: "fastened", parallel: "parallel", revolute: "revolute",
  prismatic: "slider", cylindrical: "cylindrical", pin_slot: "pin_slot",
  planar: "planar", ball: "ball",
};

export function App() {
  const viewportRef = useRef<AnimationViewport | null>(null);
  const [cameraOrientation, setCameraOrientation] = useState<ViewportOrientation>([0, 0, 0, 1]);
  const [status, setStatus] = useState("connecting to engine…");
  const [statusKind, setStatusKind] = useState<StatusKind>("busy");
  // Deep links for review: ?workspace=assets|modeling|animate&clip=<name>
  const [workspace, setWorkspace] = useState(
    () => new URLSearchParams(location.search).get("workspace") ?? "modeling"
  );
  const [preset, setPreset] = useState<LayoutPreset>(() => {
    const stored = localStorage.getItem(PRESET_KEY);
    return stored === "floating" || stored === "canvas" ? stored : "docked";
  });
  const [rig, setRig] = useState<RigSummary | null>(null);
  const rigRef = useRef<RigSummary | null>(null);
  const [rawRig, setRawRig] = useState<unknown>(null);
  const handleRef = useRef<string | null>(null);
  const [selection, setSelection] = useState<ReadonlySet<string>>(new Set());
  const [dofs, setDofs] = useState<DofState[]>([]);
  const [activeClip, setActiveClip] = useState<ClipSummary | null>(null);
  const [playing, setPlaying] = useState(false);
  const timeRef = useRef(0);
  const [timeS, setTimeS] = useState(0);
  const poseBusy = useRef(false);
  const poseDirty = useRef(false);
  const [mateSchemas, setMateSchemas] = useState<MateTypeSchema[]>([]);
  const [mateDraft, setMateDraft] = useState<MateDraft | null>(null);
  const mateDraftRef = useRef<MateDraft | null>(null);
  const [mateBusy, setMateBusy] = useState(false);

  const choosePreset = useCallback((next: LayoutPreset) => {
    localStorage.setItem(PRESET_KEY, next);
    setPreset(next);
  }, []);

  const requestPose = useCallback(() => {
    poseDirty.current = true;
  }, []);

  const adoptRig = useCallback(async (loadedRig: RigSummary, raw: unknown) => {
    rigRef.current = loadedRig;
    setRig(loadedRig);
    setRawRig(raw);
    setDofs(
      loadedRig.joints.flatMap((joint) =>
        joint.dofs.map((dof) => ({
          ...dof,
          shown: dof.neutral ?? 0,
          touched: false,
        }))
      )
    );
    await viewportRef.current?.setParts(loadedRig.parts, DEFAULT_CHARACTER);
    poseDirty.current = true;
    setStatus(
      `${loadedRig.identity.display_name ?? loadedRig.identity.name} — ` +
        `${loadedRig.parts.length} parts · ${loadedRig.joints.length} mates · ` +
        `${loadedRig.clips.length} clips`
    );
    setStatusKind("ok");
  }, []);

  // ---- engine boot -----------------------------------------------------
  const boot = useCallback(async () => {
    try {
      setStatus("connecting to engine…");
      setStatusKind("busy");
      const text = await fetchCharacterText(DEFAULT_CHARACTER);
      const loaded = await loadCharacter(text);
      handleRef.current = loaded.handle;
      await adoptRig(loaded.rig, loaded.rig);
      const types = await mateTypes();
      setMateSchemas(types.mate_types.filter((schema) => schema.category === "kinematic"));
      const clipParam = new URLSearchParams(location.search).get("clip");
      if (clipParam) {
        const clip = loaded.rig.clips.find((entry) => entry.name === clipParam);
        if (clip) setActiveClip(clip);
      }
    } catch (error) {
      setStatus(
        `engine unavailable: ${(error as Error).message} — ` +
          "run: .venv/bin/python -m animacore.httpbridge"
      );
      setStatusKind("error");
    }
  }, [adoptRig]);

  useEffect(() => {
    void boot();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ---- pose loop (coalesced; one request in flight) --------------------
  useEffect(() => {
    let cancelled = false;
    let lastTick = performance.now();
    const tick = async (now: number) => {
      if (cancelled) return;
      const delta = (now - lastTick) / 1000;
      lastTick = now;
      if (playing && activeClip) {
        timeRef.current += delta;
        if (timeRef.current > activeClip.duration_s) {
          if (activeClip.loop) {
            timeRef.current %= Math.max(activeClip.duration_s, 1e-6);
          } else {
            timeRef.current = activeClip.duration_s;
            setPlaying(false);
          }
        }
        setTimeS(timeRef.current);
        poseDirty.current = true;
      }
      if (poseDirty.current && !poseBusy.current && handleRef.current) {
        poseDirty.current = false;
        poseBusy.current = true;
        try {
          const dofValues: Record<string, number> = {};
          for (const dof of dofs) if (dof.touched) dofValues[dof.path] = dof.shown;
          const pose = await resolvePose(handleRef.current, {
            clip: activeClip?.name,
            timeS: timeRef.current,
            dofValues,
          });
          viewportRef.current?.applyPose(pose.parts);
        } catch {
          // transient engine errors surface via the next status update
        } finally {
          poseBusy.current = false;
        }
      }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    return () => {
      cancelled = true;
    };
  }, [playing, activeClip, dofs]);

  // ---- selection -------------------------------------------------------
  const select = useCallback(
    (ids: readonly string[], mode: "single" | "toggle" | "range") => {
      setSelection((current) => {
        let next: Set<string>;
        if (mode === "toggle") {
          next = new Set(current);
          for (const id of ids) {
            if (next.has(id)) next.delete(id);
            else next.add(id);
          }
        } else {
          next = new Set(ids);
        }
        viewportRef.current?.setSelection(
          new Set([...next].filter((id) => !id.includes(":")))
        );
        return next;
      });
    },
    []
  );

  // ---- mate authoring --------------------------------------------------
  const disarmMate = useCallback(() => {
    mateDraftRef.current = null;
    setMateDraft(null);
    viewportRef.current?.setConnectorMode(false);
    requestPose(); // restore the evaluated pose after any preview
  }, [requestPose]);

  const armMate = useCallback(
    (schema: MateTypeSchema) => {
      const draft: MateDraft = {
        schema,
        a: null,
        b: null,
        flipPrimaryAxis: false,
        secondaryAxisRotationDeg: 0,
      };
      mateDraftRef.current = draft;
      setMateDraft(draft);
      viewportRef.current?.setConnectorMode(true, (pick) => {
        const current = mateDraftRef.current;
        if (!current) return;
        const connector: ConnectorDTO = {
          part: pick.part,
          origin_m: pick.originM,
          primary_axis: pick.primaryAxis,
          secondary_axis: pick.secondaryAxis,
        };
        const next: MateDraft = current.a
          ? { ...current, b: connector }
          : { ...current, a: connector };
        mateDraftRef.current = next;
        setMateDraft(next);
      });
    },
    []
  );

  const updateDraft = useCallback((draft: MateDraft) => {
    mateDraftRef.current = draft;
    setMateDraft(draft);
  }, []);

  const mateName = useCallback(() => {
    const base = mateDraftRef.current?.schema.type ?? "mate";
    const existing = new Set(rigRef.current?.joints.map((joint) => joint.name));
    let index = 1;
    while (existing.has(`${base}_${index}`)) index += 1;
    return `${base}_${index}`;
  }, []);

  const solveMate = useCallback(async () => {
    const draft = mateDraftRef.current;
    const handle = handleRef.current;
    if (!draft || !handle) return;
    const joint = draftToJoint(draft, mateName());
    if (!joint) return;
    setMateBusy(true);
    try {
      const pose = await previewMate(handle, joint);
      viewportRef.current?.applyPose(pose.parts);
      setStatus(`preview: ${joint.name}`);
      setStatusKind("ok");
    } catch (error) {
      setStatus(`preview failed: ${(error as Error).message}`);
      setStatusKind("warn");
    } finally {
      setMateBusy(false);
    }
  }, [mateName]);

  const commitMate = useCallback(async () => {
    const draft = mateDraftRef.current;
    const handle = handleRef.current;
    if (!draft || !handle) return;
    const joint = draftToJoint(draft, mateName());
    if (!joint) return;
    setMateBusy(true);
    try {
      const result = await addMate(handle, joint);
      handleRef.current = result.handle;
      await adoptRig(result.rig, result.rig);
      disarmMate();
    } catch (error) {
      setStatus(`create mate failed: ${(error as Error).message}`);
      setStatusKind("warn");
    } finally {
      setMateBusy(false);
    }
  }, [adoptRig, disarmMate, mateName]);

  const deleteMate = useCallback(
    async (name: string) => {
      const handle = handleRef.current;
      if (!handle) return;
      try {
        const result = await removeMate(handle, name);
        handleRef.current = result.handle;
        await adoptRig(result.rig, result.rig);
        setSelection(new Set());
      } catch (error) {
        setStatus(`remove mate failed: ${(error as Error).message}`);
        setStatusKind("warn");
      }
    },
    [adoptRig]
  );

  // ---- clips -----------------------------------------------------------
  const chooseClip = useCallback(
    (name: string) => {
      const clip = rigRef.current?.clips.find((entry) => entry.name === name);
      setActiveClip((current) => (current?.name === name ? null : clip ?? null));
      timeRef.current = 0;
      setTimeS(0);
      setPlaying(false);
      requestPose();
    },
    [requestPose]
  );

  // ---- save ------------------------------------------------------------
  const save = useCallback(async () => {
    if (!rawRig) return;
    try {
      const { text } = await serializeCharacter(rawRig);
      await saveFile(DEFAULT_CHARACTER, text);
      setStatus("saved " + DEFAULT_CHARACTER);
      setStatusKind("ok");
    } catch (error) {
      setStatus(`save failed: ${(error as Error).message}`);
      setStatusKind("warn");
    }
  }, [rawRig]);

  // ---- panels ----------------------------------------------------------
  const partNodes = useMemo<TreeNode[]>(
    () =>
      rig?.parts.map((part) => ({
        id: part.name,
        label: part.name,
        icon: <AetherIcon name="model" />,
        badge: part.grounded ? "⏚" : undefined,
        dimmed: part.suppressed,
      })) ?? [],
    [rig]
  );
  const mateNodes = useMemo<TreeNode[]>(
    () =>
      rig?.joints.map((joint) => ({
        id: `mate:${joint.name}`,
        label: `${joint.name} · ${joint.type}`,
        icon: <AetherIcon name="mate" />,
      })) ?? [],
    [rig]
  );
  const clipNodes = useMemo<TreeNode[]>(
    () =>
      rig?.clips.map((clip) => ({
        id: `clip:${clip.name}`,
        label: `${clip.name} · ${clip.duration_s.toFixed(2)}s${clip.loop ? " ⟳" : ""}`,
        icon: <AetherIcon name="play" />,
        badge: clip.name === activeClip?.name ? "●" : undefined,
      })) ?? [],
    [rig, activeClip]
  );

  const selectedMate = useMemo(() => {
    const id = [...selection].find((entry) => entry.startsWith("mate:"));
    if (!id) return null;
    return rig?.joints.find((joint) => joint.name === id.slice(5)) ?? null;
  }, [selection, rig]);
  const selectedPart = useMemo(() => {
    const id = [...selection].find((entry) => !entry.includes(":"));
    if (!id) return null;
    return rig?.parts.find((part) => part.name === id) ?? null;
  }, [selection, rig]);

  const onDofChange = useCallback(
    (index: number, value: number) => {
      setDofs((current) =>
        current.map((entry, entryIndex) =>
          entryIndex === index ? { ...entry, shown: value, touched: true } : entry
        )
      );
      requestPose();
    },
    [requestPose]
  );
  const onDofReset = useCallback(() => {
    setDofs((current) =>
      current.map((dof) => ({ ...dof, shown: dof.neutral ?? 0, touched: false }))
    );
    requestPose();
  }, [requestPose]);

  const inspector = (
    <div className="inspector-panel">
      {selectedMate ? (
        <>
          <div className="inspector-title">{selectedMate.name}</div>
          <div className="inspector-row">type · {selectedMate.type}</div>
          <div className="inspector-row">
            {selectedMate.parent_part} → {selectedMate.child_part}
          </div>
          <div className="inspector-row">
            DOF · {selectedMate.dofs.map((dof) => dof.path).join(", ") || "none"}
          </div>
          <Button onClick={() => deleteMate(selectedMate.name)}>Remove mate</Button>
        </>
      ) : selectedPart ? (
        <>
          <div className="inspector-title">{selectedPart.name}</div>
          <div className="inspector-row">model · {selectedPart.model || "(none)"}</div>
          <div className="inspector-row">
            {selectedPart.grounded ? "grounded ⏚" : "free"}
          </div>
        </>
      ) : (
        <div className="inspector-row">select a part or mate</div>
      )}
    </div>
  );

  const characterPanel = (
    <div className="inspector-panel">
      <div className="inspector-title">
        {rig ? rig.identity.display_name ?? rig.identity.name : "…"}
      </div>
      <div className="inspector-row">{DEFAULT_CHARACTER}</div>
      <div className="inspector-row">
        {rig
          ? `${rig.parts.length} parts · ${rig.joints.length} mates · ${rig.clips.length} clips`
          : "loading"}
      </div>
      <Button onClick={boot}>Reload character</Button>
    </div>
  );

  const leftPanels: WorkspacePanel[] = [
    {
      id: "character",
      title: "Character",
      icon: <AetherIcon name="aether" />,
      content: characterPanel,
    },
    {
      id: "parts",
      title: "Parts",
      icon: <AetherIcon name="items" />,
      content: (
        <Tree nodes={partNodes} selectedIDs={selection} onSelect={select} />
      ),
    },
    {
      id: "mates",
      title: "Mates",
      icon: <AetherIcon name="mate" />,
      content: (
        <Tree
          nodes={mateNodes}
          selectedIDs={selection}
          onSelect={select}
          emptyState="no mates — arm a mate tool"
        />
      ),
    },
    {
      id: "clips",
      title: "Clips",
      icon: <AetherIcon name="play" />,
      content: (
        <Tree
          nodes={clipNodes}
          selectedIDs={new Set(activeClip ? [`clip:${activeClip.name}`] : [])}
          onSelect={(ids) => {
            const id = ids[ids.length - 1];
            if (id?.startsWith("clip:")) chooseClip(id.slice(5));
          }}
          emptyState="no clips in this character"
        />
      ),
    },
  ];

  const rightPanels: WorkspacePanel[] = [
    { id: "inspector", title: "Inspector", icon: <AetherIcon name="document" />, content: inspector },
    {
      id: "pose",
      title: "Pose",
      icon: <AetherIcon name="settings" />,
      content: <PosePanel dofs={dofs} onChange={onDofChange} onReset={onDofReset} />,
    },
  ];

  // ---- ribbon ----------------------------------------------------------
  const toolbar = (
    <Ribbon>
      {workspace === "modeling" ? (
        <>
          <RibbonGroup label="Mate">
            {mateSchemas.map((schema) => (
              <RibbonTool
                key={schema.type}
                icon={<AetherIcon name={TOOL_ICONS[schema.type] ?? "mate"} />}
                label={schema.label}
                active={mateDraft?.schema.type === schema.type}
                onClick={() =>
                  mateDraft?.schema.type === schema.type
                    ? disarmMate()
                    : armMate(schema)
                }
              />
            ))}
          </RibbonGroup>
          <RibbonGroup label="Edit">
            <RibbonTool
              icon={<AetherIcon name="delete" />}
              label="Remove"
              disabled={!selectedMate}
              onClick={() => selectedMate && deleteMate(selectedMate.name)}
            />
          </RibbonGroup>
        </>
      ) : workspace === "animate" ? (
        <RibbonGroup label="Pose">
          <RibbonTool icon={<AetherIcon name="undo" />} label="Reset" onClick={onDofReset} />
        </RibbonGroup>
      ) : (
        <RibbonGroup label="Character">
          <RibbonTool icon={<AetherIcon name="history" />} label="Reload" onClick={() => void boot()} />
          <RibbonTool icon={<AetherIcon name="save" />} label="Save" onClick={() => void save()} />
        </RibbonGroup>
      )}
    </Ribbon>
  );

  // ---- shell -----------------------------------------------------------
  return (
    <div className="app-root">
      <DocumentBar
        leading={
          <>
            {window.location.pathname.startsWith("/animation/") && <a href="/animation/" title="Aether Animation" aria-label="Aether Animation" style={{ display: "inline-flex", color: "inherit" }}><AppIcon app="animation" size={30} /></a>}
            <IconButton label="Aether Animation assets" onClick={() => setWorkspace("assets")}><AetherIcon name="home" /></IconButton>
            <strong className="app-brand">Aether Animation</strong>
            <span className="app-project">
              {rig ? rig.identity.display_name ?? rig.identity.name : "…"}
            </span>
            <StatusDot kind={statusKind} />
          </>
        }
        center={
          <Tabs
            tabs={[
              { id: "assets", label: "Assets", icon: <AetherIcon name="import" /> },
              { id: "modeling", label: "3D Modeling", icon: <AetherIcon name="design" /> },
              { id: "animate", label: "Animate", icon: <AetherIcon name="animate" /> },
              { id: "show", label: "Show", icon: <AetherIcon name="show" />, disabled: true, title: "Show workspace is awaiting the web session bridge." },
              { id: "hardware", label: "Hardware", icon: <AetherIcon name="hardware" />, disabled: true, title: "Hardware workspace is awaiting the web output session bridge." },
            ]}
            activeID={workspace}
            onSelect={setWorkspace}
          />
        }
        trailing={
          <>
            <Button onClick={save} disabled={!rawRig}>
              Save
            </Button>
            <LayoutPresetButton preset={preset} onChange={choosePreset} />
            <div data-aether-account="" />
          </>
        }
      />
      <WorkspaceShell
        preset={preset}
        preservePanelContent
        storageKey="aether.animation.panels.v1"
        style={{ flex: 1, minHeight: 0 }}
        toolbar={toolbar}
        leftPanels={leftPanels}
        rightPanels={rightPanels}
        defaultOpenLeft={["parts"]}
        defaultOpenRight={["inspector"]}
        bottom={
          workspace === "animate" ? (
            <TimelinePanel
              clip={activeClip}
              timeS={timeS}
              playing={playing}
              onSeek={(time) => {
                timeRef.current = time;
                setTimeS(time);
                setPlaying(false);
                requestPose();
              }}
              onTogglePlay={() => {
                if (
                  !playing &&
                  activeClip &&
                  timeRef.current >= activeClip.duration_s
                ) {
                  timeRef.current = 0;
                }
                setPlaying((current) => !current);
              }}
            />
          ) : undefined
        }
        statusBar={
          <StatusBar>
            <StatusDot kind={statusKind} />
            {status}
            <span className="app-status-spacer" />
            layout · {preset}
          </StatusBar>
        }
      >
        <ViewportCanvas
          className="app-viewport"
          onMount={(canvas) => {
            // A failed 3D context must degrade to a dead viewport, never
            // blank the application chrome.
            let viewport: AnimationViewport | null = null;
            try {
              viewport = new AnimationViewport(canvas);
            } catch (error) {
              setStatus(`viewport unavailable: ${(error as Error).message}`);
              setStatusKind("warn");
              return () => {};
            }
            viewport.setPickHandler((name, extend) => {
              if (name) select([name], extend ? "toggle" : "single");
              else {
                setSelection(new Set());
                viewport?.setSelection(new Set());
              }
            });
            viewportRef.current = viewport;
            viewport.setOrientationHandler(setCameraOrientation);
            // The shared shell retains this canvas across layout changes.
            // A fresh mount still hydrates from the active engine projection.
            const current = rigRef.current;
            if (current) {
              void viewport
                .setParts(current.parts, DEFAULT_CHARACTER)
                .then(() => {
                  poseDirty.current = true;
                });
            }
            return () => {
              viewport?.dispose();
              viewportRef.current = null;
            };
          }}
        />
        <div className="animation-view-cube">
          <ViewportNavigationCube orientation={cameraOrientation}
            onSelectView={(view) => viewportRef.current?.setStandardView(view)}
            onFit={() => viewportRef.current?.fitView()}
            onNudge={(horizontal, vertical) => viewportRef.current?.nudgeView(horizontal, vertical)}
            onRoll={(turns) => viewportRef.current?.rollView(turns)} />
        </div>
        {mateDraft ? (
          <MateDialog
            draft={mateDraft}
            onChange={updateDraft}
            onSolve={() => void solveMate()}
            onCommit={() => void commitMate()}
            onCancel={disarmMate}
            busy={mateBusy}
          />
        ) : null}
      </WorkspaceShell>
    </div>
  );
}
