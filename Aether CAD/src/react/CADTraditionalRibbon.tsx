import { useState, useSyncExternalStore } from "react";
import { MenuButton, Ribbon, RibbonGroup, RibbonTool, Tabs, ToolIcon } from "@aether/ui";
import { cadAssemblyWorkspace } from "../cad-assembly-workspace-store";
import { cadCommands, isCADCommandID } from "../cad-command-registry";
import {
  type CADRibbonWorkspaceID,
  type CADToolActionID,
  type CADToolDefinition,
} from "../cad-tool-catalog";
import {
  fusionTabsFor,
  sketchContextTab,
  toolbarTabsFor,
  toolbarToolById,
  toolbarWorkspaceFor,
  type CADDocumentType,
  type CADToolbarTab,
} from "../cad-toolbar-layouts";
import { useEffect } from "react";

const DESIGN_MODES = [
  { id: "design", label: "Design", kind: "radio" as const, checked: true },
  { id: "generative", label: "Generative Design", disabled: true, disabledReason: "Planned — generative studies are not implemented yet." },
  { id: "render", label: "Render", disabled: true, disabledReason: "Planned — the render workspace is not implemented yet." },
  { id: "animation", label: "Animation", disabled: true, disabledReason: "Opens in Aether Animation until suite routing is connected." },
  { id: "simulation", label: "Simulation", disabled: true, disabledReason: "Planned — simulation arrives with Aether Dynamics." },
  { id: "manufacture", label: "Manufacture", disabled: true, disabledReason: "Planned — CAM is not implemented yet." },
  { id: "drawing", label: "Drawing", disabled: true, disabledReason: "Open drawings from Utilities → Drawing until the workspace switcher lands." },
  { id: "electronics", label: "Electronics", disabled: true, disabledReason: "Planned — electronics is not implemented yet." },
];

export interface CADTraditionalRibbonProps {
  suite?: boolean;
  /** Open document type; layouts refine the shared catalog per type. */
  documentType?: CADDocumentType;
  /** True while a sketch is being edited — shows the contextual Sketch tab. */
  sketchEditing?: boolean;
  /** Kept for callers; the document strip moved out of the ribbon. */
  documentName?: string;
  activeWorkspace: CADRibbonWorkspaceID;
  partOpen: boolean;
  onSelectWorkspace: (workspace: CADRibbonWorkspaceID) => void;
  onAction: (action: CADToolActionID) => void;
}

