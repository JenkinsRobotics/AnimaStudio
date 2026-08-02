import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { Rail, RailButton } from "./Rail";

test("rail buttons expose label, pressed state, and fire clicks", () => {
  const onClick = vi.fn();
  render(
    <Rail>
      <RailButton label="Tree" active onClick={onClick}>
        ☰
      </RailButton>
      <RailButton label="Layers">▤</RailButton>
    </Rail>
  );
  expect(screen.getByLabelText("Tree").getAttribute("aria-pressed")).toBe(
    "true"
  );
  expect(screen.getByLabelText("Layers").getAttribute("aria-pressed")).toBe(
    "false"
  );
  fireEvent.click(screen.getByLabelText("Tree"));
  expect(onClick).toHaveBeenCalledTimes(1);
});
