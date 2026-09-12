/** Extrude feature editor — window layout, controls, and validation. */
import { demoCheckbox, demoInput, demoUnit, extrudeDocument, rowIn, validatedFeatureWindow } from "./shared";

export const buildExtrudeDemo = (host: HTMLElement) => {
  validatedFeatureWindow(host, {
    title: "Extrude 1",
    accept: "Apply extrude",
    caption: "Faces and sketch regions to extrude",
    entities: ["Sketch 6"],
    document: extrudeDocument,
    build: (win, mountEntities) => {
      // Onshape order: body type, boolean, selection, end type, then options.
      win.tabs(["Solid", "Surface", "Thin"]);
      win.tabs(["New", "Add", "Remove", "Intersect"]);
      mountEntities();

      // End type drives which sub-settings exist — Blind wants a depth, the
      // "up to" types want a reference instead, Through all wants neither.
      const endType = win.picker(
        ["Blind", "Symmetric", "Up to next", "Up to face", "Up to vertex", "Through all"],
        { ariaLabel: "End type", onChange: () => syncEndType() },
      );
      win.body.append(endType.element);
      const depth = win.row("Depth", demoInput("25"), demoUnit("mm"));
      const upTo = win.entitiesBox("Up to entity");
      upTo.render([{ label: "Face 12", onRemove: () => {} }]);
      const draft = win.subsection("Draft", { kind: "checkbox" });
      const draftAngle = document.createElement("input");
      draftAngle.type = "text";
      draftAngle.value = "3";
      draft.body.append(rowIn(draft.body, "Draft angle", draftAngle, demoUnit("deg")));
      const direction = win.subsection("Direction", { kind: "disclosure" });
      direction.body.append(rowIn(direction.body, "Flip direction", demoCheckbox()));
      direction.body.append(rowIn(direction.body, "Direction reference", win.picker(["Normal to sketch", "Custom"], { ariaLabel: "Direction reference" }).element));
      const startOffset = win.subsection("Starting offset", { kind: "checkbox" });
      const offsetDistance = document.createElement("input");
      offsetDistance.type = "text";
      offsetDistance.value = "0";
      startOffset.body.append(rowIn(startOffset.body, "Offset distance", offsetDistance, demoUnit("mm")));
      startOffset.body.append(rowIn(startOffset.body, "Opposite direction", demoCheckbox()));
      const secondEnd = win.subsection("Second end position", { kind: "checkbox" });
      secondEnd.body.append(rowIn(secondEnd.body, "Second end type", win.picker(["Blind", "Up to face", "Through all"], { ariaLabel: "Second end type" }).element));
      const secondDepth = document.createElement("input");
      secondDepth.type = "text";
      secondDepth.value = "10";
      secondEnd.body.append(rowIn(secondEnd.body, "Second depth", secondDepth, demoUnit("mm")));

      function syncEndType() {
        const value = endType.value();
        depth.hidden = !(value === "Blind" || value === "Symmetric");
        upTo.element.hidden = !value.startsWith("Up to ") || value === "Up to next";
        // A symmetric extrude has no separate direction or second end.
        direction.element.hidden = value === "Symmetric";
        secondEnd.element.hidden = value === "Symmetric" || value === "Through all";
      }
      syncEndType();
    },
  });
};