export function CADTraditionalRibbon({
  suite = false,
  documentType = "project",
  sketchEditing = false,
  activeWorkspace,
  partOpen,
  onSelectWorkspace,
  onAction,
}: CADTraditionalRibbonProps) {
  const commands = useSyncExternalStore(cadCommands.subscribe, cadCommands.snapshot, cadCommands.snapshot);
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const [variants,setVariants]=useState<Record<string,string>>({});
  const [density, setDensity] = useState<"standard" | "compact">(() => {
    try { return localStorage.getItem("aether-cad.ribbon-density") === "compact" ? "compact" : "standard"; } catch { return "standard"; }
  });
  const chooseDensity = (next: "standard" | "compact") => {
    setDensity(next);
    try { localStorage.setItem("aether-cad.ribbon-density", next); } catch { /* session-only */ }
  };
  const [densityMenu, setDensityMenu] = useState<{ x: number; y: number } | null>(null);
  const densityMenuElement = densityMenu ? (
    <div className="cad-ribbon-density-menu" role="menu" aria-label="Tool bar density" style={{ left: densityMenu.x, top: densityMenu.y }}
      onPointerLeave={() => setDensityMenu(null)}>
      <strong>Density</strong>
      {([
        ["compact", "Compact", "Icons only"],
        ["standard", "Standard", "Icons and labels"],
      ] as const).map(([id, label, caption]) => (
        <button key={id} type="button" role="menuitemradio" aria-checked={density === id}
          onClick={() => { chooseDensity(id); setDensityMenu(null); }}>
          <span><b>{label}</b><small>{caption}</small></span>
          {density === id ? <em>✓</em> : null}
        </button>
      ))}
    </div>
  ) : null;
  const openDensityMenu = (event: React.MouseEvent) => {
    event.preventDefault();
    setDensityMenu({ x: event.clientX, y: event.clientY });
  };
  const workspace = toolbarWorkspaceFor(documentType, activeWorkspace);
  const fusionTabs = fusionTabsFor(documentType);
  const [fusionTab, setFusionTab] = useState<string>(() => (sketchEditing ? "sketch-context" : (fusionTabs?.[0]?.id ?? "solid")));
  useEffect(() => {
    if (sketchEditing) setFusionTab("sketch-context");
    else setFusionTab((current) => (current === "sketch-context" ? (fusionTabs?.[0]?.id ?? "solid") : current));
  }, [sketchEditing, fusionTabs]);

  const availability = (definition: CADToolDefinition): { disabled: boolean; reason?: string } => {
    if (!definition.action) return { disabled: true, reason: definition.unavailableReason };
    if (isCADCommandID(definition.action)) {
      const state = commands[definition.action];
      if (!state.registered) return { disabled: true, reason: "Command is not connected to the current CAD session." };
      if (!state.enabled) return { disabled: true, reason: "Command requires an applicable selection or open document." };
      return { disabled: false };
    }
    if (definition.action === "save-assembly" && assembly.loadState !== "ready") {
      return { disabled: true, reason: "Create or open a persistent Assembly before saving it." };
    }
    if (definition.action === "show-export" && !partOpen) {
      return { disabled: true, reason: "Create or open a Part before opening model export." };
    }
    return { disabled: false };
  };

  if (fusionTabs) {
    const tabs: CADToolbarTab[] = sketchEditing ? [...fusionTabs, sketchContextTab()] : [...fusionTabs];
    const active = tabs.find((tab) => tab.id === fusionTab) ?? tabs[0];
    const renderTool = (id: string, large: boolean) => {
      const definition = toolbarToolById(id);
      if (!definition) return null;
      const state = availability(definition);
      return (
        <span
          key={definition.id}
          className="cad-ribbon-tool-wrap"
          title={state.disabled ? state.reason : definition.label}
          data-tool-id={definition.id}
          data-disabled-reason={state.disabled ? state.reason : undefined}
        >
          <RibbonTool
            data-command={definition.action && isCADCommandID(definition.action) ? definition.action : undefined}
            icon={<ToolIcon name={definition.icon} />}
            label={large ? definition.label : definition.label}
            active={Boolean(definition.action && isCADCommandID(definition.action) && commands[definition.action].active)}
            disabled={state.disabled}
            onClick={() => definition.action && onAction(definition.action)}
          />
        </span>
      );
    };
    return (
      <section className={`cad-traditional-ribbon cad-fusion-ribbon density-${density}${suite ? " cad-suite-ribbon" : ""}`} aria-label="Part tools" onContextMenu={openDensityMenu}>
        {densityMenuElement}
        <div className="cad-suite-workspace"><MenuButton label="Design" items={DESIGN_MODES} onSelect={() => {}}>Design ▾</MenuButton></div>
        <header className="cad-ribbon-navigation">
          <Tabs
            tabs={tabs.map(({ id, label }) => ({ id, label }))}
            activeID={active.id}
            onSelect={setFusionTab}
          />
        </header>
        <div className="cad-ribbon-scroll" data-ribbon-workspace={active.id}>
          <Ribbon>
            {active.sections.map((sectionDefinition) => (
              <div key={sectionDefinition.id} className="cad-fusion-section" data-section-id={sectionDefinition.id}>
                <div className="cad-fusion-section-tools">
                  {sectionDefinition.visible.map((id) => renderTool(id, true))}
                </div>
                <MenuButton
                  label={`${sectionDefinition.label} tools`}
                  placement="bottom-start"
                  items={sectionDefinition.menu
                    .map((id) => toolbarToolById(id))
                    .filter((definition): definition is NonNullable<typeof definition> => Boolean(definition))
                    .map((definition) => ({
                      id: definition.id,
                      label: definition.label,
                      icon: <ToolIcon name={definition.icon} />,
                      disabled: availability(definition).disabled,
                    }))}
                  onSelect={(id) => {
                    const definition = toolbarToolById(id);
                    if (definition?.action) onAction(definition.action);
                  }}
                >
                  {sectionDefinition.label} ▾
                </MenuButton>
              </div>
            ))}
          </Ribbon>
        </div>
      </section>
    );
  }
  return (
    <section className={`cad-traditional-ribbon density-${density}${suite ? " cad-suite-ribbon" : ""}`} aria-label="Traditional CAD tools" onContextMenu={openDensityMenu}>
      {densityMenuElement}
      <div className="cad-suite-workspace"><MenuButton label="Design" items={DESIGN_MODES} onSelect={() => {}}>Design ▾</MenuButton></div>
      <header className="cad-ribbon-navigation">
        <Tabs
          tabs={toolbarTabsFor(documentType).map(({ id, label }) => ({ id, label }))}
          activeID={workspace.id}
          onSelect={(id) => onSelectWorkspace(id as CADRibbonWorkspaceID)}
        />
      </header>
      <div className="cad-ribbon-scroll" data-ribbon-workspace={workspace.id}>
        <Ribbon>
          {workspace.groups.map((group) => (
            <RibbonGroup key={group.id} label={group.label}>
              {group.tools.map((definition) => {
                const choices=[definition,...(definition.variants??[])];
                const selected=choices.find(choice=>choice.id===variants[definition.id])??definition;
                const state = availability(selected);
                return (
                  <span
                    key={definition.id}
                    className="cad-ribbon-tool-wrap"
                    title={state.disabled ? state.reason : selected.label}
                    data-tool-id={definition.id}
                    data-disabled-reason={state.disabled ? state.reason : undefined}
                  >
                    <RibbonTool
                      data-command={selected.action && isCADCommandID(selected.action) ? selected.action : undefined}
                      icon={<ToolIcon name={selected.icon} />}
                      label={selected.label}
                      active={Boolean(selected.action && isCADCommandID(selected.action) && commands[selected.action].active)}
                      disabled={state.disabled}
                      onClick={() => selected.action && onAction(selected.action)}
                    />
                    {definition.variants && <MenuButton label={`${definition.label} variants`} placement="bottom-start"
                      items={choices.map(choice=>({id:choice.id,label:choice.label,icon:<ToolIcon name={choice.icon}/>,disabled:availability(choice).disabled,kind:'radio' as const,checked:selected.id===choice.id}))}
                      onSelect={id=>{const choice=choices.find(c=>c.id===id);if(choice?.action){setVariants(current=>({...current,[definition.id]:id}));onAction(choice.action);}}}>▾</MenuButton>}
                  </span>
                );
              })}
          </RibbonGroup>
          ))}
        </Ribbon>
      </div>
    </section>
  );
}
