/**
 * Universal tree folder organization: user-created folders, grouping and
 * sub-nesting for any ordered item list (feature tree, assembly tree, …).
 * Organization only — it never reorders or re-evaluates the underlying items.
 * A folder displays at its first member's position; empty folders append last.
 */

export interface TreeFolder {
  id: string;
  name: string;
  parentID: string | null;
}

export interface TreeOrganization {
  folders: TreeFolder[];
  /** itemID → folderID */
  membership: Record<string, string>;
}

export const emptyTreeOrganization = (): TreeOrganization => ({ folders: [], membership: {} });

const byID = (organization: TreeOrganization) =>
  new Map(organization.folders.map((folder) => [folder.id, folder]));

function ancestorChain(organization: TreeOrganization, folderID: string | null): string[] {
  const folders = byID(organization);
  const chain: string[] = [];
  const seen = new Set<string>();
  let current = folderID;
  while (current !== null && folders.has(current) && !seen.has(current)) {
    chain.push(current);
    seen.add(current);
    current = folders.get(current)!.parentID;
  }
  return chain;
}

export function canNestFolder(
  organization: TreeOrganization,
  folderID: string,
  parentID: string | null,
): boolean {
  if (parentID === null) return true;
  if (parentID === folderID) return false;
  if (!byID(organization).has(parentID)) return false;
  return !ancestorChain(organization, parentID).includes(folderID);
}

export function createFolder(
  organization: TreeOrganization,
  folder: { id: string; name: string; parentID?: string | null },
  memberIDs: readonly string[] = [],
): TreeOrganization {
  if (!folder.id || !folder.name.trim()) throw new Error("Folder id and name are required.");
  if (byID(organization).has(folder.id)) throw new Error(`Folder ${folder.id} already exists.`);
  const parentID = folder.parentID ?? null;
  if (parentID !== null && !byID(organization).has(parentID)) {
    throw new Error(`Unknown parent folder ${parentID}.`);
  }
  const next: TreeOrganization = {
    folders: [...organization.folders, { id: folder.id, name: folder.name, parentID }],
    membership: { ...organization.membership },
  };
  for (const itemID of memberIDs) next.membership[itemID] = folder.id;
  return next;
}

export function renameFolder(
  organization: TreeOrganization,
  folderID: string,
  name: string,
): TreeOrganization {
  if (!name.trim()) throw new Error("Folder name is required.");
  if (!byID(organization).has(folderID)) throw new Error(`Unknown folder ${folderID}.`);
  return {
    ...organization,
    folders: organization.folders.map((folder) =>
      folder.id === folderID ? { ...folder, name } : folder,
    ),
  };
}

/** Removes the folder; its member items and child folders pop to its parent. */
export function deleteFolder(
  organization: TreeOrganization,
  folderID: string,
): TreeOrganization {
  const folder = byID(organization).get(folderID);
  if (!folder) throw new Error(`Unknown folder ${folderID}.`);
  const membership: Record<string, string> = {};
  for (const [itemID, memberOf] of Object.entries(organization.membership)) {
    if (memberOf !== folderID) membership[itemID] = memberOf;
    else if (folder.parentID !== null) membership[itemID] = folder.parentID;
  }
  return {
    folders: organization.folders
      .filter((entry) => entry.id !== folderID)
      .map((entry) =>
        entry.parentID === folderID ? { ...entry, parentID: folder.parentID } : entry,
      ),
    membership,
  };
}

/** Assigns items to a folder, or to the top level when folderID is null. */
export function assignItems(
  organization: TreeOrganization,
  itemIDs: readonly string[],
  folderID: string | null,
): TreeOrganization {
  if (folderID !== null && !byID(organization).has(folderID)) {
    throw new Error(`Unknown folder ${folderID}.`);
  }
  const membership = { ...organization.membership };
  for (const itemID of itemIDs) {
    if (folderID === null) delete membership[itemID];
    else membership[itemID] = folderID;
  }
  return { ...organization, membership };
}

