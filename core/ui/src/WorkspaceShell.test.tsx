import { fireEvent, render, screen } from "@testing-library/react";
import { useState } from "react";
import { expect, test, vi } from "vitest";
import {
  LayoutPresetButton,
  WorkspaceShell,
  nextLayoutPreset,
  type WorkspacePanelState,
} from "./WorkspaceShell";
import { ViewportCanvas } from "./ViewportCanvas";

const panels = [
  { id: "parts", title: "Parts", icon: "▣", content: <div>parts-content</div> },
];

test("preset cycle order is floating → docked → canvas → floating", () => {
  expect(nextLayoutPreset("floating")).toBe("docked");
  expect(nextLayoutPreset("docked")).toBe("canvas");
  expect(nextLayoutPreset("canvas")).toBe("floating");
  const onChange = vi.fn();
  render(<LayoutPresetButton preset="docked" onChange={onChange} />);
  fireEvent.click(screen.getByLabelText("Layout docked, switch to canvas"));
  expect(onChange).toHaveBeenCalledWith("canvas");
});

test("docked: rail button toggles the panel open and closed", () => {
  render(
    <WorkspaceShell preset="docked" leftPanels={panels}>
      canvas
    </WorkspaceShell>
  );
  expect(screen.queryByText("parts-content")).toBeNull();
  fireEvent.click(screen.getByLabelText("Parts"));
  expect(screen.queryByText("parts-content")).not.toBeNull();
  fireEvent.click(screen.getByLabelText("Parts"));
  expect(screen.queryByText("parts-content")).toBeNull();
});

test("float button tears the panel off; dock button restacks it", () => {
  const { container } = render(
    <WorkspaceShell preset="docked" leftPanels={panels} defaultOpenLeft={["parts"]}>
      canvas
    </WorkspaceShell>
  );
  expect(container.querySelector(".aui-float-panel")).toBeNull();
  fireEvent.click(screen.getByLabelText("Float Parts"));
  expect(container.querySelector(".aui-float-panel")).not.toBeNull();
  expect(screen.queryByText("parts-content")).not.toBeNull();
  fireEvent.click(screen.getByLabelText("Dock Parts"));
  expect(container.querySelector(".aui-float-panel")).toBeNull();
  expect(screen.queryByText("parts-content")).not.toBeNull(); // back in the stack
});

test("canvas preset hides chrome until the edge hot-zone is hovered", () => {
  const { container } = render(
    <WorkspaceShell preset="canvas" leftPanels={panels} defaultOpenLeft={["parts"]}>
      canvas
    </WorkspaceShell>
  );
  expect(screen.queryByLabelText("Parts")).toBeNull(); // rail hidden
  expect(container.querySelector(".aui-shell-handle--left")).not.toBeNull();
  fireEvent.mouseEnter(container.querySelector(".aui-shell-edge--left")!);
  expect(screen.queryByLabelText("Parts")).not.toBeNull(); // rail revealed
  expect(screen.queryByText("parts-content")).not.toBeNull();
});

test("floating preset shows chrome overlays without hover", () => {
  render(
    <WorkspaceShell
      preset="floating"
      leftPanels={panels}
      defaultOpenLeft={["parts"]}
      toolbar={<div>toolbar-content</div>}
    >
      canvas
    </WorkspaceShell>
  );
  expect(screen.queryByLabelText("Parts")).not.toBeNull();
  expect(screen.queryByText("parts-content")).not.toBeNull();
  expect(screen.queryByText("toolbar-content")).not.toBeNull();
});

