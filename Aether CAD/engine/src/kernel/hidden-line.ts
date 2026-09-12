/** Hidden-line removal for drawing views — OCCT's own algorithm.
 *
 *  This is the classifier the Drawing packet describes as Core-owned work
 *  ("B-Rep projection, hidden-line classification"). It is not written here:
 *  `HLRBRep_Algo` is already in the OCCT/WASM build we ship, and it is the
 *  same algorithm FreeCAD's TechDraw and every desktop CAD drawing view use.
 *  We supply the view frame and read the classified result back as polylines.
 *
 *  See dev/docs/roadmap/FreeCAD_Inheritance.md.
 */
import type { TopAbs_ShapeEnum } from "replicad-opencascadejs";
import { getOC, type AnyShape } from "replicad";

/** A projected edge in view-plane millimetres. */
export type ViewPolyline = readonly (readonly [number, number])[];

export interface HiddenLineView {
  /** Sharp visible edges — the drawing's solid lines. */
  visible: readonly ViewPolyline[];
  /** Sharp occluded edges — the drawing's dashed lines. */
  hidden: readonly ViewPolyline[];
  /** Visible smooth silhouettes: a cylinder's side has no edge to find. */
  visibleOutline: readonly ViewPolyline[];
  /** Occluded smooth silhouettes. */
  hiddenOutline: readonly ViewPolyline[];
}

export interface HiddenLineOptions {
  /** Direction from the model toward the viewer — the view normal. Geometry
   *  further along it is nearer and occludes the rest. Default: front (-Y). */
  viewNormal?: readonly [number, number, number];
  /** Which way is up in the finished drawing. The projection's Y axis; its X
   *  axis is derived, so a view is reproducible rather than arbitrarily
   *  rotated. Default: world +Z (world +Y for a top or bottom view). */
  upDirection?: readonly [number, number, number];
  /** Angular tessellation tolerance in radians for curved edges. */
  angularToleranceRadians?: number;
  /** Chordal tessellation tolerance in millimetres for curved edges. */
  chordalToleranceMillimeters?: number;
}

/** Project `shape` and classify every edge as visible or hidden.
 *
 *  Costs a full HLR pass, so callers cache per (shape, direction) — a drawing
 *  view is regenerated on rebuild, not on pan.
 */
export function projectHiddenLineView(
  shape: AnyShape,
  options: HiddenLineOptions = {},
): HiddenLineView {
  const oc = getOC();
  const {
    viewNormal = [0, -1, 0],
    angularToleranceRadians = 0.1,
    chordalToleranceMillimeters = 0.01,
  } = options;
  const [dx, dy, dz] = viewNormal;
  if (Math.hypot(dx, dy, dz) < 1e-9)
    throw new Error("A drawing view needs a non-zero view direction.");
  // A view normal alone leaves the in-plane rotation to OCCT, which projects
  // the drawing at an arbitrary roll. Pin the plane's X axis from the up
  // direction: with Z = normal and Y = up, right-handedness gives X = up x Z.
  const up = options.upDirection ?? (
    Math.abs(dz) > 0.999 * Math.hypot(dx, dy, dz) ? [0, 1, 0] : [0, 0, 1]
  );
  const planeX: [number, number, number] = [
    up[1] * dz - up[2] * dy,
    up[2] * dx - up[0] * dz,
    up[0] * dy - up[1] * dx,
  ];
  if (Math.hypot(...planeX) < 1e-9)
    throw new Error("The up direction cannot be parallel to the view normal.");

  const algorithm = new oc.HLRBRep_Algo_1();
  // nbIso 0: no isoparametric curves. Those are a shaded-preview aid, not
  // drawing geometry, and they would pollute the edge sets.
  algorithm.Add_2(shape.wrapped, 0);
  const origin = new oc.gp_Pnt_3(0, 0, 0);
  const axis = new oc.gp_Dir_4(dx, dy, dz);
  const reference = new oc.gp_Dir_4(planeX[0], planeX[1], planeX[2]);
  const frame = new oc.gp_Ax2_2(origin, axis, reference);
  const projector = new oc.HLRAlgo_Projector_2(frame);
  algorithm.Projector_1(projector);
  algorithm.Update();
  algorithm.Hide_1();

  const handle = new oc.Handle_HLRBRep_Algo_2(algorithm);
  const result = new oc.HLRBRep_HLRToShape(handle);
  const read = (compound: ReturnType<typeof result.VCompound_1>) =>
    polylinesOf(compound, angularToleranceRadians, chordalToleranceMillimeters);
  const view: HiddenLineView = {
    visible: read(result.VCompound_1()),
    hidden: read(result.HCompound_1()),
    visibleOutline: read(result.OutLineVCompound_1()),
    hiddenOutline: read(result.OutLineHCompound_1()),
  };

  result.delete();
  handle.delete();
  projector.delete();
  frame.delete();
  reference.delete();
  axis.delete();
  origin.delete();
  algorithm.delete();
  return view;
}

/** Walk a compound's edges and tessellate each into view-plane points.
 *
 *  HLR returns the projection in the view frame with z ≈ 0, so the drawing
 *  coordinates are the x/y it hands back.
 */
function polylinesOf(
  compound: { IsNull: () => boolean } & Record<string, unknown>,
  angular: number,
  chordal: number,
): ViewPolyline[] {
  const oc = getOC();
  if (!compound || compound.IsNull()) return [];
  const polylines: ViewPolyline[] = [];
  const explorer = new oc.TopExp_Explorer_2(
    compound as never,
    oc.TopAbs_ShapeEnum.TopAbs_EDGE as TopAbs_ShapeEnum,
    oc.TopAbs_ShapeEnum.TopAbs_SHAPE as TopAbs_ShapeEnum,
  );
  while (explorer.More()) {
    const edge = oc.TopoDS.Edge_1(explorer.Current());
    const adaptor = new oc.BRepAdaptor_Curve_2(edge);
    // Two points minimum, so a straight edge stays a straight edge.
    const sampler = new oc.GCPnts_TangentialDeflection_2(
      adaptor as never, angular, chordal, 2, 1e-9, 1e-7,
    );
    const points: [number, number][] = [];
    for (let index = 1; index <= sampler.NbPoints(); index++) {
      const point = sampler.Value(index);
      points.push([point.X(), point.Y()]);
      point.delete();
    }
    if (points.length > 1) polylines.push(points);
    sampler.delete();
    adaptor.delete();
    explorer.Next();
  }
  explorer.delete();
  return polylines;
}
