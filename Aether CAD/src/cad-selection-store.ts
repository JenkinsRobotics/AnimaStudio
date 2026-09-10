export type CADSelectionFilter = "auto" | "component" | "body" | "face" | "edge" | "vertex";
export type CADSelectionKind = Exclude<CADSelectionFilter, "auto">;
export type CADBoxSelectionMode = "window" | "crossing";

export interface CADSelectionItem {
  id: string;
  kind: CADSelectionKind;
  partId: string;
  label: string;
  detail?: string;
  faceId?: number;
}

export interface CADSelectionBox {
  startX: number;
  startY: number;
  currentX: number;
  currentY: number;
  mode: CADBoxSelectionMode;
}

export interface CADScreenRect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface CADSelectionSnapshot {
  filter: CADSelectionFilter;
  items: readonly CADSelectionItem[];
  hovered: CADSelectionItem | null;
  box: CADSelectionBox | null;
}

export type CADSelectionAction =
  | { type: "set-filter"; filter: CADSelectionFilter }
  | { type: "set-hovered"; item: CADSelectionItem | null }
  | { type: "replace"; items: readonly CADSelectionItem[] }
  | { type: "add"; items: readonly CADSelectionItem[] }
  | { type: "toggle"; items: readonly CADSelectionItem[] }
  | { type: "clear" }
  | { type: "set-box"; box: CADSelectionBox | null };

export const selectionFilters: readonly CADSelectionFilter[] = [
  "auto",
  "component",
  "body",
  "face",
  "edge",
  "vertex",
];

export const defaultCADSelection: CADSelectionSnapshot = Object.freeze({
  filter: "auto",
  items: [],
  hovered: null,
  box: null,
});

export function boxSelectionMode(startX: number, currentX: number): CADBoxSelectionMode {
  return currentX >= startX ? "window" : "crossing";
}

export function normalizedSelectionBox(box: CADSelectionBox): {
  left: number;
  top: number;
  right: number;
  bottom: number;
  width: number;
  height: number;
} {
  const left = Math.min(box.startX, box.currentX);
  const right = Math.max(box.startX, box.currentX);
  const top = Math.min(box.startY, box.currentY);
  const bottom = Math.max(box.startY, box.currentY);
  return { left, top, right, bottom, width: right - left, height: bottom - top };
}

export function selectionRectangleMatches(
  mode: CADBoxSelectionMode,
  selection: CADScreenRect,
  candidate: CADScreenRect,
): boolean {
  return mode === "window"
    ? candidate.left >= selection.left && candidate.right <= selection.right &&
      candidate.top >= selection.top && candidate.bottom <= selection.bottom
    : candidate.right >= selection.left && candidate.left <= selection.right &&
      candidate.bottom >= selection.top && candidate.top <= selection.bottom;
}

function unique(items: readonly CADSelectionItem[]): readonly CADSelectionItem[] {
  return [...new Map(items.map((item) => [item.id, item] as const)).values()];
}

export function reduceCADSelection(
  current: CADSelectionSnapshot,
  action: CADSelectionAction,
): CADSelectionSnapshot {
  switch (action.type) {
    case "set-filter":
      return { ...current, filter: action.filter, hovered: null };
    case "set-hovered":
      return { ...current, hovered: action.item };
    case "replace":
      return { ...current, items: unique(action.items), box: null };
    case "add":
      return { ...current, items: unique([...current.items, ...action.items]), box: null };
    case "toggle": {
      const toggled = new Set(action.items.map((item) => item.id));
      const retained = current.items.filter((item) => !toggled.has(item.id));
      const existing = new Set(current.items.map((item) => item.id));
      return {
        ...current,
        items: unique([
          ...retained,
          ...action.items.filter((item) => !existing.has(item.id)),
        ]),
        box: null,
      };
    }
    case "clear":
      return { ...current, items: [], hovered: null, box: null };
    case "set-box":
      return { ...current, box: action.box };
  }
}

type Listener = () => void;

export class CADSelectionStore {
  private current: CADSelectionSnapshot = defaultCADSelection;
  private listeners = new Set<Listener>();

  snapshot = (): CADSelectionSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  dispatch(action: CADSelectionAction): void {
    this.current = Object.freeze(reduceCADSelection(this.current, action));
    this.listeners.forEach((listener) => listener());
  }
}

export function selectedPartIDs(snapshot: CADSelectionSnapshot): ReadonlySet<string> {
  return new Set(snapshot.items.map((item) => item.partId));
}

export const cadSelection = new CADSelectionStore();
