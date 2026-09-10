import { useEffect, useState } from "react";
import { Button, TextField } from "@aether/ui";
import { api } from "./api";
type Revision = {
  revision: number;
  name: string;
  author: string;
  saved: number;
  event: string;
  note: string;
};
export function DocumentHistory({
  file,
  onClose,
  onChanged,
}: {
  file: { id: string; name: string; revision: number; writable: boolean };
  onClose: () => void;
  onChanged: () => Promise<void>;
}) {
  const [history, setHistory] = useState<{
    revisions: Revision[];
    versions: { name: string; revision: number }[];
  }>({ revisions: [], versions: [] });
  const [error, setError] = useState(""),
    [name, setName] = useState(""),
    [busy, setBusy] = useState(false),
    [head, setHead] = useState(file.revision);
  const load = async () =>
    setHistory(await api("/api/library/history", { app: "cad", id: file.id }));
  useEffect(() => {
    void load().catch((e) => setError(e.message));
  }, [file.id]);
  const act = async (action: string, data: object) => {
    setBusy(true);
    setError("");
    try {
      const result = await api<{ revision: number }>("/api/library/" + action, {
        app: "cad",
        id: file.id,
        expected_revision: head,
        ...data,
      });
      setHead(result.revision);
      await load();
      await onChanged();
      setName("");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="library-modal">
      <section
        className="history-dialog"
        role="dialog"
        aria-modal="true"
        aria-label="Document history"
      >
        <h2>{file.name}</h2>
        <p>
          Saved history · restoring adds a new revision and retains later work.
        </p>
        {error && <p role="alert">{error}</p>}
        {file.writable && (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              void act("version", { name });
            }}
          >
            <TextField
              aria-label="Version name"
              placeholder="Name this version, e.g. Prototype 1"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              maxLength={80}
            />
            <Button type="submit" disabled={busy}>
              Create named version
            </Button>
          </form>
        )}
        {history.versions.length > 0 && (
          <p>
            {history.versions
              .map((v) => `${v.name} (r${v.revision})`)
              .join(" · ")}
          </p>
        )}
        <ol>
          {history.revisions.map((r) => (
            <li key={r.revision}>
              <strong>
                Revision {r.revision} · {r.event}
              </strong>
              <p>
                {r.author} · {new Date(r.saved * 1000).toLocaleString()}
              </p>
              {r.note && <p>{r.note}</p>}
              <a
                href={
                  "/cad/index.html?document=" +
                  encodeURIComponent(file.id) +
                  "&revision=" +
                  r.revision
                }
              >
                Open read-only
              </a>
              {file.writable && r.revision !== head && (
                <Button
                  disabled={busy}
                  onClick={() => void act("restore", { revision: r.revision })}
                >
                  Restore as new revision
                </Button>
              )}
            </li>
          ))}
        </ol>
        <Button onClick={onClose}>Close</Button>
      </section>
    </div>
  );
}
