import { createRequire } from "node:module";
import { beforeAll, beforeEach, afterAll, expect, it, vi } from "vitest";
import {
  createEmptyPartDocument,
  resolveProfileDrawing,
  parsePartDocument,
  serializePartDocument,
} from "@aether/core/document";
import { openProjectionEditor } from "./projection-editor";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let dom, doc, apply;
beforeAll(() => {
  dom = new JSDOM("", { url: "http://localhost/cad/" });
  for (const key of [
    "window",
    "document",
    "HTMLElement",
    "Event",
    "CustomEvent",
  ])
    vi.stubGlobal(key, dom.window[key]);
});
afterAll(() => {
  dom.window.close();
  vi.unstubAllGlobals();
});
beforeEach(() => {
  document.body.innerHTML = '<div class="cad-studio-viewport"></div>';
  doc = createEmptyPartDocument("Projection");
  doc.features.push(
    ...[4, 8].map((r, i) => ({
      id: `source-${i}`,
      type: "profile",
      name: `Source ${i}`,
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: {
        type: "circle",
        centerMillimeters: [0, 0],
        radiusMillimeters: r,
      },
    })),
  );
  apply = vi.fn(async (next) => {
    doc = next;
  });
});
const click = (text) => {
  const b = [...document.querySelectorAll("button")].find(
    (b) => b.textContent === text,
  );
  expect(b).toBeTruthy();
  b.click();
};
const set = (label, value) => {
  const input = document.querySelector(`[aria-label="${label}"]`);
  input.value = value;
  input.dispatchEvent(new Event("input", { bubbles: true }));
};
it("creates a reference-only projection with preview and relinks it after native reopen", async () => {
  openProjectionEditor(() => doc, apply);
  expect(document.querySelector("dialog")).toBeNull();
  expect(document.querySelector(".sketch-contour").getAttribute("r")).toBe("4");
  set("Projection name", "Linked profile");
  click("Create projection");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  expect(document.querySelector('[aria-label="Project sketch"]')).toBeNull();
  doc = parsePartDocument(serializePartDocument(doc));
  const linked = doc.features.at(-1);
  expect(linked.profile).toEqual({
    type: "projection",
    sourceFeatureId: "source-0",
  });
  openProjectionEditor(() => doc, apply, linked);
  set("Source sketch", "source-1");
  expect(document.querySelector(".sketch-contour").getAttribute("r")).toBe("8");
  click("Update projection");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  expect(doc.features.at(-1).id).toBe(linked.id);
  expect(doc.features.at(-1).profile.sourceFeatureId).toBe("source-1");
});
it("blocks invalid projection previews and preserves the document on cancellation or stale edits", async () => {
  openProjectionEditor(() => doc, apply);
  set("Plane offset (mm)", "");
  expect(document.querySelector('[role="status"]').textContent).toContain(
    "finite plane offset",
  );
  expect(
    [...document.querySelectorAll("button")].find(
      (b) => b.textContent === "Create projection",
    ).disabled,
  ).toBe(true);
  set("Plane offset (mm)", "0");
  const original = doc;
  doc = structuredClone(doc);
  click("Create projection");
  expect(apply).not.toHaveBeenCalled();
  expect(document.querySelector('[role="status"]').textContent).toContain(
    "document changed",
  );
  click("Cancel");
  expect(doc).toEqual(original);
});
it("does not replace an active sketch and allows repairing a missing source reference", () => {
  document.querySelector(".cad-studio-viewport").innerHTML =
    '<section class="cad-sketch-workspace"></section>';
  expect(() => openProjectionEditor(() => doc, apply)).toThrow(
    "Finish or cancel",
  );
  document.querySelector(".cad-sketch-workspace").remove();
  const broken = {
    id: "broken",
    type: "profile",
    name: "Broken projection",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: { type: "projection", sourceFeatureId: "missing" },
  };
  doc.features.push(broken);
  openProjectionEditor(() => doc, apply, broken);
  expect(document.querySelector('[role="status"]').textContent).toContain(
    "Broken projection reference",
  );
  set("Source sketch", "source-0");
  expect(document.querySelector(".sketch-contour")).toBeTruthy();
  click("Cancel");
});
it("preserves a selected contour reference when editing projection settings", async () => {
  doc.features[0].profile = {
    type: "drawing",
    contours: [
      { type: "circle", id: "rim", center: [0, 0], radius: 4 },
      { type: "circle", id: "hub", center: [0, 0], radius: 2 },
    ],
  };
  const linked = {
    id: "linked",
    type: "profile",
    name: "Rim",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "projection",
      sourceFeatureId: "source-0",
      sourceContourId: "rim",
    },
  };
  doc.features.push(linked);
  openProjectionEditor(() => doc, apply, linked);
  set("Projection name", "Rim copy");
  click("Update projection");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  expect(doc.features.at(-1).profile).toEqual(linked.profile);
});
it("creates one linked contour atomically and retains its identity after reordering and reopen", async () => {
  doc.features[0].profile = {
    type: "drawing",
    contours: [
      { type: "circle", center: [0, 0], radius: 4 },
      { type: "circle", center: [10, 0], radius: 2 },
    ],
  };
  const original = structuredClone(doc);
  openProjectionEditor(() => doc, apply);
  set("Source geometry", "contour:1");
  expect(document.querySelectorAll(".sketch-contour")).toHaveLength(1);
  expect(document.querySelector(".sketch-contour").getAttribute("r")).toBe("2");
  expect(doc).toEqual(original);
  click("Cancel");
  expect(doc).toEqual(original);
  openProjectionEditor(() => doc, apply);
  set("Source geometry", "contour:1");
  click("Create projection");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  const linked = doc.features.at(-1),
    id = linked.profile.sourceContourId;
  expect(id).toBeTruthy();
  expect(doc.features[0].profile.contours[1].id).toBe(id);
  doc.features[0].profile.contours.reverse();
  doc.features[0].profile.contours[0].radius = 3;
  doc = parsePartDocument(serializePartDocument(doc));
  openProjectionEditor(() => doc, apply, doc.features.at(-1));
  expect(document.querySelector('[aria-label="Source geometry"]').value).toBe(
    "contour:0",
  );
  expect(document.querySelector(".sketch-contour").getAttribute("r")).toBe("3");
  click("Update projection");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2));
  expect(doc.features.at(-1).profile.sourceContourId).toBe(id);
});
it("keeps a deleted contour broken until the user explicitly selects a replacement", async () => {
  doc.features[0].profile = {
    type: "drawing",
    contours: [{ type: "circle", id: "remaining", center: [0, 0], radius: 4 }],
  };
  const linked = {
    id: "linked",
    type: "profile",
    name: "Missing",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "projection",
      sourceFeatureId: "source-0",
      sourceContourId: "deleted",
    },
  };
  doc.features.push(linked);
  openProjectionEditor(() => doc, apply, linked);
  expect(document.querySelector('[aria-label="Source geometry"]').value).toBe(
    "missing:deleted",
  );
  expect(document.querySelector('[role="status"]').textContent).toContain(
    "Broken projection contour reference",
  );
  click("Update projection");
  expect(apply).not.toHaveBeenCalled();
  set("Source geometry", "contour:0");
  click("Update projection");
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(1));
  expect(doc.features.at(-1).profile.sourceContourId).toBe("remaining");
});

