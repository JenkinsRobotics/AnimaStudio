import { sketchConstraintCatalog } from "./sketch/constraint-catalog";

/** THE central keyboard map.
 *
 *  Every shortcut in the product is declared here, in one table, so a theme, a
 *  user preference file, or a future settings panel can remap them without
 *  hunting through feature code. Nothing else should hard-code a key.
 *
 *  A binding is written the way it is shown to the user — "d", "shift l" — and
 *  matched case-insensitively against a keyboard event. */
export interface ShortcutBinding {
  /** Command id, matching the command registry where one exists. */
  id: string;
  label: string;
  /** Onshape-compatible binding, e.g. "d", "shift m". Empty = unbound. */
  keys: string;
  group: "Sketch tools" | "Constrain" | "Dimension" | "View";
}

/** Sketch drawing tools. Onshape's single-letter defaults. */
const sketchTools: readonly ShortcutBinding[] = [
  { id: "sketch-select", label: "Select", keys: "s", group: "Sketch tools" },
  { id: "sketch-line", label: "Line", keys: "l", group: "Sketch tools" },
  { id: "sketch-rectangle", label: "Rectangle", keys: "r", group: "Sketch tools" },
  { id: "sketch-circle", label: "Circle", keys: "c", group: "Sketch tools" },
  { id: "sketch-arc", label: "Arc", keys: "a", group: "Sketch tools" },
  { id: "sketch-trim", label: "Trim", keys: "shift t", group: "Sketch tools" },
  { id: "sketch-offset", label: "Offset", keys: "o", group: "Sketch tools" },
  { id: "sketch-mirror", label: "Mirror", keys: "m", group: "Sketch tools" },
];

/** The dimension tool. Onshape binds it to d. The id is the command the ribbon
 *  Dimension button runs, so the keyboard and the ribbon invoke the same thing
 *  rather than a tool id that no command answers to. */
const dimensionTools: readonly ShortcutBinding[] = [
  { id: "sketch-constraint-distance", label: "Dimension", keys: "d", group: "Dimension" },
];

/** Constraints take their bindings from the catalog, so the menu and the
 *  keyboard can never disagree about which key applies which relationship. */
const constraintShortcuts: readonly ShortcutBinding[] = sketchConstraintCatalog.map((entry) => ({
  id: `sketch-constraint-${entry.kind}`,
  label: entry.label,
  keys: entry.shortcut,
  group: "Constrain" as const,
}));

export const defaultShortcuts: readonly ShortcutBinding[] = [
  ...sketchTools,
  ...dimensionTools,
  ...constraintShortcuts,
];

/** Normalise a binding or a keyboard event to one comparable string. */
export function shortcutSignature(source: KeyboardEvent | string): string {
  if (typeof source === "string")
    return source.trim().toLowerCase().split(/\s+/).sort().join("+");
  const parts = [source.key.toLowerCase()];
  if (source.shiftKey) parts.push("shift");
  if (source.ctrlKey) parts.push("ctrl");
  if (source.altKey) parts.push("alt");
  if (source.metaKey) parts.push("meta");
  return parts.sort().join("+");
}

/** A live, remappable map. Overrides are layered over the defaults, so a user
 *  or theme only states what it changes. */
export class ShortcutRegistry {
  private overrides = new Map<string, string>();

  bindings(): ShortcutBinding[] {
    return defaultShortcuts.map((binding) =>
      this.overrides.has(binding.id)
        ? { ...binding, keys: this.overrides.get(binding.id)! }
        : binding,
    );
  }

  /** Remap one command. Empty string unbinds it. */
  remap(id: string, keys: string): void {
    this.overrides.set(id, keys);
  }

  reset(id?: string): void {
    if (id) this.overrides.delete(id);
    else this.overrides.clear();
  }

  /** The command a key event should run, or null. */
  commandFor(event: KeyboardEvent): string | null {
    const signature = shortcutSignature(event);
    if (!signature) return null;
    const match = this.bindings().find(
      (binding) => binding.keys && shortcutSignature(binding.keys) === signature,
    );
    return match?.id ?? null;
  }

  /** Bindings that collide, so a remap cannot silently shadow a command. */
  conflicts(): { keys: string; ids: string[] }[] {
    const seen = new Map<string, string[]>();
    for (const binding of this.bindings()) {
      if (!binding.keys) continue;
      const signature = shortcutSignature(binding.keys);
      seen.set(signature, [...(seen.get(signature) ?? []), binding.id]);
    }
    return [...seen.entries()]
      .filter(([, ids]) => ids.length > 1)
      .map(([keys, ids]) => ({ keys, ids }));
  }
}

export const shortcuts = new ShortcutRegistry();
