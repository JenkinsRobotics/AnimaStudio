import { useEffect, useState } from "react";
import { Button } from "@aether/ui";

type SavedHistory = {
  revisions: { revision: number; author: string; saved: number; event: string; note: string }[];
  versions: { name: string; revision: number }[];
};
/** Read the host's canonical history; no client-side revision model. */
export function CADVersionsPanel({ documentName }: { documentName: string }) {
  const [history, setHistory] = useState<SavedHistory | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const id = typeof location !== "undefined" ? new URLSearchParams(location.search).get("document") : null;
  const load = async () => {
    if (!id) return;
    setBusy(true); setError("");
    try {
      const response = await fetch("/api/library/history", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ app: "cad", id }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error?.message ?? data.error ?? "Could not load saved history.");
      setHistory(data);
    } catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  };
  useEffect(() => { setHistory(null); void load(); }, [id, documentName]);
  return <section className="cad-versions-panel" aria-label="Saved version control">
    <p>Saved revisions of this {new URLSearchParams(typeof location !== "undefined" ? location.search : "").has("part") ? "project" : "document"}.</p>
    {!id ? <p>Save this document to your server to keep revision history.</p> : <>
      <Button onClick={() => void load()} disabled={busy}>Refresh history</Button>
      <p className="cad-version-hint">Save your edits before naming or restoring a version in CAD Home.</p>
      <a href="/cad/" target="_blank" rel="noreferrer">Manage versions in CAD Home ↗</a>
      {error && <p role="alert">{error}</p>}
      <ol className="cad-version-tree">{history?.revisions.map(r => {
        const query = new URLSearchParams(location.search); query.set("revision", String(r.revision)); query.delete("new");
        const names = history.versions.filter(v => v.revision === r.revision).map(v => v.name);
        return <li key={r.revision}>
          <a href={`${location.pathname}?${query}`} target="_blank" rel="noreferrer">{names.join(" · ") || `Revision ${r.revision}`}</a>
          <small>{r.author} · {new Date(r.saved * 1000).toLocaleString()}</small>
          <small>{r.event}{r.note ? ` · ${r.note}` : ""}</small>
        </li>;
      })}</ol>
      {history && !history.revisions.length && <p>No saved revisions yet.</p>}
      <small>Revision links open read-only in a separate tab.</small>
    </>}
  </section>;
}
