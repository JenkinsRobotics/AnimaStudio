import { createRequire } from "node:module";
import { afterAll, beforeAll, beforeEach, expect, it, vi } from "vitest";
import { createEmptyPartDocument, insertFeature } from "@aether/core/document";

// Characterization test for the feature dialogs. feature-authoring.ts carries
// every feature's controls, layout and serialization in three parallel
// if/else chains, with no direct test. This pins what each dialog SUBMITS so
// the per-feature split is provably behaviour-preserving — it asserts the
// payload handed to apply(), not the internal structure that is being moved.
const require = createRequire(new URL("../../core/ui/package.json", import.meta.url));
const { JSDOM } = require("jsdom");

let dom, mountFeatureAuthoring, cadCommands, doc, apply;

beforeAll(async () => {
  dom = new JSDOM("<!doctype html><html><body></body></html>", {
    url: "http://localhost/cad/index.html",
  });
  for (const key of ["window", "document", "HTMLElement", "CustomEvent", "Event", "location", "crypto"])
    vi.stubGlobal(key, dom.window[key]);
  vi.stubGlobal("confirm", () => true);
  mountFeatureAuthoring = (await import("./feature-authoring")).mountFeatureAuthoring;
  cadCommands = (await import("./cad-command-registry")).cadCommands;
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
beforeEach(() => {
  document.body.innerHTML = '<div class="cad-studio-viewport"></div>';
  doc = createEmptyPartDocument("Part");
  apply = vi.fn(async (next) => {
    doc = next;
  });
});

/** Seed a profile directly. The `profile` dialog branch in feature-authoring.ts
 * is unreachable — show() routes "profile" to the sketch workspace before any
 * form is built — so extrude/revolve/mirror are exercised against a seeded
 * document rather than a dialog that cannot open. */
const seedProfile = () => {
  doc = insertFeature(doc, {
    id: "profile-1",
    type: "profile",
    name: "Sketch 1",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: { type: "circle", radiusMillimeters: 10, centerMillimeters: [0, 0] },
  });
};

/** Open a feature dialog, set the named controls, commit, return the feature. */
const authored = async (type, values = {}) => {
  mountFeatureAuthoring(() => doc, apply);
  cadCommands.execute(`feature-${type}`);
  // Target the newest dialog: authoring several features in one test leaves
  // earlier panels in the DOM, and querySelector would return the stale one.
  const form = [...document.querySelectorAll("form")].at(-1);
  expect(form, `no dialog opened for ${type}`).toBeTruthy();
  // presentFeatureWindow moves each control out of the <form> into a window
  // row, keeping it associated by the `form` attribute — so search the panel.
  const panel = [...document.querySelectorAll(".cad-feature-dialog")].at(-1);
  for (const [label, value] of Object.entries(values)) {
    // Exact caption first. Only fall back to a unit-suffixed match, because
    // field() rewrites "(mm)"/"(degrees)" to the document's configured unit —
    // a bare prefix match would hit "Features to mirror" when asked for
    // "Feature".
    const control =
      panel.querySelector(`[aria-label="${label}"]`) ??
      panel.querySelector(`[aria-label^="${label} ("]`);
    expect(control, `${type}: no control labelled ${label}`).toBeTruthy();
    control.value = value;
    control.dispatchEvent(new dom.window.Event("change"));
  }
  const before = apply.mock.calls.length;
  form.dispatchEvent(new dom.window.Event("submit", { bubbles: true, cancelable: true }));
  // Wait for THIS commit, not any earlier one, or a blocked submit silently
  // returns the previously authored feature.
  await vi.waitFor(() => {
    if (apply.mock.calls.length <= before) {
      const why = [...panel.querySelectorAll('.aui-feature-error,[role="alert"]')]
        .map((e) => e.textContent).filter(Boolean).join(" | ");
      throw new Error(`${type} did not commit${why ? `: ${why}` : " (no message shown)"}`);
    }
  });
  const committed = apply.mock.calls.at(-1)[0].features.at(-1);
  // Dismiss the committed dialog so the next one is unambiguous.
  for (const cancel of document.querySelectorAll('[aria-label="Cancel"]')) cancel.click();
  return committed;
};

// The feature tree can select several features; suppress and delete must act on
// that whole set, in one undoable commit, not just the clicked row.
// Mount once: every mount adds a window listener for the whole file's lifetime,
// and a second listener re-handles the same event against the document the
// first one just committed (suppress would toggle straight back).
let treeMounted = false;
const treeAction = (actionID, clicked, selectedFeatureIDs) => {
  if (!treeMounted) {
    mountFeatureAuthoring(() => doc, (next) => apply(next));
    treeMounted = true;
  }
  window.dispatchEvent(new dom.window.CustomEvent("aether-feature-action", {
    detail: { type: "item-action", id: `feature/profile/${clicked}`, actionID, selectedFeatureIDs },
  }));
};

const seedTwoProfiles = () => {
  for (const id of ["profile-1", "profile-2"])
    doc = insertFeature(doc, {
      id, type: "profile", name: id, plane: "XY", offsetMillimeters: 0, suppressed: false,
      profile: { type: "circle", radiusMillimeters: 10, centerMillimeters: [0, 0] },
    });
};

it("deletes every selected feature in one commit", async () => {
  seedTwoProfiles();
  treeAction("delete-feature", "profile-1", ["profile-1", "profile-2"]);
  await vi.waitFor(() => expect(apply).toHaveBeenCalled());
  expect(apply).toHaveBeenCalledTimes(1);
  expect(doc.features).toHaveLength(0);
});

it("suppresses every selected feature, and leaves unselected features alone", async () => {
  seedTwoProfiles();
  treeAction("suppress-feature", "profile-1", ["profile-1"]);
  await vi.waitFor(() => expect(apply).toHaveBeenCalled());
  expect(doc.features.map((f) => f.suppressed)).toEqual([true, false]);
});

it("acts on the clicked row alone when it is outside the selection", async () => {
  seedTwoProfiles();
  treeAction("delete-feature", "profile-2", ["profile-1"]);
  await vi.waitFor(() => expect(apply).toHaveBeenCalled());
  expect(doc.features.map((f) => f.id)).toEqual(["profile-1"]);
});

it("routes profile to the sketch workspace instead of building a form", () => {
  mountFeatureAuthoring(() => doc, apply);
  cadCommands.execute("feature-profile");
  // The profile form branches in feature-authoring.ts are dead code.
  expect(document.querySelector("form")).toBeNull();
  expect(document.querySelector(".cad-sketch-workspace")).toBeTruthy();
});

it("serializes extrude with its distance and operation", async () => {
  seedProfile();
  const feature = await authored("extrude", { Sketch: "profile-1", "Distance": "25" });
  expect(feature).toMatchObject({ type: "extrude", distanceMillimeters: 25, operation: "new" });
  expect(feature.profileFeatureId).toBe("profile-1");
  expect(feature.suppressed).toBe(false);
  expect(feature.id).toBeTruthy();
});

it("serializes revolve with axis and angle", async () => {
  seedProfile();
  const feature = await authored("revolve", {
    Sketch: "profile-1",
    Axis: "Y",
    "Angle": "180",
  });
  expect(feature).toMatchObject({
    type: "revolve",
    axis: "Y",
    angleDegrees: 180,
    profileFeatureId: "profile-1",
  });
});

it("serializes mirror against its source feature and plane", async () => {
  seedProfile();
  // Seeded rather than authored: this test is about mirror's serialization, and
  // a stable id keeps it independent of how extrude happens to be committed.
  doc = insertFeature(doc, {
    id: "extrude-1",
    type: "extrude",
    name: "Extrude 1",
    suppressed: false,
    profileFeatureId: "profile-1",
    operation: "new",
    distanceMillimeters: 5,
  });
  const feature = await authored("mirror", { Feature: "extrude-1", "Mirror plane": "XZ" });
  expect(feature).toMatchObject({ type: "mirror", plane: "XZ", operation: "add" });
  expect(feature.sourceFeatureId).toBe("extrude-1");
});

it("serializes edge finishes, including the optional edge-plane scope", async () => {
  seedProfile();
  await authored("extrude", { Sketch: "profile-1", "Distance": "5" });
  const all = await authored("fillet", { "All-edge size": "2" });
  expect(all).toMatchObject({ type: "fillet", radiusMillimeters: 2 });
  expect(all.edgePlane).toBeUndefined();

  const scoped = await authored("chamfer", {
    "All-edge size": "1.5",
    Edges: "plane",
    "Edge plane": "YZ",
    "Edge plane offset": "3",
  });
  expect(scoped).toMatchObject({
    type: "chamfer",
    radiusMillimeters: 1.5,
    edgePlane: { plane: "YZ", offsetMillimeters: 3 },
  });
});

it("gives extrude the gallery anatomy: body/operation tabs and an entities box", () => {
  seedProfile();
  mountFeatureAuthoring(() => doc, apply);
  cadCommands.execute("feature-extrude");
  const panel = document.querySelector(".cad-feature-dialog");
  const tabRows = panel.querySelectorAll(".aui-feature-tabs");
  expect(tabRows.length).toBe(2);
  expect([...tabRows[0].children].map((t) => t.textContent)).toEqual(["Solid", "Surface", "Thin"]);
  expect([...tabRows[1].children].map((t) => t.textContent)).toEqual([
    "New",
    "Add",
    "Remove",
    "Intersect",
  ]);
  // Unimplemented options are visibly disabled rather than quietly missing.
  expect([...tabRows[0].children].slice(1).every((t) => t.disabled)).toBe(true);
  expect([...tabRows[1].children][3].disabled).toBe(true);
  expect(panel.textContent).toContain("Faces and sketch regions to extrude");
});

// The gallery is the design authority: the app's extrude must offer the same
// controls in the same order, not a reduced set. Controls the engine cannot
// honour yet stay visible and disabled rather than being dropped.
it("reproduces the gallery extrude layout control-for-control", () => {
  seedProfile();
  mountFeatureAuthoring(() => doc, apply);
  cadCommands.execute("feature-extrude");
  const panel = document.querySelector(".cad-feature-dialog");

  const endType = panel.querySelector('[aria-label="End type"]');
  expect(endType, "end type is a picker, as in the gallery").toBeTruthy();

  expect(panel.textContent).toContain("Depth");
  expect(panel.textContent).toContain("Up to entity");
  for (const section of ["Draft", "Direction", "Starting offset", "Second end position"])
    expect(panel.textContent, `missing sub-setting: ${section}`).toContain(section);
  expect(panel.querySelector('[aria-label="Direction reference"]')).toBeTruthy();
  expect(panel.querySelector('[aria-label="Second end type"]')).toBeTruthy();
  expect(panel.querySelectorAll(".aui-feature-subsection").length).toBe(4);

  // Depth is the one end-type option this engine evaluates, so it is live.
  const depth = panel.querySelector('[aria-label^="Distance"]');
  expect(depth.disabled).toBeFalsy();
});

// Every feature window follows the plane window's discipline: nothing is
// pre-selected, the requirement is stated live, and the accept control stays
// disabled until it is met — an invalid feature is never submittable.
it("refuses to commit a feature until its required selections are made", async () => {
  seedProfile();
  mountFeatureAuthoring(() => doc, apply);
  cadCommands.execute("feature-extrude");
  const panel = document.querySelector(".cad-feature-dialog");
  const accept = panel.querySelector('[aria-label="Apply and rebuild"]');
  const error = () => panel.querySelector(".aui-feature-error")?.textContent ?? "";

  // Nothing pre-selected, so the sketch reference is missing.
  expect(panel.querySelector(".aui-feature-entity")).toBeNull();
  expect(error()).toContain("sketch region to extrude");
  expect(accept.disabled).toBe(true);

  const source = panel.querySelector('[aria-label="Sketch"]');
  source.value = "profile-1";
  source.dispatchEvent(new dom.window.Event("change"));
  expect(error()).toBe("");
  expect(accept.disabled).toBe(false);

  // Clearing it puts the window straight back into the invalid state.
  source.value = "";
  source.dispatchEvent(new dom.window.Event("change"));
  expect(accept.disabled).toBe(true);
});

it("states every missing selection at once", async () => {
  seedProfile();
  mountFeatureAuthoring(() => doc, apply);
  cadCommands.execute("feature-mirror");
  const panel = document.querySelector(".cad-feature-dialog");
  // Mirror needs a source feature; the plane defaults to YZ, so only one is
  // outstanding and the message names exactly that one.
  expect(panel.querySelector(".aui-feature-error").textContent).toContain("feature to mirror");
  expect(panel.querySelector('[aria-label="Apply and rebuild"]').disabled).toBe(true);
});
