import { useSyncExternalStore } from "react";
import { Button, Checkbox, FieldRow, IconButton, SelectField, AetherIcon } from "@aether/ui";
import { cadAppearance } from "../cad-appearance-store";
import type { CADDisplayStyle } from "../cad-appearance-store";
import { cadCameraPresentation } from "../cad-camera-presentation-store";
import { cadCommands } from "../cad-command-registry";

/** Camera + display tool, imported from the Anima Studio right rail's "View"
 *  panel. Camera and reference-display controls live here — deliberately
 *  separate from the render environment (Appearance) panel. */
export function CADViewPanel({ active }: { active: boolean }) {
  const camera = useSyncExternalStore(
    cadCameraPresentation.subscribe,
    cadCameraPresentation.snapshot,
    cadCameraPresentation.snapshot,
  );
  const appearance = useSyncExternalStore(
    cadAppearance.subscribe,
    cadAppearance.snapshot,
    cadAppearance.snapshot,
  );
  const commands = useSyncExternalStore(cadCommands.subscribe, cadCommands.snapshot, cadCommands.snapshot);
  const gridVisible = appearance.floorMode === "grid" || appearance.floorMode === "both";
  return (
    <section className={`browser-panel${active ? " active" : ""}`} data-panel="view">
      <header className="browser-title">
        <div>
          <strong>View</strong>
          <small>Camera and display · saved on this device</small>
        </div>
      </header>
      <div className="visualization-panel-scroll">
        <section className="visualization-controls" aria-label="Camera">
          <div className="panel-heading"><span>CAMERA</span></div>
          <div className="visualization-fields">
            <FieldRow label="Projection">
              <SelectField
                aria-label="Camera projection"
                value="perspective"
                options={[
                  { value: "perspective", label: "Perspective" },
                  { value: "orthographic", label: "Orthographic — unavailable", disabled: true },
                ]}
                disabled
              />
            </FieldRow>
            <FieldRow label="Field of view">
              <SelectField
                aria-label="Camera field of view"
                value={String(camera.fieldOfViewDegrees)}
                options={[30, 42, 45, 60, 75, 90].map((degrees) => ({
                  value: String(degrees),
                  label: `${degrees}°`,
                }))}
                onChange={(event) =>
                  cadCameraPresentation.dispatch({
                    type: "set-field-of-view",
                    degrees: Number(event.target.value),
                  })
                }
              />
            </FieldRow>
            <FieldRow label="Views">
              <div className="cad-view-actions">
                <IconButton
                  label="Frame selection"
                  title="Zoom to fit (F)"
                  onClick={() => cadCommands.execute("fit-view")}
                >
                  <AetherIcon name="search" />
                </IconButton>
                <IconButton
                  label="Isometric view"
                  title="Isometric (Space opens the orientation box)"
                  onClick={() => cadCommands.execute("view-isometric")}
                >
                  <AetherIcon name="cube" />
                </IconButton>
                <Button disabled title="Named views require saved camera bookmarks.">
                  Named views
                </Button>
              </div>
            </FieldRow>
            <p className="cad-form-note">
              Space opens the orientation envelope; click a face, edge, or corner to look from
              that side.
            </p>
          </div>
        </section>
        <section className="visualization-controls" aria-label="Display">
          <div className="panel-heading"><span>DISPLAY</span></div>
          <div className="visualization-fields">
            <FieldRow label="Surface">
              <SelectField
                aria-label="Surface display style"
                value={appearance.displayStyle}
                options={[
                  { value: "shaded-edges", label: "Shaded with edges" },
                  { value: "shaded", label: "Shaded" },
                  { value: "wireframe", label: "Wireframe" },
                  { value: "hidden-line", label: "Hidden line" },
                  { value: "ghost", label: "Translucent" },
                ]}
                onChange={(event) =>
                  cadAppearance.dispatch({
                    type: "set-display-style",
                    style: event.target.value as CADDisplayStyle,
                  })
                }
              />
            </FieldRow>
            <Checkbox
              checked={appearance.edgesVisible}
              onChange={(event) =>
                cadAppearance.dispatch({ type: "set-edges-visible", visible: event.target.checked })
              }
              label="Edges"
              description="Show OCCT-derived edge segments on every Body."
            />
            <Checkbox
              checked={gridVisible}
              onChange={(event) =>
                cadAppearance.dispatch({
                  type: "set-floor-mode",
                  mode: event.target.checked ? "grid" : "none",
                })
              }
              label="Grid"
              description="World-space floor grid."
            />
            <Checkbox
              checked={commands["toggle-origin"].active}
              onChange={() => cadCommands.execute("toggle-origin")}
              label="Origin"
              description="Show the origin point in space."
            />
            <Checkbox
              disabled
              label="Axes"
              description="Axis display is not implemented yet; the origin stays a point."
            />
            <Checkbox
              disabled
              label="Section view"
              description="Clip-plane sectioning requires a renderer clip contract."
            />
            <Checkbox
              disabled
              label="High quality"
              description="Multisample quality selection is not exposed by the web renderer yet."
            />
          </div>
        </section>
      </div>
    </section>
  );
}
