import {
  resolveSegmentReference,
  identifySegmentReference,
} from "../solver/segment-reference";
import { remapTrimContact, type RetainedContactInterval } from "./trim-contact";
import { preserveRemovedDimensionDrivers } from "../solver/dimension-links";
import type { SketchDrawing } from "../drawing";
import { preservesArcLocus, preservesLineLocus } from "./split-relations";
import type {
  DrawingConstraint,
  SketchEntityRef,
} from "../drawing-constraints";
/** Provenance for each output segment; partial endpoints have no original vertex. */
export interface TrimSegmentOrigin {
  segment: number;
  keepStart: boolean;
  keepEnd: boolean;
  whole: boolean;
  interval: [number, number];
}
export function remapTrimReferences(
  source: SketchDrawing,
  next: SketchDrawing,
  contour: number,
  layout: TrimSegmentOrigin[][],
  closed: boolean,
): void {
  if (
    source.constraints?.some(
      (c) =>
        c.kind !== "ellipse-shape" &&
        [c.a, c.b].some((r) => r?.contour === contour && r.kind === "contour"),
    )
  )
    throw Error("Remove the chain offset relation before trimming its edges.");
  const original = source.contours[contour];
  if (original.type !== "path") throw new Error("Expected path.");
  const count = original.segments.length;
  const vertices = new Map<number, SketchEntityRef>();
  const segments = new Map<number, SketchEntityRef>();
  const fragments = new Map<number, SketchEntityRef[]>();
  const contacts = new Map<number, RetainedContactInterval[]>();
  const controls = new Map<string, SketchEntityRef>();
  const vertex = (old: number, ref: SketchEntityRef) => {
    vertices.set(old, ref);
    if (closed && (old === 0 || old === count)) {
      vertices.set(0, ref);
      vertices.set(count, ref);
    }
  };
  layout.forEach((entries, offset) =>
    entries.forEach((entry, index) => {
      const current = contour + offset;
      const type = original.segments[entry.segment].type;
      const retained = contacts.get(entry.segment) ?? [];
      retained.push({ contour: current, index, interval: entry.interval });
      contacts.set(entry.segment, retained);
      if (type === "line" || type === "arc" || type === "ellipse") {
        const list = fragments.get(entry.segment) ?? [];
        list.push({ contour: current, kind: type, index });
        fragments.set(entry.segment, list);
      }
      if (entry.keepStart)
        vertex(entry.segment, { contour: current, kind: "point", index });
      if (entry.keepEnd)
        vertex(entry.segment + 1, {
          contour: current,
          kind: "point",
          index: index + 1,
        });
      if (entry.whole) {
        segments.set(entry.segment, { contour: current, kind: "line", index });
        for (const control of [0, 1] as const)
          controls.set(`${entry.segment}:${control}`, {
            contour: current,
            kind: "point",
            index,
            control,
          });
      }
    }),
  );
  const remap = (
    ref: SketchEntityRef,
    constraint: DrawingConstraint,
  ): SketchEntityRef | undefined => {
    if (ref.contour !== contour)
      return {
        ...ref,
        contour:
          ref.contour > contour ? ref.contour + layout.length - 1 : ref.contour,
      };
    if (ref.kind === "point")
      return ref.control !== undefined
        ? controls.get(`${ref.index}:${ref.control}`)
        : vertices.get(ref.index!);
    if (ref.kind === "curve")
      return remapTrimContact(ref, contacts.get(ref.index!) ?? []);
    const keepLocus =
      ref.kind === "arc"
        ? preservesArcLocus(constraint)
        : ref.kind === "ellipse"
          ? ["concentric", "ellipse-locus"].includes(constraint.kind)
          : ref.kind === "line" &&
            constraint.kind !== "length" &&
            preservesLineLocus(constraint);
    const replacement =
      segments.get(ref.index!) ??
      (keepLocus ? fragments.get(ref.index!)?.[0] : undefined);
    return replacement ? { ...ref, ...replacement, kind: ref.kind } : undefined;
  };
  const map = (
    ref: SketchEntityRef,
    constraint: DrawingConstraint,
  ): SketchEntityRef | undefined => {
    const normalized =
      ref.contour === contour ? resolveSegmentReference(original, ref) : ref;
    const mapped = remap(normalized, constraint);
    if (!mapped || ref.contour !== contour) return mapped;
    const {
      segmentId: oldEdge,
      vertexId: oldVertex,
      ...local
    } = { ...ref, ...mapped };
    return identifySegmentReference(next.contours[mapped.contour], local);
  };
  // Relations tied to removed/changed entities are removed, never rebound to a different vertex.
  next.constraints = (source.constraints ?? []).flatMap((constraint) => {
    const a = map(constraint.a, constraint),
      b = constraint.b ? map(constraint.b, constraint) : undefined,
      axis = constraint.axis ? map(constraint.axis, constraint) : undefined;
    return a && (!constraint.b || b) && (!constraint.axis || axis)
      ? [{ ...constraint, a, ...(b ? { b } : {}), ...(axis ? { axis } : {}) }]
      : [];
  });
  preserveRemovedDimensionDrivers(source, next);
  const used = new Set(next.constraints.map((c) => c.id));
  const id = (kind: string) => {
    const base = `trim-${contour}-${kind}`;
    let result = base,
      suffix = 0;
    while (used.has(result)) result = `${base}-${++suffix}`;
    used.add(result);
    return result;
  };
  for (const refs of fragments.values()) {
    const a = refs[0];
    for (const b of refs.slice(1)) {
      if (a.kind === "arc")
        next.constraints.push(
          { id: id("concentric"), kind: "concentric", a, b },
          { id: id("equal"), kind: "equal", a, b },
        );
      else if (
        a.kind === "ellipse" &&
        !source.constraints?.some(
          (c) => c.kind === "ellipse-shape" && c.a.contour === contour,
        )
      )
        next.constraints.push({
          id: id("ellipse-locus"),
          kind: "ellipse-locus",
          a,
          b,
        });
      else if (a.kind === "line")
        next.constraints.push(
          { id: id("parallel"), kind: "parallel", a, b },
          {
            id: id("collinear"),
            kind: "coincident",
            a: { contour: b.contour, kind: "point", index: b.index },
            b: a,
          },
        );
    }
  }
}
