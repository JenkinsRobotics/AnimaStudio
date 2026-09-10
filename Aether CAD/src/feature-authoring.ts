import { openProjectionEditor } from "./sketch/projection-editor";
import { rectangleSketchRevision } from "@aether/core/sketch";
import { openSketchWorkspace } from "./sketch-workspace";
import { unitChoice } from "@aether/core/units";
import { documentUnits } from "./document-preferences";
import { mountProfileCanvas } from "./profile-canvas";
import {
  rollbackPosition,
  insertFeature,
  setFeatureSuppressed,
  removeFeature,
  moveFeature,
  availableBodies,
  dependentFeatures,
} from "@aether/core/document";
import { cadCommands } from "./cad-command-registry";
import type { PartDocument, PartFeature } from "@aether/core/document";
import {
  activeProject,
  editHostedProject,
  projectItemURL,
  listHostedParts,
  updateHostedLink,
} from "./host-library";
import "./feature-authoring.css";
/** Presentation only. Core validates and evaluates every submitted feature. */
export function mountFeatureAuthoring(
  getDocument: () => PartDocument | null,
  apply: (doc: PartDocument) => Promise<void>,
) {
  const actions = document.createElement("div");
  const error = document.createElement("p");
  error.className = "feature-command-error";
  error.setAttribute("role", "alert");
  document.querySelector(".cad-studio-viewport")?.append(error);
  cadCommands.register("sketch-project",()=>{
    try { openProjectionEditor(getDocument,apply); error.textContent=""; }
    catch(e){error.textContent=(e as Error).message;}
  });
  cadCommands.setEnabled("sketch-project",true);
  const button = (
    label: string,
    run: () => void,
    parent: HTMLElement = actions,
  ) => {
    const b = document.createElement("button");
    b.textContent = label;
    b.type = "button";
    b.onclick = run;
    parent.append(b);
    return b;
  };
  const show = (type: string, existing?: PartFeature) => {
    if (type === "profile") {
      if(existing?.type === "profile" && existing.profile.type === "projection") {
        try { openProjectionEditor(getDocument,apply,existing); } catch(e){error.textContent=(e as Error).message;}
        return;
      }
      openSketchWorkspace(getDocument, apply, existing?.type === "profile" ? existing : undefined);
      return;
    }
    const source = getDocument();
    if (!source) {
      error.textContent = "Create or open a Part first.";
      return;
    }
    const doc = structuredClone(source);
    const feature = existing as any;
    const modal = document.createElement("dialog");
    modal.className = "feature-dialog";
    const form = document.createElement("form");
    modal.append(form);
    const title = document.createElement("h2");
    title.textContent = (existing ? "Edit " : "Add ") + type;
    form.append(title);
    const lengthUnit = unitChoice(documentUnits(), "length"),
      angleUnit = unitChoice(documentUnits(), "angle");
    const field = (name: string, value: string, choices?: string[]) => {
      const factor = name.includes("(mm)")
        ? lengthUnit.factor / 0.001
        : name.includes("(degrees)")
          ? angleUnit.factor / (Math.PI / 180)
          : 1;
      const original = value;
      if ((name.includes("(mm)") || name.includes("(degrees)")) && !choices)
        value = value.replace(
          /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/g,
          (n) =>
            (Number(n) / factor).toFixed(
              name.includes("(mm)") ? lengthUnit.decimals : angleUnit.decimals,
            ),
        );
      name = name
        .replace("(mm)", `(${lengthUnit.unit})`)
        .replace("(degrees)", `(${angleUnit.unit})`);
      const label = document.createElement("label");
      label.textContent = name;
      const input = choices
        ? document.createElement("select")
        : document.createElement("input");
      if (choices)
        for (const value of choices) {
          const option = document.createElement("option");
          option.value = value;
          option.textContent = value;
          input.append(option);
        }
      input.value = value;
      input.name = name;
      input.dataset.canonicalFactor = String(factor);
      input.dataset.originalValue = original;
      input.dataset.displayValue = value;
      input.setAttribute("aria-label", name);
      label.append(input);
      form.append(label);
      return input;
    };
    const name = field(
      "Name",
      feature?.name ??
        type[0].toUpperCase() + type.slice(1) + " " + (doc.features.length + 1),
    );
    const before = existing
      ? doc.features.slice(
          0,
          doc.features.findIndex((f) => f.id === existing.id),
        )
      : doc.features.slice(0, rollbackPosition(doc));
    // IDs stay canonical; option labels are human-readable feature names.
    const reference = (label: string, types: string[], value?: string) => {
      const choices = before.filter((f) => types.includes(f.type));
      const select = field(
        label,
        value ?? choices.at(-1)?.id ?? "",
        choices.map((f) => f.id),
      );
      Array.from(select.children).forEach(
        (o, i) => (o.textContent = choices[i].name),
      );
      return select;
    };
    const controls: Record<string, HTMLInputElement | HTMLSelectElement> = {};
    if(type==="plane"){controls.plane=field("Reference plane",feature?.plane??"XY",["XY","XZ","YZ"]);controls.offset=field("Offset (mm)",String(feature?.offsetMillimeters??10));}
    if (type === "profile") {
      controls.plane = field("Plane", feature?.plane ?? "XY", [
        "XY",
        "XZ",
        "YZ",
      ]);
      controls.offset = field(
        "Plane offset (mm)",
        String(feature?.offsetMillimeters ?? 0),
      );
      controls.shape = field("Profile", feature?.profile.type ?? "circle", [
        "circle",
        "polygon",
      ]);
      controls.radius = field(
        "Circle radius (mm)",
        String(feature?.profile.radiusMillimeters ?? 10),
      );
      controls.center = field(
        "Circle center x,y (mm)",
        feature?.profile.centerMillimeters?.join(",") ?? "0,0",
      );
      controls.points = field(
        "Polygon points x,y; x,y (mm)",
        feature?.profile.pointsMillimeters
          ?.map((p: number[]) => p.join(","))
          .join("; ") ?? "0,0; 20,0; 20,10; 0,10",
      );
    } else if (type === "extrude" || type === "revolve") {
      controls.source = reference(
        "Sketch",
        ["sketch", "profile"],
        feature?.profileFeatureId,
      );
      controls.operation = field(
        "Operation",
        feature?.operation ??
          (doc.features.some((f) => ["extrude", "revolve"].includes(f.type))
            ? "add"
            : "new"),
        ["new", "add", "cut"],
      );
      if (type === "extrude")
        controls.distance = field(
          "Distance (mm)",
          String(feature?.distanceMillimeters ?? 10),
        );
      else {
        controls.axis = field("Axis", feature?.axis ?? "Z", ["X", "Y", "Z"]);
        controls.angle = field(
          "Angle (degrees)",
          String(feature?.angleDegrees ?? 360),
        );
      }
    } else if (type === "mirror") {
      controls.source = reference(
        "Feature",
        ["extrude", "revolve", "mirror"],
        feature?.sourceFeatureId,
      );
      controls.plane = field("Mirror plane", feature?.plane ?? "YZ", [
        "XY",
        "XZ",
        "YZ",
      ]);
      controls.offset = field(
        "Plane offset (mm)",
        String(feature?.offsetMillimeters ?? 0),
      );
      controls.operation = field("Operation", feature?.operation ?? "add", [
        "add",
        "cut",
      ]);
    } else if(type!=="plane")
      controls.radius = field(
        "All-edge size (mm)",
        String(feature?.radiusMillimeters ?? 0.5),
      );
    if (type === "profile")
      mountProfileCanvas(
        form,
        controls,
        lengthUnit.unit,
        lengthUnit.factor / 0.001,
      );
    if (!["profile", "sketch"].includes(type)) {
      const bodies = availableBodies({
        ...doc,
        features: before,
        rollbackIndex: undefined,
      });
      controls.target = field(
        "Target body",
        feature?.targetBodyId ?? bodies.at(-1)?.id ?? "",
        bodies.map((b) => b.id),
      );
      Array.from(controls.target.children).forEach(
        (o, i) => (o.textContent = bodies[i].name),
      );
      const targetVisibility = () => {
        controls.target.parentElement!.hidden =
          controls.operation?.value === "new";
      };
      controls.operation?.addEventListener("change", targetVisibility);
      targetVisibility();
    }
    if (type === "fillet" || type === "chamfer") {
      controls.edgeScope = field(
        "Edges",
        feature?.edgePlane ? "plane" : "all",
        ["all", "plane"],
      );
      controls.edgePlane = field(
        "Edge plane",
        feature?.edgePlane?.plane ?? "XY",
        ["XY", "XZ", "YZ"],
      );
      controls.edgeOffset = field(
        "Edge plane offset (mm)",
        String(feature?.edgePlane?.offsetMillimeters ?? 0),
      );
    }
    const alert = document.createElement("p");
    alert.setAttribute("role", "alert");
    form.append(alert);
    button(
      "Cancel",
      () => {
        modal.close();
        modal.remove();
      },
      form,
    );
    const submit = button("Apply and rebuild", () => {}, form);
    submit.type = "submit";
    form.onsubmit = async (e) => {
      e.preventDefault();
      submit.disabled = true;
      alert.textContent = "";
      try {
        const values = Object.fromEntries(
          Object.entries(controls).map(([k, v]) => [
            k,
            v.value === v.dataset.displayValue
              ? (v.dataset.originalValue ?? v.value)
              : Number(v.dataset.canonicalFactor ?? 1) === 1
                ? v.value
                : v.value.replace(
                    /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/g,
                    (n) =>
                      String(Number(n) * Number(v.dataset.canonicalFactor)),
                  ),
          ]),
        );
        const next: any = {
          id: existing?.id ?? crypto.randomUUID(),
          type,
          name: name.value,
          suppressed: feature?.suppressed ?? false,
        };
        if(type === "plane") Object.assign(next,{plane:values.plane,offsetMillimeters:Number(values.offset)});
        else if (type === "profile")
          Object.assign(next, {
            plane: values.plane,
            offsetMillimeters: Number(values.offset),
            profile:
              values.shape === "circle"
                ? {
                    type: "circle",
                    radiusMillimeters: Number(values.radius),
                    centerMillimeters: values.center.split(",").map(Number),
                  }
                : {
                    type: "polygon",
                    pointsMillimeters: values.points
                      .split(";")
                      .map((p) => p.trim().split(",").map(Number)),
                  },
          });
        else if (type === "extrude" || type === "revolve")
          Object.assign(next, {
            profileFeatureId: values.source,
            operation: values.operation,
            ...(type === "extrude"
              ? { distanceMillimeters: Number(values.distance) }
              : { axis: values.axis, angleDegrees: Number(values.angle) }),
          });
        else if (type === "mirror")
          Object.assign(next, {
            sourceFeatureId: values.source,
            plane: values.plane,
            offsetMillimeters: Number(values.offset),
            operation: values.operation,
          });
        else next.radiusMillimeters = Number(values.radius);
        if (feature?.bodyId) next.bodyId = feature.bodyId;
        if (values.target && values.operation !== "new")
          next.targetBodyId = values.target;
        if (
          (type === "fillet" || type === "chamfer") &&
          values.edgeScope === "plane"
        )
          next.edgePlane = {
            plane: values.edgePlane,
            offsetMillimeters: Number(values.edgeOffset),
          };
        if (existing)
          doc.features[doc.features.findIndex((f) => f.id === existing.id)] =
            next;
        await apply(existing ? doc : insertFeature(doc, next));
        refresh();
        modal.close();
        modal.remove();
      } catch (e) {
        alert.textContent = (e as Error).message;
      } finally {
        submit.disabled = false;
      }
    };
    if (existing) {
      button(
        "Move earlier",
        async () => {
          try {
            await apply(moveFeature(source, existing.id, -1));
            modal.remove();
          } catch (e) {
            alert.textContent = (e as Error).message;
          }
        },
        form,
      );
      button(
        "Move later",
        async () => {
          try {
            await apply(moveFeature(source, existing.id, 1));
            modal.remove();
          } catch (e) {
            alert.textContent = (e as Error).message;
          }
        },
        form,
      );
      button(
        "Delete feature",
        async () => {
          const affected = dependentFeatures(source, existing.id);
          if (
            !confirm(
              `Delete ${existing.name}${affected.size > 1 ? ` and ${affected.size - 1} dependent features` : ""}?`,
            )
          )
            return;
          try {
            await apply(removeFeature(source, existing.id));
            modal.remove();
          } catch (e) {
            alert.textContent = (e as Error).message;
          }
        },
        form,
      );
    }
    document.body.append(modal);
    modal.showModal();
  };
  let busy = false;
  const change = async (doc: PartDocument) => {
    if (busy) return;
    busy = true;
    error.textContent = "";
    try {
      await apply(doc);
    } catch (e) {
      error.textContent = (e as Error).message;
    } finally {
      busy = false;
      refresh();
    }
  };
  // The canonical apply path refreshes the shared Model tree.
  const refresh = () => {};
  window.addEventListener("aether-feature-action", (event) => {
    const action = (event as CustomEvent).detail;
    const doc = getDocument();
    if (!doc) return;
    const id = action.id.split("/").slice(2).join("/");
    const f = doc.features.find((f) => f.id === id);
    if (action.type === "move-item") {
      const target = action.targetID.split("/").slice(2).join("/");
      let position =
        doc.features.findIndex((f) => f.id === target) +
        (action.position === "after" ? 1 : 0);
      if (action.id === "rollback-bar")
        void change({ ...doc, rollbackIndex: position });
      else if (f) {
        const index = doc.features.indexOf(f);
        if (index < position) position--;
        try {
          void change(moveFeature(doc, f.id, position - index));
        } catch (e) {
          error.textContent = (e as Error).message;
        }
      }
      return;
    }
    if (action.actionID === "edit-feature" && f) {
      if (f.type === "sketch") {
        const state = rectangleSketchRevision(f);
        const x=f.profile.centerXMillimeters, y=f.profile.centerYMillimeters;
        const w=state.widthMillimeters/2, h=state.heightMillimeters/2;
        openSketchWorkspace(getDocument, apply, {id:f.id, name:f.name, type:"profile", suppressed:f.suppressed, plane:f.plane, offsetMillimeters:0,
          profile:{type:"polygon", pointsMillimeters:[[x-w,y-h],[x+w,y-h],[x+w,y+h],[x-w,y+h]]}});
        return;
      }
      show(f.type, f);
    } else if (action.actionID === "suppress-feature" && f)
      void change(setFeatureSuppressed(doc, f.id, !f.suppressed));
    else if (action.actionID === "rollback-before" && f)
      void change({ ...doc, rollbackIndex: doc.features.indexOf(f) });
    else if (action.actionID === "rollback-start")
      void change({ ...doc, rollbackIndex: 0 });
    else if (action.actionID === "rollback-end")
      void change({ ...doc, rollbackIndex: undefined });
    else if (
      action.actionID === "body-visibility" ||
      action.actionID === "body-rename"
    ) {
      const body = availableBodies(doc).find((b) => b.id === id);
      if (!body) return;
      const name =
        action.actionID === "body-rename"
          ? prompt("Body name", body.name)
          : body.name;
      if (!name?.trim()) return;
      void change({
        ...doc,
        bodyProperties: {
          ...doc.bodyProperties,
          [id]: {
            ...doc.bodyProperties?.[id],
            name: name.trim(),
            visible:
              action.actionID === "body-visibility"
                ? !body.visible
                : body.visible,
          },
        },
      });
    }
  });
  for (const type of [
    "plane",
    "profile",
    "extrude",
    "revolve",
    "mirror",
    "fillet",
    "chamfer",
  ] as const) {
    cadCommands.register(`feature-${type}`, () => show(type));
    cadCommands.setEnabled(`feature-${type}`, true);
  }
  return refresh;
}
export function mountProjectTabs() {
  if (!activeProject) return;
  document.querySelector(".project-tabs")?.remove();
  const bar = document.createElement("nav");
  bar.className = "project-tabs";
  bar.setAttribute("aria-label", "Project items");
  const historical = new URLSearchParams(location.search).get("revision");
  if (historical) {
    const badge = document.createElement("strong");
    badge.textContent = "Read-only revision " + historical;
    bar.append(badge);
  }
  for (const [kind, items] of [
    ["part", activeProject.parts],
    ["assembly", activeProject.assemblies],
  ] as const)
    for (const item of items) {
      const a = document.createElement("a");
      a.href = projectItemURL(item.id, kind);
      a.textContent = (kind === "part" ? "Part · " : "Assembly · ") + item.name;
      bar.append(a);
    }
  for (const kind of ["part", "assembly"] as const) {
    const b = document.createElement("button");
    b.textContent = "+ " + kind;
    b.onclick = async () => {
      const name = prompt("Name for new " + kind);
      if (!name) return;
      try {
        const result = await editHostedProject("add_" + kind, name);
        const item = (
          kind === "part" ? result.project.parts : result.project.assemblies
        ).at(-1)!;
        location.assign(projectItemURL(item.id, kind));
      } catch (e) {
        alert((e as Error).message);
      }
    };
    bar.append(b);
  }
  const choose = document.createElement("button");
  choose.textContent = "Link standalone Part";
  choose.onclick = async () => {
    try {
      const parts = await listHostedParts();
      const dialog = document.createElement("dialog");
      dialog.className = "feature-dialog";
      const form = document.createElement("form");
      const label = document.createElement("label");
      label.textContent = "Choose a Part (pins its current saved revision)";
      const select = document.createElement("select");
      for (const part of parts) {
        const o = document.createElement("option");
        o.value = part.id;
        o.textContent = part.name + " · r" + part.revision;
        select.append(o);
      }
      label.append(select);
      form.append(label);
      const submit = document.createElement("button");
      submit.textContent = "Link Part";
      submit.disabled = !parts.length;
      form.append(submit);
      const cancel = document.createElement("button");
      cancel.type = "button";
      cancel.textContent = "Cancel";
      cancel.onclick = () => dialog.remove();
      form.append(cancel);
      form.onsubmit = async (e) => {
        e.preventDefault();
        const part = parts.find((p) => p.id === select.value)!;
        try {
          await editHostedProject("link_part", part.name, {
            source_id: part.id,
            source_revision: part.revision,
          });
          location.reload();
        } catch (e) {
          alert((e as Error).message);
        }
      };
      dialog.append(form);
      document.body.append(dialog);
      dialog.showModal();
    } catch (e) {
      alert((e as Error).message);
    }
  };
  bar.append(choose);
  const assemblyId = new URLSearchParams(location.search).get("assembly");
  if (assemblyId) {
    const select = document.createElement("select");
    select.setAttribute("aria-label", "Project Part to insert");
    for (const part of activeProject.parts) {
      const o = document.createElement("option");
      o.value = part.id;
      o.textContent = part.name;
      select.append(o);
    }
    bar.append(select);
    const insert = document.createElement("button");
    insert.textContent = "Insert project Part";
    insert.onclick = async () => {
      const part = activeProject!.parts.find((p) => p.id === select.value);
      if (!part) return;
      try {
        await editHostedProject("insert_part", part.name, {
          assembly_id: assemblyId,
          part_id: part.id,
        });
        location.reload();
      } catch (e) {
        alert((e as Error).message);
      }
    };
    bar.append(insert);
  }
  const activePart = new URLSearchParams(location.search).get("part");
  const linked = activeProject.parts.find(
    (p) => p.id === activePart && p.source?.kind === "linked",
  );
  if (linked) {
    const update = document.createElement("button");
    update.textContent = "Update linked Part to latest saved revision";
    update.onclick = async () => {
      try {
        await updateHostedLink(linked.id);
        location.reload();
      } catch (e) {
        alert((e as Error).message);
      }
    };
    bar.append(update);
  }
  const home = document.createElement("a");
  home.href = "/cad/";
  home.textContent = "Files & revision history";
  bar.append(home);
  document.body.append(bar);
}
