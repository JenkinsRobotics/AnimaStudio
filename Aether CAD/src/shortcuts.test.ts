import { describe, expect, it } from "vitest";
import { ShortcutRegistry, defaultShortcuts, shortcutSignature } from "./shortcuts";
import { sketchConstraintCatalog } from "./sketch/constraint-catalog";

const press = (key: string, modifiers: Partial<KeyboardEvent> = {}) =>
  ({ key, shiftKey: false, ctrlKey: false, altKey: false, metaKey: false, ...modifiers }) as KeyboardEvent;

describe("shortcut registry", () => {
  it("binds the dimension tool to d, as Onshape does", () => {
    // The id is the real command, not a tool alias nothing answers to.
    expect(new ShortcutRegistry().commandFor(press("d"))).toBe("sketch-constraint-distance");
  });

  it("takes constraint bindings from the catalog, so they cannot diverge", () => {
    const registry = new ShortcutRegistry();
    for (const entry of sketchConstraintCatalog) {
      const binding = defaultShortcuts.find((b) => b.id === `sketch-constraint-${entry.kind}`);
      expect(binding?.keys, `${entry.label} is unbound`).toBe(entry.shortcut);
    }
    expect(registry.commandFor(press("i"))).toBe("sketch-constraint-coincident");
    expect(registry.commandFor(press("l", { shiftKey: true }))).toBe(
      "sketch-constraint-perpendicular",
    );
  });

  it("distinguishes a modified key from its bare form", () => {
    const registry = new ShortcutRegistry();
    expect(registry.commandFor(press("l"))).toBe("sketch-line");
    expect(registry.commandFor(press("l", { shiftKey: true }))).toBe(
      "sketch-constraint-perpendicular",
    );
  });

  it("ships without a conflicting default binding", () => {
    expect(new ShortcutRegistry().conflicts()).toEqual([]);
  });

  it("lets a user remap and reset without editing feature code", () => {
    const registry = new ShortcutRegistry();
    registry.remap("sketch-constraint-distance", "shift d");
    expect(registry.commandFor(press("d"))).toBeNull();
    expect(registry.commandFor(press("d", { shiftKey: true }))).toBe("sketch-constraint-distance");
    registry.reset("sketch-constraint-distance");
    expect(registry.commandFor(press("d"))).toBe("sketch-constraint-distance");
  });

  it("reports a remap that shadows another command instead of hiding it", () => {
    const registry = new ShortcutRegistry();
    registry.remap("sketch-constraint-distance", "l");
    expect(registry.conflicts()).toEqual([
      { keys: "l", ids: ["sketch-line", "sketch-constraint-distance"] },
    ]);
  });

  it("treats binding order as irrelevant", () => {
    expect(shortcutSignature("shift l")).toBe(shortcutSignature("l shift"));
  });
});
