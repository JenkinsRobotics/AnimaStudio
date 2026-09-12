/** Shared plumbing for the feature-editor demos: window construction,
 *  parameter helpers, and the Core-validated window wrapper. One file per
 *  feature lives alongside this one. */
import { openFeatureWindow } from "../../src/FeatureWindow";
import {
  createEmptyPartDocument,
  validatePartDocument,
  type PartDocument,
} from "@aether/core/document";

export const demoInput = (value: string) => {
  const input = document.createElement("input");
  input.type = "text";
  input.value = value;
  return input;
};
export const demoUnit = (text: string) => {
  const unit = document.createElement("span");
  unit.textContent = text;
  return unit;
};
export const demoCheckbox = () => {
  const box = document.createElement("input");
  box.type = "checkbox";
  return box;
};
/** A parameter row inside a nested sub-setting body. */
export function rowIn(parent: HTMLElement, label: string, ...controls: HTMLElement[]): HTMLElement {
  const row = document.createElement("div");
  row.className = "aui-feature-row";
  const caption = document.createElement("span");
  caption.textContent = label;
  const control = document.createElement("span");
  control.className = "aui-feature-row-control";
  control.append(...controls);
  row.append(caption, control);
  void parent;
  return row;
}

export const demoWindow = (host: HTMLElement, title: string, accept: string) =>
  openFeatureWindow({
    viewport: host,
    className: "gallery-demo",
    title,
    acceptLabel: accept,
    discardLabel: "Discard",
    onAccept: () => {},
    onDiscard: () => {},
  });

/** A feature window whose Entities box drives real Core validation: removing
 *  the reference makes the document invalid, so the window shows the engine's
 *  own error and refuses to accept — the pipeline the apps actually run.
 *  `build` controls layout order; call `mountEntities()` at the point the
 *  Onshape feature places its selection box. */
export function validatedFeatureWindow(
  host: HTMLElement,
  options: {
    title: string;
    accept: string;
    caption: string;
    entities: string[];
    /** Build the document for the current entity list. */
    document: (entities: string[]) => PartDocument;
    build: (win: ReturnType<typeof demoWindow>, mountEntities: () => void) => void;
  },
) {
  const win = demoWindow(host, options.title, options.accept);
  const entities = [...options.entities];
  let box: ReturnType<ReturnType<typeof demoWindow>["entitiesBox"]> | null = null;
  const validate = () => {
    try {
      validatePartDocument(options.document(entities));
      win.setError(null);
    } catch (error) {
      win.setError((error as Error).message);
    }
  };
  const render = () => {
    box?.render(
      entities.map((label, index) => ({
        label,
        onRemove: () => {
          entities.splice(index, 1);
          render();
          validate();
        },
      })),
    );
  };
  options.build(win, () => {
    box = win.entitiesBox(options.caption);
    render();
  });
  validate();
  return win;
}

/** Demo documents run through the real Core part-document validator. */
export const sketchDocument = (entities: string[]): PartDocument => {
  const document = createEmptyPartDocument("Gallery Part");
  document.features.push({
    id: "sketch-6",
    type: "profile",
    name: "Sketch 6",
    suppressed: false,
    // An empty plane is what "no reference" means to the engine.
    plane: (entities[0] === "Top plane" ? "XY" : entities[0] === "Front plane" ? "XZ" : "") as "XY",
    offsetMillimeters: 0,
    profile: { type: "drawing", contours: [] },
  } as PartDocument["features"][number]);
  return document;
};
export const extrudeDocument = (entities: string[]): PartDocument => {
  const document = sketchDocument(["Top plane"]);
  document.features.push({
    id: "extrude-1",
    type: "extrude",
    name: "Extrude 1",
    suppressed: false,
    // Core requires the extrude to reference an earlier profile.
    profileFeatureId: entities.length ? "sketch-6" : "missing-profile",
    distanceMillimeters: 25,
    operation: "new",
  } as PartDocument["features"][number]);
  return document;
};

