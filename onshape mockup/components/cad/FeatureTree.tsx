import {
  Box,
  ChevronDown,
  Circle,
  Diamond,
  Eye,
  EyeOff,
  GripHorizontal,
  PanelLeftClose,
  Pencil,
  Search,
} from 'lucide-react';
import type { Feature } from './types';
export function FeatureTree({
  features,
  filter,
  onFilter,
  planes,
  onPlane,
  selected,
  onSelect,
  onEdit,
  onContext,
  rollback,
  onRollback,
  onCollapse,
}: {
  features: Feature[];
  filter: string;
  onFilter: (v: string) => void;
  planes: boolean[];
  onPlane: (i: number) => void;
  selected: string | null;
  onSelect: (id: string) => void;
  onEdit: (f: Feature) => void;
  onContext: (e: React.MouseEvent, f: Feature) => void;
  hidden: boolean[];
  onHide: (i: number) => void;
  onIsolate: (i: number) => void;
  onAppearance: () => void;
  selectedPart: number | null;
  onPart: (i: number) => void;
  rollback: number;
  onRollback: (n: number) => void;
  onCollapse: () => void;
}) {
  return (
    <aside className="feature-sidebar">
      <div className="panel-heading">
        <strong>
          Features <span>({features.length})</span>
        </strong>
        <button title="Collapse sidebar" onClick={onCollapse}>
          <PanelLeftClose size={15} />
        </button>
      </div>
      <div className="tree-search">
        <Search size={13} />
        <input
          placeholder="Filter features and parts"
          aria-label="Filter features and parts"
          value={filter}
          onChange={(e) => onFilter(e.target.value)}
        />
      </div>
      <div className="tree-heading">
        <ChevronDown size={12} />
        <span>Default geometry</span>
      </div>
      {['Origin', 'Top', 'Front', 'Right']
        .filter((n) => n.toLowerCase().includes(filter.toLowerCase()))
        .map((name) => {
          const i = ['Origin', 'Top', 'Front', 'Right'].indexOf(name);
          return (
            <div
              className={`tree-row ${i > 0 && !planes[i - 1] ? 'muted-row' : ''}`}
              key={name}
            >
              <span className="tree-indent" />
              {i === 0 ? (
                <Circle size={14} />
              ) : (
                <Diamond size={15} className="plane-icon" />
              )}
              <span>{name}</span>
              {i > 0 && (
                <button
                  className="row-action"
                  title={`${planes[i - 1] ? 'Hide' : 'Show'} ${name} plane (P toggles all)`}
                  aria-label={`Toggle ${name} plane`}
                  onClick={() => onPlane(i - 1)}
                >
                  {planes[i - 1] ? <Eye size={14} /> : <EyeOff size={14} />}
                </button>
              )}
            </div>
          );
        })}
      <div className="tree-heading">
        <ChevronDown size={12} />
        <span>Feature history</span>
      </div>
      <div className="feature-history">
        {features.map((f, i) => (
          <div key={f.id}>
            {i === rollback && <div className="rollback-marker" />}
            {f.name.toLowerCase().includes(filter.toLowerCase()) && (
              <button
                className={`tree-row feature-row ${selected === f.id ? 'selected-row' : ''} ${f.suppressed || i >= rollback ? 'muted-row' : ''}`}
                onClick={() => onSelect(f.id)}
                onDoubleClick={() => onEdit(f)}
                onContextMenu={(e) => onContext(e, f)}
                title={`${f.name}${f.suppressed ? ' · Suppressed' : ''} · Double-click to edit`}
              >
                <span className="tree-indent" />
                {f.kind === 'Sketch' ? (
                  <Pencil size={15} />
                ) : f.kind === 'Hole' ? (
                  <Circle size={15} />
                ) : (
                  <Box size={15} />
                )}
                <span>{f.name}</span>
                {f.suppressed && <EyeOff size={12} />}
              </button>
            )}
          </div>
        ))}
        {features.length === rollback && <div className="rollback-marker" />}
      </div>
      <div className="rollback-control">
        <GripHorizontal size={14} />
        <input
          type="range"
          aria-label="Rollback position"
          min={0}
          max={features.length}
          value={rollback}
          onChange={(e) => onRollback(Number(e.target.value))}
        />
        <span>
          {rollback}/{features.length}
        </span>
      </div>
      <div className="tree-fill" />
      <div className="sidebar-footer">
        <span className="green-dot" />{' '}
        {rollback < features.length
          ? `Rolled back to feature ${rollback}`
          : 'Regeneration complete'}
      </div>
    </aside>
  );
}

export function PartsSidebar({
  hidden,
  onHide,
  onIsolate,
  onAppearance,
  selectedPart,
  onPart,
  filter,
}: Pick<
  Parameters<typeof FeatureTree>[0],
  | 'hidden'
  | 'onHide'
  | 'onIsolate'
  | 'onAppearance'
  | 'selectedPart'
  | 'onPart'
  | 'filter'
>) {
  return (
    <aside className="parts-sidebar">
      <div className="parts-section">
        <div className="panel-heading">
          <strong>
            <ChevronDown size={12} /> Parts <span>(2)</span>
          </strong>
          <span className="mini-label">MATERIAL</span>
        </div>
        {['Part 1', 'Part 2'].map(
          (p, i) =>
            `${p} ${i ? 'Delrin' : 'Aluminum 6061'}`
              .toLowerCase()
              .includes(filter.toLowerCase()) && (
              <div
                key={p}
                className={`tree-row part-row ${selectedPart === i ? 'selected-row' : ''} ${hidden[i] ? 'muted-row' : ''}`}
              >
                <button
                  className="part-select"
                  onClick={() => onPart(i)}
                  onDoubleClick={() => onIsolate(i)}
                  title={`${p} · Double-click to isolate`}
                >
                  <Box size={15} />
                  <span>
                    {p}
                    <small>{i ? 'Delrin' : 'Aluminum 6061'}</small>
                  </span>
                </button>
                <button
                  className="swatch-button"
                  aria-label={`Edit Part ${i + 1} appearance`}
                  title={`Edit ${p} appearance`}
                  onClick={() => {
                    onPart(i);
                    onAppearance();
                  }}
                >
                  <i className={`material-swatch swatch-${i}`} />
                </button>
                <button
                  title={`${hidden[i] ? 'Show' : 'Hide'} ${p}`}
                  onClick={() => onHide(i)}
                >
                  {hidden[i] ? <EyeOff size={14} /> : <Eye size={14} />}
                </button>
              </div>
            ),
        )}
      </div>
    </aside>
  );
}
