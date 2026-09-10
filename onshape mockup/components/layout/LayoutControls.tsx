import { useState } from 'react';
import { LayoutDashboard, RotateCcw, X } from 'lucide-react';
import {
  layoutStore,
  panelIds,
  panelLabels,
  useLayoutStore,
  type PanelState,
} from './layout-store';
export function LayoutControls() {
  const { activePreset, panels } = useLayoutStore();
  const [open, setOpen] = useState(false);
  return (
    <div className="layout-controls">
      <div className="preset-switch" aria-label="Layout preset">
        <button
          aria-pressed={activePreset === 'onshape'}
          onClick={() => layoutStore.setPreset('onshape')}
        >
          Onshape
        </button>
        <button
          aria-pressed={activePreset === 'shapr3d'}
          onClick={() => layoutStore.setPreset('shapr3d')}
        >
          Shapr3D
        </button>
      </div>
      <button
        title="Layout settings"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <LayoutDashboard size={16} />
      </button>
      {open && (
        <section className="layout-settings" aria-label="Layout settings">
          <header>
            <strong>Workspace layout</strong>
            <button
              title="Close layout settings"
              onClick={() => setOpen(false)}
            >
              <X size={14} />
            </button>
          </header>
          <p>Each preset remembers its panel placement.</p>
          {panelIds.map((id) => (
            <div className="layout-setting-row" key={id}>
              <label htmlFor={`layout-${id}`}>{panelLabels[id]}</label>
              <select
                id={`layout-${id}`}
                value={
                  panels[id].mode === 'docked'
                    ? panels[id].dockPosition
                    : panels[id].mode
                }
                onChange={(e) => {
                  const v = e.target.value;
                  if (v === 'floating' || v === 'hidden')
                    layoutStore.setPanelMode(id, v);
                  else
                    layoutStore.dockPanel(
                      id,
                      v as NonNullable<PanelState['dockPosition']>,
                    );
                }}
              >
                <option value="left">Dock left</option>
                <option value="right">Dock right</option>
                <option value="top">Dock top</option>
                <option value="bottom">Dock bottom</option>
                <option value="floating">Float</option>
                <option value="hidden">Hide</option>
              </select>
            </div>
          ))}
          <button
            className="reset-layout"
            onClick={() => layoutStore.resetPreset()}
          >
            <RotateCcw size={13} /> Reset{' '}
            {activePreset === 'onshape' ? 'Onshape' : 'Shapr3D'} layout
          </button>
          <small>
            Drag a floating panel to an edge to dock it. Use arrow keys on its
            grip to move it.
          </small>
        </section>
      )}
    </div>
  );
}
