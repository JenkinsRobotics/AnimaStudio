import type { SketchTextItem } from "@aether/core/sketch";
/** Optional physical ascender height; the panel retains canonical em controls. */
export function mountTextHeight(
  parent: HTMLElement,
  em: HTMLInputElement,
  changed: () => void,
) {
  const label = document.createElement("label"),
    enabled = document.createElement("input"),
    heightLabel = document.createElement("label"),
    height = document.createElement("input");
  enabled.type = "checkbox";
  enabled.setAttribute("aria-label", "Size text by ascender height");
  label.append(enabled, " Size text by ascender height");
  height.type = "text";
  height.setAttribute("aria-label", "Text height (mm)");
  heightLabel.append("Text height (mm)", height);
  parent.append(label, heightLabel);
  let fontRatio = 1,
    ready = false;
  const syncFromEm = () => {
    height.value = String(Number(em.value) * fontRatio);
  };
  enabled.onchange = () => {
    syncFromEm();
    height.disabled = !enabled.checked || !ready;
    changed();
  };
  height.oninput = () => {
    em.value = height.value.trim()
      ? String(Number(height.value) / fontRatio)
      : "";
    changed();
  };
  height.disabled = true;
  syncFromEm();
  return {
    syncFromEm,
    ratio: () => (enabled.checked ? fontRatio : undefined),
    read: () => (enabled.checked ? Number(height.value) : null),
    font(ratio: number) {
      fontRatio = ratio;
      ready = true;
      if (enabled.checked) em.value = String(Number(height.value) / ratio);
      else syncFromEm();
      height.disabled = !enabled.checked;
    },
    load(item: SketchTextItem) {
      enabled.checked = item.fontAscenderRatio !== undefined;
      if (item.fontAscenderRatio !== undefined)
        fontRatio = item.fontAscenderRatio;
      syncFromEm();
      height.disabled = !enabled.checked || !ready;
    },
    reset() {
      enabled.checked = false;
      ready = false;
      fontRatio = 1;
      syncFromEm();
      height.disabled = true;
    },
    dispose() {
      label.remove();
      heightLabel.remove();
    },
  };
}
