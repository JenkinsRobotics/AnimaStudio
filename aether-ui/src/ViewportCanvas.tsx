import { useEffect, useRef } from "react";
import type { CSSProperties } from "react";

export interface ViewportCanvasProps {
  /**
   * Mounts the imperative renderer exactly once with the live canvas and
   * returns its teardown. React NEVER re-renders through this element —
   * the viewport is a persistent Three.js/WebGPU object (see the UI
   * framework decision record).
   */
  onMount: (canvas: HTMLCanvasElement) => () => void;
  style?: CSSProperties;
  className?: string;
}

export function ViewportCanvas({ onMount, style, className }: ViewportCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const mountRef = useRef(onMount);
  mountRef.current = onMount;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    return mountRef.current(canvas);
  }, []);

  const classes = ["aui-viewport-canvas"];
  if (className) classes.push(className);
  return (
    <div className={classes.join(" ")} style={style}>
      <canvas ref={canvasRef} />
    </div>
  );
}