test("layout preset changes preserve one mounted viewport", () => {
  const teardown = vi.fn();
  const onMount = vi.fn(() => teardown);
  const workspace = (preset: "docked" | "floating" | "canvas") => (
    <WorkspaceShell
      preset={preset}
      leftPanels={panels}
      defaultOpenLeft={["parts"]}
      toolbar={<div>toolbar-content</div>}
    >
      <ViewportCanvas onMount={onMount} />
    </WorkspaceShell>
  );

  const { container, rerender, unmount } = render(workspace("docked"));
  const canvas = container.querySelector("canvas");
  expect(canvas).not.toBeNull();
  expect(onMount).toHaveBeenCalledTimes(1);

  rerender(workspace("floating"));
  expect(container.querySelector("canvas")).toBe(canvas);
  expect(onMount).toHaveBeenCalledTimes(1);
  expect(teardown).not.toHaveBeenCalled();

  rerender(workspace("canvas"));
  expect(container.querySelector("canvas")).toBe(canvas);
  expect(onMount).toHaveBeenCalledTimes(1);
  expect(teardown).not.toHaveBeenCalled();

  unmount();
  expect(teardown).toHaveBeenCalledTimes(1);
});

test("controlled panel state persists Dock, Float, Hide, and float position", () => {
  function ControlledShell() {
    const [panelState, setPanelState] = useState<WorkspacePanelState>({
      parts: { placement: "docked" },
    });
    return (
      <>
        <WorkspaceShell
          preset="docked"
          leftPanels={panels}
          panelState={panelState}
          onPanelStateChange={setPanelState}
        >
          canvas
        </WorkspaceShell>
        <output data-testid="panel-state">{JSON.stringify(panelState)}</output>
      </>
    );
  }

  const { container } = render(<ControlledShell />);
  fireEvent.click(screen.getByLabelText("Float Parts"));
  expect(container.querySelector(".aui-float-panel")).not.toBeNull();
  expect(screen.getByTestId("panel-state").textContent).toContain(
    '"placement":"floating","position":{"x":64,"y":56}',
  );

  fireEvent.click(screen.getByLabelText("Dock Parts"));
  expect(container.querySelector(".aui-float-panel")).toBeNull();
  expect(screen.getByTestId("panel-state").textContent).toContain(
    '"placement":"docked"',
  );

  fireEvent.click(screen.getByLabelText("Close Parts"));
  expect(screen.queryByText("parts-content")).toBeNull();
  expect(screen.getByTestId("panel-state").textContent).toContain(
    '"placement":"hidden"',
  );
});


test("retained panel preserves its input node and draft across dock, float and hide", () => {
  const content = [{ id: "editor", title: "Editor", icon: "E", content: <input aria-label="Draft" defaultValue="initial" /> }];
  const { rerender } = render(<WorkspaceShell preset="docked" preservePanelContent leftPanels={content} panelState={{ editor: { placement: "docked" } }}><canvas /></WorkspaceShell>);
  const input = screen.getByLabelText("Draft") as HTMLInputElement;
  fireEvent.change(input, { target: { value: "unsaved" } });
  for (const placement of ["floating", "hidden", "docked"] as const) {
    rerender(<WorkspaceShell preset="floating" preservePanelContent leftPanels={content} panelState={{ editor: { placement } }}><canvas /></WorkspaceShell>);
    expect(screen.getByLabelText("Draft")).toBe(input);
    expect(input.value).toBe("unsaved");
  }
});


test("versioned layouts persist separately per preset and tolerate invalid storage", () => {
  const key = "aether.test.panels";
  localStorage.setItem(key, "invalid");
  const renderShell = (preset: "docked" | "floating") => <WorkspaceShell preset={preset} storageKey={key} leftPanels={panels} defaultOpenLeft={["parts"]}><canvas /></WorkspaceShell>;
  const { rerender, unmount } = render(renderShell("docked"));
  fireEvent.click(screen.getByLabelText("Close Parts"));
  expect(screen.queryByText("parts-content")).toBeNull();
  rerender(renderShell("floating"));
  expect(screen.getByText("parts-content")).toBeTruthy();
  rerender(renderShell("docked"));
  expect(screen.queryByText("parts-content")).toBeNull();
  unmount();
  const restored = render(renderShell("docked"));
  expect(screen.queryByText("parts-content")).toBeNull();
  restored.unmount();
  localStorage.removeItem(key);
});
