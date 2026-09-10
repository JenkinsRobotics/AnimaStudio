import type { KeyboardEvent } from "react";
import { AetherIcon } from "./AetherIcon";

export type ViewportOrientation = readonly [
  x: number,
  y: number,
  z: number,
  w: number,
];

export type StandardViewportView =
  | "front"
  | "back"
  | "right"
  | "left"
  | "top"
  | "bottom";

export interface ViewportNavigationCubeProps {
  orientation: ViewportOrientation;
  id?: string;
  className?: string;
  onSelectView: (view: StandardViewportView) => void;
  onFit: () => void;
  onNudge: (horizontalSteps: number, verticalSteps: number) => void;
  onRoll: (quarterTurns: number) => void;
}

type Vector3 = readonly [number, number, number];

interface FaceDefinition {
  id: StandardViewportView;
  label: string;
  normal: Vector3;
  vertices: readonly Vector3[];
}

const point = (x: number, y: number, z: number): Vector3 => [x, y, z];

const faces: readonly FaceDefinition[] = [
  { id: "front", label: "Front", normal: point(0, 0, 1), vertices: [point(-1, -1, 1), point(1, -1, 1), point(1, 1, 1), point(-1, 1, 1)] },
  { id: "back", label: "Back", normal: point(0, 0, -1), vertices: [point(1, -1, -1), point(-1, -1, -1), point(-1, 1, -1), point(1, 1, -1)] },
  { id: "right", label: "Right", normal: point(1, 0, 0), vertices: [point(1, -1, 1), point(1, -1, -1), point(1, 1, -1), point(1, 1, 1)] },
  { id: "left", label: "Left", normal: point(-1, 0, 0), vertices: [point(-1, -1, -1), point(-1, -1, 1), point(-1, 1, 1), point(-1, 1, -1)] },
  { id: "top", label: "Top", normal: point(0, 1, 0), vertices: [point(-1, 1, 1), point(1, 1, 1), point(1, 1, -1), point(-1, 1, -1)] },
  { id: "bottom", label: "Bottom", normal: point(0, -1, 0), vertices: [point(-1, -1, -1), point(1, -1, -1), point(1, -1, 1), point(-1, -1, 1)] },
];

function normalizedOrientation([x, y, z, w]: ViewportOrientation): ViewportOrientation {
  const length = Math.hypot(x, y, z, w) || 1;
  return [x / length, y / length, z / length, w / length];
}

function rotateIntoCamera(vector: Vector3, orientation: ViewportOrientation): Vector3 {
  const [sourceX, sourceY, sourceZ, sourceW] = normalizedOrientation(orientation);
  const x = -sourceX;
  const y = -sourceY;
  const z = -sourceZ;
  const [vx, vy, vz] = vector;
  const dot = x * vx + y * vy + z * vz;
  const crossX = y * vz - z * vy;
  const crossY = z * vx - x * vz;
  const crossZ = x * vy - y * vx;
  const scalar = sourceW * sourceW - x * x - y * y - z * z;
  return [
    2 * dot * x + scalar * vx + 2 * sourceW * crossX,
    2 * dot * y + scalar * vy + 2 * sourceW * crossY,
    2 * dot * z + scalar * vz + 2 * sourceW * crossZ,
  ];
}

/** Retained as the renderer-independent quaternion projection helper used by
 * camera presentation stores. */
export function viewportCubeTransform(orientation: ViewportOrientation): string {
  let [x, y, z, w] = normalizedOrientation(orientation);
  x = -x;
  y = -y;
  z = -z;
  const xx = x * x;
  const yy = y * y;
  const zz = z * z;
  const xy = x * y;
  const xz = x * z;
  const yz = y * z;
  const wx = w * x;
  const wy = w * y;
  const wz = w * z;
  const matrix = [
    1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy), 0,
    2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx), 0,
    2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy), 0,
    0, 0, 0, 1,
  ];
  return `matrix3d(${matrix.join(",")})`;
}

const project = ([x, y]: Vector3): readonly [number, number] => [46 + x * 21, 46 - y * 21];

function centroid(points: readonly (readonly [number, number])[]): readonly [number, number] {
  const [x, y] = points.reduce(
    ([sumX, sumY], [pointX, pointY]) => [sumX + pointX, sumY + pointY],
    [0, 0],
  );
  return [x / points.length, y / points.length];
}

function activateFace(
  event: KeyboardEvent<SVGGElement>,
  id: StandardViewportView,
  onSelectView: (view: StandardViewportView) => void,
) {
  if (event.key !== "Enter" && event.key !== " ") return;
  event.preventDefault();
  onSelectView(id);
}

/** Shared suite ViewCube, visually aligned with the native Studio projection.
 * Applications retain camera behavior and pass typed intent callbacks. */
