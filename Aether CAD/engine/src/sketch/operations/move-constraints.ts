import type { SketchDrawing } from "../drawing";
import type { SketchTransform } from "../curves/similarity";
import { copyInternalConstraints } from "./copy-constraints";

/** Reuse similarity adaptation with original identities. Relations to unselected
 * geometry, fixed anchors and unsupported adaptations remain authoritative;
 * the caller rejects the move if their residuals no longer hold. */
export function moveInternalConstraints(source:SketchDrawing,indices:number[],transform:SketchTransform) {
  const adapted=copyInternalConstraints(source,indices,0,transform,true);
  const ids=new Set(adapted.map(c=>c.id));
  for(const constraint of adapted) {
    for(const ref of [constraint.a,constraint.b,constraint.axis])if(ref)ref.contour=indices[ref.contour];
    const original=source.constraints!.find(c=>c.id===constraint.id)!;
    // A moved follower must remain linked to an unmoved driver, not flatten it.
    if(original.valueFrom!==undefined&&!ids.has(original.valueFrom)) {
      for(const key of ["valueFrom","valueSign","valueScale","valueOffset"] as const) {
        if(original[key]===undefined)delete constraint[key];
        else Object.assign(constraint,{[key]:original[key]});
      }
      delete constraint.valueExpression;
    }
  }
  const byId=new Map(adapted.map(c=>[c.id,c]));
  return source.constraints?.map(original=>original.kind==="fix" ? structuredClone(original) : byId.get(original.id)??structuredClone(original));
}
