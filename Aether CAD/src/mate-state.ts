import type { ConnectorCandidate, MateConnector } from "./domain";

export interface ConstraintDecision {
  allowed: boolean;
  reason?: string;
}

/** Persistent, stable-ID connector collection independent from completed mates. */
export class MateConnectorRegistry {
  private readonly connectors = new Map<string, MateConnector>();
  private sequence = 0;

  create(
    partId: string,
    partName: string,
    candidate: ConnectorCandidate,
  ): MateConnector {
    this.sequence += 1;
    const connector: MateConnector = {
      id: crypto.randomUUID(),
      name: `Connector ${this.sequence}`,
      partId,
      partName,
      candidate,
    };
    this.connectors.set(connector.id, connector);
    return connector;
  }

  get(id: string): MateConnector | undefined {
    return this.connectors.get(id);
  }

  list(): MateConnector[] {
    return [...this.connectors.values()];
  }

  remove(id: string): boolean {
    return this.connectors.delete(id);
  }
}

export type MatePickResult =
  | { kind: "first"; connector: MateConnector }
  | { kind: "complete"; moving: MateConnector; target: MateConnector }
  | { kind: "rejected"; reason: string };

/** Two connector references form a mate; connector creation is a separate flow. */
export class FastenedMateDraft {
  private first: MateConnector | null = null;

  get movingConnector(): MateConnector | null {
    return this.first;
  }

  choose(connector: MateConnector): MatePickResult {
    if (!this.first) {
      this.first = connector;
      return { kind: "first", connector };
    }
    if (this.first.id === connector.id) {
      return { kind: "rejected", reason: "Choose a different connector." };
    }
    if (this.first.partId === connector.partId) {
      return {
        kind: "rejected",
        reason: "A mate needs connectors on two different Parts.",
      };
    }
    const moving = this.first;
    this.first = null;
    return { kind: "complete", moving, target: connector };
  }

  clear(): void {
    this.first = null;
  }
}

/**
 * Deliberately small first-proof constraint policy.
 *
 * A Part may be the stationary target of any number of mates, but a Part that
 * has already been repositioned as the moving side cannot be selected as the
 * moving side again. A production assembly solver will replace this with graph
 * and cycle analysis; silently over-constraining this demo would hide errors.
 */
export class MateConstraintTracker {
  private readonly constrainedMovingParts = new Set<string>();

  canUseAsMoving(partId: string): ConstraintDecision {
    return this.constrainedMovingParts.has(partId)
      ? {
          allowed: false,
          reason:
            "This Part already has a driving mate. Clear it before using the Part as the moving side again.",
        }
      : { allowed: true };
  }

  markMovingPart(partId: string): void {
    this.constrainedMovingParts.add(partId);
  }

  isConstrained(partId: string): boolean {
    return this.constrainedMovingParts.has(partId);
  }

  clear(): void {
    this.constrainedMovingParts.clear();
  }
}
