import {
  rectangleSketchRevision,
  replaceRectangleSketch,
  reviseCenterRectangleSketch,
  sketchDefinitionState,
  type PartDocument,
  type RectangleSketchRevision,
  type SketchFeature,
} from "./aether-core";

export interface SketchEditorCallbacks {
  onCommit(document: PartDocument): void | Promise<void>;
  onCancel(): void;
  onStatus(message: string, tone?: "normal" | "error" | "success"): void;
}

function sketchFromDocument(document: PartDocument): SketchFeature {
  const sketch = document.features.find(
    (feature): feature is SketchFeature => feature.type === "sketch",
  );
  if (!sketch) throw new Error("Part needs a Sketch.");
  return sketch;
}

function escapeHTML(value: string): string {
  const element = document.createElement("div");
  element.textContent = value;
  return element.innerHTML;
}

export class SketchEditor {
  private readonly root: HTMLElement;
  private document: PartDocument | null = null;
  private sketch: SketchFeature | null = null;
  private revision: RectangleSketchRevision | null = null;
  private draggingCorner = false;

  constructor(
    host: HTMLElement,
    private readonly callbacks: SketchEditorCallbacks,
  ) {
    this.root = document.createElement("section");
    this.root.className = "sketch-editor hidden";
    host.append(this.root);
    this.root.addEventListener("click", (event) => this.handleClick(event));
    this.root.addEventListener("change", (event) => this.handleInput(event));
    this.root.addEventListener("pointerdown", (event) =>
      this.handlePointerDown(event),
    );
    window.addEventListener("pointermove", (event) =>
      this.handlePointerMove(event),
    );
    window.addEventListener("pointerup", () => {
      this.draggingCorner = false;
    });
    window.addEventListener("keydown", (event) => this.handleKeyDown(event));
  }

  get active(): boolean {
    return this.document !== null;
  }

  open(document: PartDocument): void {
    this.document = structuredClone(document);
    this.sketch = structuredClone(sketchFromDocument(document));
    this.revision = rectangleSketchRevision(this.sketch);
    this.root.classList.remove("hidden");
    this.render();
    this.callbacks.onStatus(
      `${this.sketch.name} · ${this.sketch.plane} plane. Drag a corner for rough geometry, then apply dimensions.`,
    );
  }

  close(): void {
    this.document = null;
    this.sketch = null;
    this.revision = null;
    this.draggingCorner = false;
    this.root.classList.add("hidden");
    this.root.innerHTML = "";
  }

  private currentState(): {
    document: PartDocument;
    sketch: SketchFeature;
    revision: RectangleSketchRevision;
  } {
    if (!this.document || !this.sketch || !this.revision) {
      throw new Error("Sketch editor is not active.");
    }
    return {
      document: this.document,
      sketch: this.sketch,
      revision: this.revision,
    };
  }

