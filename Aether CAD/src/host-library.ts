import { configureDocumentSession } from "./document-session";
import { isPartFile, isProjectFile } from "@aether/core/document";
/** Hosted file transport only; document interpretation stays in Core. */
export const hostedCAD = location.pathname.startsWith("/cad/");
type StoredFile = {
  id: string;
  name: string;
  revision: number;
  writable: boolean;
  data_base64?: string;
};
export type Project = {
  parts: {
    id: string;
    name: string;
    document: unknown;
    source?: { kind: string; asset_ref?: string; label?: string };
  }[];
  assemblies: { id: string; name: string }[];
};
export let activeProject: Project | null = null;
let activePartId: string | null = null;
let linkedPartReadOnly = false;
export async function editHostedProject(
  operation: string,
  name: string,
  extra: object = {},
) {
  if (dirty)
    throw new Error("Save your current work before changing project items.");
  if (!active?.writable) throw new Error("This project is read-only.");
  const result = (await request("project_edit", {
    id: active.id,
    expected_revision: active.revision,
    operation,
    name,
    ...extra,
  })) as StoredFile & { project: Project };
  active = result;
  activeProject = result.project;
  return result;
}
export function projectItemURL(id: string, kind: "part" | "assembly") {
  return (
    "/cad/index.html?document=" +
    encodeURIComponent(active!.id) +
    "&" +
    kind +
    "=" +
    encodeURIComponent(id) +
    (query.has("revision")
      ? "&revision=" + encodeURIComponent(query.get("revision")!)
      : "")
  );
}
let active: StoredFile | null = null;
let saving = false;
let dirty = false;
configureDocumentSession(() => active, () => {
  if (dirty || saving) throw new Error("Save your current edits before changing document settings.");
});
/* Continuous saving (PDM): edits autosave in the background as revisions;
 * explicit Commit annotates a revision with a name + message. */
