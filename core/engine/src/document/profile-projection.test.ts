import { expect, it } from "vitest";
import { createEmptyPartDocument, type ProfileFeature } from "./part-document";
import { parsePartDocument, serializePartDocument } from "./part-serialization";
import {
  profileSketchFrame,
  resolveProfileDrawing,
} from "./profile-projection";
const circle: ProfileFeature = {
  id: "source",
  type: "profile",
  name: "Source",
  plane: "XY",
  offsetMillimeters: 0,
  suppressed: false,
  profile: { type: "circle", centerMillimeters: [0, 0], radiusMillimeters: 5 },
};
const projection: ProfileFeature = {
  id: "linked",
  type: "profile",
  name: "Projected sketch",
  plane: "XY",
  offsetMillimeters: 0,
  suppressed: false,
  frame: {
    originMillimeters: [0, 0, 0],
    xDirection: [1, 0, 0],
    normal: [0, 0.6, 0.8],
  },
  profile: { type: "projection", sourceFeatureId: "source" },
};
it("saves only a stable source ID and rebuilds from source edits and renames", () => {
  const doc = createEmptyPartDocument("Linked sketches");
  doc.features.push(structuredClone(circle), structuredClone(projection));
  const saved = parsePartDocument(serializePartDocument(doc));
  expect((saved.features[1] as ProfileFeature).profile).toEqual({
    type: "projection",
    sourceFeatureId: "source",
  });
  const first = resolveProfileDrawing(saved.features, "linked").contours[0];
  if (first.type !== "path" || first.segments[0].type !== "ellipse")
    throw Error();
  expect(first.segments[0].radiusY).toBeCloseTo(4);
  const source = saved.features[0] as ProfileFeature;
  source.name = "Renamed";
  if (source.profile.type !== "circle") throw Error();
  source.profile.radiusMillimeters = 10;
  const second = resolveProfileDrawing(saved.features, "linked").contours[0];
  if (second.type !== "path" || second.segments[0].type !== "ellipse")
    throw Error();
  expect(second.segments[0].radiusY).toBeCloseTo(8);
  expect((saved.features[1] as ProfileFeature).profile.type).toBe("projection");
});
it("supports projection chains and reports suppressed, missing and forward references", () => {
  const a = structuredClone(circle),
    b = structuredClone(projection),
    c: ProfileFeature = {
      ...structuredClone(projection),
      id: "chain",
      profile: { type: "projection", sourceFeatureId: "linked" },
    };
  expect(resolveProfileDrawing([a, b, c], "chain").contours).toHaveLength(1);
  a.suppressed = true;
  expect(() => resolveProfileDrawing([a, b, c], "chain")).toThrow("suppressed");
  a.suppressed = false;
  expect(() => resolveProfileDrawing([b, c], "chain")).toThrow(
    "Broken projection reference",
  );
  expect(() => resolveProfileDrawing([b, a], "linked")).toThrow("earlier");
  const doc = createEmptyPartDocument("Invalid");
  doc.features.push(b, a);
  expect(() => serializePartDocument(doc)).toThrow("earlier profile");
});
it("maps named planes using the kernel orientation and applies offsets once", () => {
  expect(
    profileSketchFrame({ ...circle, plane: "XZ", offsetMillimeters: 3 }),
  ).toEqual({
    originMillimeters: [0, -3, 0],
    normal: [0, -1, 0],
    xDirection: [1, 0, 0],
  });
  expect(
    profileSketchFrame({ ...circle, plane: "YZ", offsetMillimeters: 2 }),
  ).toEqual({
    originMillimeters: [2, 0, 0],
    normal: [1, 0, 0],
    xDirection: [0, 1, 0],
  });
  expect(profileSketchFrame({ ...projection, offsetMillimeters: 100 })).toEqual(
    projection.frame,
  );
});
it("includes projected sketches and downstream solids in source history operations", async () => {
  const { dependentFeatures, setFeatureSuppressed, removeFeature } =
    await import("./feature-history");
  const doc = createEmptyPartDocument("Dependencies");
  doc.features.push(structuredClone(circle), structuredClone(projection), {
    id: "solid",
    type: "extrude",
    name: "Extrude",
    profileFeatureId: "linked",
    distanceMillimeters: 2,
    operation: "new",
    suppressed: false,
  });
  expect([...dependentFeatures(doc, "source")]).toEqual([
    "source",
    "linked",
    "solid",
  ]);
  expect(
    setFeatureSuppressed(doc, "source", true).features.every(
      (f) => f.suppressed,
    ),
  ).toBe(true);
  expect(
    setFeatureSuppressed(
      setFeatureSuppressed(doc, "source", true),
      "solid",
      false,
    ).features.every((f) => !f.suppressed),
  ).toBe(true);
  expect(removeFeature(doc, "source").features).toHaveLength(0);
});

