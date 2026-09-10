'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Menu,
  Box,
  GitBranch,
  Undo2,
  Redo2,
  Search,
  CloudCheck,
  MessageSquare,
  Bell,
  ChevronDown,
  Plus,
  Layers,
  FileText,
  Palette,
  Ruler,
  Settings2,
  Info,
  Eye,
  ChevronRight,
  X,
  Scissors,
  Check,
  Pencil,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { CADViewport } from './CADViewport';
import { CommandRibbon, solidTools } from './CommandRibbon';
import { FeatureTree, PartsSidebar } from './FeatureTree';
import { AdaptiveLayout } from '../layout/AdaptiveLayout';
import { LayoutControls } from '../layout/LayoutControls';
import { layoutStore } from '../layout/layout-store';
import { FeatureDialog, type FeatureDraft } from './FeatureDialog';
import { AuxiliaryPanel } from './AuxiliaryPanel';
import {
  initialFeatures,
  type Feature,
  type ElementTab,
  type DisplayStyle,
  type ViewportHandle,
} from './types';
const initialTabs: ElementTab[] = [
  { id: 'part', name: 'Part Studio 1', kind: 'part' },
  { id: 'assembly', name: 'Assembly 1', kind: 'assembly' },
  { id: 'drawing', name: 'Drawing 1', kind: 'drawing' },
];
const tabIcons: Record<ElementTab['kind'], LucideIcon> = {
  part: Box,
  assembly: Layers,
  drawing: FileText,
};
type MenuState = {
  x: number;
  y: number;
  type: 'feature' | 'tab' | 'add' | 'document';
  id?: string;
};
export function CADWorkspace() {
  const [tabs, setTabs] = useState(initialTabs);
  const [activeTab, setActiveTab] = useState('part');
  const tab = tabs.find((t) => t.id === activeTab) ?? tabs[0];
  const [features, setFeatures] = useState(initialFeatures);
  const [undoStack, setUndoStack] = useState<Feature[][]>([]);
  const [redoStack, setRedoStack] = useState<Feature[][]>([]);
  const [sketch, setSketch] = useState(false);
  const [sketchEditing, setSketchEditing] = useState<Feature | null>(null);
  const [construction, setConstruction] = useState(false);
  const [selectedTool, setSelectedTool] = useState('');
  const [planes, setPlanes] = useState([true, true, true]);
  const [hidden, setHidden] = useState([false, false]);
  const [selected, setSelected] = useState<string | null>(null);
  const [selectedPart, setSelectedPart] = useState<number | null>(null);
  const [filter, setFilter] = useState('');
  const [rollback, setRollback] = useState(initialFeatures.length);
  const [dialog, setDialog] = useState<{
    kind: string;
    feature?: Feature;
  } | null>(null);
  const [panel, setPanel] = useState<string | null>(null);
  const [color, setColor] = useState('#a7b5c5');
  const [opacity, setOpacity] = useState(1);
  const [width, setWidth] = useState(120);
  const [display, setDisplay] = useState<DisplayStyle>('Shaded with edges');
  const [section, setSection] = useState(false);
  const [menu, setMenu] = useState<MenuState | null>(null);
  const [rename, setRename] = useState<{
    type: 'tab' | 'feature';
    id: string;
    name: string;
  } | null>(null);
  const [search, setSearch] = useState<string | null>(null);
  const [toast, setToast] = useState('');
  const viewport = useRef<ViewportHandle>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const notify = (s: string) => setToast(s);
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(''), 4000);
    return () => clearTimeout(t);
  }, [toast]);
  const mutate = useCallback(
    (next: Feature[]) => {
      setUndoStack((s) => [...s, features]);
      setRedoStack([]);
      setFeatures(next);
      setRollback(next.length);
    },
    [features],
  );
  const undo = useCallback(() => {
    const prev = undoStack.at(-1);
    if (!prev) return;
    setRedoStack((s) => [...s, features]);
    setUndoStack((s) => s.slice(0, -1));
    setFeatures(prev);
    setRollback(prev.length);
    setSelected(null);
  }, [features, undoStack]);
  const redo = useCallback(() => {
    const next = redoStack.at(-1);
    if (!next) return;
    setUndoStack((s) => [...s, features]);
    setRedoStack((s) => s.slice(0, -1));
    setFeatures(next);
    setRollback(next.length);
  }, [features, redoStack]);
  const startSketch = (feature?: Feature) => {
    setSketch(true);
    setSketchEditing(feature ?? null);
    setDialog(null);
    setSelectedTool('Line');
    viewport.current?.snap('Top');
  };
  const finishSketch = () => {
    if (!sketchEditing) {
      const n =
        Math.max(
          0,
          ...features
            .filter((f) => f.kind === 'Sketch')
            .map((f) => Number(f.name.match(/\d+$/)?.[0]) || 0),
        ) + 1;
      const f = {
        id: crypto.randomUUID(),
        name: `Sketch ${n}`,
        kind: 'Sketch',
      };
      mutate([...features, f]);
      setSelected(f.id);
      notify(`${f.name} added to feature history`);
    } else notify(`${sketchEditing.name} closed`);
    setSketch(false);
    setSketchEditing(null);
    setSelectedTool('');
    viewport.current?.snap('Isometric');
  };
  const cancelSketch = () => {
    setSketch(false);
    setSketchEditing(null);
    setSelectedTool('');
    viewport.current?.snap('Isometric');
  };
  const runTool = (name: string) => {
    setSearch(null);
    if (name === 'Sketch') {
      startSketch();
      return;
    }
    if (sketch) {
      if (name === 'Construction') setConstruction((c) => !c);
      setSelectedTool(name);
      return;
    }
    if (name === 'Plane') {
      setPlanes([true, true, true]);
      notify('Default reference planes shown');
      return;
    }
    setSelectedTool(name);
    setDialog({ kind: name });
  };
  const editFeature = (f: Feature) => {
    setSelected(f.id);
    if (f.kind === 'Sketch') startSketch(f);
    else setDialog({ kind: f.kind, feature: f });
  };
  const applyFeature = (draft: FeatureDraft) => {
    if (!dialog) return;
    if (dialog.feature)
      mutate(
        features.map((f) =>
          f.id === dialog.feature?.id ? { ...f, depthMm: draft.depthMm } : f,
        ),
      );
    else {
      const n = features.filter((f) => f.kind === draft.kind).length + 1;
      const f = {
        id: crypto.randomUUID(),
        name: `${draft.kind} ${n}`,
        kind: draft.kind,
        depthMm: draft.depthMm,
      };
      mutate([...features, f]);
      setSelected(f.id);
    }
    setDialog(null);
    setSelectedTool('');
    notify('Mock feature parameters applied');
  };
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const typing = (e.target as HTMLElement)?.closest(
        'input,textarea,select,[contenteditable]',
      );
      if (e.key === 'Escape') {
        setMenu(null);
        setSearch(null);
        setDialog(null);
        setRename(null);
        if (sketch) cancelSketch();
        return;
      }
      if (typing) return;
      if (e.altKey && e.key.toLowerCase() === 'c') {
        e.preventDefault();
        setSearch('');
        return;
      }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') {
        e.preventDefault();
        if (e.shiftKey) redo();
        else undo();
        return;
      }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'y') {
        e.preventDefault();
        redo();
        return;
      }
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      switch (e.key.toLowerCase()) {
        case 'p':
          setPlanes((p) =>
            p.some(Boolean) ? [false, false, false] : [true, true, true],
          );
          break;
        case 'f':
          viewport.current?.fit();
          break;
        case 'q':
          if (sketch) setConstruction((c) => !c);
          break;
        case 'd':
          if (sketch) setSelectedTool('Dimension');
          break;
      }
    };
    window.addEventListener('keydown', key);
    return () => window.removeEventListener('keydown', key);
  }, [sketch, undo, redo]);
  useEffect(() => {
    if (search !== null) searchInput.current?.focus();
  }, [search]);
  const openMenu = (
    e: React.MouseEvent,
    type: MenuState['type'],
    id?: string,
  ) => {
    e.preventDefault();
    setMenu({
      x: Math.min(e.clientX, window.innerWidth - 200),
      y: Math.min(e.clientY, window.innerHeight - 195),
      type,
      id,
    });
  };
  const addTab = (kind: ElementTab['kind']) => {
    const name =
      kind === 'part'
        ? 'Part Studio'
        : kind === 'assembly'
          ? 'Assembly'
          : 'Drawing';
    const t = {
      id: crypto.randomUUID(),
      kind,
      name: `${name} ${tabs.filter((t) => t.kind === kind).length + 1}`,
    };
    setTabs([...tabs, t]);
    setActiveTab(t.id);
    setSketch(false);
    setDialog(null);
    setMenu(null);
  };
  const exportTab = (id: string) => {
    const t = tabs.find((t) => t.id === id);
    const blob = new Blob(
      [
        JSON.stringify(
          { prototype: true, tab: t, features, units: 'mm' },
          null,
          2,
        ),
      ],
      { type: 'application/json' },
    );
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${t?.name ?? 'workspace'}.mockup.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    notify('Prototype state exported as JSON');
  };
  const contextAction = (action: string) => {
    if (!menu) return;
    const f = features.find((f) => f.id === menu.id),
      t = tabs.find((t) => t.id === menu.id);
    if (menu.type === 'feature' && f) {
      if (action === 'Edit') editFeature(f);
      if (action === 'Rename')
        setRename({ type: 'feature', id: f.id, name: f.name });
      if (action === 'Suppress' || action === 'Unsuppress')
        mutate(
          features.map((x) =>
            x.id === f.id ? { ...x, suppressed: !x.suppressed } : x,
          ),
        );
      if (action === 'Delete') {
        mutate(features.filter((x) => x.id !== f.id));
        setSelected(null);
      }
    }
    if (menu.type === 'tab' && t) {
      if (action === 'Rename')
        setRename({ type: 'tab', id: t.id, name: t.name });
      if (action === 'Duplicate') {
        const copy = { ...t, id: crypto.randomUUID(), name: `${t.name} copy` };
        setTabs([...tabs, copy]);
        setActiveTab(copy.id);
      }
      if (action === 'Export prototype JSON') exportTab(t.id);
      if (action === 'Delete' && tabs.length > 1) {
        setTabs(tabs.filter((x) => x.id !== t.id));
        if (activeTab === t.id)
          setActiveTab(tabs.find((x) => x.id !== t.id)!.id);
      }
    }
    setMenu(null);
  };
  const partHidden = hidden.map(
    (h, i) =>
      h ||
      (i === 0
        ? rollback < 2 || !features.some((f) => f.id === 'e1' && !f.suppressed)
        : rollback < 4),
  );
  return (
    <main className="cad-workspace">
      <header className="global-header">
        <button
          className="brand-mark"
          aria-label="Document menu"
          onClick={(e) => openMenu(e, 'document')}
        >
          <Menu size={18} />
        </button>
        <span className="wordmark">
          onshape
          <span className="prototype-dot" />
        </span>
        <span className="header-divider" />
        <button
          className="document-title"
          onClick={() =>
            notify('Caster Wheel Assembly · local prototype document')
          }
        >
          Caster Wheel Assembly <ChevronDown size={13} />
          <span className="version">
            <GitBranch size={13} /> v1.0*
          </span>
        </button>
        <span className="header-divider" />
        <button
          title="Undo (Ctrl+Z)"
          disabled={!undoStack.length}
          onClick={undo}
        >
          <Undo2 size={16} />
        </button>
        <button
          title="Redo (Ctrl+Y)"
          disabled={!redoStack.length}
          onClick={redo}
        >
          <Redo2 size={16} />
        </button>
        <div className="header-space" />
        <button className="tool-search" onClick={() => setSearch('')}>
          <Search size={14} />
          <span>Search tools</span>
          <kbd>Alt C</kbd>
        </button>
        <span
          className="save-state"
          title="Local session only; cloud storage is not connected"
        >
          <CloudCheck size={15} /> All changes saved <small>· local</small>
        </span>
        <div className="avatars" title="Sample collaborators">
          <span>JL</span>
          <span>AK</span>
        </div>
        <Button
          className="share-button"
          size="sm"
          onClick={() =>
            notify('Sharing will be available when collaboration is connected.')
          }
        >
          Share
        </Button>
        <button
          aria-label="Comments"
          onClick={() => setPanel(panel === 'Comments' ? null : 'Comments')}
        >
          <MessageSquare size={17} />
        </button>
        <button
          aria-label="Notifications"
          onClick={() =>
            setPanel(panel === 'Notifications' ? null : 'Notifications')
          }
        >
          <Bell size={17} />
        </button>
        <button
          className="user-avatar"
          aria-label="User profile"
          onClick={() => setPanel(panel === 'Profile' ? null : 'Profile')}
        >
          JJ
        </button>
        <LayoutControls />
      </header>
      <AdaptiveLayout
        panels={{
          commandRibbon: (
            <CommandRibbon
              mode={sketch ? 'sketch' : tab.kind}
              selected={selectedTool}
              onTool={runTool}
              onCommit={finishSketch}
              onCancel={cancelSketch}
            />
          ),
          historyTree: (
            <FeatureTree
              features={features}
              filter={filter}
              onFilter={setFilter}
              planes={planes}
              onPlane={(i) =>
                setPlanes((p) => p.map((v, j) => (j === i ? !v : v)))
              }
              selected={selected}
              onSelect={(id) => {
                setSelected(id);
                setSelectedPart(null);
              }}
              onEdit={editFeature}
              onContext={(e, f) => openMenu(e, 'feature', f.id)}
              hidden={hidden}
              onHide={(i) =>
                setHidden((h) => h.map((v, j) => (j === i ? !v : v)))
              }
              onIsolate={(i) => {
                setHidden((h) =>
                  h.some(Boolean) ? [false, false] : [i !== 0, i !== 1],
                );
                notify('Part isolation toggled');
              }}
              onAppearance={() => setPanel('Appearance')}
              selectedPart={selectedPart}
              onPart={(i) => {
                setSelectedPart(i);
                setSelected(null);
              }}
              rollback={rollback}
              onRollback={setRollback}
              onCollapse={() =>
                layoutStore.setPanelMode('historyTree', 'hidden')
              }
            />
          ),
          leftSidebar: (
            <PartsSidebar
              filter={filter}
              hidden={hidden}
              onHide={(i) =>
                setHidden((h) => h.map((v, j) => (i === j ? !v : v)))
              }
              onIsolate={(i) =>
                setHidden((h) =>
                  h.some(Boolean) ? [false, false] : [i !== 0, i !== 1],
                )
              }
              onAppearance={() => setPanel('Appearance')}
              selectedPart={selectedPart}
              onPart={(i) => {
                setSelectedPart(i);
                setSelected(null);
              }}
            />
          ),
          elementTabs: (
            <footer className="element-bar">
              <button
                className="add-tab"
                aria-label="Add element"
                onClick={(e) => openMenu(e, 'add')}
              >
                <Plus size={19} />
                <ChevronDown size={10} />
              </button>
              <button
                className="element-list"
                aria-label="List elements"
                onClick={() => notify(tabs.map((t) => t.name).join(' · '))}
              >
                <Menu size={16} />
              </button>
              <div
                className="element-tabs"
                role="tablist"
                aria-label="Document elements"
              >
                {tabs.map((t) => {
                  const Icon = tabIcons[t.kind];
                  return (
                    <div
                      key={t.id}
                      className={`element-tab ${activeTab === t.id ? 'active' : ''}`}
                    >
                      <button
                        className="tab-main"
                        role="tab"
                        aria-selected={activeTab === t.id}
                        onClick={() => {
                          setActiveTab(t.id);
                          setSketch(false);
                          setDialog(null);
                          setSelectedTool('');
                        }}
                        onContextMenu={(e) => openMenu(e, 'tab', t.id)}
                      >
                        <Icon size={16} />
                        <span>{t.name}</span>
                      </button>
                      <button
                        className="tab-menu-trigger"
                        aria-label={`Options for ${t.name}`}
                        onClick={(e) => openMenu(e, 'tab', t.id)}
                      >
                        <ChevronDown size={11} />
                      </button>
                    </div>
                  );
                })}
              </div>
              <div className="header-space" />
              <span className="local-label">Interactive prototype</span>
              <span className="units">
                mm · deg <ChevronDown size={10} />
              </span>
            </footer>
          ),
        }}
        viewport={(navigationHost) => (
          <section className="viewport-area">
            <div className="viewport-breadcrumb">
              {tab.name}
              <ChevronRight size={12} />
              <span>Main</span>
            </div>
            <CADViewport
              navigationHost={navigationHost}
              ref={viewport}
              planes={planes}
              sketch={sketch}
              hidden={partHidden}
              color={color}
              opacity={opacity}
              display={display}
              section={section}
              widthMm={width}
              depthMm={features.find((f) => f.id === 'e1')?.depthMm}
              selectedPart={selectedPart}
              onSelect={(i) => {
                setSelectedPart(i);
                setSelected(null);
              }}
            />
            {tab.kind === 'drawing' && (
              <div className="drawing-placeholder">
                <FileText size={24} />
                <strong>{tab.name}</strong>
                <span>Drawing workspace scaffold</span>
                <p>
                  Sheet generation and projected views will be supplied by the
                  geometry engine.
                </p>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    setActiveTab(
                      tabs.find((t) => t.kind === 'part')?.id ?? tabs[0].id,
                    )
                  }
                >
                  Return to Part Studio
                </Button>
              </div>
            )}
            {sketch && (
              <div className="sketch-banner">
                <Pencil size={15} />
                <strong>
                  {sketchEditing?.name ??
                    `Sketch ${features.filter((f) => f.kind === 'Sketch').length + 1}`}
                  : Top Plane
                </strong>
                <span>
                  {selectedTool}
                  {construction ? ' · Construction' : ''}
                </span>
                <button title="Finish sketch" onClick={finishSketch}>
                  <Check size={17} />
                </button>
                <button title="Cancel sketch" onClick={cancelSketch}>
                  <X size={16} />
                </button>
                <small>Tool selection preview</small>
              </div>
            )}
            <div className="display-controls">
              <select
                aria-label="Display style"
                value={display}
                onChange={(e) => setDisplay(e.target.value as DisplayStyle)}
              >
                {[
                  'Shaded with edges',
                  'Shaded',
                  'Hidden edges visible',
                  'Wireframe',
                ].map((s) => (
                  <option key={s}>{s}</option>
                ))}
              </select>
              <button
                title="Section view"
                aria-pressed={section}
                className={section ? 'active' : ''}
                onClick={() => setSection(!section)}
              >
                <Scissors size={15} />
              </button>
              <button
                title="Toggle construction planes (P)"
                aria-pressed={planes.some(Boolean)}
                onClick={() =>
                  setPlanes((p) =>
                    p.some(Boolean)
                      ? [false, false, false]
                      : [true, true, true],
                  )
                }
              >
                <Eye size={15} />
              </button>
            </div>
            {dialog && (
              <FeatureDialog
                key={`${dialog.kind}-${dialog.feature?.id ?? 'new'}`}
                {...dialog}
                onClose={() => {
                  setDialog(null);
                  setSelectedTool('');
                }}
                onApply={applyFeature}
              />
            )}
            <div className="viewport-tag">
              <Box size={13} />
              {sketch
                ? 'Editing sketch'
                : tab.kind === 'assembly'
                  ? 'Assembly'
                  : 'Part Studio'}
              <span>•</span>
              <span>
                {selectedPart === null
                  ? 'Millimeter'
                  : `Part ${selectedPart + 1} selected`}
              </span>
            </div>
            <div className="viewport-help">
              Rotate <kbd>Drag</kbd>
              <span /> Pan <kbd>Right drag</kbd>
              <span /> Zoom <kbd>Scroll</kbd>
              <span /> Fit <kbd>F</kbd>
            </div>
            {toast && (
              <output className="cad-toast">
                <Info size={14} />
                {toast}
                <button
                  aria-label="Dismiss notification"
                  onClick={() => setToast('')}
                >
                  <X size={13} />
                </button>
              </output>
            )}
          </section>
        )}
        auxiliary={
          <>
            {' '}
            {panel && (
              <AuxiliaryPanel
                panel={panel}
                onClose={() => setPanel(null)}
                color={color}
                onColor={setColor}
                opacity={opacity}
                onOpacity={setOpacity}
                selectedPart={selectedPart}
                width={width}
                onWidth={setWidth}
              />
            )}
            <nav className="aux-rail" aria-label="Auxiliary panels">
              {(
                [
                  ['Appearance', Palette],
                  ['Measure', Ruler],
                  ['Configuration', Settings2],
                  ['Properties', Info],
                ] as [string, LucideIcon][]
              ).map(([name, Icon]) => (
                <button
                  key={name}
                  className={panel === name ? 'active' : ''}
                  aria-label={name}
                  title={name}
                  onClick={() => setPanel(panel === name ? null : name)}
                >
                  <Icon size={19} />
                </button>
              ))}
            </nav>
          </>
        }
      />

      {menu && (
        <>
          <button
            aria-label="Dismiss menu"
            className="menu-dismiss"
            onClick={() => setMenu(null)}
          />
          <div
            className="cad-context-menu"
            role="menu"
            style={{ left: menu.x, top: menu.y }}
          >
            {menu.type === 'add' ? (
              <>
                <button role="menuitem" onClick={() => addTab('part')}>
                  <Box size={14} /> Create Part Studio
                </button>
                <button role="menuitem" onClick={() => addTab('assembly')}>
                  <Layers size={14} /> Create Assembly
                </button>
                <button role="menuitem" onClick={() => addTab('drawing')}>
                  <FileText size={14} /> Create Drawing
                </button>
                <hr />
                <button
                  role="menuitem"
                  onClick={() => {
                    fileInput.current?.click();
                    setMenu(null);
                  }}
                >
                  Import prototype JSON…
                </button>
              </>
            ) : menu.type === 'document' ? (
              <>
                <button
                  role="menuitem"
                  onClick={() => {
                    exportTab(activeTab);
                    setMenu(null);
                  }}
                >
                  Export prototype JSON
                </button>
                <button
                  role="menuitem"
                  onClick={() => {
                    setPlanes([true, true, true]);
                    setHidden([false, false]);
                    viewport.current?.fit();
                    setMenu(null);
                  }}
                >
                  Reset view
                </button>
              </>
            ) : (
              (menu.type === 'feature'
                ? [
                    'Edit',
                    'Rename',
                    features.find((f) => f.id === menu.id)?.suppressed
                      ? 'Unsuppress'
                      : 'Suppress',
                    'Delete',
                  ]
                : ['Rename', 'Duplicate', 'Export prototype JSON', 'Delete']
              ).map((a) => (
                <button
                  role="menuitem"
                  key={a}
                  disabled={
                    menu.type === 'tab' && a === 'Delete' && tabs.length === 1
                  }
                  onClick={() => contextAction(a)}
                >
                  {a}
                </button>
              ))
            )}
          </div>
        </>
      )}
      {rename && (
        <div className="modal-scrim">
          <dialog open className="rename-dialog" aria-label="Rename">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (!rename.name.trim()) return;
                if (rename.type === 'feature')
                  mutate(
                    features.map((f) =>
                      f.id === rename.id
                        ? { ...f, name: rename.name.trim() }
                        : f,
                    ),
                  );
                else
                  setTabs(
                    tabs.map((t) =>
                      t.id === rename.id
                        ? { ...t, name: rename.name.trim() }
                        : t,
                    ),
                  );
                setRename(null);
              }}
            >
              <strong>
                Rename {rename.type === 'tab' ? 'element' : 'feature'}
              </strong>
              <input
                autoFocus
                aria-label="New name"
                value={rename.name}
                onChange={(e) => setRename({ ...rename, name: e.target.value })}
              />
              <div className="dialog-footer">
                <Button
                  variant="outline"
                  size="sm"
                  type="button"
                  onClick={() => setRename(null)}
                >
                  Cancel
                </Button>
                <Button size="sm" type="submit" disabled={!rename.name.trim()}>
                  Rename
                </Button>
              </div>
            </form>
          </dialog>
        </div>
      )}
      {search !== null && (
        <div className="modal-scrim">
          <dialog open className="command-search" aria-label="Search tools">
            <div className="command-search-input">
              <Search size={18} />
              <input
                ref={searchInput}
                aria-label="Search command"
                placeholder="Search tools and features…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              <button title="Close search" onClick={() => setSearch(null)}>
                <X size={16} />
              </button>
            </div>
            <div className="search-results">
              {solidTools
                .flat()
                .filter(([name]) =>
                  name.toLowerCase().includes(search.toLowerCase()),
                )
                .map(([name, Icon]) => (
                  <button key={name} onClick={() => runTool(name)}>
                    <Icon size={17} />
                    <span>{name}</span>
                    <small>Part modeling</small>
                  </button>
                ))}
              {features
                .filter((f) =>
                  f.name.toLowerCase().includes(search.toLowerCase()),
                )
                .map((f) => (
                  <button
                    key={f.id}
                    onClick={() => {
                      setSearch(null);
                      editFeature(f);
                    }}
                  >
                    <Box size={17} />
                    <span>{f.name}</span>
                    <small>Feature</small>
                  </button>
                ))}
            </div>
          </dialog>
        </div>
      )}
      <input
        hidden
        type="file"
        ref={fileInput}
        accept=".json"
        onChange={async (e) => {
          const file = e.target.files?.[0];
          if (!file) return;
          try {
            const data = JSON.parse(await file.text());
            if (
              data.prototype !== true ||
              !Array.isArray(data.features) ||
              !data.features.every(
                (f: Feature) =>
                  typeof f.id === 'string' &&
                  typeof f.name === 'string' &&
                  typeof f.kind === 'string' &&
                  (f.depthMm === undefined ||
                    (Number.isFinite(f.depthMm) &&
                      f.depthMm > 0 &&
                      f.depthMm <= 150)),
              )
            )
              throw new Error();
            mutate(data.features);
            notify('Prototype feature history imported');
          } catch {
            notify('Import requires a valid exported .mockup.json file.');
          }
          e.target.value = '';
        }}
      />
    </main>
  );
}
