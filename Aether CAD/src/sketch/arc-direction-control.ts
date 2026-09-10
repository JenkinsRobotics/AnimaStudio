/** Gesture setting only. Saved arcs encode direction in their exact geometry. */
export function mountArcDirectionControl(
  parent: HTMLElement,
  preview: () => void,
) {
  const label = document.createElement("label");
  label.textContent = "Arc direction";
  const select = document.createElement("select");
  select.setAttribute("aria-label", "Arc direction");
  for (const [value, text] of [
    ["counterclockwise", "Counterclockwise"],
    ["clockwise", "Clockwise"],
  ]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = text;
    select.append(option);
  }
  label.append(select);
  label.hidden = true;
  parent.append(label);
  select.addEventListener("change", preview);
  return {
    clockwise: () => select.value === "clockwise",
    update: (tool: string) => {
      label.hidden = tool !== "center-arc" && tool !== "elliptical-arc";
    },
  };
}
