import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import {
  AetherIcon,
  Button,
  SettingsCard,
  SettingsRow,
  SettingsWindow,
  type CommandPaletteCommand,
  type SettingsSection,
} from "@aether/ui";
import { cadCommands, isCADCommandID } from "../cad-command-registry";
import { cadAppearance } from "../cad-appearance-store";
import type {
  CADBackgroundPreset,
  CADDisplayStyle,
  CADFloorMode,
  CADLightingPreset,
  CADMaterialFinish,
} from "../cad-appearance-store";
import { cadPresentation, type CADToolbarMode } from "../cad-presentation-store";
import { documentUnits, subscribeDocumentUnits } from "../document-preferences";
import { unitChoice } from "@aether/core/units";

const SECTIONS: SettingsSection[] = [
  {
    title: "General",
    panes: [
      { id: "workspace", label: "Workspace", icon: <AetherIcon name="folder" /> },
      { id: "layout", label: "Layout", icon: <AetherIcon name="layout" /> },
      { id: "ui", label: "UI", icon: <AetherIcon name="sidebar" /> },
    ],
  },
  {
    title: "Viewport",
    panes: [
      { id: "renderer", label: "Renderer", icon: <AetherIcon name="cube" /> },
      { id: "appearance", label: "Appearance", icon: <AetherIcon name="palette" /> },
      { id: "materials", label: "Materials & Edges", icon: <AetherIcon name="layers" /> },
      { id: "lighting", label: "Lighting", icon: <AetherIcon name="lighting" /> },
      { id: "navigation", label: "Navigation", icon: <AetherIcon name="mouse" /> },
    ],
  },
  {
    title: "Reference",
    panes: [
      { id: "commands", label: "Commands", icon: <AetherIcon name="commands" /> },
      { id: "help", label: "Help", icon: <AetherIcon name="help" /> },
    ],
  },
  {
    title: "Advanced",
    panes: [{ id: "developer", label: "Developer", icon: <AetherIcon name="hammer" /> }],
  },
];

const select = (
  value: string,
  options: readonly { value: string; label: string }[],
  onChange?: (value: string) => void,
  props: { ariaLabel: string; disabled?: boolean } = { ariaLabel: "setting" },
) => (
  <select
    aria-label={props.ariaLabel}
    value={value}
    disabled={props.disabled}
    onChange={(event) => onChange?.(event.target.value)}
  >
    {options.map((option) => (
      <option key={option.value} value={option.value}>
        {option.label}
      </option>
    ))}
  </select>
);

/** Aether CAD's per-app settings, faithful to the Anima Studio Settings
 *  window. Rows without a working implementation render disabled. */
