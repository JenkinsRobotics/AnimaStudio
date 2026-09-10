import {
  putSketchText,
  detachSketchText,
  attachSketchTextFrame,
  type SketchDrawing,
  type SketchTextItem,
} from "@aether/core/sketch";
/** Saved-text selection and async commits; the panel owns the editing fields. */
export function mountTextItems(
  parent: HTMLElement,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
  controls: {
    read: () => Omit<Parameters<typeof putSketchText>[1], "id">;
    load: (item: SketchTextItem) => void;
    clear: () => void;
    error: (message: string) => void;
  },
) {
  const select = document.createElement("select"),
    save = document.createElement("button"),
    detach = document.createElement("button"),
    frame = document.createElement("button");
  select.setAttribute("aria-label", "Saved sketch text");
  save.type = detach.type = frame.type = "button";
  save.textContent = "Create editable text";
  detach.textContent = "Detach text to curves";
  save.disabled = detach.disabled = true;
  frame.textContent = "Add text frame";
  frame.title =
    "Add construction edges for text position, em height and independent frame width dimensions.";
  parent.append(select, save, frame, detach);
  let loadedSignature = "";
  let selected = "",
    generation = 0,
    ready = false,
    disposed = false;
  function sync() {
    const items = drawing().textItems ?? [];
    if (selected && !items.some((item) => item.id === selected)) {
      selected = "";
      controls.clear();
    }
    const current = items.find((item) => item.id === selected);
    if (current && JSON.stringify(current) !== loadedSignature) {
      loadedSignature = JSON.stringify(current);
      controls.load(structuredClone(current));
    }
    select.replaceChildren();
    const initial = document.createElement("option");
    initial.value = "";
    initial.textContent = "New text";
    select.append(initial);
    for (const item of items) {
      const option = document.createElement("option");
      option.value = item.id;
      option.textContent = item.text.slice(0, 80);
      select.append(option);
    }
    select.value = selected;
    detach.disabled = !selected;
    frame.disabled = !current || !!current.frameContourId;
    save.textContent = selected
      ? "Update editable text"
      : "Create editable text";
  }
  select.onchange = () => {
    ++generation;
    selected = select.value;
    const item = drawing().textItems?.find((item) => item.id === selected);
    loadedSignature = item ? JSON.stringify(item) : "";
    if (item) controls.load(structuredClone(item));
    else controls.clear();
    sync();
  };
  save.onclick = async () => {
    if (!ready || disposed) return;
    const request = ++generation,
      source = structuredClone(drawing()),
      snapshot = JSON.stringify(source);
    save.disabled = true;
    try {
      const next = await putSketchText(source, {
        ...controls.read(),
        ...(selected ? { id: selected } : {}),
      });
      if (disposed || request !== generation) return;
      if (JSON.stringify(drawing()) !== snapshot)
        throw Error(
          "The sketch changed while text was being prepared. Review the sketch and try again.",
        );
      selected = next.textItems!.at(-1)!.id;
      commit(next);
      sync();
    } catch (error) {
      if (!disposed && request === generation)
        controls.error((error as Error).message);
    } finally {
      if (!disposed && request === generation) save.disabled = !ready;
    }
  };
  detach.onclick = () => {
    if (!selected) return;
    try {
      ++generation;
      const next = detachSketchText(drawing(), selected);
      selected = "";
      controls.clear();
      commit(next);
      sync();
    } catch (error) {
      controls.error((error as Error).message);
    }
  };
  frame.onclick = () => {
    if (!selected || disposed) return;
    try {
      ++generation;
      commit(attachSketchTextFrame(drawing(), selected));
      sync();
    } catch (error) {
      controls.error((error as Error).message);
    }
  };
  sync();
  return {
    sync,
    selected: () => selected,
    ready(value: boolean) {
      ++generation;
      ready = value;
      save.disabled = !value;
    },
    dispose() {
      disposed = true;
      ++generation;
      select.remove();
      save.remove();
      detach.remove();
      frame.remove();
    },
  };
}
