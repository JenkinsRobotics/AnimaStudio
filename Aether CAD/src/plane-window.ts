import { insertFeature, removeFeature, resolvePlaneFrame } from "@aether/core/document";
import type { SketchFrame } from "@aether/core/sketch";
import type {
  PartDocument,
  PartFeature,
  PlaneDefinition,
  PlaneReference,
  PointReference,
  AxisReference,
} from "@aether/core/document";
import { openFeatureWindow } from "@aether/ui";
import { cadSelection } from "./cad-selection-store";

type PlaneFeature = PartFeature & { type: "plane" };
type Principal = "XY" | "XZ" | "YZ";

const PRINCIPAL_LABELS: Record<Principal, string> = {
  XY: "Top plane",
  XZ: "Front plane",
  YZ: "Right plane",
};

/** Onshape-anatomy plane editor on the standard feature window: entities
 * box (viewport/tree clicks add references), method dropdown, offset
 * distance with flip-direction arrow, flip normal. ✓ commits, ✕ discards a
 * freshly created plane. */
export async function openPlaneWindow(
  getDocument: () => PartDocument | null,
  apply: (doc: PartDocument) => Promise<void>,
  existing?: PlaneFeature,
): Promise<void> {
  const viewport = document.querySelector<HTMLElement>(".cad-studio-viewport");
  const source = getDocument();
  if (!viewport || !source) return;
  if (viewport.querySelector(".cad-plane-window") || document.querySelector(".cad-sketch-workspace")) return;
  const feature: PlaneFeature =
    existing ??
    ({
      id: crypto.randomUUID(),
      type: "plane",
      name: `Plane ${source.features.filter((f) => f.type === "plane").length + 1}`,
      plane: "XY",
      offsetMillimeters: 10,
      suppressed: false,
      definition: {
        method: "offset",
        reference: { kind: "principal", plane: "XY" },
        distanceMillimeters: 10,
      },
    } satisfies PlaneFeature);
  const created = !existing;
  const earlierPlanes = (): PlaneFeature[] => {
    const doc = getDocument();
    if (!doc) return [];
    const cutoff = doc.features.findIndex((f) => f.id === feature.id);
    return doc.features
      .slice(0, cutoff < 0 ? doc.features.length : cutoff)
      .filter((f): f is PlaneFeature => f.type === "plane" && f.id !== feature.id);
  };
  const labelFor = (reference: PlaneReference): string =>
    reference.kind === "principal"
      ? PRINCIPAL_LABELS[reference.plane]
      : reference.kind === "face"
        ? (reference.label ?? `Face ${reference.faceId}`)
        : (earlierPlanes().find((f) => f.id === reference.featureId)?.name ?? "Missing plane");

  const initial = feature.definition ?? {
    method: "offset" as const,
    reference: { kind: "principal" as const, plane: feature.plane },
    distanceMillimeters: feature.offsetMillimeters,
  };
  // A NEW plane starts with an empty Entities box: the seeded definition exists
  // only so the feature is well-formed in the tree, and pre-filling "Top plane"
  // made it look like a choice the user had made. Editing an existing plane
  // still shows the references it was built from.
  // Existing planes show the references they were built from; the geometry
  // methods carry their own picks instead, restored just below.
  const references: PlaneReference[] = !created
    ? initial.method === "offset"
      ? [initial.reference]
      : initial.method === "mid"
        ? [...initial.references]
        : initial.method === "angle"
          ? [initial.reference]
          : []
    : [];
  let flip = Boolean(feature.definition?.flip);

  /** Points and an axis picked for the geometry-driven methods. */
  let points: PointReference[] =
    !created && initial.method === "three-point" ? [...initial.points] : [];
  let axis: AxisReference | null =
    !created && initial.method === "angle" ? initial.axis : null;

  /** The definition these controls currently describe, or null when the plane
   *  is not yet complete. One builder feeds the live preview AND the commit, so
   *  what you see in the viewport is exactly what gets saved. */
  const buildDefinition = (): PlaneDefinition | null => {
    if (methodPicker.value() === "Three point") {
      if (points.length !== 3) return null;
      return { method: "three-point", points: [points[0], points[1], points[2]], ...(flip ? { flip } : {}) };
    }
    if (methodPicker.value() === "Angle") {
      const angleDegrees = Number(angleInput.value);
      if (!axis || references.length !== 1 || !Number.isFinite(angleDegrees)) return null;
      return { method: "angle", axis, reference: references[0], angleDegrees, ...(flip ? { flip } : {}) };
    }
    if (methodPicker.value() === "Offset") {
      if (references.length !== 1) return null;
      const distanceMillimeters = Number(offsetInput.value);
      if (!Number.isFinite(distanceMillimeters)) return null;
      return { method: "offset", reference: references[0], distanceMillimeters, ...(flip ? { flip } : {}) };
    }
    if (references.length !== 2) return null;
    return { method: "mid", references: [references[0], references[1]], ...(flip ? { flip } : {}) };
  };

  /** Why the plane is not complete, in the window's own words. */
  const describeRequirement = (): string | null => {
    if (methodPicker.value() === "Three point")
      return points.length === 3
        ? null
        : `Three point needs exactly 3 points — ${points.length} selected.`;
    if (methodPicker.value() === "Angle") {
      if (!axis) return "Angle needs an edge to rotate about.";
      if (references.length !== 1)
        return `Angle needs exactly 1 reference plane — ${references.length} selected.`;
      if (!Number.isFinite(Number(angleInput.value))) return "Enter a finite angle in degrees.";
      return null;
    }
    const need = methodPicker.value() === "Offset" ? 1 : 2;
    const noun = need === 1 ? "reference plane" : "reference planes";
    if (references.length !== need)
      return `${methodPicker.value()} needs exactly ${need} ${noun} — ${references.length} selected.`;
    if (methodPicker.value() === "Offset" && !Number.isFinite(Number(offsetInput.value)))
      return "Enter a finite offset in millimetres.";
    return null;
  };

  const cleanup = () => {
    window.dispatchEvent(
      new CustomEvent("aether-plane-preview", { detail: { featureId: feature.id, frame: null } }),
    );
    window.dispatchEvent(
      new CustomEvent("aether-plane-highlight", { detail: { references: [] } }),
    );
    unsubscribeSelection();
    window.removeEventListener("aether-plane-geometry", onGeometry);
    window.removeEventListener("aether-sketch-plane", onPrincipalPick);
    window.removeEventListener("aether-plane-feature-picked", onFeaturePick);
    window.removeEventListener("aether-sketch-face", onFacePick);
    window.dispatchEvent(new CustomEvent("aether-sketch-plane-selection", { detail: false }));
    win.close();
  };
  const win = openFeatureWindow({
    viewport,
    className: "cad-plane-window",
    title: feature.name,
    acceptLabel: "Apply plane",
    discardLabel: created ? "Discard plane" : "Close plane window",
    onAccept: async () => {
      const doc = getDocument();
      const index = doc?.features.findIndex((f) => f.id === feature.id) ?? -1;
      if (!doc || index < 0) return cleanup();
      const definition = buildDefinition();
      if (!definition) {
        win.status.textContent = describeRequirement() ?? "This plane is not complete yet.";
        return;
      }
      const next = structuredClone(doc);
      const target = next.features[index] as PlaneFeature;
      target.definition = definition;
      // Keep legacy fields meaningful for principal offsets (older consumers).
      if (definition.method === "offset" && definition.reference.kind === "principal") {
        target.plane = definition.reference.plane;
        target.offsetMillimeters = definition.distanceMillimeters;
      }
      try {
        await apply(next);
        cleanup();
      } catch (e) {
        win.status.textContent = (e as Error).message;
      }
    },
    onDiscard: async () => {
      if (created) {
        const doc = getDocument();
        if (doc?.features.some((f) => f.id === feature.id)) {
          try {
            await apply(removeFeature(doc, feature.id));
          } catch (e) {
            win.status.textContent = (e as Error).message;
            return;
          }
        }
      }
      cleanup();
    },
  });

  const entities = win.entitiesBox("Entities");
  const renderEntities = () => {
    const method = methodPicker?.value?.();
    if (method === "Three point")
      return entities.render(
        points.map((p, index) => ({
          label: p.label ?? `Point ${index + 1}`,
          onRemove: () => {
            points = points.filter((_, at) => at !== index);
            renderEntities();
            validate();
          },
        })),
      );
    if (method === "Angle")
      return entities.render([
        ...(axis
          ? [{ label: axis.label ?? "Edge", onRemove: () => { axis = null; renderEntities(); validate(); } }]
          : []),
        ...references.map((reference, index) => ({
          label: labelFor(reference),
          onRemove: () => {
            references.splice(index, 1);
            renderEntities();
            validate();
          },
        })),
      ]);
    return entities.render(
      references.map((reference, index) => ({
        label: labelFor(reference),
        onRemove: () => {
          references.splice(index, 1);
          renderEntities();
          validate();
        },
      })),
    );
  };

  const methodPicker = win.picker(["Offset", "Mid plane", "Three point", "Angle"], {
    ariaLabel: "Plane method",
    value: initial.method === "mid" ? "Mid plane" : "Offset",
    onChange: () => syncMethod(),
  });
  win.body.append(methodPicker.element);
  win.body.append(win.status);

  const offsetInput = document.createElement("input");
  offsetInput.type = "text";
  offsetInput.value = String(initial.method === "offset" ? initial.distanceMillimeters : 10);
  offsetInput.setAttribute("aria-label", "Offset distance");
  const unit = document.createElement("span");
  unit.textContent = "mm";
  const flipDirection = document.createElement("button");
  flipDirection.type = "button";
  flipDirection.textContent = "⇅";
  flipDirection.setAttribute("aria-label", "Flip offset direction");
  flipDirection.onclick = () => {
    const value = Number(offsetInput.value);
    if (Number.isFinite(value)) offsetInput.value = String(-value);
    validate();
  };
  offsetInput.addEventListener("input", validate);
  const offsetRow = win.row("Offset distance", offsetInput, unit, flipDirection);

  const angleInput = document.createElement("input");
  angleInput.type = "text";
  angleInput.value = "45";
  angleInput.setAttribute("aria-label", "Plane angle");
  const angleUnit = document.createElement("span");
  angleUnit.textContent = "deg";
  const angleRow = win.row("Angle", angleInput, angleUnit);
  angleInput.addEventListener("input", () => validate());

  const flipInput = document.createElement("input");
  flipInput.type = "checkbox";
  flipInput.checked = flip;
  flipInput.setAttribute("aria-label", "Flip normal");
  flipInput.onchange = () => {
    flip = flipInput.checked;
    validate();
  };
  win.row("Flip normal", flipInput);

  /** Report arity against the CURRENT method, and disable the accept control
   *  until it is satisfied — the window cannot commit an invalid plane. */
  function validate() {
    win.setError(describeRequirement());
    preview();
  }

  /** Show the plane being described, live, in the viewport. The feature is
   *  already in the document, so this moves the REAL construction plane rather
   *  than drawing a decoration — and hides it while the definition is
   *  incomplete, so an empty Entities box never shows a stale plane. */
  function preview() {
    const doc = getDocument();
    const index = doc?.features.findIndex((f) => f.id === feature.id) ?? -1;
    const definition = buildDefinition();
    let frame: SketchFrame | null = null;
    if (doc && index >= 0 && definition) {
      try {
        frame = resolvePlaneFrame(
          { ...feature, definition },
          doc.features.slice(0, index),
        );
      } catch {
        // An unresolvable reference (deleted plane) simply has no preview.
        frame = null;
      }
    }
    window.dispatchEvent(
      new CustomEvent("aether-plane-preview", { detail: { featureId: feature.id, frame } }),
    );
    // Whatever this feature is using reads orange in the viewport, so the
    // entity chips and the geometry always agree about the selection.
    window.dispatchEvent(
      new CustomEvent("aether-plane-highlight", { detail: { references: [...references] } }),
    );
  }

  function syncMethod() {
    const method = methodPicker.value();
    if (method === "Three point" || method === "Angle") requestGeometry();
    offsetRow.hidden = method !== "Offset";
    angleRow.hidden = method !== "Angle";
    // Each method collects only what it uses, so a leftover pick from another
    // method can never satisfy it.
    entitiesBoxCaption(method);
    validate();
  }

  /** Name the box after what the current method is asking for. */
  function entitiesBoxCaption(method: string) {
    const caption = entities.element.querySelector(".aui-feature-entities-caption");
    if (caption)
      caption.textContent =
        method === "Three point" ? "Points" : method === "Angle" ? "Edge and reference plane" : "Entities";
  }
  syncMethod();
  renderEntities();

  // Entities come from clicking planes in the viewport or Items tree.
  const addReference = (reference: PlaneReference) => {
    const key = JSON.stringify(reference);
    if (references.some((r) => JSON.stringify(r) === key)) return;
    references.push(reference);
    renderEntities();
    validate();
  };
  const onPrincipalPick = (event: Event) => {
    const plane = (event as CustomEvent).detail;
    if (plane === "XY" || plane === "XZ" || plane === "YZ")
      addReference({ kind: "principal", plane });
  };
  const onFeaturePick = (event: Event) => {
    const featureId = (event as CustomEvent).detail?.featureId;
    if (typeof featureId === "string" && earlierPlanes().some((f) => f.id === featureId))
      addReference({ kind: "feature", featureId });
  };
  /** A planar face on a solid is a plane like any other. The frame is captured
   *  here because face geometry lives in the kernel, not the document. */
  const onFacePick = (event: Event) => {
    const detail = (event as CustomEvent).detail;
    if (!detail?.frame || typeof detail.partId !== "string" || !Number.isInteger(detail.faceId)) {
      if (detail?.error) win.status.textContent = detail.error;
      return;
    }
    win.status.textContent = "";
    addReference({
      kind: "face",
      partId: detail.partId,
      faceId: detail.faceId,
      label: detail.label,
      frame: detail.frame,
    });
  };
  /** Points and edges come from the same selection the rest of the app uses. */
  const onGeometry = (event: Event) => {
    const detail = (event as CustomEvent).detail;
    if (methodPicker.value() === "Three point") {
      points = (detail?.points ?? []).slice(0, 3).map((p: any) => ({
        kind: "point" as const,
        partId: p.partId,
        candidateId: p.candidateId,
        label: p.label,
        positionMillimeters: p.positionMillimeters,
      }));
    } else if (methodPicker.value() === "Angle") {
      axis = detail?.axis
        ? {
            kind: "axis" as const,
            partId: detail.axis.partId,
            candidateId: detail.axis.candidateId,
            label: detail.axis.label,
            originMillimeters: detail.axis.originMillimeters,
            directionMillimeters: detail.axis.directionMillimeters,
          }
        : null;
    }
    renderEntities();
    validate();
  };
  /** Ask for the current point/edge selection. The methods that need geometry
   *  read the same selection the rest of the app uses, so picking in the
   *  viewport or the tree both work without a second pathway. */
  const requestGeometry = () =>
    window.dispatchEvent(new CustomEvent("aether-plane-geometry-request"));
  const unsubscribeSelection = cadSelection.subscribe(() => {
    const method = methodPicker.value();
    if (method === "Three point" || method === "Angle") requestGeometry();
  });
  window.addEventListener("aether-plane-geometry", onGeometry);
  window.addEventListener("aether-sketch-plane", onPrincipalPick);
  window.addEventListener("aether-plane-feature-picked", onFeaturePick);
  window.addEventListener("aether-sketch-face", onFacePick);
  window.dispatchEvent(new CustomEvent("aether-sketch-plane-selection", { detail: true }));

  if (created) {
    try {
      await apply(insertFeature(source, feature));
    } catch (e) {
      win.status.textContent = (e as Error).message;
    }
  }
}
