import {CreateMenu, type CreateMenuChoices, type CreateChoice} from "./CreateMenu";
import {ContextMenu} from "./ContextMenu";
import { DocumentHistory } from "./DocumentHistory";
import { useEffect, useRef, useState } from "react";
import { CollapsibleSidebar, SidebarLabel, SidebarToggle, AppIcon, AetherIcon, Button, TextField , type AetherIconName } from "@aether/ui";
import { api } from "./api";
import "./library.css";

type Entry = {
  id: string;
  name: string;
  kind: "file" | "folder";
  scope: string;
  parent: string | null;
  owner: string;
  writable: boolean;
  revision: number;
  modified: number;
  size: number;
  data_base64?: string;
};
type View = "home" | "personal" | "recent" | "workspace" | "shared" | "trash";


function ToolMenu({
  label,
  icon,
  items,
  onPick,
}: {
  label: React.ReactNode;
  icon?: React.ReactNode;
  items: { id: string; label: string; icon?: React.ReactNode; checked?: boolean }[];
  onPick: (id: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const dismiss = (event: MouseEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    window.addEventListener("pointerdown", dismiss);
    return () => window.removeEventListener("pointerdown", dismiss);
  }, [open]);
  return (
    <div ref={root} className="library-toolmenu">
      <button
        type="button"
        className="library-tool"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        {icon}
        {label}
        <AetherIcon name="chevron" width={11} height={11} />
      </button>
      {open && (
        <div role="menu" className="library-toolmenu-list">
          {items.map((item) => (
            <button
              key={item.id}
              type="button"
              role="menuitemradio"
              aria-checked={item.checked}
              onClick={() => {
                setOpen(false);
                onPick(item.id);
              }}
            >
              {item.icon}
              <span>{item.label}</span>
              {item.checked ? <span className="library-toolmenu-check">✓</span> : null}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

export interface LibraryAppType {
  id: string;
  label: string;
  icon: AetherIconName;
  test: RegExp;
}
export interface LibraryAppConfig {
  brand: string;
  appIcon: "cad" | "animation";
  appUrl: string;
  accept: string;
  uploadPattern: RegExp;
  uploadHint: string;
  heroLead: string;
  emptyHint: string;
  fallbackIcon: AetherIconName;
  types: readonly LibraryAppType[];
  menu: CreateMenuChoices;
  start: readonly {
    kind: string;
    title: string;
    tagline: string;
    icon: AetherIconName;
    action?: "new-doc" | "dialog" | "import";
    tooltip?: string;
  }[];
}
const LIBRARY_APPS: Record<"cad" | "animation", LibraryAppConfig> = {
  cad: {
    brand: "Aether CAD",
    appIcon: "cad",
    appUrl: "/cad/index.html",
    accept: ".acpart,.acad,.acasm,.cadpart,.aether,.step,.stp",
    uploadPattern: /\.(acpart|acad|acasm|cadpart|aether|step|stp)$/i,
    uploadHint: "Import an .acpart, .acad, .acasm, .step or legacy CAD file.",
    heroLead: "Create a part, pick up recent work, or bring an existing design into your library.",
    emptyHint: "Create a Part or import a design to get started.",
    fallbackIcon: "file-part",
    types: [
      { id: "part", label: "Parts", icon: "file-part", test: /\.(acpart|cadpart)$/ },
      { id: "assembly", label: "Assemblies", icon: "file-assembly", test: /\.(acasm|aether)$/ },
      { id: "drawing", label: "Drawings", icon: "file-drawing", test: /\.acdraw$/ },
      { id: "project", label: "Projects", icon: "file-project", test: /\.acad$/ },
    ],
    menu: [["project","Project document","document"],["folder","Folder","folder"],["part","Part","design"],["assembly","Assembly","assembly"],["import","Import file…","import"]],
    start: [
      { kind: "part", title: "Part", tagline: "Model exact solid geometry", icon: "file-part", action: "new-doc" },
      { kind: "assembly", title: "Assembly", tagline: "Mate parts into mechanisms", icon: "file-assembly", action: "dialog" },
      { kind: "drawing", title: "Drawing", tagline: "Dimensioned sheets — open a document", icon: "file-drawing", tooltip: "Drawing sheets are created inside an open Part or Assembly document." },
      { kind: "project", title: "Project", tagline: "Group related documents", icon: "file-project", action: "dialog" },
    ],
  },
  animation: {
    brand: "Aether Animation",
    appIcon: "animation",
    appUrl: "/animation/index.html",
    accept: ".anima,.aether",
    uploadPattern: /\.(anima|aether)$/i,
    uploadHint: "Import an .anima character or .aether workspace file.",
    heroLead: "Create a character, pick up recent work, or bring an existing rig into your library.",
    emptyHint: "Create a Character or import a rig to get started.",
    fallbackIcon: "file-character",
    types: [
      { id: "character", label: "Characters", icon: "file-character", test: /\.anima$/ },
      { id: "workspace", label: "Workspaces", icon: "file-assembly", test: /\.aether$/ },
      { id: "show", label: "Shows", icon: "file-show", test: /\.show$/ },
    ],
    menu: [["folder","Folder","folder"],["character","Character","design"],["import","Import file…","import"]],
    start: [
      { kind: "character", title: "Character", tagline: "Rig and pose a machine", icon: "file-character", action: "new-doc" },
      { kind: "clip", title: "Clip", tagline: "Author motion inside a character", icon: "file-clip", tooltip: "Clips are authored inside an open character." },
      { kind: "show", title: "Show", tagline: "Sequence clips for playback", icon: "file-show", tooltip: "Show authoring arrives with the web session bridge." },
      { kind: "project", title: "Project", tagline: "Group related documents", icon: "file-project", tooltip: "Projects are a CAD library feature today." },
    ],
  },
};


const titles = {
  home: "Home",
  personal: "My files",
  recent: "Recently opened",
  workspace: "Workspace",
  shared: "Shared",
  trash: "Recycle bin",
};
export function LibraryHome({ workspace, app = "cad" }: { workspace: string; app?: "cad" | "animation" }) {
  const cfg = LIBRARY_APPS[app];
  const typeOf = (file: { kind: string; name: string }) => file.kind === "folder" ? "folder" : (cfg.types.find((type) => type.test.test(file.name.toLowerCase()))?.id ?? "import");
  const iconOf = (file: { kind: string; name: string }): AetherIconName => file.kind === "folder" ? "folder" : (cfg.types.find((type) => type.test.test(file.name.toLowerCase()))?.icon ?? cfg.fallbackIcon);
  const [view, setView] = useState<View>("home");
  const [userName, setUserName] = useState("");
  useEffect(() => {
    const sync = (event: Event) => {
      const detail = (event as CustomEvent<{ full_name?: string; username?: string } | null>).detail;
      setUserName(detail ? detail.full_name || detail.username || "" : "");
    };
    document.addEventListener("aether-account", sync);
    void api<{ user: { full_name?: string; username?: string } | null }>("/api/status").then(
      (status) => setUserName(status.user ? status.user.full_name || status.user.username || "" : ""),
      () => undefined,
    );
    return () => document.removeEventListener("aether-account", sync);
  }, []);
  const [files, setFiles] = useState<Entry[]>([]);
  const [folders, setFolders] = useState<Entry[]>([]);
  const [selected, setSelected] = useState<Entry | null>(null);
  const [query, setQuery] = useState("");
  const [grid, setGrid] = useState(false);
  const [typeFilter, setTypeFilter] = useState<string>("all");
  const [nameFilter, setNameFilter] = useState("");
  const [menu, setMenu] = useState<{ x: number; y: number; file?: Entry } | null>(null);
  const [showDetails, setShowDetails] = useState(true);
  const [sortKey, setSortKey] = useState<"name" | "opened" | "owner">("opened");
  const [sortAsc, setSortAsc] = useState(false);
  const filterText = nameFilter.trim().toLowerCase();
  const compareShown = (a: Entry, b: Entry) => {
    const result =
      sortKey === "name"
        ? a.name.localeCompare(b.name)
        : sortKey === "owner"
          ? a.owner.localeCompare(b.owner) || a.name.localeCompare(b.name)
          : a.modified - b.modified;
    return sortAsc ? result : -result;
  };
  const shown = files.filter((file) => {
    const type = typeOf(file);
    if (typeFilter !== "all" && !(type === typeFilter || (type === "import" && typeFilter === cfg.types[0].id))) return false;
    if (filterText && !file.name.toLowerCase().includes(filterText) && !file.owner.toLowerCase().includes(filterText)) return false;
    return true;
  }).sort(compareShown);
  const startCreate = (choice: CreateChoice) => {
    if (choice === "part" || choice === "character") newDocument(choice);
    else if (choice === "import") input.current?.click();
    else {
      setName("");
      setDialog(choice);
    }
  };
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [dialog, setDialog] = useState<
    "folder" | "rename" | "project" | "assembly" | null
  >(null);
  const [showHistory, setShowHistory] = useState(false);
  const [name, setName] = useState("");
  const input = useRef<HTMLInputElement>(null);
  const parent = folders.at(-1)?.id ?? null;
  const list = async () => {
    if (view === "trash" || view === "shared") { setFiles([]); setSelected(null); return; }
    const result = await api<{ files: Entry[] }>("/api/library/list", {
      app,
      view: view === "home" ? (query ? "personal" : "recent") : view,
      parent,
      query,
    });
    setFiles(result.files);
    setSelected(
      (current) => result.files.find((f) => f.id === current?.id) ?? null,
    );
  };
  useEffect(() => {
    let live = true;
    setError("");
    if (view === "trash" || view === "shared") { setFiles([]); setSelected(null); return; }
    api<{ files: Entry[] }>("/api/library/list", {
      app,
      view: view === "home" ? (query ? "personal" : "recent") : view,
      parent,
      query,
    })
      .then((r) => {
        if (live) {
          setFiles(r.files);
          setSelected(null);
        }
      })
      .catch((e) => live && setError(e.message));
    return () => {
      live = false;
    };
  }, [view, parent, query]);
  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setError("");
    try {
      await fn();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };
  const navigate = (next: View) => {
    setView(next);
    setFolders([]);
    setQuery("");
  };
  const open = (file: Entry) => {
    if (file.kind === "folder") {
      setFolders([...folders, file]);
      setQuery("");
      return;
    }
    location.assign(cfg.appUrl + "?document=" + encodeURIComponent(file.id));
  };
  const scope = view === "workspace" ? "workspace" : "personal";
  const upload = async (file: File) => {
    if (!cfg.uploadPattern.test(file.name))
      throw new Error(
        cfg.uploadHint,
      );
    if (file.size > 6 * 1024 * 1024)
      throw new Error("Choose a file up to 6 MB.");
    const bytes = new Uint8Array(await file.arrayBuffer());
    let binary = "";
    for (let i = 0; i < bytes.length; i += 32768)
      binary += String.fromCharCode(...bytes.subarray(i, i + 32768));
    await api("/api/library/create", {
      app,
      name: file.name,
      scope,
      parent,
      data_base64: btoa(binary),
    });
    if (view === "home" || view === "recent")
      navigate(scope === "workspace" ? "workspace" : "personal");
    else await list();
  };
  const edit = async () => {
    if (dialog === "project" || dialog === "assembly") {
      const project = await api<Entry>("/api/library/project_create", {
        app,
        name,
        scope,
        parent,
        packaging: dialog === "assembly" ? "assembly" : "project",
      });
      open(project);
      return;
    }
    if (dialog === "folder")
      await api("/api/library/create", {
        app,
        name,
        kind: "folder",
        scope,
        parent,
      });
    else if (selected)
      await api("/api/library/rename", {
        app,
        id: selected.id,
        name,
        expected_revision: selected.revision,
      });
    const folderCreated=dialog === "folder";
    setDialog(null);
    if(folderCreated && (view === "home" || view === "recent"))navigate(scope === "workspace" ? "workspace" : "personal");
    else await list();
  };
  const share = () =>
    run(async () => {
      if (!selected) return;
      await api("/api/library/share", {
        app,
        id: selected.id,
        scope: selected.scope === "personal" ? "workspace" : "personal",
        expected_revision: selected.revision,
      });
      await list();
    });
  const download = () =>
    run(async () => {
      if (!selected) return;
      const file = await api<Entry>("/api/library/read", {
        app,
        id: selected.id,
      });
      const bytes = Uint8Array.from(atob(file.data_base64!), (c) =>
        c.charCodeAt(0),
      );
      const url = URL.createObjectURL(new Blob([bytes]));
      const a = document.createElement("a");
      a.href = url;
      a.download = file.name;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
  const newDocument = (kind: string) =>
    location.assign(
      cfg.appUrl + "?new=" + kind +
        (parent ? "&folder=" + encodeURIComponent(parent) : "") +
        "&scope=" +
        scope,
    );
  return (
    <div className={"studio library-root" + (showDetails ? "" : " details-closed")}>
      <header className="library-top">
        <a href="/" className="library-brand" title="Aether Studio">
          <AppIcon app={cfg.appIcon} size={36} />
        </a>
        <strong>{cfg.brand}</strong>
        <span className="library-workspace">{workspace}</span>
        <TextField
          aria-label={"Search " + cfg.brand + " files"}
          placeholder="Search files and folders"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div data-aether-account="" />
      </header>
      <CollapsibleSidebar id="cad-library" ariaLabel="CAD library sidebar" className="library-nav" toggle="custom">
        <CreateMenu disabled={busy} onChoose={startCreate} items={cfg.menu}/>
        <input
          ref={input}
          type="file"
          hidden
          accept={cfg.accept}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void run(() => upload(file));
            e.target.value = "";
          }}
        />
        <div className="library-user-row">
          <SidebarLabel><strong>{userName || workspace}</strong></SidebarLabel>
          <SidebarToggle />
        </div>
        <nav aria-label="CAD library">
          {(["home", "personal", "shared", "trash"] as View[]).map((id) => (
            <button
              key={id}
              aria-current={view === id ? "page" : undefined}
              onClick={() => navigate(id)}
            >
              <AetherIcon
                name={
                  id === "home"
                    ? "home"
                    : id === "recent"
                      ? "history"
                      : id === "shared"
                        ? "link"
                        : id === "trash"
                          ? "delete"
                          : "folder"
                }
              />
              <SidebarLabel>{titles[id]}</SidebarLabel>
            </button>
          ))}
        </nav>
        <div className="library-section-title"><SidebarLabel>Workspaces</SidebarLabel></div>
        <div className="library-workspaces">
          <button
            type="button"
            aria-current={view === "workspace" ? "page" : undefined}
            title={workspace}
            onClick={() => navigate("workspace")}
          >
            <span className="library-workspace-tile" aria-hidden="true">{workspace.slice(0, 1).toUpperCase()}</span>
            <SidebarLabel>{workspace}</SidebarLabel>
          </button>
          <button type="button" disabled title="Planned — not functional yet."><AetherIcon name="new" /><SidebarLabel>New workspace…</SidebarLabel></button>
        </div>
        <div className="library-nav-spacer" />

      </CollapsibleSidebar>
      <main
        className="library-main"
        onContextMenu={(e) => {
          e.preventDefault();
          setMenu({ x: e.clientX, y: e.clientY });
        }}
      >
        {menu && (
          <ContextMenu
            x={menu.x}
            y={menu.y}
            onClose={() => setMenu(null)}
            onPick={(id) => {
              const target = menu.file;
              setMenu(null);
              if (id === "open" && target) open(target);
              else if (id === "details" && target) setSelected(target);
              else if (id.startsWith("new-"))
                startCreate(id.slice(4) as CreateChoice);
            }}
            items={
              menu.file
                ? [
                    { id: "open", label: "Open", icon: <AetherIcon name="open" width={15} height={15} /> },
                    { id: "details", label: "Details", icon: <AetherIcon name="document" width={15} height={15} /> },
                  ]
                : [
                    {
                      id: "add",
                      label: "Add New",
                      icon: <span className="library-context-plus">+</span>,
                      children: cfg.menu.map(([id, label, icon]) => ({
                        id: "new-" + id,
                        label,
                        icon: <AetherIcon name={icon} width={15} height={15} />,
                      })),
                    },
                    { id: "details", label: "Details", icon: <AetherIcon name="document" width={15} height={15} />, disabled: !selected },
                  ]
            }
          />
        )}
        {folders.length > 0 && <div className="library-breadcrumb">
          <button onClick={() => setFolders([])}>{view === "workspace" ? workspace : titles[view]}</button>
          {folders.map((folder, index) => (
            <span key={folder.id}>
              {" "}
              /{" "}
              <button onClick={() => setFolders(folders.slice(0, index + 1))}>
                {folder.name}
              </button>
            </span>
          ))}
        </div>}
        {error && (
          <div className="message error" role="alert">
            {error}
          </div>
        )}
        {(view === "home" || (view === "personal" && !parent && !query)) && (
          <section className="library-welcome">
            <div>
              <span className="library-eyebrow">YOUR DESIGN WORKSPACE</span>
              <h1>Make room for your next idea.</h1>
              <p>
                {cfg.heroLead}
              </p>

            </div>
            <div className="library-hero-art" aria-hidden="true">
              <AppIcon app={cfg.appIcon} size={135} />
            </div>
          </section>
        )}
        {(view === "home" || (view === "personal" && !parent && !query)) && (
          <section className="library-start" aria-label="Get started">
            <h2>Get started</h2>
            <div className="library-start-cards">
              {cfg.start.map((card) => (
                <button
                  key={card.kind}
                  type="button"
                  disabled={busy || !card.action}
                  title={card.tooltip}
                  onClick={() => {
                    if (card.action === "new-doc") newDocument(card.kind);
                    else if (card.action === "dialog") { setName(""); setDialog(card.kind as "project" | "assembly" | "folder"); }
                    else if (card.action === "import") input.current?.click();
                  }}
                >
                  <AetherIcon name={card.icon} width={34} height={34} />
                  <span><strong>{card.title}</strong><small>{card.tagline}</small></span>
                </button>
              ))}
            </div>
          </section>
        )}
        <div className="library-list-heading">
          <h2>{view === "home" ? "Recently opened" : view === "workspace" ? workspace : titles[view]}</h2>
          <span>{shown.length} items</span>

        </div>
        <div className="library-filter-row">
          {selected ? (
          <div className="library-filter-left library-command-bar">
            <button type="button" className="library-tool" onClick={() => open(selected)}>
              <AetherIcon name="open" width={15} height={15} /> Open
            </button>
            {selected.writable && (
              <button type="button" className="library-tool" onClick={() => { setName(selected.name); setDialog("rename"); }}>
                <AetherIcon name="document" width={15} height={15} /> Rename
              </button>
            )}
            {selected.kind === "file" && (
              <>
                <button type="button" className="library-tool" disabled={busy} onClick={download}>
                  <AetherIcon name="import" width={15} height={15} /> Download
                </button>
                <button
                  type="button"
                  className="library-tool"
                  disabled={busy}
                  onClick={() =>
                    run(async () => {
                      await api("/api/library/copy", { app, id: selected.id });
                      if (view === "personal" && !parent && !query) await list();
                      else navigate("personal");
                    })
                  }
                >
                  <AetherIcon name="save" width={15} height={15} /> Duplicate
                </button>
                {selected.writable && (
                  <button type="button" className="library-tool" disabled={busy} onClick={share}>
                    <AetherIcon name="link" width={15} height={15} /> {selected.scope === "workspace" ? "Make private" : "Share"}
                  </button>
                )}
                <button type="button" className="library-tool" onClick={() => setShowHistory(true)}>
                  <AetherIcon name="history" width={15} height={15} /> History
                </button>
              </>
            )}
            <button type="button" className="library-tool" disabled title="Recycle bin arrives with library delete support.">
              <AetherIcon name="delete" width={15} height={15} /> Delete
            </button>
          </div>
          ) : (
          <div className="library-filter-left">
            <ToolMenu
              label={typeFilter === "all" ? "All" : (cfg.types.find((type) => type.id === typeFilter)?.label ?? "All")}
              icon={typeFilter !== "all" ? <AetherIcon name={cfg.types.find((type) => type.id === typeFilter)?.icon ?? cfg.fallbackIcon} width={15} height={15} /> : null}
              onPick={(id) => setTypeFilter(id)}
              items={[
                { id: "all", label: "All", checked: typeFilter === "all" },
                ...cfg.types.map((type) => ({
                  id: type.id,
                  label: type.label,
                  icon: <AetherIcon name={type.icon} width={15} height={15} />,
                  checked: typeFilter === type.id,
                })),
              ]}
            />
            <input
              className="library-name-filter"
              aria-label="Filter by name or person"
              placeholder="Filter by name or person"
              value={nameFilter}
              onChange={(e) => setNameFilter(e.target.value)}
            />
          </div>
          )}
          <div className="library-list-tools">
            {selected && (
              <button
                type="button"
                className="library-tool library-selected-chip"
                aria-label="Clear selection"
                onClick={() => setSelected(null)}
              >
                ✕ 1 selected
              </button>
            )}
            <ToolMenu
              label="Sort"
              icon={<span className="library-tool-glyph">⇅</span>}
              onPick={(id) => {
                if (id === "asc" || id === "desc") setSortAsc(id === "asc");
                else setSortKey(id as "name" | "opened" | "owner");
              }}
              items={[
                { id: "opened", label: "Opened", checked: sortKey === "opened" },
                { id: "name", label: "Name", checked: sortKey === "name" },
                { id: "owner", label: "Owner", checked: sortKey === "owner" },
                { id: "asc", label: "Ascending", checked: sortAsc },
                { id: "desc", label: "Descending", checked: !sortAsc },
              ]}
            />
            <ToolMenu
              label=""
              icon={<AetherIcon name={grid ? "layout" : "items"} />}
              onPick={(id) => setGrid(id === "grid")}
              items={[
                { id: "list", label: "List view", icon: <AetherIcon name="items" width={15} height={15} />, checked: !grid },
                { id: "grid", label: "Grid view", icon: <AetherIcon name="layout" width={15} height={15} />, checked: grid },
              ]}
            />
            <button
              type="button"
              className="library-tool"
              aria-pressed={showDetails}
              onClick={() => setShowDetails(!showDetails)}
            >
              <AetherIcon name="sidebar" /> Details
            </button>
          </div>
        </div>
        {view === "workspace" && (
          <p className="library-note">
            The {workspace} workspace library. Owners edit originals;
            everyone with CAD access can open or copy them.
          </p>
        )}
        {view === "shared" && (
          <p className="library-note">
            Files individually shared with you will appear here once
            per-user sharing lands on the host. Workspace files live under
            your workspace in the sidebar.
          </p>
        )}
        {view === "trash" && (
          <p className="library-note">
            Deleted files will be recoverable here once host-side deletion
            lands.
          </p>
        )}
        {shown.length === 0 ? (
          <div className="library-empty">
            <AetherIcon name="folder" width={48} height={48} />
            <h3>
              {query
                ? "No matching files"
                : view === "home" || view === "recent"
                  ? "Your recent work will appear here"
                  : "This folder is ready for your work"}
            </h3>
            <p>
              {query
                ? "Try another search."
                : cfg.emptyHint}
            </p>
          </div>
        ) : grid ? (
          <div className="library-grid">
            {shown.map((file) => (
              <button
                key={file.id}
                className={selected?.id === file.id ? "selected" : ""}
                onClick={() => setSelected(file)}
                onDoubleClick={() => open(file)}
                onContextMenu={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setSelected(file);
                  setMenu({ x: e.clientX, y: e.clientY, file });
                }}
              >
                <AetherIcon
                  name={iconOf(file)}
                  width={56}
                  height={56}
                />
                <strong>{file.name}</strong>
                <small>{file.owner}</small>
              </button>
            ))}
          </div>
        ) : (
          <table className="library-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Opened</th>
                <th>Owner</th>
              </tr>
            </thead>
            <tbody>
              {shown.map((file) => (
                <tr
                  key={file.id}
                  className={selected?.id === file.id ? "selected" : ""}
                  onClick={() => setSelected(file)}
                  onDoubleClick={() => open(file)}
                  onContextMenu={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    setSelected(file);
                    setMenu({ x: e.clientX, y: e.clientY, file });
                  }}
                >
                  <td>
                    <button
                      onClick={() => setSelected(file)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") open(file);
                      }}
                    >
                      <AetherIcon name={iconOf(file)} width={28} height={28} />
                      <span className="library-file-name">
                        <strong>{file.name}</strong>
                        <small>{file.scope === "workspace" ? "Workspace shared" : "My files"}</small>
                      </span>
                    </button>
                  </td>
                  <td>{new Date(file.modified * 1000).toLocaleDateString()}</td>
                  <td>{file.owner}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </main>
      <aside className="library-details" aria-hidden={!showDetails}>
        <h2>Details</h2>
        {selected ? (
          <>
            <AetherIcon name={iconOf(selected)} width={64} height={64} />
            <h3>{selected.name}</h3>
            <dl>
              <dt>Owner</dt>
              <dd>{selected.owner}</dd>
              <dt>Modified</dt>
              <dd>{new Date(selected.modified * 1000).toLocaleString()}</dd>
              <dt>Access</dt>
              <dd>
                {selected.scope === "workspace"
                  ? "Workspace can view; owner can edit"
                  : "Only you"}
              </dd>
              {selected.kind === "file" && (
                <>
                  <dt>Size</dt>
                  <dd>{Math.max(1, Math.round(selected.size / 1024))} KB</dd>
                </>
              )}
            </dl>
            <Button primary onClick={() => open(selected)}>
              Open {selected.kind === "folder" ? "folder" : "file"}
            </Button>
            {selected.writable && (
              <Button
                onClick={() => {
                  setName(selected.name);
                  setDialog("rename");
                }}
              >
                Rename
              </Button>
            )}
            {selected.kind === "file" && (
              <>
                <Button onClick={() => setShowHistory(true)}>
                  Versions and history
                </Button>
                <Button onClick={download} disabled={busy}>
                  Download copy
                </Button>
                <Button
                  disabled={busy}
                  onClick={() =>
                    run(async () => {
                      await api("/api/library/copy", {
                        app,
                        id: selected.id,
                      });
                      if (view === "personal" && !parent && !query)
                        await list();
                      else navigate("personal");
                    })
                  }
                >
                  Make a copy in My files
                </Button>
                {selected.writable && (
                  <Button onClick={share} disabled={busy}>
                    {selected.scope === "workspace"
                      ? "Make private"
                      : "Share with workspace"}
                  </Button>
                )}
              </>
            )}
          </>
        ) : (
          <div className="library-details-empty">
            <AetherIcon name="document" width={70} height={70} />
            <p>Select a file or folder to see its details.</p>
          </div>
        )}
      </aside>
      {showHistory && selected && (
        <DocumentHistory
          file={selected}
          onClose={() => setShowHistory(false)}
          onChanged={list}
        />
      )}
      {dialog && (
        <div className="library-modal">
          <form
            role="dialog"
            aria-modal="true"
            aria-label={
              dialog === "folder"
                ? "New folder"
                : dialog === "project"
                  ? "New project"
                  : dialog === "assembly"
                    ? "New Assembly"
                    : "Rename"
            }
            onSubmit={(e) => {
              e.preventDefault();
              void run(edit);
            }}
          >
            <h2>
              {dialog === "folder"
                ? "New folder"
                : dialog === "project"
                  ? "New project"
                  : dialog === "assembly"
                    ? "New Assembly"
                    : "Rename"}
            </h2>
            <label>
              Name
              <TextField
                aria-label="Name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                autoFocus
                required
                maxLength={180}
              />
            </label>
            {error && <p role="alert">{error}</p>}
            <div>
              <Button onClick={() => setDialog(null)}>Cancel</Button>
              <Button primary type="submit" disabled={busy}>
                {dialog === "folder"
                  ? "Create folder"
                  : dialog === "project"
                    ? "Create project"
                    : dialog === "assembly"
                      ? "Create Assembly"
                      : "Save name"}
              </Button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
