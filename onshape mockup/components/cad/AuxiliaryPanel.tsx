import { X, Ruler, Box, Palette } from 'lucide-react';
import { Button } from '@/components/ui/button';
export function AuxiliaryPanel({
  panel,
  onClose,
  color,
  onColor,
  opacity,
  onOpacity,
  selectedPart,
  width,
  onWidth,
}: {
  panel: string;
  onClose: () => void;
  color: string;
  onColor: (v: string) => void;
  opacity: number;
  onOpacity: (v: number) => void;
  selectedPart: number | null;
  width: number;
  onWidth: (v: number) => void;
}) {
  return (
    <aside className="aux-panel">
      <div className="panel-heading">
        <strong>{panel}</strong>
        <button title="Close panel" onClick={onClose}>
          <X size={15} />
        </button>
      </div>
      <div className="aux-content">
        {panel === 'Appearance' ? (
          <>
            <div className="panel-subheading">
              <Palette size={15} /> Part 1 · Aluminum 6061
            </div>
            <div className="field-label">Color</div>
            <div className="color-palette">
              {[
                '#a7b5c5',
                '#3f658b',
                '#d3d8dc',
                '#5a6572',
                '#c39458',
                '#467d75',
                '#a44f4f',
                '#72789b',
              ].map((c) => (
                <button
                  key={c}
                  title={c}
                  aria-label={`Set color ${c}`}
                  style={{ background: c }}
                  className={color === c ? 'chosen' : ''}
                  onClick={() => onColor(c)}
                />
              ))}
            </div>
            <label className="field-label" htmlFor="custom-color">
              Custom color
            </label>
            <div className="color-input">
              <input
                id="custom-color"
                type="color"
                value={color}
                onChange={(e) => onColor(e.target.value)}
              />
              <code>{color.toUpperCase()}</code>
            </div>
            <label className="field-label" htmlFor="opacity">
              Opacity <span>{Math.round(opacity * 100)}%</span>
            </label>
            <input
              id="opacity"
              type="range"
              min="0.1"
              max="1"
              step="0.05"
              value={opacity}
              onChange={(e) => onOpacity(Number(e.target.value))}
            />
            <div className="field-label">Finish</div>
            <div className="selection-field">Satin metal</div>
            <p className="inline-note">
              PBR texture mapping is reserved for the geometry integration.
            </p>
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                onColor('#a7b5c5');
                onOpacity(1);
              }}
            >
              Reset appearance
            </Button>
          </>
        ) : panel === 'Measure' ? (
          <>
            <div className="panel-subheading">
              <Ruler size={15} /> Sample model dimensions
            </div>
            <p className="inline-note">
              Nominal fixture measurements. Exact face and edge measurements
              will come from OCCT.
            </p>
            <dl className="property-list">
              <dt>Mounting width</dt>
              <dd>{width.toFixed(2)} mm</dd>
              <dt>Mounting depth</dt>
              <dd>76.00 mm</dd>
              <dt>Plate thickness</dt>
              <dd>8.00 mm</dd>
              <dt>Bore diameter</dt>
              <dd>27.00 mm</dd>
              <dt>Plate angle</dt>
              <dd>90.00°</dd>
              <dt>Surface area</dt>
              <dd>Engine required</dd>
            </dl>
            <div className="selection-field">
              <Box size={14} />
              {selectedPart === null
                ? 'Select a part in the viewport'
                : `Part ${selectedPart + 1} selected`}
            </div>
          </>
        ) : panel === 'Configuration' ? (
          <>
            <div className="panel-subheading">Default configuration</div>
            <label className="field-label" htmlFor="width">
              width
            </label>
            <div className="unit-field">
              <input
                id="width"
                type="number"
                min="80"
                max="180"
                value={width}
                onChange={(e) => {
                  const v = Number(e.target.value);
                  if (v >= 80 && v <= 180) onWidth(v);
                }}
              />
              <span>mm</span>
            </div>
            <div className="field-label">holes</div>
            <div className="selection-field">4</div>
            <p className="inline-note">
              Width scales the sample mounting plate. Hole count is fixed in
              this fixture.
            </p>
            <Button size="sm" variant="outline" onClick={() => onWidth(120)}>
              Reset configuration
            </Button>
          </>
        ) : panel === 'Properties' ? (
          <>
            <div className="panel-subheading">
              <Box size={15} />{' '}
              {selectedPart === null ? 'Document' : `Part ${selectedPart + 1}`}
            </div>
            <dl className="property-list">
              <dt>Part number</dt>
              <dd>CW-001</dd>
              <dt>Description</dt>
              <dd>Caster mount</dd>
              <dt>Revision</dt>
              <dd>A</dd>
              <dt>Material</dt>
              <dd>{selectedPart === 1 ? 'Delrin' : 'Aluminum 6061'}</dd>
              <dt>Mass</dt>
              <dd>Engine required</dd>
              <dt>Units</dt>
              <dd>mm · deg</dd>
            </dl>
          </>
        ) : panel === 'Comments' ? (
          <>
            <div className="empty-panel">No comments yet</div>
            <p className="inline-note">
              Collaboration is not connected in this local prototype.
            </p>
          </>
        ) : panel === 'Notifications' ? (
          <>
            <div className="panel-subheading">You’re up to date</div>
            <p className="inline-note">
              This prototype stores edits only for the current session.
            </p>
          </>
        ) : (
          <>
            <div className="panel-subheading">Jonathan Jenkins</div>
            <p className="inline-note">Local prototype session</p>
          </>
        )}
      </div>
    </aside>
  );
}
