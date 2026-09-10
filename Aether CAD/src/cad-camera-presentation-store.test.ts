import { describe, expect, it, vi } from "vitest";
import { CADCameraPresentationStore } from "./cad-camera-presentation-store";

describe("CADCameraPresentationStore", () => {
  it("publishes changed renderer orientation without duplicate notifications", () => {
    const store = new CADCameraPresentationStore();
    const listener = vi.fn();
    store.subscribe(listener);

    store.setOrientation([0, 0, 0, 1]);
    expect(listener).not.toHaveBeenCalled();
    store.setOrientation([0, 0.5, 0, 0.8660254]);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(store.snapshot().orientation).toEqual([0, 0.5, 0, 0.8660254]);
  });

  it("forwards typed navigation intent only while a viewer handler is live", () => {
    const store = new CADCameraPresentationStore();
    const handler = vi.fn();
    expect(store.dispatch({ type: "fit-isometric" })).toBe(false);

    const release = store.registerActionHandler(handler);
    expect(store.dispatch({ type: "select-view", view: "top" })).toBe(true);
    expect(store.dispatch({ type: "nudge", horizontalSteps: -1, verticalSteps: 0 })).toBe(true);
    expect(store.dispatch({ type: "roll", quarterTurns: 1 })).toBe(true);
    expect(handler.mock.calls.map(([action]) => action)).toEqual([
      { type: "select-view", view: "top" },
      { type: "nudge", horizontalSteps: -1, verticalSteps: 0 },
      { type: "roll", quarterTurns: 1 },
    ]);

    release();
    expect(store.dispatch({ type: "fit-isometric" })).toBe(false);
  });
});