let autosaveFlush: (() => Promise<void>) | null = null;
let autosaveTimer: ReturnType<typeof setTimeout> | null = null;
export function configureAutosave(flush: () => Promise<void>) {
  autosaveFlush = flush;
}
async function runAutosave() {
  if (!autosaveFlush || !dirty) return;
  if (saving) {
    scheduleAutosave();
    return;
  }
  await autosaveFlush();
}
function scheduleAutosave() {
  if (!autosaveFlush) return;
  if (autosaveTimer) clearTimeout(autosaveTimer);
  autosaveTimer = setTimeout(() => {
    autosaveTimer = null;
    void runAutosave();
  }, 1200);
}
export async function flushAutosaveNow() {
  if (autosaveTimer) {
    clearTimeout(autosaveTimer);
    autosaveTimer = null;
  }
  await runAutosave();
}
export async function commitHosted(name: string, message: string) {
  if (!active) throw new Error("Open a server document to commit.");
  await flushAutosaveNow();
  await request("version", {
    id: active.id,
    expected_revision: active.revision,
    name,
    message,
  });
}
export function markHostedDirty() {
  dirty = true;
  scheduleAutosave();
}
export function markHostedClean() {
  dirty = false;
}
window.addEventListener("beforeunload", (event) => {
  if (hostedCAD && dirty) {
    event.preventDefault();
    event.returnValue = "";
  }
});
const query = new URLSearchParams(location.search);
async function request(action: string, data: object): Promise<StoredFile> {
  const response = await fetch("/api/library/" + action, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ app: "cad", ...data }),
  });
  const result = await response.json();
  if (!response.ok)
    throw new Error(result.error || "Unable to access your file library.");
  return result;
}
export function detachHostedFile() {
  active = null;
  activeProject = null;
  activePartId = null;
  linkedPartReadOnly = false;
  document.querySelector(".project-tabs")?.remove();
  history.replaceState(null, "", location.pathname);
}
export async function loadHostedFile(): Promise<File | null> {
  const id = query.get("document");
  if (!hostedCAD || !id) return null;
  active = await request(query.has("revision") ? "read_revision" : "read", {
    id,
    revision: Number(query.get("revision")),
    branch: query.get("branch") ?? undefined,
  });
  if (isProjectFile(active.name)) {
    const result = (await request("project_read", {
      id,
      revision: active.revision,
    })) as StoredFile & { project: Project };
    activeProject = result.project;
    if (
      query.has("part") &&
      !activeProject.parts.some((p) => p.id === query.get("part"))
    )
      throw new Error(
        "This Part is not present in the selected project revision.",
      );
    const part =
      query.has("assembly") ||
      (/\.acasm$/i.test(active.name) && !query.has("part"))
        ? null
        : (activeProject.parts.find((p) => p.id === query.get("part")) ??
          activeProject.parts.find((p) => p.document));
    if (part?.document) {
      activePartId = part.id;
      linkedPartReadOnly = part.source?.kind === "linked";
      return new File([JSON.stringify(part.document)], part.name + ".acpart");
    }
  }
  if (activeProject && !query.has("assembly") && activeProject.assemblies[0]) {
    const params = new URLSearchParams(location.search);
    params.set("assembly", activeProject.assemblies[0].id);
    history.replaceState(null, "", location.pathname + "?" + params.toString());
  }
  const bytes = Uint8Array.from(atob(active.data_base64!), (c) =>
    c.charCodeAt(0),
  );
  return new File([bytes], active.name);
}
export async function saveHostedFile(
  name: string,
  bytes: Uint8Array,
): Promise<void> {
  if (saving) throw new Error("A save is already in progress.");
  saving = true;
  try {
    if (query.get("branch") && activePartId) {
      throw new Error(
        "Branch editing supports standalone parts today; project packages branch after the workspace contract lands.",
      );
    }
    if (activePartId && active && isPartFile(name)) {
      if (!active.writable || linkedPartReadOnly)
        throw new Error(
          "This Part is read-only. Edit the original source or create a standalone copy.",
        );
      const result = (await request("project_edit", {
        id: active.id,
        expected_revision: active.revision,
        operation: "save_part",
        part_id: activePartId,
        document: JSON.parse(new TextDecoder().decode(bytes)),
      })) as StoredFile & { project: Project };
      active = result;
      activeProject = result.project;
      dirty = false;
      return;
    }
    let binary = "";
    for (let offset = 0; offset < bytes.length; offset += 32768)
      binary += String.fromCharCode(...bytes.subarray(offset, offset + 32768));
    const data_base64 = btoa(binary);
    const sameType =
      active &&
      ((isPartFile(active.name) && isPartFile(name)) ||
        (isProjectFile(active.name) && isProjectFile(name)) ||
        active.name.split(".").at(-1) === name.split(".").at(-1));
    if (active && sameType) {
      if (!active.writable)
        throw new Error(
          "This shared file is read-only. Use Make a copy in My files from CAD Home to edit your own copy.",
        );
      active = await request("save", {
        id: active.id,
        expected_revision: active.revision,
        data_base64,
        branch: query.get("branch") ?? undefined,
      });
    } else
      active = await request("create", {
        name,
        data_base64,
        parent: query.get("folder"),
        scope: query.get("scope") === "workspace" ? "workspace" : "personal",
      });
    history.replaceState(
      null,
      "",
      "/cad/index.html?document=" +
        encodeURIComponent(active.id) +
        (isProjectFile(name) &&
        new URLSearchParams(location.search).get("assembly")
          ? "&assembly=" +
            encodeURIComponent(
              new URLSearchParams(location.search).get("assembly")!,
            )
          : ""),
    );
    dirty = false;
  } finally {
    saving = false;
  }
}

export async function listHostedParts(): Promise<
  { id: string; name: string; revision: number }[]
> {
  const groups = await Promise.all(
    ["personal", "workspace"].map(async (view) => {
      const response = await fetch("/api/library/list", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ app: "cad", query: ".", view }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error);
      return result.files as { id: string; name: string; revision: number }[];
    }),
  );
  return [
    ...new Map(
      groups
        .flat()
        .filter((f) => isPartFile(f.name))
        .map((f) => [f.id, f]),
    ).values(),
  ];
}

export async function updateHostedLink(partId: string) {
  const part = activeProject?.parts.find((p) => p.id === partId);
  const match = part?.source?.asset_ref?.match(/^library:([a-f0-9]+)@(\d+)$/);
  if (!part || !match)
    throw new Error("The original server source is unavailable.");
  const source = await request("read", { id: match[1] });
  if (source.revision === Number(match[2]))
    throw new Error("This link already uses the latest saved revision.");
  return editHostedProject("update_link", part.name, {
    part_id: partId,
    source_id: source.id,
    source_revision: source.revision,
  });
}
