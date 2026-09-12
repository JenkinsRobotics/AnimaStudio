export interface PlaneFeature {id:string;name:string;type:"plane";plane:SketchPlane;offsetMillimeters:number;suppressed:boolean;definition?:PlaneDefinition;}
import { validateSketchDrawing, type SketchDrawing, type SketchFrame } from "../sketch/drawing";
import type { SketchPlane } from "../sketch/index";
import { resolvePlaneFrame, validatePlaneDefinition, type PlaneDefinition } from "./construction-planes";
export function constructionPlaneFrame(plane:PlaneFeature,earlier:readonly {id:string;type:string}[]=[]):SketchFrame {
 return resolvePlaneFrame(plane,earlier);
}
export interface ProfileFeature {
  id: string;
  type: "profile";
  name: string;
  plane: SketchPlane;
  offsetMillimeters: number;
  suppressed: boolean;
  frame?: SketchFrame;
  profile:
    | SketchDrawing
    | { type: "projection"; sourceFeatureId: string; sourceContourId?: string; authored?: SketchDrawing }
    | {
        type: "circle";
        radiusMillimeters: number;
        centerMillimeters: [number, number];
      }
    | { type: "polygon"; pointsMillimeters: [number, number][] };
}
export interface RevolveFeature {
  id: string;
  type: "revolve";
  name: string;
  profileFeatureId: string;
  axis: "X" | "Y" | "Z";
  angleDegrees: number;
  operation: "new" | "add" | "cut";
  bodyId?: string;
  targetBodyId?: string;
  suppressed: boolean;
}
export interface MirrorFeature {
  id: string;
  type: "mirror";
  name: string;
  sourceFeatureId: string;
  plane: SketchPlane;
  offsetMillimeters: number;
  operation: "add" | "cut";
  targetBodyId?: string;
  suppressed: boolean;
}
export type EdgeFinishFeature = {
  id: string;
  name: string;
  radiusMillimeters: number;
  targetBodyId?: string;
  edgePlane?: { plane: SketchPlane; offsetMillimeters: number };
  suppressed: boolean;
} & ({ type: "fillet" } | { type: "chamfer" });
export type SolidFeature =
  PlaneFeature | ProfileFeature | RevolveFeature | MirrorFeature | EdgeFinishFeature;
export function validateSolidFeature(
  feature: SolidFeature,
  earlier: Map<string, string>,
): void {
  const positive = (value: number, label: string) => {
    if (!Number.isFinite(value) || value <= 0)
      throw new Error(`${label} must be positive.`);
  };
  if(feature.type==="plane"){if(!["XY","XZ","YZ"].includes(feature.plane)||!Number.isFinite(feature.offsetMillimeters))throw new Error("Invalid construction plane.");validatePlaneDefinition(feature,new Set([...earlier].filter(([,type])=>type==="plane").map(([id])=>id)));return;}
  if (feature.type === "profile") {
    if (
      !["XY", "XZ", "YZ"].includes(feature.plane) ||
      !Number.isFinite(feature.offsetMillimeters)
    )
      throw new Error("Sketch plane or offset is invalid.");
    if (feature.frame) {
      const { originMillimeters: origin, xDirection: x, normal: n } = feature.frame;
      if (![origin,x,n].every(v => Array.isArray(v) && v.length===3 && v.every(Number.isFinite)) || Math.abs(Math.hypot(...x)-1)>1e-6 || Math.abs(Math.hypot(...n)-1)>1e-6 || Math.abs(x.reduce((sum,v,i)=>sum+v*n[i],0))>1e-6) throw new Error("Invalid sketch frame.");
    }
    if (feature.profile?.type === "projection") {
      if (feature.profile.authored !== undefined) {
        // External equations require the document source context, checked after feature validation.
        const authored=feature.profile.authored;
        if(authored.projectionContext!==undefined)throw Error("Resolved projection context must not be saved.");
        validateSketchDrawing({...authored,constraints:authored.constraints?.filter(c=>![c.a,c.b,c.axis].some(r=>r?.projectedContourId!==undefined))});
      }
      const contourId=feature.profile.sourceContourId;
      if(contourId!==undefined&&(typeof contourId!=="string"||!contourId.trim()||contourId.length>128))throw Error("Invalid projected contour identity.");
      if (typeof feature.profile.sourceFeatureId !== "string" || earlier.get(feature.profile.sourceFeatureId) !== "profile")
        throw new Error(`${feature.name}: projection must reference an earlier profile (${feature.profile.sourceFeatureId}).`);
    } else if (feature.profile?.type === "drawing") {
      if(feature.profile.projectionContext!==undefined)throw Error("Resolved projection context must not be saved.");
      validateSketchDrawing(feature.profile);
    } else if (feature.profile?.type === "circle") {
      positive(feature.profile.radiusMillimeters, "Circle radius");
      if (
        feature.profile.centerMillimeters?.length !== 2 ||
        !feature.profile.centerMillimeters.every(Number.isFinite)
      )
        throw new Error("Circle center is invalid.");
    } else if (feature.profile?.type === "polygon") {
      const points = feature.profile.pointsMillimeters;
      if (
        !Array.isArray(points) ||
        points.length < 3 ||
        points.length > 1000 ||
        !points.every(
          (p) => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite),
        )
      )
        throw new Error("A closed profile needs at least three finite points.");
      const area = points.reduce(
        (a, p, i) =>
          a +
          p[0] * points[(i + 1) % points.length][1] -
          points[(i + 1) % points.length][0] * p[1],
        0,
      );
      if (Math.abs(area) < 1e-8) throw new Error("Profile has zero area.");
    } else throw new Error("Unsupported sketch profile.");
  } else if (feature.type === "revolve") {
    if (
      !["profile", "sketch"].includes(
        earlier.get(feature.profileFeatureId) || "",
      )
    )
      throw new Error("Revolve must reference an earlier sketch.");
    positive(feature.angleDegrees, "Revolve angle");
    if (
      feature.angleDegrees > 360 ||
      !["X", "Y", "Z"].includes(feature.axis) ||
      !["new", "add", "cut"].includes(feature.operation)
    )
      throw new Error("Invalid revolve settings.");
  } else if (feature.type === "mirror") {
    if (
      !["extrude", "revolve", "mirror"].includes(
        earlier.get(feature.sourceFeatureId) || "",
      )
    )
      throw new Error("Mirror must reference an earlier solid feature.");
    if (
      !["XY", "XZ", "YZ"].includes(feature.plane) ||
      !Number.isFinite(feature.offsetMillimeters) ||
      !["add", "cut"].includes(feature.operation)
    )
      throw new Error("Invalid mirror settings.");
  } else if (feature.type === "fillet" || feature.type === "chamfer") {
    positive(feature.radiusMillimeters, "Edge finish size");
    if (
      feature.edgePlane &&
      (!["XY", "XZ", "YZ"].includes(feature.edgePlane.plane) ||
        !Number.isFinite(feature.edgePlane.offsetMillimeters))
    )
      throw new Error("Invalid edge selection plane.");
  } else throw new Error("Unsupported solid feature.");
}
