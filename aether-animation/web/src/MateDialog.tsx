import { Button, FloatingPanel } from "@aether/ui";
import type { ConnectorDTO, MateJointDTO, MateTypeSchema } from "./engine";

/** In-progress mate authoring state owned by the app. */
export interface MateDraft {
  schema: MateTypeSchema;
  a: ConnectorDTO | null;
  b: ConnectorDTO | null;
  flipPrimaryAxis: boolean;
  secondaryAxisRotationDeg: number;
}

export function draftToJoint(draft: MateDraft, name: string): MateJointDTO | null {
  if (!draft.a || !draft.b) return null;
  return {
    name,
    type: draft.schema.type,
    parent_part: draft.a.part,
    child_part: draft.b.part,
    dofs: draft.schema.dofs.map((dof) => ({ name: dof.name, kind: dof.kind })),
    controls: {
      connectors: { a: draft.a, b: draft.b },
      flip_primary_axis: draft.flipPrimaryAxis,
      secondary_axis_rotation_deg: draft.secondaryAxisRotationDeg,
      simulation_connection: false,
    },
  };
}

export interface MateDialogProps {
  draft: MateDraft;
  onChange: (draft: MateDraft) => void;
  onSolve: () => void;
  onCommit: () => void;
  onCancel: () => void;
  busy: boolean;
}

/** Onshape-style mate card: two viewport-picked connectors, orientation
 *  controls, engine Solve preview, commit/cancel. Floats over the
 *  viewport while the tool is armed. */
export function MateDialog({ draft, onChange, onSolve, onCommit, onCancel, busy }: MateDialogProps) {
  const ready = draft.a !== null && draft.b !== null;
  const slot = (label: string, connector: ConnectorDTO | null) => (
    <div className={"mate-slot" + (connector ? " mate-slot--filled" : "")}>
      <span className="mate-slot-label">{label}</span>
      <span>
        {connector
          ? `${connector.part} · [${connector.origin_m
              .map((value) => value.toFixed(3))
              .join(", ")}]`
          : "click a part surface in the viewport"}
      </span>
    </div>
  );

  return (
    <FloatingPanel
      title={`${draft.schema.label} mate`}
      x={16}
      y={16}
      width={290}
      onMove={() => {}}
      onClose={onCancel}
    >
      <div className="mate-dialog">
        {slot("Connector A (parent)", draft.a)}
        {slot("Connector B (child)", draft.b)}
        <label className="mate-row">
          <input
            type="checkbox"
            checked={draft.flipPrimaryAxis}
            onChange={(event) =>
              onChange({ ...draft, flipPrimaryAxis: event.target.checked })
            }
          />
          Flip primary axis
        </label>
        <label className="mate-row">
          Reorient secondary
          <select
            value={draft.secondaryAxisRotationDeg}
            onChange={(event) =>
              onChange({
                ...draft,
                secondaryAxisRotationDeg: Number(event.target.value),
              })
            }
          >
            {[0, 90, 180, 270].map((degrees) => (
              <option key={degrees} value={degrees}>
                {degrees}°
              </option>
            ))}
          </select>
        </label>
        <div className="mate-actions">
          <Button disabled={!ready || busy} onClick={onSolve}>
            Solve
          </Button>
          <Button primary disabled={!ready || busy} onClick={onCommit}>
            ✓ Create
          </Button>
          <Button onClick={onCancel}>✕</Button>
        </div>
      </div>
    </FloatingPanel>
  );
}
