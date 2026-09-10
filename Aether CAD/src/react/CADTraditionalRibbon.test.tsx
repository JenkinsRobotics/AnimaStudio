import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import { CADTraditionalRibbon } from "./CADTraditionalRibbon";

describe("CADTraditionalRibbon", () => {
  it("renders all traditional workspaces and document context without duplicating suite navigation", () => {
    const html = renderToStaticMarkup(<CADTraditionalRibbon
      activeWorkspace="solid"
      documentName="Drive Bracket"
      partOpen
      onSelectWorkspace={vi.fn()}
      onAction={vi.fn()}
      onUseFloatingTools={vi.fn()}
    />);
    expect(html).not.toContain('aria-label="Aether suite stages"');
    for (const label of ["Home", "Sketch", "3D Tools", "Assembly", "View", "Manage", "Output"]) {
      expect(html).toContain(`aria-label="${label}"`);
    }
    expect(html).toContain('data-ribbon-workspace="solid"');
    expect(html).toContain('aria-label="Open documents"');
    expect(html).toContain("Drive Bracket");
  });

  it("exposes unavailable features with exact reasons", () => {
    const html = renderToStaticMarkup(<CADTraditionalRibbon
      activeWorkspace="assembly"
      documentName="Assembly 1"
      partOpen={false}
      onSelectWorkspace={vi.fn()}
      onAction={vi.fn()}
      onUseFloatingTools={vi.fn()}
    />);
    expect(html).toContain('data-tool-id="assembly-revolute"');
    expect(html).toContain("Requires a canonical Core Assembly mutation or mate solver command");
    expect(html).toContain('data-tool-id="assembly-interference"');
    expect(html).toContain("Requires an exact Core analysis contract");
    expect(html).toContain("Create or open a persistent Assembly before saving it.");
  });
});