it("resolves authored constraints separately while keeping mixed projections live",()=>{
 const doc=createEmptyPartDocument("Mixed");
 const p=structuredClone(projection);p.frame=undefined;
 if(p.profile.type!=="projection")throw Error();
 p.profile.authored={type:"drawing",contours:[{type:"circle",center:[20,0],radius:2}],constraints:[{id:"radius",kind:"radius",a:{kind:"circle",contour:0},value:3}]};
 doc.features.push(structuredClone(circle),p);
 const saved=parsePartDocument(serializePartDocument(doc));
 const first=resolveProfileDrawing(saved.features,"linked");
 expect(first.contours).toMatchObject([{type:"circle",radius:5},{type:"circle",radius:expect.closeTo(3,6)}]);
 expect(first.constraints).toBeUndefined();
 const source=saved.features[0] as ProfileFeature;if(source.profile.type!=="circle")throw Error();source.profile.radiusMillimeters=8;
 expect(resolveProfileDrawing(saved.features,"linked").contours).toMatchObject([{radius:8},{radius:expect.closeTo(3,6)}]);
 const retained=saved.features[1] as ProfileFeature;if(retained.profile.type!=="projection")throw Error();
 expect(retained.profile.authored?.constraints?.[0].a.contour).toBe(0);
 expect(retained.profile.authored?.contours).toHaveLength(1);
});

it("rejects ambiguous mixed contour identities and invalid authored geometry",()=>{
 const source=structuredClone(circle);source.profile={type:"drawing",contours:[{id:"same",type:"circle",center:[0,0],radius:5}]};
 const p=structuredClone(projection);p.frame=undefined;if(p.profile.type!=="projection")throw Error();
 p.profile.authored={type:"drawing",contours:[{id:"same",type:"circle",center:[20,0],radius:2}]};
 expect(()=>resolveProfileDrawing([source,p],p.id)).toThrow("duplicate contour identity");
 p.profile.authored.contours[0]={type:"circle",center:[20,0],radius:-1};
 const doc=createEmptyPartDocument("Invalid");doc.features.push(source,p);expect(()=>serializePartDocument(doc)).toThrow();
});

it("rebuilds native mixed-sketch constraints against a stable projected contour",()=>{
 const doc=createEmptyPartDocument("Linked constraint");
 const s=structuredClone(circle);s.profile={type:"drawing",contours:[{id:"rim",type:"circle",center:[10,0],radius:5}]};
 const p=structuredClone(projection);p.frame=undefined;if(p.profile.type!=="projection")throw Error();
 p.profile.authored={type:"drawing",contours:[{type:"circle",center:[0,0],radius:2}],constraints:[{id:"concentric",kind:"concentric",a:{kind:"circle",contour:0},b:{kind:"circle",contour:-1,projectedContourId:"rim"}}]};
 doc.features.push(s,p);const saved=parsePartDocument(serializePartDocument(doc));
 const resolved=resolveProfileDrawing(saved.features,p.id);expect(resolved.contours[1]).toMatchObject({center:[expect.closeTo(10),expect.closeTo(0)]});
 const source=saved.features[0] as ProfileFeature;if(source.profile.type!=="drawing"||source.profile.contours[0].type!=="circle")throw Error();source.profile.contours[0].center=[15,4];
 expect(resolveProfileDrawing(saved.features,p.id).contours[1]).toMatchObject({center:[expect.closeTo(15),expect.closeTo(4)]});
 expect((saved.features[1] as ProfileFeature).profile).toMatchObject({authored:{constraints:[{b:{contour:-1,projectedContourId:"rim"}}]}});
});

it("rejects editor projection context in persisted authored data",()=>{
 const doc=createEmptyPartDocument("No derived snapshots");const p=structuredClone(projection);if(p.profile.type!=="projection")throw Error();
 p.profile.authored={type:"drawing",contours:[],projectionContext:[{id:"derived",type:"circle",center:[0,0],radius:5}]};doc.features.push(structuredClone(circle),p);
 expect(()=>serializePartDocument(doc)).toThrow("must not be saved");
});
