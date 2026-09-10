import { parsePartDocument } from "@aether/core/document";
import { useEffect, useState } from "react";
import {
  Button,
  Checkbox,
  Dialog,
  FieldRow,
  SelectField,
  TextField,
} from "@aether/ui";
import {
  unitCatalog,
  unitChoice,
  displayQuantity,
  parseQuantity,
  type UnitFamily,
  type UnitPreferences,
} from "@aether/core/units";
import { documentSession, requireSavedDocument } from "../document-session";
import { applyDocumentUnits } from "../document-preferences";
export type Settings = {
  description: string;
  revisionManaged: boolean;
  workspaceName: string;
  workspaceDescription: string;
  units: UnitPreferences;
  itemQuantities?: Record<string, Partial<Record<UnitFamily, number>>>;
};
type Item = {
  id: string;
  kind: string;
  name: string;
  description: string;
  category: string;
  readOnly?: boolean;
};
export type Metadata = {
  id: string;
  name: string;
  revision: number;
  writable: boolean;
  scope: string;
  parent: string | null;
  settings: Settings;
  items: Item[];
  deleted: Item[];
  featureVersion: number;
  upgradeDocuments: Record<string, unknown>;
  upgradeNeeded: boolean;
  updates: {
    part_id: string;
    name: string;
    current: number;
    latest?: number;
    available: boolean;
  }[];
};
export async function documentAPI<T>(action: string, data: object): Promise<T> {
  const response = await fetch("/api/library/" + action, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ app: "cad", ...data }),
  });
  const result = await response.json();
  if (!response.ok)
    throw new Error(result.error || "Document operation failed.");
  return result;
}
export function loadDocumentMetadata(): Promise<Metadata> {
  const query = new URLSearchParams(location.search);
  const id = documentSession()?.id ?? query.get("document");
  if (!id)
    return Promise.reject(
      new Error("Save this document to your server first."),
    );
  return documentAPI<Metadata>("cad_metadata", {
    id,
    ...(query.has("revision")
      ? { revision: Number(query.get("revision")) }
      : {}),
  });
}
export function CADDocumentSettings({
  action,
  onClose,
}: {
  action: string;
  onClose: () => void;
}) {
  const [meta, setMeta] = useState<Metadata | null>(null),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const [name, setName] = useState(""),
    [settings, setSettings] = useState<Settings | null>(null),
    [item, setItem] = useState<Item | null>(null);
  const [parent, setParent] = useState<string | null>(null),
    [path, setPath] = useState<{ id: string | null; name: string }[]>([
      { id: null, name: "My files" },
    ]);
  const [folders, setFolders] = useState<{ id: string; name: string }[]>([]),
    [folderName, setFolderName] = useState("");
  const [applied,setApplied]=useState(false);
  const close = () => { if(applied) location.assign(location.href); else onClose(); };
  const [selectedUpdates, setSelectedUpdates] = useState<string[]>([]);
  useEffect(() => {
    void loadDocumentMetadata()
      .then((value) => {
        setMeta(value);
        setSettings(structuredClone(value.settings));
        setName(
          (action === "copy" ? "Copy of " : "") +
            value.name.replace(/\.[^.]+$/, ""),
        );
        setItem(value.items[0]);
        setParent(null);
        setPath([
          {
            id: null,
            name:
              action === "move" && value.scope === "workspace"
                ? "Workspace shared"
                : "My files",
          },
        ]);
        applyDocumentUnits(value.settings.units);
      })
      .catch((e) => setError(e.message));
  }, [action]);
  useEffect(() => {
    if (!meta || !["move", "copy"].includes(action)) return;
    void documentAPI<{
      files: { id: string; name: string; kind: string; writable: boolean }[];
    }>("list", { view: action === "copy" ? "personal" : meta.scope, parent })
      .then((r) =>
        setFolders(r.files.filter((f) => f.kind === "folder" && f.writable)),
      )
      .catch((e) => setError(e.message));
  }, [meta, parent, action]);
  const mutate = async (operation = action, extra: object = {}, stayOpen = false) => {
    if (!meta) return;
    setBusy(true);
    setError("");
    try {
      requireSavedDocument();
      const result = await documentAPI<{ id: string }>("cad_operation", {
        id: meta.id,
        expected_revision: meta.revision,
        ...(new URLSearchParams(location.search).has("revision")
          ? { revision: meta.revision }
          : {}),
        operation,
        name,
        parent,
        ...(settings
          ? {
              description: settings.description,
              revisionManaged: settings.revisionManaged,
              units: settings.units,
            }
          : {}),
        ...(item
          ? {
              item_id: item.id,
              ...(operation === "properties"
                ? {
                    name: item.name,
                    description: item.description,
                    category: item.category,
                    quantities: settings?.itemQuantities?.[item.id] ?? {},
                  }
                : {}),
            }
          : {}),
        parts: selectedUpdates,
        ...(operation === "update"
          ? {
              upgraded_documents: Object.fromEntries(
                Object.entries(meta.upgradeDocuments).map(([key, doc]) => [
                  key,
                  parsePartDocument(JSON.stringify(doc)),
                ]),
              ),
            }
          : {}),
        ...extra,
      });
      if(stayOpen) {
        setApplied(true);
        const latest=await loadDocumentMetadata();
        setMeta(latest);setSettings(structuredClone(latest.settings));setItem(latest.items.find(value=>value.id===item?.id)??latest.items[0]);
        return;
      }
      const query = new URLSearchParams(location.search);
      if (operation === "copy") {
        query.set("document", result.id);
        query.delete("revision");
      }
      if (operation === "delete_item") {
        query.delete("part");
        query.delete("assembly");
      }
      // Reload the authoritative snapshot only after a successful, clean-session mutation.
      location.assign(location.pathname + "?" + query);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };
  const readonly = meta && !meta.writable && action !== "copy";
  const titles: Record<string, string> = {
    rename: "Rename document",
    move: "Move document",
    details: "Document details",
    restore: "Restore deleted workspaces",
    copy: "Copy workspace",
    update: "Update workspace",
    units: "Workspace units",
    properties: "Workspace properties",
  };
  const folderBrowser = (
    <>
      <nav className="cad-folder-path">
        {path.map((p, i) => (
          <Button
            key={p.id ?? "root"}
            onClick={() => {
              setParent(p.id);
              setPath(path.slice(0, i + 1));
            }}
          >
            {p.name}
          </Button>
        ))}
      </nav>
      <div className="cad-folder-browser">
        {folders.map((f) => (
          <Button
            key={f.id}
            onClick={() => {
              setParent(f.id);
              setPath([...path, { id: f.id, name: f.name }]);
            }}
          >
            ▱ {f.name}
          </Button>
        ))}
        {!folders.length && <p>No subfolders. You can choose this location.</p>}
      </div>
      <div className="cad-folder-create">
        <TextField
          aria-label="New folder name"
          value={folderName}
          onChange={(e) => setFolderName(e.target.value)}
          placeholder="New folder name"
        />
        <Button
          disabled={busy || !folderName.trim()}
          onClick={async () => {
            try {
              setBusy(true);
              const f = await documentAPI<{ id: string; name: string }>(
                "create",
                {
                  kind: "folder",
                  name: folderName,
                  parent,
                  scope: action === "copy" ? "personal" : meta?.scope,
                },
              );
              setFolders([...folders, f]);
              setFolderName("");
            } catch (e) {
              setError((e as Error).message);
            } finally {
              setBusy(false);
            }
          }}
        >
          New folder
        </Button>
      </div>
    </>
  );
  return (
    <Dialog
      open
      title={titles[action] ?? "Document settings"}
      onClose={close}
      actions={
        <>
          <Button onClick={close}>{applied?"Close":"Cancel"}</Button>
          {action==="properties"&&<Button disabled={busy||!meta||Boolean(readonly)||Boolean(error)||item?.readOnly} onClick={()=>void mutate("properties",{},true)}>Apply</Button>}
          {!["restore", "update"].includes(action) && (
            <Button
              primary
              disabled={
                busy ||
                !meta ||
                Boolean(readonly) ||
                Boolean(error) ||
                Boolean(action === "properties" && item?.readOnly)
              }
              onClick={() => void mutate()}
            >
              {action === "move"
                ? "Move here"
                : action === "copy"
                  ? "Create copy"
                  : "Save"}
            </Button>
          )}
          {action === "update" && (
            <Button
              primary
              disabled={
                busy ||
                !meta ||
                Boolean(readonly) ||
                (!meta.upgradeNeeded && !selectedUpdates.length)
              }
              onClick={() => void mutate("update")}
            >
              Apply selected updates
            </Button>
          )}
        </>
      }
    >
      <div className="cad-document-settings">
        {error && <p role="alert">{error}</p>}
        {!meta && !error && <p>Loading document…</p>}
        {readonly && (
          <p>This snapshot is read-only. Copy it to edit your own workspace.</p>
        )}
        {meta && settings && (
          <fieldset disabled={busy || Boolean(readonly)} onInput={()=>setError("")}>
            {["rename", "copy"].includes(action) && (
              <FieldRow label="Name" htmlFor="document-setting-name">
                <TextField
                  id="document-setting-name"
                  value={name}
                  maxLength={160}
                  onChange={(e) => setName(e.target.value)}
                />
              </FieldRow>
            )}
            {["move", "copy"].includes(action) && (
              <>
                {action === "move" && (
                  <p>
                    {meta.name} · sharing remains{" "}
                    {meta.scope === "workspace"
                      ? "workspace shared"
                      : "private"}
                    .
                  </p>
                )}
                {folderBrowser}
                {action === "copy" && (
                  <p>
                    Creates a private, self-contained copy of this saved
                    snapshot. The source history stays with the original.
                  </p>
                )}
              </>
            )}
            {action === "details" && (
              <>
                <label>
                  Document description (up to 10,000 characters)
                  <textarea
                    value={settings.description}
                    maxLength={10000}
                    onChange={(e) =>
                      setSettings({ ...settings, description: e.target.value })
                    }
                  />
                </label>
                <Checkbox
                  label="Not revision managed"
                  checked={!settings.revisionManaged}
                  onChange={(e) =>
                    setSettings({
                      ...settings,
                      revisionManaged: !e.target.checked,
                    })
                  }
                />
                <p>
                  Disables naming new versions. Saved history, recovery and
                  existing versions are retained.
                </p>
              </>
            )}
            {action === "units" && (
              <>
                <p>
                  Changes input and display units; stored geometry keeps its
                  canonical dimensions.
                </p>
                <div className="cad-unit-settings">
                  {(Object.keys(unitCatalog) as UnitFamily[]).map((key) => {
                    const choice = unitChoice(settings.units, key);
                    return (
                      <div key={key}>
                        <FieldRow
                          label={unitCatalog[key].label}
                          htmlFor={"unit-" + key}
                        >
                          <SelectField
                            id={"unit-" + key}
                            value={choice.unit}
                            options={Object.keys(unitCatalog[key].options).map(
                              (u) => ({ value: u, label: u }),
                            )}
                            onChange={(e) =>
                              setSettings({
                                ...settings,
                                units: {
                                  ...settings.units,
                                  [key]: {
                                    unit: e.target.value,
                                    decimals: choice.decimals,
                                  },
                                },
                              })
                            }
                          />
                        </FieldRow>
                        <FieldRow
                          label="Display decimals"
                          htmlFor={"decimals-" + key}
                        >
                          <SelectField
                            id={"decimals-" + key}
                            value={String(choice.decimals)}
                            options={Array.from({ length: 9 }, (_, i) => ({
                              value: String(i),
                              label: String(i),
                            }))}
                            onChange={(e) =>
                              setSettings({
                                ...settings,
                                units: {
                                  ...settings.units,
                                  [key]: {
                                    unit: choice.unit,
                                    decimals: Number(e.target.value),
                                  },
                                },
                              })
                            }
                          />
                        </FieldRow>
                      </div>
                    );
                  })}
                </div>
              </>
            )}
            {action === "properties" && item && (
              <div className="cad-property-editor">
                <nav>
                  {meta.items.map((i) => (
                    <Button key={i.id} onClick={() => {const original=meta.items.find(value=>value.id===item.id);const changed=JSON.stringify(original)!==JSON.stringify(item)||JSON.stringify(settings.itemQuantities?.[item.id])!==JSON.stringify(meta.settings.itemQuantities?.[item.id]);if(changed&&!confirm("Discard unapplied property edits? Choose Cancel and Apply to save them first."))return;setItem({...i});}}>
                      {i.kind === "body" ? "↳ " : ""}
                      {i.name} · {i.kind}
                    </Button>
                  ))}
                </nav>
                <section>
                  <FieldRow label="Name" htmlFor="property-name">
                    <TextField
                      id="property-name"
                      value={item.name}
                      onChange={(e) =>
                        setItem({ ...item, name: e.target.value })
                      }
                    />
                  </FieldRow>
                  <label>
                    Description
                    <textarea
                      value={item.description}
                      onChange={(e) =>
                        setItem({ ...item, description: e.target.value })
                      }
                      maxLength={10000}
                    />
                  </label>
                  <FieldRow label="Category" htmlFor="property-category">
                    <TextField
                      id="property-category"
                      value={item.category}
                      disabled={["workspace", "assembly"].includes(item.kind)}
                      onChange={(e) =>
                        setItem({ ...item, category: e.target.value })
                      }
                    />
                  </FieldRow>
                  <details>
                    <summary>Engineering properties</summary>
                    <p>
                      Optional, manually entered quantities; values are stored
                      in SI units.
                    </p>
                    {(Object.keys(unitCatalog) as UnitFamily[]).map(
                      (family) => {
                        const choice = unitChoice(settings.units, family),
                          value = settings.itemQuantities?.[item.id]?.[family];
                        return (
                          <FieldRow
                            key={family}
                            label={`${unitCatalog[family].label} (${choice.unit})`}
                            htmlFor={"quantity-" + family}
                          >
                            <TextField
                              id={"quantity-" + family}
                              key={`${item.id}-${choice.unit}`}
                              defaultValue={
                                value === undefined
                                  ? ""
                                  : displayQuantity(
                                      value,
                                      settings.units,
                                      family,
                                    )
                              }
                              onBlur={(e) => {
                                try {
                                  const values = {
                                    ...settings.itemQuantities?.[item.id],
                                  };
                                  if (e.target.value.trim())
                                    values[family] = parseQuantity(
                                      e.target.value,
                                      settings.units,
                                      family,
                                    );
                                  else delete values[family];
                                  setSettings({
                                    ...settings,
                                    itemQuantities: {
                                      ...settings.itemQuantities,
                                      [item.id]: values,
                                    },
                                  });
                                  setError("");
                                } catch (e) {
                                  setError((e as Error).message);
                                }
                              }}
                            />
                          </FieldRow>
                        );
                      },
                    )}
                  </details>
                  {item.readOnly && (
                    <p>Linked Part: edit properties in its source document.</p>
                  )}
                  {["part", "assembly"].includes(item.kind) &&
                    item.id !== "part" && (
                      <Button
                        disabled={item.readOnly}
                        onClick={() => {
                          if (
                            confirm(
                              `Delete ${item.name}? It can be restored from deleted workspaces. Referenced items must be detached first.`,
                            )
                          )
                            void mutate("delete_item");
                        }}
                      >
                        Delete workspace…
                      </Button>
                    )}
                </section>
              </div>
            )}
            {action === "restore" && (
              <>
                <p>
                  Recover deleted Part or Assembly tabs in this project.
                  Restoring adds a new saved revision.
                </p>
                {meta.deleted.map((i) => (
                  <div className="cad-deleted-item" key={i.id}>
                    <span>
                      {i.name} · {i.kind}
                    </span>
                    <Button
                      onClick={() =>
                        void mutate("restore_item", { item_id: i.id })
                      }
                    >
                      Restore
                    </Button>
                  </div>
                ))}
                {!meta.deleted.length && (
                  <p>No deleted workspaces to restore.</p>
                )}
              </>
            )}
            {action === "update" && (
              <>
                <p>
                  {meta.upgradeNeeded
                    ? "An authored feature format upgrade is available."
                    : "Workspace is already at the latest supported feature format (v" +
                      meta.featureVersion +
                      ")."}
                </p>
                {meta.updates.map((u) => (
                  <Checkbox
                    key={u.part_id}
                    label={`${u.name} · r${u.current}${u.available ? " → r" + u.latest : " · source unavailable"}`}
                    disabled={!u.available || u.current === u.latest}
                    checked={selectedUpdates.includes(u.part_id)}
                    onChange={(e) =>
                      setSelectedUpdates(
                        e.target.checked
                          ? [...selectedUpdates, u.part_id]
                          : selectedUpdates.filter((id) => id !== u.part_id),
                      )
                    }
                  />
                ))}
                {!meta.updates.length && <p>No linked Parts to update.</p>}
                <p>
                  Selected links adopt the latest saved source snapshot.
                  Previous snapshots remain in document history.
                </p>
              </>
            )}
          </fieldset>
        )}
      </div>
    </Dialog>
  );
}
