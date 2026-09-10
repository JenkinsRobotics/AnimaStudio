import { mountRecentRadius } from "./recent-radius";
import { mountRecentEllipse } from "./recent-ellipse";
/** One lifecycle for optional post-placement sizing, with tool-specific controls. */
export function mountRecentCurveSizing(
  options: Parameters<typeof mountRecentRadius>[0],
) {
  const radius = mountRecentRadius(options),
    ellipse = mountRecentEllipse(options);
  return {
    clear() {
      radius.clear();
      ellipse.clear();
    },
    dispose() {
      radius.dispose();
      ellipse.dispose();
    },
    offer(tool: string, previous: number, active: number) {
      radius.offer(tool, previous, active);
      ellipse.offer(tool, previous);
    },
    key(e: KeyboardEvent) {
      radius.key(e);
      ellipse.key(e);
    },
  };
}
