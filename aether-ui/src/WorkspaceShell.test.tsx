import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import {
  LayoutPresetButton,
  WorkspaceShell,
  nextLayoutPreset,
} from "./WorkspaceShell";

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
