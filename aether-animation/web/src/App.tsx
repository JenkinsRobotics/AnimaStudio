import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Button,
  DockPanel,
  StatusBar,
  StatusDot,
  Tabs,
  Tree,
  ViewportCanvas,
} from "@aether/ui";
import type { StatusKind, TreeNode } from "@aether/ui";
import {
  fetchCharacterText,
  loadCharacter,
  resolvePose,
  saveFile,
  serializeCharacter,
} from "./engine";
import type { ClipSummary, DofSummary, RigSummary } from "./engine";
import { AnimationViewport } from "./viewport";

const DEFAULT_CHARACTER = "examples/pan_tilt_head.character.anima";

interface DofState extends DofSummary {
  shown: number;
  touched: boolean;
}

export function App() {
  const viewportRef = useRef<AnimationViewport | null>(null);
  const [status, setStatus] = useState("connecting to engine…");
  const [statusKind, setStatusKind] = useState<StatusKind>("busy");
  const [workspace, setWorkspace] = useState("animate");
  const [rig, setRig] = useState<RigSummary | null>(null);
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

  // ---- engine boot -----------------------------------------------------
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const text = await fetchCharacterText(DEFAULT_CHARACTER);
        const loaded = await loadCharacter(text);
        if (cancelled) return;
        handleRef.current = loaded.handle;
        setRig(loaded.rig);
        setRawRig(loaded.rig);
        setDofs(
          loaded.rig.joints.flatMap((joint) =>
            joint.dofs.map((dof) => ({
              ...dof,
              shown: dof.neutral ?? 0,
              touched: false,
            }))
          )
        );
        await viewportRef.current?.setParts(loaded.rig.parts, DEFAULT_CHARACTER);
        poseDirty.current = true;
        setStatus(
          `${loaded.rig.identity.display_name ?? loaded.rig.identity.name} — ` +
            `${loaded.rig.parts.length} parts · ${loaded.rig.joints.length} mates`
        );
        setStatusKind("ok");
      } catch (error) {
        setStatus(`engine unavailable: ${(error as Error).message} — ` +
          "run: .venv/bin/python -m animacore.httpbridge");
        setStatusKind("error");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // ---- pose loop (coalesced; one request in flight) --------------------
  const requestPose = useCallback(() => {
    poseDirty.current = true;
  }, []);

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
  const select = useCallback((id: string, extend: boolean) => {
    setSelection((current) => {
      const next = extend ? new Set(current) : new Set<string>();
      if (current.has(id) && extend) next.delete(id);
      else next.add(id);
      viewportRef.current?.setSelection(next);
      return next;
    });
  }, []);

  // ---- project tree ----------------------------------------------------
  const treeNodes = useMemo<TreeNode[]>(() => {
    if (!rig) return [];
    return [
      {
        id: "#instances",
        label: "Instances",
        badge: String(rig.parts.length),
        children: rig.parts.map((part) => ({
          id: part.name,
          label: part.name + (part.grounded ? " ⏚" : ""),
        })),
      },
      {
        id: "#mates",
        label: "Mate features",
        badge: String(rig.joints.length),
        children: rig.joints.map((joint) => ({
          id: `mate:${joint.name}`,
          label: `${joint.name} · ${joint.type}`,
        })),
      },
      {
        id: "#clips",
        label: "Clips",
        badge: String(rig.clips.length),
        children: rig.clips.map((clip) => ({
          id: `clip:${clip.name}`,
          label: `${clip.name} · ${clip.duration_s.toFixed(2)}s` +
            (clip.loop ? " ⟳" : ""),
        })),
      },
    ];
  }, [rig]);

  const onTreeSelect = useCallback(
    (id: string, extend: boolean) => {
      if (id.startsWith("clip:")) {
        const name = id.slice(5);
        const clip = rig?.clips.find((candidate) => candidate.name === name);
        setActiveClip((current) => (current?.name === name ? null : clip ?? null));
        timeRef.current = 0;
        setTimeS(0);
        setPlaying(false);
        requestPose();
        return;
      }
      if (id.startsWith("#") || id.startsWith("mate:")) return;
      select(id, extend);
    },
    [rig, requestPose, select]
  );

  // ---- save ------------------------------------------------------------
  const save = useCallback(async () => {
    if (!rawRig) return;
    try {
      const { text } = await serializeCharacter(rawRig);
      await saveFile(DEFAULT_CHARACTER, text);
      setStatus("saved " + DEFAULT_CHARACTER);
    } catch (error) {
      setStatus(`save failed: ${(error as Error).message}`);
      setStatusKind("warn");
    }
  }, [rawRig]);

  return (
    <div className="app-shell">
      <header className="app-topbar">
        <strong className="app-brand">◆ AETHER ANIMATION</strong>
        <Tabs
          tabs={[
            { id: "assets", label: "Assets" },
            { id: "modeling", label: "3D Modeling" },
            { id: "animate", label: "Animate" },
          ]}
          activeID={workspace}
          onSelect={setWorkspace}
        />
        <span className="app-topbar-spacer" />
        <Button onClick={save} disabled={!rawRig}>
          Save
        </Button>
      </header>
      <div className="app-body">
        <DockPanel title="Project" width="var(--aether-size-sidebar)">
          <Tree
            nodes={treeNodes}
            selectedIDs={selection}
            onSelect={onTreeSelect}
          />
        </DockPanel>
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
              if (name) select(name, extend);
              else {
                setSelection(new Set());
                viewport?.setSelection(new Set());
              }
            });
            viewportRef.current = viewport;
            return () => {
              viewport?.dispose();
              viewportRef.current = null;
            };
          }}
        />
        <DockPanel title="Pose" width={260}>
          <div className="pose-panel">
            {dofs.map((dof, index) => (
              <label key={dof.path} className="pose-row">
                <span className="pose-label">
                  {(dof.touched ? "● " : "") + dof.path}
                </span>
                <input
                  type="range"
                  min={dof.min ?? (dof.neutral ?? 0) - Math.PI}
                  max={dof.max ?? (dof.neutral ?? 0) + Math.PI}
                  step={0.001}
                  value={dof.shown}
                  onChange={(event) => {
                    const value = Number(event.target.value);
                    setDofs((current) =>
                      current.map((entry, entryIndex) =>
                        entryIndex === index
                          ? { ...entry, shown: value, touched: true }
                          : entry
                      )
                    );
                    requestPose();
                  }}
                />
                <span className="pose-value">{dof.shown.toFixed(2)}</span>
              </label>
            ))}
            {dofs.some((dof) => dof.touched) ? (
              <Button
                onClick={() => {
                  setDofs((current) =>
                    current.map((dof) => ({
                      ...dof,
                      shown: dof.neutral ?? 0,
                      touched: false,
                    }))
                  );
                  requestPose();
                }}
              >
                Reset pose overrides
              </Button>
            ) : null}
          </div>
        </DockPanel>
      </div>
      <footer className="app-transport">
        <Button
          disabled={!activeClip}
          onClick={() => {
            if (!playing && activeClip &&
                timeRef.current >= activeClip.duration_s) {
              timeRef.current = 0;
            }
            setPlaying((current) => !current);
          }}
        >
          {playing ? "❚❚" : "▶"}
        </Button>
        <input
          className="app-scrub"
          type="range"
          min={0}
          max={activeClip?.duration_s ?? 1}
          step={0.001}
          disabled={!activeClip}
          value={timeS}
          onChange={(event) => {
            timeRef.current = Number(event.target.value);
            setTimeS(timeRef.current);
            setPlaying(false);
            requestPose();
          }}
        />
        <span className="app-time">
          {activeClip
            ? `${timeS.toFixed(2)} / ${activeClip.duration_s.toFixed(2)} s · ${activeClip.name}`
            : "select a clip in the project tree"}
        </span>
        <StatusBar>
          <StatusDot kind={statusKind} />
          {status}
        </StatusBar>
      </footer>
    </div>
  );
}
