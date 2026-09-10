import {CreateMenu} from "./CreateMenu";
import { DocumentHistory } from "./DocumentHistory";
import { useEffect, useRef, useState } from "react";
import { AppIcon, AetherIcon, Button, TextField } from "@aether/ui";
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
type View = "home" | "personal" | "recent" | "workspace";
const titles = {
  home: "Home",
  personal: "My files",
  recent: "Recently opened",
  workspace: "Workspace shared",
};
export function LibraryHome({ workspace }: { workspace: string }) {
  const [view, setView] = useState<View>("home");
  const [files, setFiles] = useState<Entry[]>([]);
  const [folders, setFolders] = useState<Entry[]>([]);
  const [selected, setSelected] = useState<Entry | null>(null);
  const [query, setQuery] = useState("");
  const [grid, setGrid] = useState(false);
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
    const result = await api<{ files: Entry[] }>("/api/library/list", {
      app: "cad",
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
    api<{ files: Entry[] }>("/api/library/list", {
      app: "cad",
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
    location.assign("/cad/index.html?document=" + encodeURIComponent(file.id));
  };
  const scope = view === "workspace" ? "workspace" : "personal";
  const upload = async (file: File) => {
    if (!/\.(acpart|acad|acasm|cadpart|aether|step|stp)$/i.test(file.name))
      throw new Error(
        "Import an .acpart, .acad, .acasm, .step or legacy CAD file.",
      );
    if (file.size > 6 * 1024 * 1024)
      throw new Error("Choose a file up to 6 MB.");
    const bytes = new Uint8Array(await file.arrayBuffer());
    let binary = "";
    for (let i = 0; i < bytes.length; i += 32768)
      binary += String.fromCharCode(...bytes.subarray(i, i + 32768));
    await api("/api/library/create", {
      app: "cad",
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
        app: "cad",
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
        app: "cad",
        name,
        kind: "folder",
        scope,
        parent,
      });
    else if (selected)
      await api("/api/library/rename", {
        app: "cad",
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
        app: "cad",
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
        app: "cad",
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
  const createPart = () =>
    location.assign(
      "/cad/index.html?new=part" +
        (parent ? "&folder=" + encodeURIComponent(parent) : "") +
        "&scope=" +
        scope,
    );
  return (
    <div className="studio library-root">
      <header className="library-top">
        <a href="/" className="library-brand" title="Aether Studio">
          <AppIcon app="cad" size={36} />
        </a>
        <strong>Aether CAD</strong>
        <span className="library-workspace">{workspace}</span>
        <TextField
          aria-label="Search CAD files"
          placeholder="Search files and folders"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div data-aether-account="" />
      </header>
      <aside className="library-nav">
        <CreateMenu disabled={busy} onChoose={choice=>{
          if(choice === "part")createPart();
          else if(choice === "import")input.current?.click();
          else {setName("");setDialog(choice);}
        }}/>
        <input
          ref={input}
          type="file"
          hidden
          accept=".acpart,.acad,.acasm,.cadpart,.aether,.step,.stp"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void run(() => upload(file));
            e.target.value = "";
          }}
        />
        <nav aria-label="CAD library">
          {(["home", "personal", "recent", "workspace"] as View[]).map((id) => (
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
                      : id === "workspace"
                        ? "assembly"
                        : "folder"
                }
              />
              {titles[id]}
            </button>
          ))}
        </nav>
        <div className="library-nav-footer">
          <AetherIcon name="save" />
          <span>
            Saved on your server
            <br />
            <small>Available across your devices</small>
          </span>
        </div>
        <a href="/">← Aether Studio</a>
      </aside>
      <main className="library-main">
        <div className="library-breadcrumb">
          <button onClick={() => setFolders([])}>{titles[view]}</button>
          {folders.map((folder, index) => (
            <span key={folder.id}>
              {" "}
              /{" "}
              <button onClick={() => setFolders(folders.slice(0, index + 1))}>
                {folder.name}
              </button>
            </span>
          ))}
        </div>
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
                Create a part, pick up recent work, or bring an existing design
                into your library.
              </p>

            </div>
            <div className="library-hero-art" aria-hidden="true">
              <AppIcon app="cad" size={135} />
            </div>
          </section>
        )}
        <div className="library-list-heading">
          <h2>{view === "home" ? "Recently opened" : titles[view]}</h2>
          <span>{files.length} items</span>
          <div className="library-list-tools">
            <Button
              aria-label="List view"
              aria-pressed={!grid}
              onClick={() => setGrid(false)}
            >
              <AetherIcon name="items" />
            </Button>
            <Button
              aria-label="Grid view"
              aria-pressed={grid}
              onClick={() => setGrid(true)}
            >
              <AetherIcon name="layout" />
            </Button>
          </div>
        </div>
        {view === "workspace" && (
          <p className="library-note">
            Files shared with this Studio workspace. Owners edit originals;
            everyone with CAD access can open or copy them.
          </p>
        )}
        {files.length === 0 ? (
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
                : "Create a Part or import a design to get started."}
            </p>
          </div>
        ) : grid ? (
          <div className="library-grid">
            {files.map((file) => (
              <button
                key={file.id}
                className={selected?.id === file.id ? "selected" : ""}
                onClick={() => setSelected(file)}
                onDoubleClick={() => open(file)}
              >
                <AetherIcon
                  name={file.kind === "folder" ? "folder" : "design"}
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
                <th>Modified</th>
                <th>Owner</th>
                <th>Location</th>
              </tr>
            </thead>
            <tbody>
              {files.map((file) => (
                <tr
                  key={file.id}
                  className={selected?.id === file.id ? "selected" : ""}
                  onClick={() => setSelected(file)}
                  onDoubleClick={() => open(file)}
                >
                  <td>
                    <button
                      onClick={() => setSelected(file)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") open(file);
                      }}
                    >
                      <AetherIcon
                        name={file.kind === "folder" ? "folder" : "design"}
                      />
                      {file.name}
                    </button>
                  </td>
                  <td>{new Date(file.modified * 1000).toLocaleDateString()}</td>
                  <td>{file.owner}</td>
                  <td>
                    {file.scope === "workspace"
                      ? "Workspace shared"
                      : "My files"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </main>
      <aside className="library-details">
        <h2>Details</h2>
        {selected ? (
          <>
            <AetherIcon
              name={selected.kind === "folder" ? "folder" : "design"}
              width={64}
              height={64}
            />
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
                        app: "cad",
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
