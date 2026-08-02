import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { Tree } from "./Tree";

const nodes = [
  {
    id: "group",
    label: "Group",
    children: [
      { id: "a", label: "Alpha" },
      { id: "b", label: "Beta", dimmed: true },
      { id: "c", label: "Gamma", disabled: true },
    ],
  },
  { id: "solo", label: "Solo" },
];

function renderTree(overrides: Partial<Parameters<typeof Tree>[0]> = {}) {
  const onSelect = vi.fn();
  const utils = render(
    <Tree nodes={nodes} selectedIDs={new Set()} onSelect={onSelect} {...overrides} />
  );
  return { onSelect, ...utils };
}

test("single click replaces, cmd toggles, shift range-selects visible order", () => {
  const { onSelect } = renderTree();
  fireEvent.click(screen.getByText("Alpha"));
  expect(onSelect).toHaveBeenLastCalledWith(["a"], "single");
  fireEvent.click(screen.getByText("Solo"), { metaKey: true });
  expect(onSelect).toHaveBeenLastCalledWith(["solo"], "toggle");
  // Range from the Alpha anchor to Solo spans the visible rows, skipping
  // the disabled row.
  fireEvent.click(screen.getByText("Alpha"));
  fireEvent.click(screen.getByText("Solo"), { shiftKey: true });
  expect(onSelect).toHaveBeenLastCalledWith(["a", "b", "solo"], "range");
});

test("disclosure collapses without selecting", () => {
  const { onSelect } = renderTree();
  fireEvent.click(screen.getByText("▾"));
  expect(screen.queryByText("Alpha")).toBeNull();
  expect(onSelect).not.toHaveBeenCalled();
});

test("controlled expansion follows expandedIDs and reports onToggle", () => {
  const onToggle = vi.fn();
  const { rerender } = render(
    <Tree
      nodes={nodes}
      selectedIDs={new Set()}
      onSelect={() => {}}
      expandedIDs={new Set()}
      onToggle={onToggle}
    />
  );
  expect(screen.queryByText("Alpha")).toBeNull();
  fireEvent.click(screen.getByText("▸"));
  expect(onToggle).toHaveBeenCalledWith("group", true);
  rerender(
    <Tree
      nodes={nodes}
      selectedIDs={new Set()}
      onSelect={() => {}}
      expandedIDs={new Set(["group"])}
      onToggle={onToggle}
    />
  );
  expect(screen.queryByText("Alpha")).not.toBeNull();
});

test("filter keeps matches and ancestors, reveals collapsed branches", () => {
  render(
    <Tree
      nodes={nodes}
      selectedIDs={new Set()}
      onSelect={() => {}}
      defaultCollapsedIDs={["group"]}
      filter="bet"
    />
  );
  expect(screen.queryByText("Beta")).not.toBeNull();
  expect(screen.queryByText("Group")).not.toBeNull(); // ancestor kept
  expect(screen.queryByText("Alpha")).toBeNull();
  expect(screen.queryByText("Solo")).toBeNull();
});

test("keyboard: arrows navigate, left collapses to parent, enter selects", () => {
  const { onSelect } = renderTree();
  const first = screen.getByText("Group").closest("button")!;
  first.focus();
  fireEvent.keyDown(first, { key: "ArrowDown" });
  expect(document.activeElement).toBe(
    screen.getByText("Alpha").closest("button")
  );
  fireEvent.keyDown(document.activeElement!, { key: "ArrowLeft" });
  expect(document.activeElement).toBe(first);
  fireEvent.keyDown(first, { key: "Enter" });
  expect(onSelect).toHaveBeenLastCalledWith(["group"], "single");
});

test("disabled rows cannot be selected", () => {
  const { onSelect } = renderTree();
  fireEvent.click(screen.getByText("Gamma"));
  expect(onSelect).not.toHaveBeenCalled();
});

test("trailing actions fire without changing selection", () => {
  const onAction = vi.fn();
  const onSelect = vi.fn();
  render(
    <Tree
      nodes={[
        {
          id: "x",
          label: "X",
          actions: [{ id: "hide", label: "Hide", icon: "👁" }],
        },
      ]}
      selectedIDs={new Set()}
      onSelect={onSelect}
      onAction={onAction}
    />
  );
  fireEvent.click(screen.getByLabelText("Hide"));
  expect(onAction).toHaveBeenCalledWith("x", "hide");
  expect(onSelect).not.toHaveBeenCalled();
});

test("activate on double-click and context menu reports position", () => {
  const onActivate = vi.fn();
  const onContextMenu = vi.fn();
  renderTree({ onActivate, onContextMenu });
  fireEvent.doubleClick(screen.getByText("Solo"));
  expect(onActivate).toHaveBeenCalledWith("solo");
  fireEvent.contextMenu(screen.getByText("Solo"), { clientX: 9, clientY: 11 });
  expect(onContextMenu).toHaveBeenCalledWith("solo", 9, 11);
});

test("empty state renders when no rows survive", () => {
  render(
    <Tree
      nodes={[]}
      selectedIDs={new Set()}
      onSelect={() => {}}
      emptyState="nothing here"
    />
  );
  expect(screen.getByText("nothing here")).not.toBeNull();
});
