import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { Tabs } from "./Tabs";

const tabs = [
  { id: "a", label: "Assets" },
  { id: "m", label: "Modeling" },
  { id: "n", label: "Animate" },
];

test("click selects; active tab is the only tab-stop", () => {
  const onSelect = vi.fn();
  render(<Tabs tabs={tabs} activeID="a" onSelect={onSelect} />);
  fireEvent.click(screen.getByText("Modeling"));
  expect(onSelect).toHaveBeenCalledWith("m");
  expect(screen.getByText("Assets").tabIndex).toBe(0);
  expect(screen.getByText("Modeling").tabIndex).toBe(-1);
});

test("arrows move+select with wrap, Home/End jump, focus follows", () => {
  const onSelect = vi.fn();
  render(<Tabs tabs={tabs} activeID="a" onSelect={onSelect} />);
  const first = screen.getByText("Assets");
  first.focus();
  fireEvent.keyDown(first, { key: "ArrowRight" });
  expect(onSelect).toHaveBeenLastCalledWith("m");
  expect(document.activeElement).toBe(screen.getByText("Modeling"));
  fireEvent.keyDown(first, { key: "ArrowLeft" });
  expect(onSelect).toHaveBeenLastCalledWith("n"); // wraps
  fireEvent.keyDown(first, { key: "End" });
  expect(onSelect).toHaveBeenLastCalledWith("n");
  fireEvent.keyDown(first, { key: "Home" });
  expect(onSelect).toHaveBeenLastCalledWith("a");
});