export function CADSettingsWindow({
  open,
  onClose,
  chromeTheme,
  onChromeTheme,
  initialPane = "workspace",
  paletteCommands,
  onOpenCommandPalette,
}: {
  open: boolean;
  onClose: () => void;
  chromeTheme: "suite" | "classic";
  onChromeTheme: (theme: "suite" | "classic") => void;
  initialPane?: string;
  paletteCommands: readonly CommandPaletteCommand[];
  onOpenCommandPalette: () => void;
}) {
  const [pane, setPane] = useState(initialPane);
  const [commandQuery, setCommandQuery] = useState("");
  useEffect(() => {
    if (open) setPane(initialPane);
  }, [open, initialPane]);
  const commandGroups = useMemo(() => {
    const query = commandQuery.trim().toLowerCase();
    const matches = paletteCommands.filter(
      (command) =>
        !query ||
        command.label.toLowerCase().includes(query) ||
        (command.keywords ?? []).some((keyword) => keyword.includes(query)),
    );
    const groups = new Map<string, CommandPaletteCommand[]>();
    for (const command of matches) {
      const category = command.category ?? "Other";
      const list = groups.get(category) ?? [];
      list.push(command);
      groups.set(category, list);
    }
    return [...groups.entries()];
  }, [paletteCommands, commandQuery]);
  const appearance = useSyncExternalStore(
    cadAppearance.subscribe,
    cadAppearance.snapshot,
    cadAppearance.snapshot,
  );
  const presentation = useSyncExternalStore(
    cadPresentation.subscribe,
    cadPresentation.snapshot,
    cadPresentation.snapshot,
  );
  const units = useSyncExternalStore(subscribeDocumentUnits, documentUnits, documentUnits);
  const lengthUnit = unitChoice(units, "length").unit;
  return (
    <SettingsWindow
      open={open}
      title="Aether CAD Settings"
      sections={SECTIONS}
      activePaneID={pane}
      onSelectPane={setPane}
      onClose={onClose}
    >
      {pane === "workspace" ? (
        <>
          <SettingsCard
            title="Project Workspace"
            caption="Choose where new Aether CAD documents are stored by default."
          >
            <SettingsRow
              label="Default project location"
              disabled
              caption="Hosted documents live in the Aether Studio library; a local folder default arrives with workspace packaging."
            >
              <input aria-label="Default project location" value="Aether Studio library" disabled readOnly />
              <Button disabled>Change…</Button>
            </SettingsRow>
          </SettingsCard>
          <SettingsCard
            title="Authoring Defaults"
            caption="Defaults for newly imported assets and new documents."
          >
            <SettingsRow
              label="Document length units"
              caption={`Current Part: ${lengthUnit}. Change per document in Document controls → Workspace units.`}
              disabled
            >
              {select(lengthUnit, [{ value: lengthUnit, label: lengthUnit }], undefined, {
                ariaLabel: "Document length units",
                disabled: true,
              })}
            </SettingsRow>
            <SettingsRow
              label="Unitless model units"
              disabled
              caption="STL and OBJ are unitless. The import review sheet still lets the operator override this choice per file."
            >
              {select("mm", [
                { value: "mm", label: "Millimeters (mm)" },
                { value: "cm", label: "Centimeters (cm)" },
                { value: "in", label: "Inches (in)" },
                { value: "m", label: "Meters (m)" },
              ], undefined, { ariaLabel: "Unitless model units", disabled: true })}
            </SettingsRow>
            <SettingsRow label="Display precision" disabled caption="Fixed presentation precision for the current Part contract.">
              <output>0.01 mm</output>
            </SettingsRow>
            <SettingsRow label="Autosave after import" disabled>
              <input type="checkbox" className="aui-switch" aria-label="Autosave after import" disabled />
            </SettingsRow>
            <SettingsRow
              label="Default frame rate"
              disabled
              caption="Animation clip default — an Aether Animation setting."
            >
              <input type="range" aria-label="Default frame rate" min={12} max={60} defaultValue={30} disabled />
              <output>30 fps</output>
            </SettingsRow>
          </SettingsCard>
          <SettingsCard
            tone="notice"
            title="Plain project folders"
            caption="Each project remains a browsable folder containing project.json, characters, scenes, editor metadata, and portable assets."
          />
        </>
      ) : pane === "layout" ? (
        <>
          <SettingsCard icon={<AetherIcon name="layout" />} title="Tool presentation">
            <SettingsRow label="Toolbars">
              {select(
                presentation.toolbarMode,
                [
                  { value: "traditional", label: "Traditional ribbon" },
                  { value: "floating", label: "Floating tools" },
                ],
                (mode) =>
                  cadPresentation.dispatch({
                    type: "select-toolbar-mode",
                    mode: mode as CADToolbarMode,
                  }),
                { ariaLabel: "Toolbars" },
              )}
            </SettingsRow>
            <SettingsRow label="Window chrome">
              {select(
                chromeTheme,
                [
                  { value: "suite", label: "Full suite layout" },
                  { value: "classic", label: "Classic layout" },
                ],
                (theme) => onChromeTheme(theme as "suite" | "classic"),
                { ariaLabel: "Window chrome" },
              )}
            </SettingsRow>
            <SettingsRow label="Panels">
              <Button onClick={() => cadPresentation.dispatch({ type: "reset-panel-placements" })}>
                Reset panel placements
              </Button>
            </SettingsRow>
          </SettingsCard>
        </>
      ) : pane === "ui" ? (
        <>
          <SettingsCard icon={<AetherIcon name="sidebar" />} title="Appearance">
            <SettingsRow label="Theme" disabled caption="Light theme requires the adaptive renderer palette.">
              {select("dark", [
                { value: "dark", label: "Aether Dark" },
                { value: "light", label: "Light — unavailable" },
              ], undefined, { ariaLabel: "Theme", disabled: true })}
            </SettingsRow>
            <SettingsRow
              label="Follow reduced-motion preference"
              disabled
              caption="Animations use the operating-system accessibility setting."
            >
              <input type="checkbox" className="aui-switch" aria-label="Follow reduced-motion preference" checked disabled readOnly />
            </SettingsRow>
            <SettingsRow label="High-contrast override" disabled caption="System contrast remains respected by shared controls.">
              <input type="checkbox" className="aui-switch" aria-label="High-contrast override" disabled />
            </SettingsRow>
          </SettingsCard>
          <SettingsCard icon={<AetherIcon name="design" />} title="Design profile" caption="The shared profile updates panels, ribbons, fields, and semantic chrome together.">
            <SettingsRow label="Design preset" disabled>
              {select("standard", [
                { value: "standard", label: "Standard" },
                { value: "compact", label: "Compact" },
                { value: "high-contrast", label: "High Contrast" },
              ], undefined, { ariaLabel: "Design preset", disabled: true })}
            </SettingsRow>
            <SettingsRow label="Accent color" disabled>
              <input type="color" aria-label="Accent color" value="#4c9dff" disabled readOnly />
            </SettingsRow>
            <SettingsRow label="Tool density" disabled>
              {select("standard", [
                { value: "compact", label: "Compact" },
                { value: "standard", label: "Standard" },
                { value: "expanded", label: "Expanded" },
              ], undefined, { ariaLabel: "Tool density", disabled: true })}
            </SettingsRow>
            <SettingsRow label="Show workspace status bar" disabled>
              <input type="checkbox" className="aui-switch" aria-label="Show workspace status bar" checked disabled readOnly />
            </SettingsRow>
          </SettingsCard>
        </>
      ) : pane === "renderer" ? (
        <>
          <SettingsCard icon={<AetherIcon name="cube" />} title="Render backend">
            <SettingsRow label="Render engine" disabled caption="Open CASCADE geometry with the Three.js renderer; alternate backends are not selectable on the web.">
              {select("threejs", [{ value: "threejs", label: "Open CASCADE → Three.js WebGPU" }], undefined, {
                ariaLabel: "Render engine",
                disabled: true,
              })}
            </SettingsRow>
            <SettingsRow label="Active backend">
              <output>{"gpu" in navigator ? "Three.js WebGPU" : "Three.js WebGL 2"}</output>
            </SettingsRow>
            <SettingsRow label="Geometry kernel">
              <output>Open CASCADE (Replicad WASM)</output>
            </SettingsRow>
            <SettingsRow label="Engine frame status overlay" disabled caption="Not implemented in the web renderer yet.">
              <input type="checkbox" className="aui-switch" aria-label="Engine frame status overlay" disabled />
            </SettingsRow>
            <SettingsRow label="CAD metrics overlay" disabled caption="Not implemented in the web renderer yet.">
              <input type="checkbox" className="aui-switch" aria-label="CAD metrics overlay" disabled />
            </SettingsRow>
          </SettingsCard>
        </>
      ) : pane === "appearance" ? (
        <>
          <SettingsCard icon={<AetherIcon name="palette" />} title="Viewport appearance">
            <SettingsRow label="Display style">
              {select(
                appearance.displayStyle,
                [
                  { value: "shaded", label: "Shaded" },
                  { value: "shaded-edges", label: "Shaded with edges" },
                  { value: "wireframe", label: "Wireframe" },
                  { value: "hidden-line", label: "Hidden line" },
                  { value: "ghost", label: "Ghost" },
                ],
                (style) =>
                  cadAppearance.dispatch({ type: "set-display-style", style: style as CADDisplayStyle }),
                { ariaLabel: "Display style" },
              )}
            </SettingsRow>
            <SettingsRow label="Background">
              {select(
                appearance.background,
                [
                  { value: "graphite", label: "Graphite" },
                  { value: "midnight", label: "Midnight" },
                  { value: "slate", label: "Slate" },
                ],
                (background) =>
                  cadAppearance.dispatch({
                    type: "set-background",
                    background: background as CADBackgroundPreset,
                  }),
                { ariaLabel: "Background" },
              )}
            </SettingsRow>
            <SettingsRow label="Ground">
              {select(
                appearance.floorMode,
                [
                  { value: "none", label: "None" },
                  { value: "grid", label: "Grid" },
                  { value: "floor", label: "Floor" },
                  { value: "both", label: "Grid and floor" },
                ],
                (mode) => cadAppearance.dispatch({ type: "set-floor-mode", mode: mode as CADFloorMode }),
                { ariaLabel: "Ground" },
              )}
            </SettingsRow>
            <SettingsRow label="Contact shadows">
              <input
                type="checkbox"
                aria-label="Contact shadows"
                checked={appearance.contactShadowsVisible}
                onChange={(event) =>
                  cadAppearance.dispatch({
                    type: "set-contact-shadows-visible",
                    visible: event.target.checked,
                  })
                }
              />
            </SettingsRow>
            <SettingsRow label="Reset">
              <Button onClick={() => cadAppearance.dispatch({ type: "reset" })}>Reset appearance</Button>
            </SettingsRow>
          </SettingsCard>
          <SettingsCard icon={<AetherIcon name="design" />} title="Coordinated themes" caption="Whole-viewport theme presets arrive with the shared CAD theme runtime.">
            <SettingsRow label="Coordinated CAD theme" disabled>
              {select("onshape", [
                { value: "onshape", label: "Onshape" },
                { value: "studio-blue", label: "Studio Blue" },
                { value: "blueprint", label: "Blueprint" },
                { value: "midnight-glow", label: "Midnight Glow" },
              ], undefined, { ariaLabel: "Coordinated CAD theme", disabled: true })}
            </SettingsRow>
            <SettingsRow label="Reflections" disabled>
              {select("subtle", [
                { value: "off", label: "Reflections Off" },
                { value: "subtle", label: "Subtle Reflections" },
                { value: "studio", label: "Studio Reflections" },
              ], undefined, { ariaLabel: "Reflections", disabled: true })}
            </SettingsRow>
            <SettingsRow label="Environment rotation" disabled>
              <input type="range" aria-label="Environment rotation" min={0} max={360} defaultValue={0} disabled />
              <output>0°</output>
            </SettingsRow>
          </SettingsCard>
        </>
      ) : pane === "materials" ? (
        <>
          <SettingsCard icon={<AetherIcon name="layers" />} title="Materials & Edges">
            <SettingsRow label="Material finish">
              {select(
                appearance.materialFinish,
                [
                  { value: "matte", label: "Matte" },
                  { value: "satin", label: "Satin" },
                  { value: "gloss", label: "Gloss" },
                ],
                (finish) =>
                  cadAppearance.dispatch({
                    type: "set-material-finish",
                    finish: finish as CADMaterialFinish,
                  }),
                { ariaLabel: "Material finish" },
              )}
            </SettingsRow>
            <SettingsRow label="Feature edges">
              <input
                type="checkbox"
                aria-label="Feature edges"
                checked={appearance.edgesVisible}
                onChange={(event) =>
                  cadAppearance.dispatch({ type: "set-edges-visible", visible: event.target.checked })
                }
              />
            </SettingsRow>
            <SettingsRow label="Preserve STEP / XDE colors" disabled caption="Imported color policy is not configurable yet.">
              <input type="checkbox" className="aui-switch" aria-label="Preserve STEP / XDE colors" checked disabled readOnly />
            </SettingsRow>
            <SettingsRow label="Surface roughness" disabled caption="Renderer-neutral material values arrive with the shared theme runtime.">
              <input type="range" aria-label="Surface roughness" min={0} max={100} defaultValue={46} disabled />
            </SettingsRow>
            <SettingsRow label="Surface metallic" disabled>
              <input type="range" aria-label="Surface metallic" min={0} max={100} defaultValue={2} disabled />
            </SettingsRow>
            <SettingsRow label="Edge definition" disabled>
              <input type="range" aria-label="Edge definition" min={0} max={100} defaultValue={82} disabled />
            </SettingsRow>
          </SettingsCard>
        </>
      ) : pane === "lighting" ? (
        <>
          <SettingsCard icon={<AetherIcon name="lighting" />} title="Lighting">
            <SettingsRow label="Preset">
              {select(
                appearance.lightingPreset,
                [
                  { value: "studio", label: "Studio" },
                  { value: "softbox", label: "Softbox" },
                  { value: "daylight", label: "Daylight" },
                  { value: "dark-room", label: "Dark room" },
                ],
                (preset) =>
                  cadAppearance.dispatch({
                    type: "set-lighting-preset",
                    preset: preset as CADLightingPreset,
                  }),
                { ariaLabel: "Lighting preset" },
              )}
            </SettingsRow>
            <SettingsRow label="Environment intensity">
              <input
                type="range"
                aria-label="Environment intensity"
                min={0}
                max={100}
                value={appearance.environmentPercent}
                onChange={(event) =>
                  cadAppearance.dispatch({
                    type: "set-environment-percent",
                    percent: Number(event.target.value),
                  })
                }
              />
              <output>{appearance.environmentPercent}%</output>
            </SettingsRow>
            <SettingsRow label="Cast viewport shadows" disabled caption="Shadow casting follows the lighting preset; a dedicated toggle is not implemented.">
              <input type="checkbox" className="aui-switch" aria-label="Cast viewport shadows" checked disabled readOnly />
            </SettingsRow>
            <SettingsRow label="Key light" disabled caption="Per-light rig control arrives with the shared theme runtime.">
              <input type="range" aria-label="Key light" min={0} max={100} defaultValue={40} disabled />
            </SettingsRow>
            <SettingsRow label="Fill light" disabled>
              <input type="range" aria-label="Fill light" min={0} max={100} defaultValue={16} disabled />
            </SettingsRow>
            <SettingsRow label="Rim light" disabled>
              <input type="range" aria-label="Rim light" min={0} max={100} defaultValue={8} disabled />
            </SettingsRow>
          </SettingsCard>
        </>
      ) : pane === "commands" ? (
        <>
          <SettingsCard icon={<AetherIcon name="commands" />} title="Command palette" caption="Every command is searchable from the keyboard.">
            <SettingsRow label="Open command palette">
              <output>⌘K</output>
              <Button
                onClick={() => {
                  onClose();
                  onOpenCommandPalette();
                }}
              >
                Open
              </Button>
            </SettingsRow>
          </SettingsCard>
          <SettingsCard icon={<AetherIcon name="commands" />} title="All commands">
            <SettingsRow label="Filter">
              <input
                aria-label="Filter commands"
                value={commandQuery}
                placeholder="Search commands"
                onChange={(event) => setCommandQuery(event.target.value)}
              />
            </SettingsRow>
            {commandGroups.map(([category, list]) => (
              <div key={category} className="cad-settings-command-group">
                <strong className="aui-settings-card-caption">{category}</strong>
                {list.map((command) => (
                  <SettingsRow key={command.id} label={command.label} disabled={command.disabled} caption={command.disabledReason}>
                    {command.shortcut ? <output>{command.shortcut}</output> : null}
                    <Button
                      disabled={command.disabled}
                      onClick={() => {
                        if (isCADCommandID(command.id)) cadCommands.execute(command.id);
                        onClose();
                      }}
                    >
                      Run
                    </Button>
                  </SettingsRow>
                ))}
              </div>
            ))}
          </SettingsCard>
        </>
      ) : pane === "help" ? (
        <>
          <SettingsCard icon={<AetherIcon name="document" />} title="Part workflow">
            <ol className="cad-settings-steps">
              <li>Start New Part and choose a principal plane.</li>
              <li>Sketch profiles and apply dimensions and constraints.</li>
              <li>Finish Sketch, then Extrude or Revolve to rebuild the exact OCCT Body.</li>
            </ol>
          </SettingsCard>
          <SettingsCard icon={<AetherIcon name="assembly" />} title="Assembly workflow">
            <ol className="cad-settings-steps">
              <li>Import STEP Parts or create a Part.</li>
              <li>Place exact mate connectors on inferred topology.</li>
              <li>Choose Fastened and pick moving then target connectors.</li>
            </ol>
          </SettingsCard>
          <SettingsCard icon={<AetherIcon name="window" />} title="Keyboard and viewport">
            <SettingsRow label="Zoom to fit"><output>F</output></SettingsRow>
            <SettingsRow label="Open Sketch"><output>R</output></SettingsRow>
            <SettingsRow label="Cancel the active tool or plane choice"><output>Esc</output></SettingsRow>
            <SettingsRow label="Command palette"><output>⌘K</output></SettingsRow>
            <SettingsRow label="Orbit"><output>RMB</output></SettingsRow>
            <SettingsRow label="Pan"><output>MMB</output></SettingsRow>
            <SettingsRow label="Zoom"><output>Wheel</output></SettingsRow>
          </SettingsCard>
          <SettingsCard
            tone="notice"
            title="Where to look"
            caption="Problems reports definition warnings. Properties shows canonical Part values and exact topology statistics."
          />
        </>
      ) : pane === "navigation" ? (
        <>
          <SettingsCard icon={<AetherIcon name="mouse" />} title="Navigation Profile" caption="Viewport-only preferences · saved in this browser.">
            <SettingsRow label="Navigation profile" disabled caption="Profiles and custom button maps arrive with input mapping.">
              {select("default", [
                { value: "default", label: "Default (RMB orbit · MMB pan)" },
                { value: "solidworks", label: "SolidWorks" },
                { value: "onshape", label: "Onshape" },
                { value: "fusion", label: "Fusion 360" },
                { value: "custom", label: "Custom" },
              ], undefined, { ariaLabel: "Navigation profile", disabled: true })}
            </SettingsRow>
          </SettingsCard>
          <SettingsCard
            icon={<AetherIcon name="history" />}
            title="Motion Response"
            caption="Tune each camera movement independently without changing its button mapping."
          >
            <SettingsRow label="Orbit speed" value="Standard" stacked disabled>
              <input type="range" aria-label="Orbit speed" min={0} max={4} defaultValue={2} disabled />
            </SettingsRow>
            <SettingsRow label="Pan speed" value="Standard" stacked disabled>
              <input type="range" aria-label="Pan speed" min={0} max={4} defaultValue={2} disabled />
            </SettingsRow>
            <SettingsRow label="Zoom speed" value="Reduced" stacked disabled>
              <input type="range" aria-label="Zoom speed" min={0} max={4} defaultValue={1} disabled />
            </SettingsRow>
            <SettingsRow label="Reverse wheel zoom direction" disabled>
              <input type="checkbox" className="aui-switch" aria-label="Reverse wheel zoom direction" disabled />
            </SettingsRow>
          </SettingsCard>
          <SettingsCard icon={<AetherIcon name="window" />} title="Keyboard" caption="Viewport shortcuts.">
            <SettingsRow label="Fit shortcut">
              <output>F</output>
            </SettingsRow>
            <SettingsRow label="Sketch shortcut">
              <output>R</output>
            </SettingsRow>
            <SettingsRow label="Cancel">
              <output>Esc</output>
            </SettingsRow>
          </SettingsCard>
        </>
      ) : (
        <>
          <SettingsCard icon={<AetherIcon name="hammer" />} title="Developer">
            <SettingsRow label="Engine frame diagnostics" disabled caption="Not implemented.">
              <input type="checkbox" className="aui-switch" aria-label="Engine frame diagnostics" disabled />
            </SettingsRow>
            <SettingsRow label="Exact topology statistics overlay" disabled caption="Shown today in the Properties panel instead.">
              <input type="checkbox" className="aui-switch" aria-label="Exact topology statistics overlay" disabled />
            </SettingsRow>
          </SettingsCard>
        </>
      )}
    </SettingsWindow>
  );
}
