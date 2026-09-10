import { fireEvent, render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import {
  ViewportNavigationCube,
  viewportCubeTransform,
} from "./ViewportNavigationCube";

test("projects camera orientation into the inverse world cube transform", () => {
  expect(viewportCubeTransform([0, 0, 0, 1])).toBe(
    "matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)",
  );
  const { container, rerender } = render(
    <ViewportNavigationCube
      orientation={[0, 0, 0, 1]}
      onSelectView={() => {}}
      onFit={() => {}}
      onNudge={() => {}}
      onRoll={() => {}}
    />,
  );
  const front = container.querySelector<SVGElement>('[data-view="front"]');
  const originalPoints = front?.querySelector("polygon")?.getAttribute("points");
  expect(front).not.toBeNull();
  rerender(
    <ViewportNavigationCube
      orientation={[0, Math.SQRT1_2, 0, Math.SQRT1_2]}
      onSelectView={() => {}}
      onFit={() => {}}
      onNudge={() => {}}
      onRoll={() => {}}
    />,
  );
  expect(container.querySelector('[data-view="front"]')).toBeNull();
  expect(container.querySelector('[data-view="right"]')).not.toBeNull();
  expect(originalPoints).not.toBe("");
});

test("emits typed face, fit, nudge, and roll intent", () => {
  const onSelectView = vi.fn();
  const onFit = vi.fn();
  const onNudge = vi.fn();
  const onRoll = vi.fn();
  render(
    <ViewportNavigationCube
      orientation={[0, 0, 0, 1]}
      onSelectView={onSelectView}
      onFit={onFit}
      onNudge={onNudge}
      onRoll={onRoll}
    />,
  );

  fireEvent.click(screen.getByRole("button", { name: "Front view" }));
  fireEvent.click(screen.getByRole("button", { name: "Nudge view left 15 degrees" }));
  fireEvent.click(screen.getByRole("button", { name: "Roll view clockwise" }));
  fireEvent.click(screen.getByRole("button", { name: "Fit isometric view" }));

  expect(onSelectView).toHaveBeenCalledWith("front");
  expect(onNudge).toHaveBeenCalledWith(-1, 0);
  expect(onRoll).toHaveBeenCalledWith(1);
  expect(onFit).toHaveBeenCalledTimes(1);
});

test('face lettering follows a half-turn camera roll instead of staying upright',()=>{
 const props={onSelectView:()=>{},onFit:()=>{},onNudge:()=>{},onRoll:()=>{}};
 const {container,rerender}=render(<ViewportNavigationCube {...props} orientation={[0,0,0,1]}/>);
 expect(container.querySelector('[data-view="front"] text')?.getAttribute('transform')).toBe('matrix(1 0 0 1 46 46)');
 rerender(<ViewportNavigationCube {...props} orientation={[0,0,1,0]}/>);
 expect(container.querySelector('[data-view="front"] text')?.getAttribute('transform')).toBe('matrix(-1 0 0 -1 46 46)');
});
