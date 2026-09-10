import { render } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { ViewportCanvas } from "./ViewportCanvas";

test("mounts the renderer exactly once and tears down on unmount", () => {
  const teardown = vi.fn();
  const onMount = vi.fn((_canvas: HTMLCanvasElement) => teardown);
  const { rerender, unmount } = render(<ViewportCanvas onMount={onMount} />);
  expect(onMount).toHaveBeenCalledTimes(1);
  expect(onMount.mock.calls[0][0]).toBeInstanceOf(HTMLCanvasElement);
  rerender(<ViewportCanvas onMount={onMount} />); // re-render must NOT remount
  expect(onMount).toHaveBeenCalledTimes(1);
  expect(teardown).not.toHaveBeenCalled();
  unmount();
  expect(teardown).toHaveBeenCalledTimes(1);
});
