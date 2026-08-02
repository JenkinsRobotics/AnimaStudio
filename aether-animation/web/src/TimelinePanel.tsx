import { useMemo } from "react";
import { Timeline } from "@aether/ui";
import type { TimelineTrack } from "@aether/ui";
import type { ClipSummary } from "./engine";

export interface TimelinePanelProps {
  clip: ClipSummary | null;
  timeS: number;
  playing: boolean;
  onSeek: (timeS: number) => void;
  onTogglePlay: () => void;
}

/** The Animate bottom editor: the active clip's keyframes as per-DOF
 *  dope-sheet tracks. Read-only until the engine clip-CRUD verbs land
 *  (queued packet); scrub + transport are live. */
export function TimelinePanel(props: TimelinePanelProps) {
  const tracks = useMemo<TimelineTrack[]>(() => {
    if (!props.clip) return [];
    const byDof = new Map<string, { timeS: number }[]>();
    for (const keyframe of props.clip.keyframes) {
      for (const path of Object.keys(keyframe.values)) {
        if (!byDof.has(path)) byDof.set(path, []);
        byDof.get(path)!.push({ timeS: keyframe.time_s });
      }
    }
    return [...byDof.entries()].map(([path, keyframes]) => ({
      id: path,
      label: path,
      keyframes,
    }));
  }, [props.clip]);

  return (
    <Timeline
      tracks={tracks}
      durationS={props.clip?.duration_s ?? 1}
      timeS={props.timeS}
      onSeek={props.onSeek}
      playing={props.playing}
      onTogglePlay={props.onTogglePlay}
      emptyState="select a clip in the Clips panel"
    />
  );
}
