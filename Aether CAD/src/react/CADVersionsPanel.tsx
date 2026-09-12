import { useEffect, useState } from "react";
import { Button } from "@aether/ui";
import { cadCommands } from "../cad-command-registry";

type SavedHistory = {
  revisions: { revision: number; author: string; saved: number; event: string; note: string; branch: string; parent_revision: number | null }[];
  versions: { name: string; revision: number; created: number; message: string }[];
  branches: { name: string; head_revision: number; created_from: number | null }[];
};

async function call(action: string, body: object) {
  const response = await fetch("/api/library/" + action, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ app: "cad", ...body }),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error?.message ?? data.error ?? "Version control request failed.");
  return data;
}

/** Onshape-style versions-and-history: commits, branches and changes over the
 * host's revision DAG. Merge is listed but disabled until engine-level
 * feature merge lands (see PDM_Versioning.md). */
export function CADVersionsPanel({ documentName }: { documentName: string }) {
  const [history, setHistory] = useState<SavedHistory | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [showChanges, setShowChanges] = useState(false);
  const search = typeof location !== "undefined" ? new URLSearchParams(location.search) : new URLSearchParams();
  const id = search.get("document");
  const activeBranch = search.get("branch") ?? "Main";
  const load = async () => {
    if (!id) return;
    setBusy(true); setError("");
    try { setHistory((await call("history", { id })) as SavedHistory); }
    catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  };
  useEffect(() => { setHistory(null); void load(); }, [id, documentName]);
  if (!id) return <section className="cad-versions-panel" aria-label="Saved version control"><p>Save this document to your server to keep history, commits and branches.</p></section>;
  const mainHead = history?.branches.find((b) => b.name === "Main")?.head_revision ?? 0;
  const versionAt = new Map((history?.versions ?? []).map((v) => [v.revision, v]));
  const headOf = new Map((history?.branches ?? []).map((b) => [b.head_revision, b.name]));
  const rows = (history?.revisions ?? []).filter((r) =>
    showChanges || versionAt.has(r.revision) || headOf.has(r.revision) || r.revision === mainHead,
  );
  const branchURL = (branch: string) => {
    const next = new URLSearchParams(location.search);
    if (branch === "Main") next.delete("branch"); else next.set("branch", branch);
    next.delete("revision");
    return location.pathname + "?" + next.toString();
  };
  const createBranch = async (from: number) => {
    const name = prompt("Branch name", "");
    if (!name?.trim()) return;
    setBusy(true); setError("");
    try {
      await call("branch_create", { id, name: name.trim(), from_revision: from, expected_revision: mainHead });
      await load();
    } catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  };
  return (
    <section className="cad-versions-panel" aria-label="Saved version control">
      <div className="cad-version-actions">
        <Button primary disabled={busy || activeBranch !== "Main"} title={activeBranch === "Main" ? "Commit — name this state" : "Commits land on Main; branch commits arrive with merge"} onClick={() => void cadCommands.execute("commit-part")}>Commit</Button>
        <Button disabled={busy} onClick={() => void createBranch(mainHead)}>New branch…</Button>
        <Button disabled title="Planned — engine feature-list merge (see PDM roadmap)">Merge…</Button>
        <Button disabled={busy} onClick={() => void load()}>Refresh</Button>
      </div>
      <div className="cad-version-branches" aria-label="Branches">
        {(history?.branches ?? []).map((branch) => (
          <a key={branch.name} className={"cad-version-branch" + (branch.name === activeBranch ? " cad-version-branch--active" : "")} href={branchURL(branch.name)} title={branch.name === activeBranch ? "Current workspace" : `Open the ${branch.name} branch`}>
            {branch.name}
          </a>
        ))}
      </div>
      <label className="cad-version-toggle"><input type="checkbox" checked={showChanges} onChange={(e) => setShowChanges(e.target.checked)} /> Show changes</label>
      {error && <p role="alert">{error}</p>}
      <ol className="cad-version-graph" aria-label="Versions and history">
        {rows.map((r) => {
          const version = versionAt.get(r.revision);
          const workspace = headOf.get(r.revision);
          const kind = version ? "commit" : workspace ? "workspace" : "change";
          return (
            <li key={`${r.branch}-${r.revision}`} className={`cad-version-node cad-version-node--${kind}`} data-branch={r.branch}>
              <span className="cad-version-marker" aria-hidden="true" />
              <div className="cad-version-body">
                <strong>{version ? version.name : workspace ? `${workspace} (workspace)` : r.note || r.event}</strong>
                {version?.message ? <p className="cad-version-message">{version.message}</p> : null}
                <small>{r.branch} · r{r.revision} · {r.author} · {new Date(r.saved * 1000).toLocaleString()}</small>
                <span className="cad-version-links">
                  <a href={`${location.pathname}?document=${encodeURIComponent(id)}&revision=${r.revision}`} target="_blank" rel="noreferrer">Open read-only</a>
                  <button type="button" disabled={busy} onClick={() => void createBranch(r.revision)}>Branch from here</button>
                </span>
              </div>
            </li>
          );
        })}
      </ol>
      <div className="cad-version-legend" aria-hidden="true">
        <span><i className="cad-version-marker cad-version-node--workspace" /> Workspace</span>
        <span><i className="cad-version-marker cad-version-node--commit" /> Commit</span>
        <span><i className="cad-version-marker cad-version-node--change" /> Change</span>
      </div>
    </section>
  );
}
