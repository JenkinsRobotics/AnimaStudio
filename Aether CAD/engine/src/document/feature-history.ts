import {
  validatePartDocument,
  type PartDocument,
  type PartFeature,
} from "./part-document";
export const rollbackPosition = (doc: PartDocument) =>
  doc.rollbackIndex ?? doc.features.length;
export function bodyIDForFeature(
  doc: PartDocument,
  feature: PartFeature,
): string {
  if (
    (feature.type === "extrude" || feature.type === "revolve") &&
    feature.bodyId
  )
    return feature.bodyId;
  const first = doc.features.find(
    (f) =>
      (f.type === "extrude" || f.type === "revolve") && f.operation === "new",
  );
  return first?.id === feature.id
    ? `${doc.documentId}:body-1`
    : `${doc.documentId}:body-${feature.id}`;
}
function stableBodies(doc: PartDocument): PartDocument {
  return {
    ...structuredClone(doc),
    features: doc.features.map((f) =>
      (f.type === "extrude" || f.type === "revolve") && f.operation === "new"
        ? { ...f, bodyId: bodyIDForFeature(doc, f) }
        : structuredClone(f),
    ),
  };
}
export function featureDependencies(doc: PartDocument): Map<string, string[]> {
  const result = new Map<string, string[]>(),
    bodyProducers = new Map<string, string>();
  let lastBody: string | undefined;
  for (const f of doc.features) {
    const refs: string[] = [];
    if ("profileFeatureId" in f) refs.push(f.profileFeatureId);
    if ("sourceFeatureId" in f) refs.push(f.sourceFeatureId);
    if (f.type === "profile" && f.profile.type === "projection") refs.push(f.profile.sourceFeatureId);
    if (
      (f.type === "extrude" || f.type === "revolve") &&
      f.operation === "new"
    ) {
      lastBody = bodyIDForFeature(doc, f);
      bodyProducers.set(lastBody, f.id);
    } else if (!["sketch", "profile", "plane"].includes(f.type)) {
      const body =
        "targetBodyId" in f && f.targetBodyId ? f.targetBodyId : lastBody;
      const producer = body && bodyProducers.get(body);
      if (producer) refs.push(producer);
    }
    result.set(f.id, [...new Set(refs)]);
  }
  return result;
}
export function dependentFeatures(doc: PartDocument, id: string): Set<string> {
  const affected = new Set([id]);
  for (const [key, refs] of featureDependencies(doc))
    if (refs.some((r) => affected.has(r))) affected.add(key);
  return affected;
}
export function setFeatureSuppressed(
  doc: PartDocument,
  id: string,
  suppressed: boolean,
): PartDocument {
  const next = structuredClone(doc),
    affected = suppressed ? dependentFeatures(doc, id) : new Set([id]);
  if (!suppressed) {
    const deps = featureDependencies(doc);
    const visit = (key: string) => {
      for (const ref of deps.get(key) ?? [])
        if (!affected.has(ref)) {
          affected.add(ref);
          visit(ref);
        }
    };
    visit(id);
  }
  next.features = next.features.map((f) =>
    affected.has(f.id) ? { ...f, suppressed } : f,
  );
  validatePartDocument(next);
  return next;
}
export function insertFeature(
  doc: PartDocument,
  feature: PartFeature,
): PartDocument {
  const next = stableBodies(doc),
    index = rollbackPosition(doc);
  if (
    (feature.type === "extrude" || feature.type === "revolve") &&
    feature.operation === "new"
  )
    feature = {
      ...feature,
      bodyId:
        feature.bodyId ??
        (doc.features.some(
          (f) =>
            (f.type === "extrude" || f.type === "revolve") &&
            f.operation === "new",
        )
          ? `${doc.documentId}:body-${feature.id}`
          : `${doc.documentId}:body-1`),
    };
  next.features.splice(index, 0, feature);
  if (doc.rollbackIndex !== undefined) next.rollbackIndex = index + 1;
  validatePartDocument(next);
  return next;
}
export function moveFeature(
  doc: PartDocument,
  id: string,
  delta: number,
): PartDocument {
  const next = stableBodies(doc),
    index = next.features.findIndex((f) => f.id === id),
    target = index + delta;
  if (index < 0 || target < 0 || target >= next.features.length)
    throw new Error("Choose a position inside the feature history.");
  const [feature] = next.features.splice(index, 1);
  next.features.splice(target, 0, feature);
  validatePartDocument(next);
  return next;
}
export function removeFeature(doc: PartDocument, id: string): PartDocument {
  const next = stableBodies(doc),
    affected = dependentFeatures(doc, id),
    cutoff = rollbackPosition(doc);
  next.features = next.features.filter((f) => !affected.has(f.id));
  if (doc.rollbackIndex !== undefined)
    next.rollbackIndex = doc.features
      .slice(0, cutoff)
      .filter((f) => !affected.has(f.id)).length;
  validatePartDocument(next);
  return next;
}
export function availableBodies(
  doc: PartDocument,
): { id: string; name: string; visible: boolean }[] {
  return doc.features
    .slice(0, rollbackPosition(doc))
    .filter(
      (f) =>
        !f.suppressed &&
        (f.type === "extrude" || f.type === "revolve") &&
        f.operation === "new",
    )
    .map((f) => {
      const id = bodyIDForFeature(doc, f);
      const ordinal =
        doc.features
          .filter(
            (item) =>
              (item.type === "extrude" || item.type === "revolve") &&
              item.operation === "new",
          )
          .findIndex((item) => item.id === f.id) + 1;
      return {
        id,
        name: doc.bodyProperties?.[id]?.name ?? `Body ${ordinal}`,
        visible: doc.bodyProperties?.[id]?.visible ?? true,
      };
    });
}
