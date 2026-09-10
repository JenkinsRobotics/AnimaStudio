import { useState } from 'react';
import {
  ArrowDownUp,
  Box,
  Check,
  ChevronDown,
  GripVertical,
  HelpCircle,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import type { Feature } from './types';
export type FeatureDraft = {
  name: string;
  kind: string;
  depthMm: number;
  condition: string;
  reversed: boolean;
  draft: boolean;
};
export function FeatureDialog({
  feature,
  kind,
  onClose,
  onApply,
}: {
  feature?: Feature;
  kind: string;
  onClose: () => void;
  onApply: (draft: FeatureDraft) => void;
}) {
  const [depth, setDepth] = useState(String(feature?.depthMm ?? 25));
  const [condition, setCondition] = useState('Blind');
  const [reversed, setReversed] = useState(false);
  const [draft, setDraft] = useState(false);
  const [angle, setAngle] = useState('3');
  const [operation, setOperation] = useState('New');
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const valid =
    Number.isFinite(Number(depth)) &&
    Number(depth) > 0 &&
    Number(depth) <= 150 &&
    (!draft || (Number(angle) >= 0 && Number(angle) < 90));
  return (
    <dialog
      open
      aria-label={`${kind} parameters`}
      className="feature-dialog"
      style={{ transform: `translate(${offset.x}px,${offset.y}px)` }}
      onKeyDown={(e) => {
        if (e.key === 'Escape') onClose();
      }}
    >
      <div
        className="dialog-heading"
        onPointerDown={(e) => {
          if ((e.target as HTMLElement).closest('button')) return;
          const x = e.clientX,
            y = e.clientY,
            start = { ...offset };
          e.currentTarget.setPointerCapture(e.pointerId);
          const move = (event: PointerEvent) =>
            setOffset({
              x: Math.max(-10, Math.min(300, start.x + event.clientX - x)),
              y: Math.max(-10, Math.min(200, start.y + event.clientY - y)),
            });
          const node = e.currentTarget;
          node.addEventListener('pointermove', move);
          node.addEventListener(
            'pointerup',
            () => node.removeEventListener('pointermove', move),
            { once: true },
          );
        }}
      >
        <GripVertical size={13} />
        <Box size={17} />
        <strong>{feature?.name ?? kind}</strong>
        <button
          className="commit"
          title={`Apply ${kind}`}
          disabled={!valid || condition === 'Up to face'}
          onClick={() =>
            onApply({
              name: feature?.name ?? kind,
              kind,
              depthMm: Number(depth),
              condition,
              reversed,
              draft,
            })
          }
        >
          <Check size={18} />
        </button>
        <button title="Cancel feature" onClick={onClose}>
          <X size={18} />
        </button>
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (valid && condition !== 'Up to face')
            onApply({
              name: feature?.name ?? kind,
              kind,
              depthMm: Number(depth),
              condition,
              reversed,
              draft,
            });
        }}
      >
        <div className="dialog-tabs">
          <button type="button" className="active">
            Solid
          </button>
          <button
            type="button"
            disabled
            title="Surface tools require the geometry engine"
          >
            Surface
          </button>
          <button
            type="button"
            disabled
            title="Thin extrusion requires the geometry engine"
          >
            Thin
          </button>
        </div>
        <div className="dialog-fields">
          <div className="operation-tabs">
            {['New', 'Add', 'Remove', 'Intersect'].map((v) => (
              <button
                type="button"
                key={v}
                className={operation === v ? 'active' : ''}
                onClick={() => setOperation(v)}
              >
                {v}
              </button>
            ))}
          </div>
          <div className="field-label">Faces and sketch regions</div>
          <div className="selection-field">
            <span>Sketch 1 · face 1</span>
            <ChevronDown size={13} />
          </div>
          <label className="field-label" htmlFor="end-condition">
            End condition
          </label>
          <select
            id="end-condition"
            value={condition}
            onChange={(e) => setCondition(e.target.value)}
          >
            <option>Blind</option>
            <option>Symmetric</option>
            <option>Up to face</option>
          </select>
          {condition === 'Up to face' ? (
            <div className="inline-note">
              Select a terminating face. Face references will be connected with
              the geometry engine.
            </div>
          ) : (
            <>
              <label className="field-label" htmlFor="depth">
                {kind === 'Fillet'
                  ? 'Radius'
                  : kind === 'Hole'
                    ? 'Diameter'
                    : 'Depth'}
              </label>
              <div className="unit-field">
                <Input
                  autoFocus
                  id="depth"
                  value={depth}
                  onChange={(e) => setDepth(e.target.value)}
                  inputMode="decimal"
                />
                <span>mm</span>
                <button
                  type="button"
                  title="Flip direction"
                  aria-pressed={reversed}
                  className={reversed ? 'active' : ''}
                  onClick={() => setReversed(!reversed)}
                >
                  <ArrowDownUp size={17} />
                </button>
              </div>
            </>
          )}
          <label className="checkbox-row">
            <input
              type="checkbox"
              checked={draft}
              onChange={(e) => setDraft(e.target.checked)}
            />{' '}
            Draft angle
          </label>
          {draft && (
            <div className="unit-field">
              <input
                aria-label="Draft angle in degrees"
                value={angle}
                onChange={(e) => setAngle(e.target.value)}
              />
              <span>deg</span>
            </div>
          )}
          {!valid && (
            <p className="error-text" role="alert">
              Enter a depth from 0–150 mm and a draft angle from 0–89°.
            </p>
          )}
          <div className="dialog-note">
            <HelpCircle size={13} />
            <span>Mock parameters · geometry engine not connected</span>
          </div>
          <div className="dialog-footer">
            <Button variant="outline" size="sm" type="button" onClick={onClose}>
              Cancel
            </Button>
            <Button
              size="sm"
              disabled={!valid || condition === 'Up to face'}
              type="submit"
            >
              Apply
            </Button>
          </div>
        </div>
      </form>
    </dialog>
  );
}
