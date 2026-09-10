import { mountTextExpression } from "./text-expression";
import type { DocumentVariable } from "@aether/core/document";
import { mountTextFonts } from "./text-fonts";
import { mountTextItems } from "./text-items";
import { mountTextBoxPlacement } from "./text-box-placement";
import { mountTextResize } from "./text-resize";
import { mountTextHeight } from "./text-height";
import {
  sketchTextOutline,
  decodeTextFont,
  transformContour,
  textPlacementTransform,
  textFrameContour,
  sketchTextFontAscenderRatio,
  validateSketchDrawing,
  type SketchDrawing,
} from "@aether/core/sketch";
import { mountTextPlacement } from "./text-placement";
import { contourPath } from "./svg-geometry";

/** UI owns async font selection and preview; Core owns font geometry. */
export function mountTextPanel(
  parent: HTMLElement,
  svg: SVGSVGElement,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
  variables: () => readonly DocumentVariable[] | undefined = () => undefined,
) {
  const root = document.createElement("details"),
    summary = document.createElement("summary");
  summary.textContent = "Sketch text";
  root.append(summary);
  parent.append(root);
  const field = (label: string, value: string, type = "text") => {
    const row = document.createElement("label"),
      input = document.createElement("input");
    row.textContent = label;
    input.type = type;
    input.value = value;
    input.setAttribute("aria-label", label);
    row.append(input);
    root.append(row);
    return input;
  };
  const font = field("Text font file", "", "file");
  font.accept = ".otf,.ttf,.woff";
  const textRow = document.createElement("label"),
    text = document.createElement("textarea");
  textRow.textContent = "Sketch text";
  text.value = "Text";
  text.rows = 3;
  text.setAttribute("aria-label", "Sketch text");
  textRow.append(text);
  root.append(textRow);
  const expression = mountTextExpression(root, text, variables, () => {
    void refresh();
  });
  const size = field("Text em size (mm)", "10"),
    x = field("Text baseline X (mm)", "0"),
    y = field("Text baseline Y (mm)", "0"),
    angle = field("Text rotation (degrees)", "0"),
    width = field("Text frame width (mm)", "");
  const toggle = (label: string) => {
    const row = document.createElement("label"),
      input = document.createElement("input");
    input.type = "checkbox";
    input.setAttribute("aria-label", label);
    row.append(input, label);
    root.append(row);
    input.onchange = () => renderPlacement();
    return input;
  };
  const flipHorizontal = toggle("Flip text horizontally"),
    flipVertical = toggle("Flip text vertically"),
    flipAboutFrame = toggle("Flip about frame center");
  let placementReflected = false;
  flipAboutFrame.checked = true;
  const heightSizing = mountTextHeight(root, size, renderPlacement);
  const hint = document.createElement("p");
  hint.textContent =
    "Create editable text to retain wording and font, or insert ordinary outlines. Enter adds a line below the first-line frame. Em size measures the font design space.";
  root.append(hint);
  const status = document.createElement("p");
  status.setAttribute("role", "status");
  root.append(status);
  const insert = document.createElement("button"),
    cancel = document.createElement("button");
  insert.type = cancel.type = "button";
  insert.textContent = "Insert text outlines";
  cancel.textContent = "Cancel text";
  insert.disabled = true;
  root.append(insert, cancel);
  let variableSignature = JSON.stringify(variables());
  let sourceWording: string | undefined;
  let bytes: ArrayBuffer | undefined,
    preview: SketchDrawing | undefined,
    source: SketchDrawing | undefined,
    generation = 0,
    fontGeneration = 0,
    disposed = false;
  const clear = () => {
    svg.querySelector(".sketch-text-preview")?.remove();
    svg.querySelector(".sketch-text-frame-preview")?.remove();
    preview = undefined;
    insert.disabled = true;
    items?.ready(false);
    resize?.clear();
  };
  function readPreparedExpression() {
    const value = expression.read();
    if (value.text !== sourceWording) {
      void refresh();
      throw Error(
        "Text or variables changed. Review the refreshed preview before saving.",
      );
    }
    return value;
  }
  const items = mountTextItems(root, drawing, commit, {
    read: () => ({
      ...readPreparedExpression(),
      fontBytes: bytes,
      emSizeMillimeters: Number(size.value),
      textHeightMillimeters: heightSizing.read(),
      originMillimeters: [Number(x.value), Number(y.value)],
      rotationDegrees: Number(angle.value),
      flipHorizontal: flipHorizontal.checked,
      flipVertical: flipVertical.checked,
      placementReflected,
      flipAboutFrame: !!width.value.trim() && flipAboutFrame.checked,
      ...(width.value.trim()
        ? { frameWidthMillimeters: Number(width.value) }
        : {}),
    }),
    load: (item) => {
      bundledFonts.cancel();
      ++fontGeneration;
      bytes = decodeTextFont(item);
      font.value = "";
      text.value = item.text;
      expression.load(item);
      size.value = String(item.emSizeMillimeters);
      heightSizing.load(item);
      x.value = String(item.originMillimeters[0]);
      y.value = String(item.originMillimeters[1]);
      angle.value = String(item.rotationDegrees);
      width.value =
        item.frameWidthMillimeters === undefined
          ? ""
          : String(item.frameWidthMillimeters);
      flipHorizontal.checked = item.flipHorizontal ?? false;
      flipVertical.checked = item.flipVertical ?? false;
      flipAboutFrame.checked = item.flipAboutFrame ?? false;
      placementReflected = item.placementReflected ?? false;
      root.open = true;
      void refresh();
    },
    clear: () => {
      reset();
    },
    error: (message) => {
      status.textContent = message;
    },
  });
  const resize = mountTextResize(
    svg,
    drawing,
    items.selected,
    commit,
    (message) => {
      status.textContent = message;
    },
  );
  const placement = mountTextPlacement(
    root,
    svg,
    { x, y },
    drawing,
    renderPlacement,
  );
  const box = mountTextBoxPlacement(
    root,
    svg,
    { x, y, size, width, angle, flipHorizontal, flipVertical, flipAboutFrame },
    drawing,
    () => {
      heightSizing.syncFromEm();
      renderPlacement();
    },
    () => heightSizing.ratio() ?? 1,
    () => placementReflected,
  );
  const bundledFonts = mountTextFonts(root, {
    start: () => {
      ++fontGeneration;
      ++generation;
      bytes = undefined;
      source = undefined;
      clear();
      placement.available(false);
      box.available(false);
      font.value = "";
      status.textContent = "Loading font…";
    },
    loaded: (data) => {
      bytes = data;
      void refresh();
    },
    error: (message) => {
      status.textContent = message;
    },
  });
  function renderPlacement() {
    clear();
    if (!source) return;
    try {
      readPreparedExpression();
      const values = [size, x, y, angle].map((input) => {
        if (!input.value.trim())
          throw Error("Enter all text size and placement values.");
        const value = Number(input.value);
        if (!Number.isFinite(value))
          throw Error("Text size and placement must be finite numbers.");
        return value;
      });
      if (values[0] <= 0) throw Error("Text em size must be positive.");
      if (
        width.value.trim() &&
        (!Number.isFinite(Number(width.value)) || Number(width.value) <= 0)
      )
        throw Error("Text frame width must be positive.");
      const transform = textPlacementTransform(
        {
          originMillimeters: [values[1], values[2]],
          rotationDegrees: values[3],
          flipHorizontal: flipHorizontal.checked,
          flipVertical: flipVertical.checked,
          placementReflected,
          flipAboutFrame: !!width.value.trim() && flipAboutFrame.checked,
          frameWidthMillimeters: Number(width.value),
          emSizeMillimeters: values[0],
          fontAscenderRatio: heightSizing.ratio(),
        },
        values[0],
      );
      const result: SketchDrawing = {
        type: "drawing",
        contours: source.contours.map((c) => transformContour(c, transform)),
      };
      validateSketchDrawing(result);
      preview = result;
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.classList.add("sketch-text-preview");
      group.setAttribute("pointer-events", "none");
      for (const contour of result.contours) {
        if (contour.type !== "path") continue;
        const path = document.createElementNS(
          "http://www.w3.org/2000/svg",
          "path",
        );
        path.classList.add("sketch-preview");
        path.setAttribute("d", contourPath(contour));
        group.append(path);
      }
      svg.append(group);
      resize.render();
      if (width.value.trim()) {
        const frame = textFrameContour({
          frameWidthMillimeters: Number(width.value),
          emSizeMillimeters: values[0],
          fontAscenderRatio: heightSizing.ratio(),
          originMillimeters: [values[1], values[2]],
          rotationDegrees: values[3],
          flipHorizontal: flipHorizontal.checked,
          flipVertical: flipVertical.checked,
          placementReflected,
          flipAboutFrame: flipAboutFrame.checked,
        });
        if (frame.type === "path") {
          const path = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "path",
          );
          path.classList.add("sketch-text-frame-preview", "sketch-preview");
          path.setAttribute("d", contourPath(frame));
          path.setAttribute("stroke-dasharray", "4 3");
          path.setAttribute("fill", "none");
          path.setAttribute("pointer-events", "none");
          svg.append(path);
        }
      }
      insert.disabled = false;
      items.ready(true);
      status.textContent = `${result.contours.length} contours · ${result.contours.filter((c) => c.hole).length} holes`;
    } catch (error) {
      status.textContent = (error as Error).message;
    }
  }
  async function refresh() {
    const request = ++generation;
    clear();
    source = undefined;
    placement.available(false);
    box.available(false);
    if (!bytes) return;
    try {
      const wording = expression.read().text;
      const [result, ratio] = await Promise.all([
        sketchTextOutline(bytes, wording, {
          emSizeMillimeters: 1,
        }),
        sketchTextFontAscenderRatio(bytes),
      ]);
      if (disposed || request !== generation) return;
      heightSizing.font(ratio);
      source = result;
      sourceWording = wording;
      placement.available(true);
      box.available(true);
      renderPlacement();
    } catch (error) {
      if (!disposed && request === generation)
        status.textContent = (error as Error).message;
    }
  }
  font.onchange = async () => {
    bundledFonts.cancel();
    const request = ++fontGeneration;
    ++generation;
    bytes = undefined;
    source = undefined;
    placement.available(false);
    box.available(false);
    clear();
    status.textContent = "";
    const selected = font.files?.[0];
    if (!selected) return;
    try {
      if (selected.size > 32 * 1024 * 1024)
        throw Error("Font files must be at most 32 MB.");
      const loaded = await selected.arrayBuffer();
      if (disposed || request !== fontGeneration) return;
      bytes = loaded;
      await refresh();
    } catch (error) {
      if (!disposed && request === fontGeneration)
        status.textContent = (error as Error).message;
    }
  };
  text.oninput = () => {
    void refresh();
  };
  for (const input of [size, x, y, angle, width])
    input.oninput = renderPlacement;
  size.oninput = () => {
    heightSizing.syncFromEm();
    renderPlacement();
  };
  const reset = () => {
    bundledFonts.cancel();
    ++generation;
    ++fontGeneration;
    clear();
    source = undefined;
    placement.available(false);
    box.available(false);
    width.value = "";
    placementReflected = false;
    flipAboutFrame.checked = true;
    heightSizing.reset();
    expression.reset();
    bytes = undefined;
    font.value = "";
    status.textContent = "";
    root.open = false;
  };
  cancel.onclick = reset;
  insert.onclick = () => {
    if (!preview) return;
    try {
      readPreparedExpression();
      const next = structuredClone(drawing());
      next.contours.push(...structuredClone(preview.contours));
      validateSketchDrawing(next);
      commit(next);
      reset();
    } catch (error) {
      status.textContent = (error as Error).message;
    }
  };
  const requestText = () => {
    root.open = true;
    if (!bytes) bundledFonts.useDefault();
    else renderPlacement();
    text.focus();
    text.select();
  };
  window.addEventListener("aether-sketch-text", requestText);
  return {
    sync: () => {
      items.sync();
      const signature = JSON.stringify(variables());
      if (signature !== variableSignature) {
        variableSignature = signature;
        void refresh();
      }
    },
    dispose() {
      disposed = true;
      window.removeEventListener("aether-sketch-text", requestText);
      reset();
      placement.dispose();
      box.dispose();
      resize.dispose();
      heightSizing.dispose();
      expression.dispose();
      items.dispose();
      bundledFonts.dispose();
      root.remove();
    },
  };
}
