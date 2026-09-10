import {
  createSketchClipboard,
  serializeSketchClipboard,
  pasteSketchClipboard,
  type DocumentVariable,
} from "@aether/core/document";
import { similarityTransform, type SketchDrawing } from "@aether/core/sketch";
import { contourPath } from "./svg-geometry";
const mime = "application/x-aether-sketch+json";
type State = { drawing: SketchDrawing; variables?: DocumentVariable[] };
/** Browser transport and preview only. Core owns selection packaging and paste semantics. */
export function mountSketchClipboard(
  parent: HTMLElement,
  svg: SVGSVGElement,
  state: () => State,
  selectedContour: () => number | undefined,
  enabled: () => boolean,
  commit: (drawing: SketchDrawing, variables: DocumentVariable[]) => void,
  selectTool: () => void,
) {
  const root = document.createElement("details"),
    summary = document.createElement("summary");
  summary.textContent = "Sketch clipboard";
  root.append(summary);
  parent.append(root);
  const selection = document.createElement("select");
  selection.multiple = true;
  selection.size = 4;
  selection.setAttribute("aria-label", "Clipboard contours");
  root.append(selection);
  const status = document.createElement("p");
  status.setAttribute("role", "status");
  const button = (text: string, run: () => void) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.onclick = run;
    root.append(b);
    return b;
  };
  const field = (name: string, value: string) => {
    const label = document.createElement("label"),
      input = document.createElement("input");
    input.value = value;
    input.setAttribute("aria-label", name);
    label.append(name, input);
    root.append(label);
    return input;
  };
  const x = field("Paste offset X (mm)", "10"),
    y = field("Paste offset Y (mm)", "10"),
    angle = field("Paste rotation (degrees)", "0"),
    scale = field("Paste scale", "1");
  let payload: string | undefined,
    preview: ReturnType<typeof pasteSketchClipboard> | undefined,
    snapshot = "",
    signature = "",
    disposed = false,
    generation = 0;
  const current = () => JSON.stringify(state());
  const clear = () => {
    payload = undefined;
    preview = undefined;
    svg.querySelector(".sketch-clipboard-preview")?.remove();
    apply.disabled = true;
  };
  const report = (error: unknown) => {
    status.textContent = error instanceof Error ? error.message : String(error);
  };
  function renderPreview() {
    svg.querySelector(".sketch-clipboard-preview")?.remove();
    preview = undefined;
    apply.disabled = true;
    if (!payload) return;
    try {
      if (current() !== snapshot)
        throw Error(
          "The sketch changed. Paste again to review the new result.",
        );
      const numbers = [x, y, angle, scale].map((input) => {
        if (!input.value.trim())
          throw Error("Enter all paste placement values.");
        return Number(input.value);
      });
      preview = pasteSketchClipboard(
        state().drawing,
        state().variables,
        payload,
        similarityTransform(
          [0, 0],
          [numbers[0], numbers[1]],
          numbers[2],
          numbers[3],
        ),
      );
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.classList.add("sketch-clipboard-preview");
      group.setAttribute("pointer-events", "none");
      for (const contour of preview.drawing.contours.slice(
        state().drawing.contours.length,
      )) {
        const element = document.createElementNS(
          "http://www.w3.org/2000/svg",
          contour.type === "circle" ? "circle" : "path",
        );
        element.classList.add("sketch-preview");
        if (contour.type === "circle") {
          element.setAttribute("cx", String(contour.center[0]));
          element.setAttribute("cy", String(-contour.center[1]));
          element.setAttribute("r", String(contour.radius));
        } else element.setAttribute("d", contourPath(contour));
        group.append(element);
      }
      svg.append(group);
      apply.disabled = false;
      status.textContent =
        "Review the paste preview, then Apply paste. Escape cancels.";
    } catch (error) {
      report(error);
    }
  }
  const copyText = () => {
    const chosen = [...selection.selectedOptions].map((option) =>
        Number(option.value),
      ),
      picked = selectedContour();
    const indices = chosen.length
      ? chosen
      : picked !== undefined && picked >= 0
        ? [picked]
        : [];
    return serializeSketchClipboard(
      createSketchClipboard(state().drawing, indices, state().variables),
    );
  };
  function stage(text: string) {
    selectTool();
    clear();
    payload = text;
    snapshot = current();
    root.open = true;
    renderPreview();
  }
  button("Select all for copy", () => {
    for (const option of selection.options) option.selected = true;
  });
  button("Copy sketch selection", () => {
    void (async () => {
      try {
        if (!enabled()) return;
        const text = copyText();
        if (!navigator.clipboard?.writeText)
          throw Error("Focus the sketch and use your browser's Copy command.");
        await navigator.clipboard.writeText(text);
        if (!disposed) status.textContent = "Sketch selection copied.";
      } catch (error) {
        if (!disposed) report(error);
      }
    })();
  });
  button("Paste sketch", () => {
    void (async () => {
      const request = ++generation,
        before = current();
      try {
        if (!enabled()) return;
        if (!navigator.clipboard?.readText)
          throw Error("Focus the sketch and use your browser's Paste command.");
        const text = await navigator.clipboard.readText();
        if (disposed || request !== generation) return;
        if (current() !== before)
          throw Error(
            "The sketch changed while reading the clipboard. Paste again.",
          );
        stage(text);
      } catch (error) {
        if (!disposed && request === generation) report(error);
      }
    })();
  });
  const apply = button("Apply paste", () => {
    try {
      if (!enabled() || !preview) return;
      if (current() !== snapshot)
        throw Error("The sketch changed. Paste again.");
      const next = preview;
      clear();
      commit(next.drawing, next.variables);
      status.textContent =
        "Pasted geometry and variables added to the sketch draft.";
    } catch (error) {
      report(error);
    }
  });
  apply.disabled = true;
  button("Cancel paste", () => {
    ++generation;
    clear();
    status.textContent = "Paste canceled.";
  });
  root.append(status);
  for (const input of [x, y, angle, scale]) input.oninput = renderPreview;
  const onCanvas = (event: Event) =>
    enabled() &&
    (event.target === svg ||
      (event.target instanceof svg.ownerDocument.defaultView!.Node &&
        svg.contains(event.target)));
  const copy = (event: ClipboardEvent) => {
    if (!onCanvas(event) || !event.clipboardData) return;
    try {
      const text = copyText();
      event.clipboardData.setData(mime, text);
      event.clipboardData.setData("text/plain", text);
      event.preventDefault();
      status.textContent = "Sketch selection copied.";
    } catch (error) {
      report(error);
    }
  };
  const paste = (event: ClipboardEvent) => {
    if (!onCanvas(event) || !event.clipboardData) return;
    event.preventDefault();
    ++generation;
    stage(
      event.clipboardData.getData(mime) ||
        event.clipboardData.getData("text/plain"),
    );
  };
  const escape = (event: KeyboardEvent) => {
    if (event.key === "Escape" && payload) {
      event.preventDefault();
      event.stopPropagation();
      ++generation;
      clear();
      status.textContent = "Paste canceled.";
    }
  };
  svg.addEventListener("copy", copy);
  svg.addEventListener("paste", paste);
  parent.addEventListener("keydown", escape, true);
  svg.addEventListener("keydown", escape, true);
  return {
    pending: () => payload !== undefined,
    sync() {
      const next = current();
      if (next !== signature) {
        signature = next;
        if (payload && next !== snapshot) {
          clear();
          status.textContent = "Sketch changed; paste preview canceled.";
        }
        selection.replaceChildren();
        state().drawing.contours.forEach((contour, index) => {
          const option = document.createElement("option");
          option.value = String(index);
          option.textContent = `${index + 1}. ${contour.type}`;
          selection.append(option);
        });
      }
      if (payload) renderPreview();
    },
    dispose() {
      disposed = true;
      ++generation;
      clear();
      svg.removeEventListener("copy", copy);
      svg.removeEventListener("paste", paste);
      parent.removeEventListener("keydown", escape, true);
      svg.removeEventListener("keydown", escape, true);
      root.remove();
    },
  };
}