export function moveFolder(
  organization: TreeOrganization,
  folderID: string,
  parentID: string | null,
): TreeOrganization {
  if (!byID(organization).has(folderID)) throw new Error(`Unknown folder ${folderID}.`);
  if (!canNestFolder(organization, folderID, parentID)) {
    throw new Error("A folder cannot be nested inside itself or its descendants.");
  }
  return {
    ...organization,
    folders: organization.folders.map((folder) =>
      folder.id === folderID ? { ...folder, parentID } : folder,
    ),
  };
}

export function validateTreeOrganization(value: unknown): asserts value is TreeOrganization | undefined {
  if (value === undefined) return;
  if (!value || typeof value !== "object") throw new Error("Organization must be an object.");
  const organization = value as Partial<TreeOrganization>;
  if (!Array.isArray(organization.folders) || !organization.membership || typeof organization.membership !== "object") {
    throw new Error("Organization requires folders and membership.");
  }
  const ids = new Set<string>();
  for (const folder of organization.folders) {
    if (!folder || typeof folder.id !== "string" || !folder.id || typeof folder.name !== "string" || !folder.name.trim()) {
      throw new Error("Every folder requires an id and a name.");
    }
    if (ids.has(folder.id)) throw new Error(`Duplicate folder id ${folder.id}.`);
    ids.add(folder.id);
  }
  for (const folder of organization.folders) {
    if (folder.parentID !== null && !ids.has(folder.parentID)) {
      throw new Error(`Folder ${folder.id} references unknown parent ${folder.parentID}.`);
    }
  }
  const complete = organization as TreeOrganization;
  // A parent chain that never reaches the top level means a cycle among ancestors.
  for (const folder of complete.folders) {
    const chain = ancestorChain(complete, folder.id);
    const last = complete.folders.find((entry) => entry.id === chain[chain.length - 1]);
    if (last && last.parentID !== null) throw new Error(`Folder nesting cycle at ${folder.id}.`);
  }
  for (const [itemID, folderID] of Object.entries(complete.membership)) {
    if (typeof folderID !== "string" || !ids.has(folderID)) {
      throw new Error(`Item ${itemID} references unknown folder ${String(folderID)}.`);
    }
  }
}

type Slot<T> =
  | { kind: "item"; item: T }
  | { kind: "folder"; folder: TreeFolder; children: Slot<T>[] };

/**
 * Nests a flat ordered item list per the organization. Generic over the node
 * type so products build UI nodes without this module knowing about UI.
 */
export function buildFolderedTree<T extends { id: string }>(
  items: readonly T[],
  organization: TreeOrganization | undefined,
  makeFolder: (folder: TreeFolder, children: readonly T[]) => T,
): T[] {
  if (!organization || organization.folders.length === 0) return [...items];
  const folders = byID(organization);
  const top: Slot<T>[] = [];
  const slots = new Map<string, Slot<T> & { kind: "folder" }>();
  const ensureFolderSlot = (folder: TreeFolder, guard: Set<string>): Slot<T> & { kind: "folder" } => {
    const existing = slots.get(folder.id);
    if (existing) return existing;
    const slot: Slot<T> & { kind: "folder" } = { kind: "folder", folder, children: [] };
    slots.set(folder.id, slot);
    const parent = folder.parentID !== null && !guard.has(folder.parentID) ? folders.get(folder.parentID) : undefined;
    if (parent) {
      guard.add(folder.id);
      ensureFolderSlot(parent, guard).children.push(slot);
    } else {
      top.push(slot);
    }
    return slot;
  };
  for (const item of items) {
    const folderID = organization.membership[item.id];
    const folder = folderID ? folders.get(folderID) : undefined;
    if (folder) ensureFolderSlot(folder, new Set([folder.id])).children.push({ kind: "item", item });
    else top.push({ kind: "item", item });
  }
  for (const folder of organization.folders) ensureFolderSlot(folder, new Set([folder.id]));
  const render = (slot: Slot<T>): T =>
    slot.kind === "item"
      ? slot.item
      : makeFolder(slot.folder, slot.children.map(render));
  return top.map(render);
}
