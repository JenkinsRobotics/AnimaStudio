import type {
  StandardViewportView,
  ViewportOrientation,
} from "@aether/ui";

export interface CADCameraPresentationSnapshot {
  orientation: ViewportOrientation;
  fieldOfViewDegrees: number;
}

export type CADCameraPresentationAction =
  | { type: "select-view"; view: StandardViewportView }
  | { type: "fit-isometric" }
  | { type: "nudge"; horizontalSteps: number; verticalSteps: number }
  | { type: "roll"; quarterTurns: number }
  | { type: "set-field-of-view"; degrees: number };

type Listener = () => void;
type ActionHandler = (action: CADCameraPresentationAction) => void;

const initialSnapshot: CADCameraPresentationSnapshot = Object.freeze({
  orientation: Object.freeze([0, 0, 0, 1]) as ViewportOrientation,
  fieldOfViewDegrees: 42,
});

/** Isolated renderer-to-React camera projection. Camera behavior stays in the
 * viewer; this store only publishes orientation and forwards typed UI intent. */
export class CADCameraPresentationStore {
  private current = initialSnapshot;
  private listeners = new Set<Listener>();
  private actionHandler: ActionHandler | null = null;

  snapshot = (): CADCameraPresentationSnapshot => this.current;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  setOrientation(orientation: ViewportOrientation): void {
    const next = Object.freeze([...orientation]) as ViewportOrientation;
    if (next.every((value, index) => value === this.current.orientation[index])) {
      return;
    }
    this.current = Object.freeze({ ...this.current, orientation: next });
    this.listeners.forEach((listener) => listener());
  }

  setFieldOfView(degrees: number): void {
    if (degrees === this.current.fieldOfViewDegrees) return;
    this.current = Object.freeze({ ...this.current, fieldOfViewDegrees: degrees });
    this.listeners.forEach((listener) => listener());
  }

  registerActionHandler(handler: ActionHandler): () => void {
    this.actionHandler = handler;
    return () => {
      if (this.actionHandler === handler) this.actionHandler = null;
    };
  }

  dispatch(action: CADCameraPresentationAction): boolean {
    if (!this.actionHandler) return false;
    this.actionHandler(action);
    return true;
  }
}

export const cadCameraPresentation = new CADCameraPresentationStore();
