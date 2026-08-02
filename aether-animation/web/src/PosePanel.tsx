import { Button } from "@aether/ui";
import type { DofSummary } from "./engine";

export interface DofState extends DofSummary {
  shown: number;
  touched: boolean;
}

export interface PosePanelProps {
  dofs: readonly DofState[];
  onChange: (index: number, value: number) => void;
  onReset: () => void;
}

/** Live DOF override sliders (the Pose inspector panel). */
export function PosePanel({ dofs, onChange, onReset }: PosePanelProps) {
  return (
    <div className="pose-panel">
      {dofs.map((dof, index) => (
        <label key={dof.path} className="pose-row">
          <span className="pose-label">{(dof.touched ? "● " : "") + dof.path}</span>
          <input
            type="range"
            min={dof.min ?? (dof.neutral ?? 0) - Math.PI}
            max={dof.max ?? (dof.neutral ?? 0) + Math.PI}
            step={0.001}
            value={dof.shown}
            onChange={(event) => onChange(index, Number(event.target.value))}
          />
          <span className="pose-value">{dof.shown.toFixed(2)}</span>
        </label>
      ))}
      {dofs.some((dof) => dof.touched) ? (
        <Button onClick={onReset}>Reset pose overrides</Button>
      ) : null}
    </div>
  );
}
