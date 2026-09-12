import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import { CADTraditionalRibbon } from "./CADTraditionalRibbon";

describe("CADTraditionalRibbon", () => {
  it("renders all traditional workspaces and document context without duplicating suite navigation", () => {
    const html = renderToStaticMarkup(<CADTraditionalRibbon
      activeWorkspace="solid"
      partOpen
      onSelectWorkspace={vi.fn()}
      onAction={vi.fn()}
    />);
    expect(html).not.toContain('aria-label="Aether suite stages"');
    for (const label of ["Home", "Sketch", "3D Tools", "Assembly", "View", "Manage", "Output"]) {
      expect(html).toContain(`aria-label="${label}"`);
    }
    expect(html).toContain('data-ribbon-workspace="solid"');
    expect(html).not.toContain('aria-label="Open documents"');
  });

  it("exposes unavailable features with exact reasons", () => {
    const html = renderToStaticMarkup(<CADTraditionalRibbon
      activeWorkspace="assembly"
      partOpen={false}
      onSelectWorkspace={vi.fn()}
      onAction={vi.fn()}
    />);
    expect(html).toContain('data-tool-id="assembly-revolute"');
    expect(html).toContain("Requires a canonical Core Assembly mutation or mate solver command");
    expect(html).toContain('data-tool-id="assembly-interference"');
    expect(html).toContain("Requires an exact Core analysis contract");
    expect(html).toContain("Create or open a persistent Assembly before saving it.");
  });

  it("part documents render the Fusion layout with section dropdowns and contextual Sketch tab", () => {
    const html = renderToStaticMarkup(<CADTraditionalRibbon
      documentType="part"
      activeWorkspace="solid"
      partOpen
      documentName="Part 1"
      onSelectWorkspace={vi.fn()}
      onAction={vi.fn()}
    />);
    for (const label of ["Solid", "Surface", "Mesh", "Sheet Metal", "Plastic", "Manage", "Utilities"])
      expect(html).toContain(`aria-label="${label}"`);
    expect(html).not.toContain('aria-label="Assembly"');
    expect(html).toContain("Create ▾");
    expect(html).toContain("Modify ▾");
    const sketching = renderToStaticMarkup(<CADTraditionalRibbon
      documentType="part"
      sketchEditing
      activeWorkspace="solid"
      partOpen
      documentName="Part 1"
      onSelectWorkspace={vi.fn()}
      onAction={vi.fn()}
    />);
    // Finish Sketch lives on the sketch feature window's accept control, not
    // in the ribbon, and the Floating tools switch was removed.
    expect(sketching).not.toContain("Finish Sketch");
    expect(sketching).not.toContain("Floating tools");
    expect(sketching).toContain('data-ribbon-workspace="sketch-context"');
  });
});
// Onshape puts every relationship behind one Constrain button with a dropdown,
// and every dimension type behind one Dimension button — not a row of 26.
it("renders Constrain and Dimension as single buttons with dropdowns", () => {
  const html = renderToStaticMarkup(<CADTraditionalRibbon
    activeWorkspace="sketch"
    partOpen
    documentName="Part 1"
    onSelectWorkspace={vi.fn()}
    onAction={vi.fn()}
  />);
  // The two collapsed buttons exist...
  expect(html).toContain('data-tool-id="sketch-constrain"');
  expect(html).toContain('data-tool-id="sketch-dimension"');
  // ...each with a variants dropdown.
  expect(html).toContain('aria-label="Coincident variants"');
  expect(html).toContain('aria-label="Dimension variants"');
  // ...and the relationships are NOT flat buttons in the ribbon any more.
  for (const kind of ["horizontal", "vertical", "parallel", "perpendicular", "tangent"])
    expect(html, `${kind} should live in the dropdown`).not.toContain(
      `data-tool-id="sketch-constraint-${kind}"`,
    );
});
