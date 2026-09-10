import { render } from "@testing-library/react";
import { expect, test } from "vitest";
import { AetherIcon } from "./AetherIcon";

test("renders shared chrome icons as presentation-only SVG", () => {
  const { container, rerender } = render(<AetherIcon name="home" />);
  expect(container.querySelector("svg")?.getAttribute("aria-hidden")).toBe("true");
  expect(container.querySelectorAll("path").length).toBeGreaterThan(0);

  rerender(<AetherIcon name="settings" className="suite-icon" />);
  expect(container.querySelector("svg")?.classList.contains("suite-icon")).toBe(true);
  expect(container.querySelector("circle")).not.toBeNull();
});


test("shared icon sources are scalable geometry without embedded raster or font glyphs", () => {
  const sources = import.meta.glob("../../assets/icons/*.svg", { query: "?raw", import: "default", eager: true });
  expect(Object.keys(sources).length).toBeGreaterThan(30);
  for (const markup of Object.values(sources)) {
    expect(markup).toContain('viewBox="0 0 24 24"');
    expect(markup).toContain('stroke="currentColor"');
    expect(markup).not.toMatch(/<(?:text|image|script|foreignObject)\b/i);
  }
});
