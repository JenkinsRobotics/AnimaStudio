export type SketchPlane = "XY" | "XZ" | "YZ";

export interface RectangleProfile {
  type: "center-rectangle";
  widthMillimeters: number;
  heightMillimeters: number;
  centerXMillimeters: number;
  centerYMillimeters: number;
  construction: boolean;
}

export type SketchConstraintType =
  | "horizontal"
  | "vertical"
  | "coincident-origin";

export interface SketchConstraint {
  id: string;
  type: SketchConstraintType;
  target: "center-rectangle";
}

export type SketchDimensionType = "width" | "height";

export interface SketchDimension {
  id: string;
  type: SketchDimensionType;
  target: "center-rectangle";
  valueMillimeters: number;
}

export interface SketchFeature {
  id: string;
  type: "sketch";
  name: string;
  plane: SketchPlane;
  profile: RectangleProfile;
  constraints: SketchConstraint[];
  dimensions: SketchDimension[];
  suppressed: boolean;
}

export interface RectangleSketchRevision {
  plane: SketchPlane;
  widthMillimeters: number;
  heightMillimeters: number;
  horizontal: boolean;
  vertical: boolean;
  anchoredToOrigin: boolean;
  widthDimensioned: boolean;
  heightDimensioned: boolean;
  construction: boolean;
}

export interface SketchDefinitionState {
  fullyDefined: boolean;
  remainingDegreesOfFreedom: number;
  label: "Fully defined" | "Under-defined";
}

const constraintOrder: readonly SketchConstraintType[] = [
  "horizontal",
  "vertical",
  "coincident-origin",
];

const dimensionOrder: readonly SketchDimensionType[] = ["width", "height"];