export function ViewportNavigationCube({
  orientation,
  id,
  className,
  onSelectView,
  onFit,
  onNudge,
  onRoll,
}: ViewportNavigationCubeProps) {
  const classes = ["aui-viewport-cube"];
  if (className) classes.push(className);
  const projections = faces
    .map((face) => {
      const normal = rotateIntoCamera(face.normal, orientation);
      const vertices = face.vertices.map((vertex) => rotateIntoCamera(vertex, orientation));
      return {
        ...face,
        facing: normal[2],
        depth: vertices.reduce((sum, vertex) => sum + vertex[2], 0) / vertices.length,
        points: vertices.map(project),
      };
    })
    .filter((face) => face.facing > 0.001)
    .sort((first, second) => first.depth - second.depth);
  const headOn = projections.some((face) => face.facing >= 0.96);
  const axisOrigin = rotateIntoCamera(point(-1.15, -1.15, -1.15), orientation);
  const axes = [
    { id: "x", end: rotateIntoCamera(point(1.2, -1.15, -1.15), orientation) },
    { id: "y", end: rotateIntoCamera(point(-1.15, 1.2, -1.15), orientation) },
    { id: "z", end: rotateIntoCamera(point(-1.15, -1.15, 1.2), orientation) },
  ] as const;
  const [axisX, axisY] = project(axisOrigin);

  return (
    <div id={id} className={classes.join(" ")} aria-label="Viewport navigation">
      <button className="aui-viewport-cube-roll aui-viewport-cube-roll--left" type="button" hidden={!headOn} title="Roll view counterclockwise" aria-label="Roll view counterclockwise" onClick={() => onRoll(-1)}>
        <AetherIcon name="undo" />
      </button>
      <button className="aui-viewport-cube-roll aui-viewport-cube-roll--right" type="button" hidden={!headOn} title="Roll view clockwise" aria-label="Roll view clockwise" onClick={() => onRoll(1)}>
        <AetherIcon name="redo" />
      </button>
      <button className="aui-viewport-cube-nudge aui-viewport-cube-nudge--up" type="button" title="Nudge view up 15 degrees" aria-label="Nudge view up 15 degrees" onClick={() => onNudge(0, 1)}>▴</button>
      <button className="aui-viewport-cube-nudge aui-viewport-cube-nudge--left" type="button" title="Nudge view left 15 degrees" aria-label="Nudge view left 15 degrees" onClick={() => onNudge(-1, 0)}>◂</button>
      <svg className="aui-viewport-cube-stage" viewBox="0 0 92 92" role="img" aria-label="Camera ViewCube">
        {projections.map((face) => {
          const [labelX, labelY] = centroid(face.points);
          const [bottomLeft,bottomRight,,topLeft]=face.points;
          const labelTransform=`matrix(${(bottomRight[0]-bottomLeft[0])/42} ${(bottomRight[1]-bottomLeft[1])/42} ${(bottomLeft[0]-topLeft[0])/42} ${(bottomLeft[1]-topLeft[1])/42} ${labelX} ${labelY})`;
          return (
            <g
              key={face.id}
              className={`aui-viewport-cube-face aui-viewport-cube-face--${face.id}`}
              data-view={face.id}
              role="button"
              tabIndex={0}
              aria-label={`${face.label} view`}
              onClick={() => onSelectView(face.id)}
              onKeyDown={(event) => activateFace(event, face.id, onSelectView)}
            >
              <polygon points={face.points.map(([x, y]) => `${x},${y}`).join(" ")} />
              {face.facing >= 0.28 ? <text x={0} y={0} transform={labelTransform}>{face.label}</text> : null}
            </g>
          );
        })}
        <g className="aui-viewport-cube-axes" aria-hidden="true">
          {axes.map((axis) => {
            const [endX, endY] = project(axis.end);
            return (
              <g key={axis.id} className={`aui-viewport-cube-axis-${axis.id}`}>
                <line x1={axisX} y1={axisY} x2={endX} y2={endY} />
                <text x={endX} y={endY}>{axis.id.toUpperCase()}</text>
              </g>
            );
          })}
          <circle cx={axisX} cy={axisY} r="1.8" />
        </g>
      </svg>
      <button className="aui-viewport-cube-nudge aui-viewport-cube-nudge--right" type="button" title="Nudge view right 15 degrees" aria-label="Nudge view right 15 degrees" onClick={() => onNudge(1, 0)}>▸</button>
      <button className="aui-viewport-cube-nudge aui-viewport-cube-nudge--down" type="button" title="Nudge view down 15 degrees" aria-label="Nudge view down 15 degrees" onClick={() => onNudge(0, -1)}>▾</button>
      <button className="aui-viewport-cube-home" type="button" title="Fit isometric view" aria-label="Fit isometric view" onClick={onFit}>
        <AetherIcon name="home" />
      </button>
    </div>
  );
}
