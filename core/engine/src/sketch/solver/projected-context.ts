import type {SketchDrawing,SketchContour} from "../drawing";
import type {SketchEntityRef} from "./types";

/** Resolve external geometry without adding it to the authored coordinate array. */
export function referencedContour(d:SketchDrawing,r:SketchEntityRef):SketchContour|undefined {
  if(r?.projectedContourId===undefined)return d.contours[r?.contour];
  if(typeof r.projectedContourId!=="string"||!r.projectedContourId.trim()||r.contour!==-1)throw Error("Invalid projected constraint reference.");
  const matches=d.projectionContext?.filter(c=>c.id===r.projectedContourId)??[];
  if(matches.length!==1)throw Error(`Broken projected constraint reference: ${r.projectedContourId}.`);
  return matches[0];
}
