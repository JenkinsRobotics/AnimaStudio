// Thin typed client for the animacore HTTP bridge. The engine remains the
// single semantic authority: this file carries requests and DTOs, never
// animation/mate meaning.

export const ENGINE_URL =
  (import.meta.env.VITE_ENGINE_URL as string | undefined) ??
  "http://127.0.0.1:8787";

export interface DofSummary {
  path: string;
  min: number | null;
  max: number | null;
  neutral: number | null;
}

export interface JointSummary {
  name: string;
  type: string;
  parent_part: string;
  child_part: string;
  dofs: DofSummary[];
}

export interface PartSummary {
  name: string;
  parent: string | null;
  model: string;
  suppressed: boolean;
  grounded: boolean;
}

export interface ClipSummary {
  name: string;
  duration_s: number;
  loop: boolean;
}

export interface RigSummary {
  identity: { name: string; display_name: string | null };
  parts: PartSummary[];
  joints: JointSummary[];
  clips: ClipSummary[];
}

export interface PartTransform {
  position: [number, number, number];
  orientation: [number, number, number, number]; // quaternion xyzw
}

interface BridgeResponse<T> {
  ok: boolean;
  result?: T;
  error?: { code: string; message: string };
}

let nextID = 1;

async function rpc<T>(method: string, params: object): Promise<T> {
  const response = await fetch(`${ENGINE_URL}/rpc`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: nextID++, method, params }),
  });
  const envelope = (await response.json()) as BridgeResponse<T>;
  if (!envelope.ok || envelope.result === undefined) {
    throw new Error(envelope.error?.message ?? `engine error in ${method}`);
  }
  return envelope.result;
}

export function assetURL(characterPath: string, model: string): string {
  const directory = characterPath.split("/").slice(0, -1).join("/");
  return `${ENGINE_URL}/assets/${directory}/${model}`;
}

export async function fetchCharacterText(path: string): Promise<string> {
  const response = await fetch(`${ENGINE_URL}/assets/${path}`);
  if (!response.ok) throw new Error(`could not read ${path}`);
  return response.text();
}

export function loadCharacter(text: string) {
  return rpc<{ handle: string; rig: RigSummary }>("load_character", { text });
}

export function resolvePose(
  handle: string,
  options: { clip?: string; timeS?: number; dofValues?: Record<string, number> }
) {
  const params: Record<string, unknown> = { handle, time_s: options.timeS ?? 0 };
  if (options.clip) params.clip = options.clip;
  if (options.dofValues && Object.keys(options.dofValues).length > 0) {
    params.dof_values = options.dofValues;
  }
  return rpc<{ parts: Record<string, PartTransform> }>("resolve_pose", params);
}

export function serializeCharacter(rig: unknown) {
  return rpc<{ text: string }>("serialize_character", { rig });
}

export async function saveFile(path: string, text: string): Promise<void> {
  const response = await fetch(`${ENGINE_URL}/files/save`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path, text }),
  });
  if (!response.ok) throw new Error("save failed");
}
