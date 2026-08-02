import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { Dialog } from "./Dialog";

test("renders nothing when closed and content when open", () => {
  const { rerender } = render(
    <Dialog open={false} title="T" onClose={() => {}}>
      body
    </Dialog>
  );
  expect(screen.queryByRole("dialog")).toBeNull();
  rerender(
    <Dialog open title="T" onClose={() => {}}>
      body
    </Dialog>
  );
  expect(screen.getByRole("dialog")).not.toBeNull();
});

test("scrim click and close button both close; body click does not", () => {
  const onClose = vi.fn();
  render(
    <Dialog open title="T" onClose={onClose}>
      body
    </Dialog>
  );
  fireEvent.click(screen.getByText("body"));
  expect(onClose).not.toHaveBeenCalled();
  fireEvent.click(screen.getByLabelText("Close"));
  expect(onClose).toHaveBeenCalledTimes(1);
});