function positiveFinite(value: number, label: string): void {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${label} must be greater than zero.`);
  }
}

function constraintId(sketchId: string, type: SketchConstraintType): string {
  return `${sketchId}:constraint:${type}`;
}

function dimensionId(sketchId: string, type: SketchDimensionType): string {
  return `${sketchId}:dimension:${type}`;
}

export function createCenterRectangleSketch(
  sketchId: string,
  plane: SketchPlane,
  widthMillimeters: number,
  heightMillimeters: number,
  fullyDefined = true,
): SketchFeature {
  return reviseCenterRectangleSketch(
    {
      id: sketchId,
      type: "sketch",
      name: "Sketch 1",
      plane,
      profile: {
        type: "center-rectangle",
        widthMillimeters,
        heightMillimeters,
        centerXMillimeters: 0,
        centerYMillimeters: 0,
        construction: false,
      },
      constraints: [],
      dimensions: [],
      suppressed: false,
    },
    {
      plane,
      widthMillimeters,
      heightMillimeters,
      horizontal: true,
      vertical: true,
      anchoredToOrigin: true,
      widthDimensioned: fullyDefined,
      heightDimensioned: fullyDefined,
      construction: false,
    },
  );
}

export function rectangleSketchRevision(
  sketch: SketchFeature,
): RectangleSketchRevision {
  const constraints = new Set(
    sketch.constraints.map((constraint) => constraint.type),
  );
  const dimensions = new Set(
    sketch.dimensions.map((dimension) => dimension.type),
  );
  return {
    plane: sketch.plane,
    widthMillimeters:
      sketch.dimensions.find((dimension) => dimension.type === "width")
        ?.valueMillimeters ?? sketch.profile.widthMillimeters,
    heightMillimeters:
      sketch.dimensions.find((dimension) => dimension.type === "height")
        ?.valueMillimeters ?? sketch.profile.heightMillimeters,
    horizontal: constraints.has("horizontal"),
    vertical: constraints.has("vertical"),
    anchoredToOrigin: constraints.has("coincident-origin"),
    widthDimensioned: dimensions.has("width"),
    heightDimensioned: dimensions.has("height"),
    construction: sketch.profile.construction,
  };
}

export function reviseCenterRectangleSketch(
  sketch: SketchFeature,
  revision: RectangleSketchRevision,
): SketchFeature {
  positiveFinite(revision.widthMillimeters, "Sketch width");
  positiveFinite(revision.heightMillimeters, "Sketch height");
  const enabledConstraints = new Set<SketchConstraintType>();
  if (revision.horizontal) enabledConstraints.add("horizontal");
  if (revision.vertical) enabledConstraints.add("vertical");
  if (revision.anchoredToOrigin) enabledConstraints.add("coincident-origin");
  const enabledDimensions = new Set<SketchDimensionType>();
  if (revision.widthDimensioned) enabledDimensions.add("width");
  if (revision.heightDimensioned) enabledDimensions.add("height");
  return {
    ...sketch,
    plane: revision.plane,
    profile: {
      ...sketch.profile,
      widthMillimeters: revision.widthMillimeters,
      heightMillimeters: revision.heightMillimeters,
      centerXMillimeters: revision.anchoredToOrigin
        ? 0
        : sketch.profile.centerXMillimeters,
      centerYMillimeters: revision.anchoredToOrigin
        ? 0
        : sketch.profile.centerYMillimeters,
      construction: revision.construction,
    },
    constraints: constraintOrder
      .filter((type) => enabledConstraints.has(type))
      .map((type) => ({
        id: constraintId(sketch.id, type),
        type,
        target: "center-rectangle" as const,
      })),
    dimensions: dimensionOrder
      .filter((type) => enabledDimensions.has(type))
      .map((type) => ({
        id: dimensionId(sketch.id, type),
        type,
        target: "center-rectangle" as const,
        valueMillimeters:
          type === "width"
            ? revision.widthMillimeters
            : revision.heightMillimeters,
      })),
  };
}

export function sketchDefinitionState(
  sketch: SketchFeature,
): SketchDefinitionState {
  const revision = rectangleSketchRevision(sketch);
  let remainingDegreesOfFreedom = 0;
  if (!revision.horizontal) remainingDegreesOfFreedom += 1;
  if (!revision.vertical) remainingDegreesOfFreedom += 1;
  if (!revision.anchoredToOrigin) remainingDegreesOfFreedom += 2;
  if (!revision.widthDimensioned) remainingDegreesOfFreedom += 1;
  if (!revision.heightDimensioned) remainingDegreesOfFreedom += 1;
  return remainingDegreesOfFreedom === 0
    ? {
        fullyDefined: true,
        remainingDegreesOfFreedom: 0,
        label: "Fully defined",
      }
    : {
        fullyDefined: false,
        remainingDegreesOfFreedom,
        label: "Under-defined",
      };
}

export function validateSketchFeature(sketch: SketchFeature): void {
  if (!sketch.id || !sketch.name.trim()) {
    throw new Error("Sketch needs an ID and name.");
  }
  if (!["XY", "XZ", "YZ"].includes(sketch.plane)) {
    throw new Error(`Unsupported sketch plane: ${String(sketch.plane)}.`);
  }
  if (sketch.profile.type !== "center-rectangle") {
    throw new Error("Part v2 supports a center-rectangle Sketch.");
  }
  positiveFinite(sketch.profile.widthMillimeters, "Sketch width");
  positiveFinite(sketch.profile.heightMillimeters, "Sketch height");
  if (!Number.isFinite(sketch.profile.centerXMillimeters)) {
    throw new Error("Sketch center X must be finite.");
  }
  if (!Number.isFinite(sketch.profile.centerYMillimeters)) {
    throw new Error("Sketch center Y must be finite.");
  }
  if (typeof sketch.profile.construction !== "boolean") {
    throw new Error("Sketch construction state is invalid.");
  }
  const ids = new Set<string>();
  for (const constraint of sketch.constraints) {
    if (!constraint.id || ids.has(constraint.id)) {
      throw new Error("Sketch constraint IDs must be unique.");
    }
    ids.add(constraint.id);
    if (!constraintOrder.includes(constraint.type)) {
      throw new Error(
        `Unsupported sketch constraint: ${String(constraint.type)}.`,
      );
    }
    if (constraint.target !== "center-rectangle") {
      throw new Error("Sketch constraint target is invalid.");
    }
  }
  for (const dimension of sketch.dimensions) {
    if (!dimension.id || ids.has(dimension.id)) {
      throw new Error("Sketch dimension IDs must be unique.");
    }
    ids.add(dimension.id);
    if (!dimensionOrder.includes(dimension.type)) {
      throw new Error(
        `Unsupported sketch dimension: ${String(dimension.type)}.`,
      );
    }
    if (dimension.target !== "center-rectangle") {
      throw new Error("Sketch dimension target is invalid.");
    }
    positiveFinite(dimension.valueMillimeters, `${dimension.type} dimension`);
  }
}
