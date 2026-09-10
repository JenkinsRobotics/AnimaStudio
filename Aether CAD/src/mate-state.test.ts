import { describe, expect, it } from "vitest";
import type { ConnectorCandidate } from "./domain";
import {
  FastenedMateDraft,
  MateConnectorRegistry,
  MateConstraintTracker,
} from "./mate-state";

const candidate: ConnectorCandidate = {
  id: "candidate",
  faceId: 1,
  kind: "face-center",
  label: "Face center",
  origin: [0, 0, 0],
  xAxis: [1, 0, 0],
  yAxis: [0, 1, 0],
  zAxis: [0, 0, 1],
};

describe("initial mate constraint policy", () => {
  it("rejects reusing an already-driven moving Part", () => {
    const tracker = new MateConstraintTracker();
    expect(tracker.canUseAsMoving("arm").allowed).toBe(true);
    tracker.markMovingPart("arm");
    expect(tracker.canUseAsMoving("arm")).toMatchObject({ allowed: false });
  });

  it("allows a constrained Part to remain a stationary target", () => {
    const tracker = new MateConstraintTracker();
    tracker.markMovingPart("base");
    expect(tracker.isConstrained("base")).toBe(true);
    // No target-side prohibition exists in the initial proof policy.
    expect(tracker.canUseAsMoving("arm").allowed).toBe(true);
  });

  it("clears all constraints with the demo reset", () => {
    const tracker = new MateConstraintTracker();
    tracker.markMovingPart("arm");
    tracker.clear();
    expect(tracker.canUseAsMoving("arm").allowed).toBe(true);
  });
});

describe("connector-first authoring", () => {
  it("allows any number of persistent connectors on the same Part", () => {
    const registry = new MateConnectorRegistry();
    registry.create("arm", "Arm", candidate);
    registry.create("arm", "Arm", candidate);
    registry.create("arm", "Arm", candidate);
    expect(registry.list()).toHaveLength(3);
    expect(new Set(registry.list().map((item) => item.id)).size).toBe(3);
  });

  it("requires two saved connectors on different Parts", () => {
    const registry = new MateConnectorRegistry();
    const armA = registry.create("arm", "Arm", candidate);
    const armB = registry.create("arm", "Arm", candidate);
    const base = registry.create("base", "Base", candidate);
    const draft = new FastenedMateDraft();

    expect(draft.choose(armA).kind).toBe("first");
    expect(draft.choose(armB)).toMatchObject({ kind: "rejected" });
    expect(draft.choose(base)).toMatchObject({
      kind: "complete",
      moving: { id: armA.id },
      target: { id: base.id },
    });
  });
});
