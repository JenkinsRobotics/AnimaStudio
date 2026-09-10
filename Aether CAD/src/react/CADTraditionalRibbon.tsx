import { useState, useSyncExternalStore } from "react";
import { MenuButton, Ribbon, RibbonGroup, RibbonTool, Tabs, ToolIcon } from "@aether/ui";
import { cadAssemblyWorkspace } from "../cad-assembly-workspace-store";
import { cadCommands, isCADCommandID } from "../cad-command-registry";
import {
  cadRibbonWorkspace,
  cadRibbonWorkspaces,
  type CADRibbonWorkspaceID,
  type CADToolActionID,
  type CADToolDefinition,
} from "../cad-tool-catalog";

export interface CADTraditionalRibbonProps {
  suite?: boolean;
  activeWorkspace: CADRibbonWorkspaceID;
  documentName: string;
  partOpen: boolean;
  onSelectWorkspace: (workspace: CADRibbonWorkspaceID) => void;
  onAction: (action: CADToolActionID) => void;
  onUseFloatingTools: () => void;
}

export function CADTraditionalRibbon({
  suite = false,
  activeWorkspace,
  documentName,
  partOpen,
  onSelectWorkspace,
  onAction,
  onUseFloatingTools,
}: CADTraditionalRibbonProps) {
  const commands = useSyncExternalStore(cadCommands.subscribe, cadCommands.snapshot, cadCommands.snapshot);
  const assembly = useSyncExternalStore(
    cadAssemblyWorkspace.subscribe,
    cadAssemblyWorkspace.snapshot,
    cadAssemblyWorkspace.snapshot,
  );
  const [variants,setVariants]=useState<Record<string,string>>({});
  const workspace = cadRibbonWorkspace(activeWorkspace);

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

  return (
    <section className={`cad-traditional-ribbon${suite ? " cad-suite-ribbon" : ""}`} aria-label="Traditional CAD tools">
      {suite && <div className="cad-suite-workspace"><MenuButton label="Design" items={[
        {id: "design", label: "Design", kind: "radio", checked: true},
        {id: "animate", label: "Animate — Aether Animation", disabled: true},
        {id: "show", label: "Show — Aether Animation", disabled: true},
        {id: "hardware", label: "Hardware — Aether Animation", disabled: true},
      ]} onSelect={() => {}}>Design ▾</MenuButton></div>}
      <header className="cad-ribbon-navigation">
        <Tabs
          tabs={cadRibbonWorkspaces.map(({ id, label }) => ({ id, label }))}
          activeID={activeWorkspace}
          onSelect={(id) => onSelectWorkspace(id as CADRibbonWorkspaceID)}
        />
        {!suite && <button className="cad-toolbar-mode-command" type="button" onClick={onUseFloatingTools}>Floating tools</button>}
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
      <footer className="cad-document-strip" aria-label="Open documents">
        <button type="button" onClick={() => onAction("show-home")}>Start</button>
        <button type="button" className="active" aria-current="page"><span aria-hidden>◇</span>{documentName}</button>
        <span>{workspace.label} workspace</span>
      </footer>
    </section>
  );
}
