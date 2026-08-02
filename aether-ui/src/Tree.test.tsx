import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { Tree } from "./Tree";

const nodes = [
  {
    id: "group",
    label: "Group",
    children: [{ id: "leaf", label: "Leaf" }],
  },
];

test("selecting a row reports id and extend modifier", () => {
  const onSelect = vi.fn();
  render(<Tree nodes={nodes} selectedIDs={new Set()} onSelect={onSelect} />);
  fireEvent.click(screen.getByText("Leaf"));
  expect(onSelect).toHaveBeenCalledWith("leaf", false);
  fireEvent.click(screen.getByText("Group"), { shiftKey: true });
  expect(onSelect).toHaveBeenCalledWith("group", true);
});

test("disclosure collapses children without selecting", () => {
  const onSelect = vi.fn();
  render(<Tree nodes={nodes} selectedIDs={new Set()} onSelect={onSelect} />);
  expect(screen.queryByText("Leaf")).not.toBeNull();
  fireEvent.click(screen.getByText("▾"));
  expect(screen.queryByText("Leaf")).toBeNull();
  expect(onSelect).not.toHaveBeenCalled();
});

test("selected row carries the selected class", () => {
  render(
    <Tree nodes={nodes} selectedIDs={new Set(["group"])} onSelect={() => {}} />
  );
  const row = screen.getByText("Group").closest("button");
  expect(row?.className).toContain("aui-tree-row--selected");
});
