import { dxfLayers } from "@aether/core/sketch";
/** Layer choices affect importer input; geometry decoding stays in Core. */
export function mountDxfLayerControl(parent: HTMLElement, changed: () => void) {
  const root = document.createElement("fieldset"),
    legend = document.createElement("legend");
  legend.textContent = "DXF layers";
  root.append(legend);
  root.hidden = true;
  parent.append(root);
  const inputs: HTMLInputElement[] = [];
  return {
    source(text: string) {
      inputs.length = 0;
      root.replaceChildren(legend);
      const layers = text ? dxfLayers(text) : [];
      root.hidden = !layers.length;
      for (const layer of layers) {
        const label = document.createElement("label"),
          input = document.createElement("input");
        input.type = "checkbox";
        input.checked = true;
        input.value = layer.name;
        input.setAttribute("aria-label", `Import DXF layer ${layer.name}`);
        input.onchange = changed;
        label.append(input, `${layer.name} (${layer.entityCount})`);
        root.append(label);
        inputs.push(input);
      }
    },
    selected() {
      return inputs
        .filter((input) => input.checked)
        .map((input) => input.value);
    },
  };
}