  private render(): void {
    const { document, sketch, revision } = this.currentState();
    const definition = sketchDefinitionState(
      reviseCenterRectangleSketch(sketch, revision),
    );
    const width = this.root.clientWidth || 900;
    const height = this.root.clientHeight || 650;
    const centerX = width / 2;
    const centerY = height / 2;
    const scale = Math.max(
      1.5,
      Math.min(width * 0.46 / revision.widthMillimeters, height * 0.46 / revision.heightMillimeters),
    );
    const rectangleWidth = revision.widthMillimeters * scale;
    const rectangleHeight = revision.heightMillimeters * scale;
    const left = centerX - rectangleWidth / 2;
    const top = centerY - rectangleHeight / 2;
    const geometryClass = definition.fullyDefined
      ? "fully-defined"
      : "under-defined";
    const constructionClass = revision.construction ? " construction" : "";
    this.root.innerHTML = `
      <svg class="sketch-canvas" width="${width}" height="${height}" aria-label="Sketch canvas">
        <defs>
          <pattern id="minor-grid" width="20" height="20" patternUnits="userSpaceOnUse">
            <path d="M 20 0 L 0 0 0 20" fill="none" stroke="#e6ebef" stroke-width="1" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="#fbfcfd" />
        <rect width="100%" height="100%" fill="url(#minor-grid)" />
        <line class="sketch-axis x-axis" x1="0" y1="${centerY}" x2="${width}" y2="${centerY}" />
        <line class="sketch-axis y-axis" x1="${centerX}" y1="0" x2="${centerX}" y2="${height}" />
        <circle class="sketch-origin" cx="${centerX}" cy="${centerY}" r="5" />
        <g class="sketch-geometry ${geometryClass}${constructionClass}">
          <rect x="${left}" y="${top}" width="${rectangleWidth}" height="${rectangleHeight}" />
          <line class="construction-diagonal" x1="${left}" y1="${top}" x2="${left + rectangleWidth}" y2="${top + rectangleHeight}" />
          <line class="construction-diagonal" x1="${left + rectangleWidth}" y1="${top}" x2="${left}" y2="${top + rectangleHeight}" />
          <circle class="corner-handle" data-sketch-corner cx="${left + rectangleWidth}" cy="${top}" r="7" />
        </g>
        ${revision.widthDimensioned ? `<g class="sketch-dimension"><line x1="${left}" y1="${top - 26}" x2="${left + rectangleWidth}" y2="${top - 26}"/><text x="${centerX}" y="${top - 32}">${revision.widthMillimeters.toFixed(2)} mm</text></g>` : ""}
        ${revision.heightDimensioned ? `<g class="sketch-dimension"><line x1="${left - 28}" y1="${top}" x2="${left - 28}" y2="${top + rectangleHeight}"/><text transform="translate(${left - 36} ${centerY}) rotate(-90)">${revision.heightMillimeters.toFixed(2)} mm</text></g>` : ""}
        <text class="sketch-plane-label" x="${width - 22}" y="${height - 20}" text-anchor="end">${sketch.plane} PLANE</text>
      </svg>
      <div class="sketch-mode-toolbar" role="toolbar" aria-label="Sketch tools">
        <button class="sketch-command selected" data-sketch-action="rectangle" title="Center-point Rectangle (R)"><b>▭</b><span>Rectangle</span><kbd>R</kbd></button>
        <button class="sketch-command ${revision.construction ? "selected" : ""}" data-sketch-action="construction" title="Construction (Q)"><b>┄</b><span>Construction</span><kbd>Q</kbd></button>
        <span class="sketch-tool-divider"></span>
        <button class="sketch-command ${revision.horizontal ? "selected" : ""}" data-sketch-action="horizontal" title="Horizontal constraint (H)"><b>—</b><span>Horizontal</span><kbd>H</kbd></button>
        <button class="sketch-command ${revision.vertical ? "selected" : ""}" data-sketch-action="vertical" title="Vertical constraint (V)"><b>|</b><span>Vertical</span><kbd>V</kbd></button>
        <button class="sketch-command ${revision.anchoredToOrigin ? "selected" : ""}" data-sketch-action="anchor" title="Coincident with Origin (I)"><b>⊙</b><span>Coincident</span><kbd>I</kbd></button>
        <button class="sketch-command" data-sketch-action="dimension" title="Dimension (D)"><b>↔</b><span>Dimension</span><kbd>D</kbd></button>
      </div>
      <aside class="sketch-dialog">
        <header><div><b>${escapeHTML(sketch.name)}</b><span>${escapeHTML(document.name)} · ${sketch.plane}</span></div><div><button class="sketch-accept" data-sketch-action="finish" title="Finish Sketch">✓</button><button class="sketch-cancel" data-sketch-action="cancel" title="Cancel">×</button></div></header>
        <section>
          <div class="definition-state ${definition.fullyDefined ? "complete" : "incomplete"}"><span></span><b>${definition.label}</b><small>${definition.fullyDefined ? "0 remaining degrees of freedom" : `${definition.remainingDegreesOfFreedom} remaining degrees of freedom`}</small></div>
          <p>Drag the upper-right handle to rough in the rectangle. Center remains at the Origin while Coincident is active.</p>
          <div class="sketch-field-grid">
            <label>Width <span>mm</span><input id="sketch-width" type="number" min="0.001" step="1" value="${revision.widthMillimeters}" /></label>
            <label>Height <span>mm</span><input id="sketch-height" type="number" min="0.001" step="1" value="${revision.heightMillimeters}" /></label>
          </div>
          <button class="apply-dimensions" data-sketch-action="dimension">Apply Width + Height Dimensions</button>
          <div class="constraint-list">
            <button class="${revision.anchoredToOrigin ? "active" : ""}" data-sketch-action="anchor"><span>●</span> Center coincident with Origin</button>
            <button class="${revision.horizontal ? "active" : ""}" data-sketch-action="horizontal"><span>H</span> Opposite edges horizontal</button>
            <button class="${revision.vertical ? "active" : ""}" data-sketch-action="vertical"><span>V</span> Opposite edges vertical</button>
            <button class="${revision.widthDimensioned ? "active" : ""}" data-sketch-action="dimension"><span>D</span> Width dimension</button>
            <button class="${revision.heightDimensioned ? "active" : ""}" data-sketch-action="dimension"><span>D</span> Height dimension</button>
          </div>
        </section>
      </aside>`;
  }

