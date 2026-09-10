import {
  Box,
  Pencil,
  RotateCw,
  Spline,
  Layers,
  Copy,
  Circle,
  CornerUpRight,
  Scissors,
  Combine,
  Grid2X2,
  FlipHorizontal2,
  Diamond,
  Crosshair,
  MoveUp,
  Square,
  Minus,
  Type,
  Triangle,
  Link,
  Lock,
  Magnet,
  Ruler,
  Check,
  X,
  ChevronDown,
  ArrowRightLeft,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
export const solidTools: [string, LucideIcon][][] = [
  [['Sketch', Pencil]],
  [
    ['Extrude', Box],
    ['Revolve', RotateCw],
    ['Sweep', Spline],
    ['Loft', Layers],
    ['Thicken', Copy],
  ],
  [
    ['Fillet', CornerUpRight],
    ['Chamfer', Triangle],
    ['Draft', MoveUp],
    ['Rib', Layers],
    ['Shell', Box],
    ['Hole', Circle],
  ],
  [
    ['Boolean', Combine],
    ['Split', Scissors],
    ['Pattern', Grid2X2],
    ['Mirror', FlipHorizontal2],
  ],
  [
    ['Plane', Diamond],
    ['Mate connector', Crosshair],
    ['Helix', Spline],
  ],
];
const sketchTools: [string, LucideIcon][][] = [
  [
    ['Line', Minus],
    ['Corner rectangle', Square],
    ['Center rectangle', Square],
    ['Circle', Circle],
    ['3-point circle', Circle],
    ['Arc', RotateCw],
    ['Spline', Spline],
    ['Point', Crosshair],
    ['Text', Type],
    ['Construction', Pencil],
  ],
  [
    ['Trim', Scissors],
    ['Extend', MoveUp],
    ['Offset', Copy],
    ['Mirror', FlipHorizontal2],
    ['Fillet', CornerUpRight],
  ],
  [
    ['Coincident', Magnet],
    ['Concentric', Circle],
    ['Parallel', Minus],
    ['Perpendicular', CornerUpRight],
    ['Horizontal', Minus],
    ['Vertical', MoveUp],
    ['Tangent', Circle],
    ['Equal', ArrowRightLeft],
    ['Midpoint', Triangle],
    ['Fix', Lock],
  ],
  [['Dimension', Ruler]],
];
const mateTools: [string, LucideIcon][][] = [
  [['Insert', Box]],
  [
    ['Fastened', Lock],
    ['Revolute', RotateCw],
    ['Slider', ArrowRightLeft],
    ['Planar', Layers],
    ['Cylindrical', Circle],
    ['Pin-slot', Link],
  ],
  [
    ['Mate connector', Crosshair],
    ['Group', Combine],
    ['Replicate', Grid2X2],
  ],
];
export function CommandRibbon({
  mode,
  selected,
  onTool,
  onCommit,
  onCancel,
}: {
  mode: string;
  selected: string;
  onTool: (name: string) => void;
  onCommit: () => void;
  onCancel: () => void;
}) {
  const groups =
    mode === 'sketch'
      ? sketchTools
      : mode === 'assembly'
        ? mateTools
        : mode === 'drawing'
          ? ([
              [
                ['View', Box],
                ['Dimension', Ruler],
                ['Text', Type],
              ],
            ] as [string, LucideIcon][][])
          : solidTools;
  return (
    <div
      className={`command-ribbon ${mode === 'sketch' ? 'sketch-mode' : ''}`}
      aria-label="CAD commands"
    >
      {mode === 'sketch' && (
        <div className="sketch-controls">
          <button className="commit" title="Finish sketch" onClick={onCommit}>
            <Check size={20} />
          </button>
          <button className="cancel" title="Cancel sketch" onClick={onCancel}>
            <X size={19} />
          </button>
          <span>Sketch · Top</span>
        </div>
      )}
      {groups.map((group, i) => (
        <div className="tool-group" key={i}>
          {group.map(([name, Icon]) => (
            <button
              key={name}
              className={`ribbon-tool ${name === 'Sketch' ? 'sketch-trigger' : ''} ${selected === name ? 'selected' : ''}`}
              title={`${name}${name === 'Construction' ? ' (Q)' : name === 'Dimension' ? ' (D)' : ''}`}
              onClick={() => onTool(name)}
            >
              <Icon size={20} strokeWidth={1.5} />
              {(name === 'Sketch' ||
                name === 'Extrude' ||
                mode === 'assembly') && <span>{name}</span>}
              <ChevronDown size={9} className="tool-chevron" />
            </button>
          ))}
        </div>
      ))}
      <div className="header-space" />
      <span className="ribbon-mode">
        {mode === 'sketch'
          ? 'SKETCH'
          : mode === 'assembly'
            ? 'ASSEMBLY'
            : 'PART MODELING'}
      </span>
    </div>
  );
}