it("creates an edge-on circle projection and follows source edits after native reopen",async()=>{
 openProjectionEditor(()=>doc,apply);set("Target plane","XZ");
 expect(document.querySelector(".sketch-contour")).not.toBeNull();
 click("Create projection");await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 doc=parsePartDocument(serializePartDocument(doc));const id=doc.features.at(-1).id;
 let result=resolveProfileDrawing(doc.features,id).contours[0];
 expect(result).toMatchObject({type:"path",start:[-4,0],segments:[{type:"line",end:[4,0]}]});
 doc.features[0].profile.contours[0].radius=7;
 result=resolveProfileDrawing(doc.features,id).contours[0];expect(result.start[0]).toBe(-7);expect(result.segments[0].end[0]).toBe(7);
 openProjectionEditor(()=>doc,apply,doc.features.at(-1));expect(document.querySelector(".sketch-contour")).not.toBeNull();click("Cancel");
});

it("preserves authored geometry when relinking a mixed projection",async()=>{
 const authored={type:"drawing",contours:[{type:"circle",center:[20,0],radius:2}],constraints:[]};
 const feature={id:"mixed",name:"Mixed",type:"profile",plane:"XY",offsetMillimeters:0,suppressed:false,profile:{type:"projection",sourceFeatureId:"source-0",authored}};
 doc.features.push(feature);openProjectionEditor(()=>doc,apply,feature);
 expect(document.querySelectorAll('.sketch-contour')).toHaveLength(2);
 set("Source sketch","source-1");click("Update projection");await vi.waitFor(()=>expect(apply).toHaveBeenCalledTimes(1));
 const saved=parsePartDocument(serializePartDocument(doc));expect(saved.features.at(-1).profile.authored).toEqual(authored);
 expect(resolveProfileDrawing(saved.features,"mixed").contours).toMatchObject([{radius:8},{radius:2}]);
});

it("opens the normal sketch workspace after saving a projection",async()=>{
 openProjectionEditor(()=>doc,apply);click("Save and edit geometry");await vi.waitFor(()=>expect(document.querySelector('[aria-label="Sketch workspace"]')).toBeTruthy());
 expect(apply).toHaveBeenCalledTimes(1);expect(doc.features.at(-1).profile.type).toBe('projection');expect(document.querySelector('.sketch-projected-background circle')).toBeTruthy();click('Cancel');
});

it("assigns whole-source identities only when saved and exposes them for authoring",async()=>{
 const before=structuredClone(doc);openProjectionEditor(()=>doc,apply);click('Cancel');expect(doc).toEqual(before);
 openProjectionEditor(()=>doc,apply);click('Save and edit geometry');await vi.waitFor(()=>expect(document.querySelector('[aria-label="Sketch workspace"]')).toBeTruthy());
 expect(doc.features[0].profile.type).toBe('drawing');const id=doc.features[0].profile.contours[0].id;expect(id).toBeTruthy();
 const options=[...document.querySelector('[aria-label="Entity B"]').options];expect(options.some(o=>o.value&&JSON.parse(o.value).projectedContourId===id)).toBe(true);click('Cancel');
});