  private revise(change: Partial<RectangleSketchRevision>): void {
    const state = this.currentState();
    this.revision = { ...state.revision, ...change };
    this.sketch = reviseCenterRectangleSketch(state.sketch, this.revision);
    this.render();
  }

  private numericInputs(): { widthMillimeters: number; heightMillimeters: number } {
    const width = this.root.querySelector<HTMLInputElement>("#sketch-width")
      ?.valueAsNumber;
    const height = this.root.querySelector<HTMLInputElement>("#sketch-height")
      ?.valueAsNumber;
    return {
      widthMillimeters: Number.isFinite(width) ? (width as number) : 0,
      heightMillimeters: Number.isFinite(height) ? (height as number) : 0,
    };
  }

  private handleClick(event: Event): void {
    const action = (event.target as HTMLElement)
      .closest<HTMLElement>("[data-sketch-action]")
      ?.dataset.sketchAction;
    if (!action || !this.active) return;
    const revision = this.currentState().revision;
    if (action === "finish") {
      if (revision.construction) {
        this.callbacks.onStatus(
          "A construction-only rectangle cannot feed Extrude 1. Toggle Construction off before finishing.",
          "error",
        );
        return;
      }
      const sketch = reviseCenterRectangleSketch(
        this.currentState().sketch,
        revision,
      );
      const updated = replaceRectangleSketch(this.currentState().document, sketch);
      void this.callbacks.onCommit(updated);
      return;
    }
    if (action === "cancel") {
      this.close();
      this.callbacks.onCancel();
      return;
    }
    if (action === "construction") {
      this.revise({ construction: !revision.construction });
      return;
    }
    if (action === "horizontal") {
      this.revise({ horizontal: !revision.horizontal });
      return;
    }
    if (action === "vertical") {
      this.revise({ vertical: !revision.vertical });
      return;
    }
    if (action === "anchor") {
      this.revise({ anchoredToOrigin: !revision.anchoredToOrigin });
      return;
    }
    if (action === "dimension") {
      const dimensions = this.numericInputs();
      try {
        this.revise({
          ...dimensions,
          widthDimensioned: true,
          heightDimensioned: true,
        });
        this.callbacks.onStatus("Width and height dimensions applied.", "success");
      } catch (error) {
        this.callbacks.onStatus(
          error instanceof Error ? error.message : String(error),
          "error",
        );
      }
    }
  }

  private handleInput(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!this.active || (input.id !== "sketch-width" && input.id !== "sketch-height")) {
      return;
    }
    const values = this.numericInputs();
    if (values.widthMillimeters <= 0 || values.heightMillimeters <= 0) return;
    const revision = this.currentState().revision;
    this.revise({
      ...values,
      widthDimensioned: revision.widthDimensioned,
      heightDimensioned: revision.heightDimensioned,
    });
  }

  private handlePointerDown(event: PointerEvent): void {
    if (!(event.target as Element).closest("[data-sketch-corner]")) return;
    this.draggingCorner = true;
    event.preventDefault();
  }

  private handlePointerMove(event: PointerEvent): void {
    if (!this.draggingCorner || !this.active) return;
    const bounds = this.root.getBoundingClientRect();
    const centerX = bounds.left + bounds.width / 2;
    const centerY = bounds.top + bounds.height / 2;
    const revision = this.currentState().revision;
    const scale = Math.max(
      1.5,
      Math.min(
        bounds.width * 0.46 / revision.widthMillimeters,
        bounds.height * 0.46 / revision.heightMillimeters,
      ),
    );
    const widthMillimeters = Math.max(1, Math.abs(event.clientX - centerX) * 2 / scale);
    const heightMillimeters = Math.max(1, Math.abs(event.clientY - centerY) * 2 / scale);
    this.revise({
      widthMillimeters: Math.round(widthMillimeters * 10) / 10,
      heightMillimeters: Math.round(heightMillimeters * 10) / 10,
      widthDimensioned: false,
      heightDimensioned: false,
    });
  }

  private handleKeyDown(event: KeyboardEvent): void {
    if (!this.active || (event.target as HTMLElement).matches("input")) return;
    const key = event.key.toLowerCase();
    const actionByKey: Record<string, string> = {
      q: "construction",
      h: "horizontal",
      v: "vertical",
      i: "anchor",
      d: "dimension",
    };
    if (key === "escape") {
      this.close();
      this.callbacks.onCancel();
      return;
    }
    const action = actionByKey[key];
    if (!action) return;
    event.preventDefault();
    this.root
      .querySelector<HTMLElement>(`[data-sketch-action="${action}"]`)
      ?.click();
  }
}
