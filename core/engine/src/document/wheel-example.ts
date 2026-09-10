import type { PartDocument, PartFeature } from "./part-document";
/** Demonstration dimensions, not measurements inferred from the reference image. */
export function createWheelExample(documentId = "wheel-example"): PartDocument {
  const features: PartFeature[] = [
    {
      id: "section",
      type: "profile",
      name: "Wheel section",
      plane: "XZ",
      offsetMillimeters: 0,
      suppressed: false,
      profile: {
        type: "polygon",
        pointsMillimeters: [
          [0, 0],
          [40, 0],
          [40, 3],
          [34, 3],
          [34, 18],
          [30, 18],
          [30, 6],
          [0, 6],
        ],
      },
    },
    {
      id: "revolve",
      type: "revolve",
      name: "Revolve wheel",
      profileFeatureId: "section",
      axis: "Z",
      angleDegrees: 360,
      operation: "new",
      suppressed: false,
    },
    {
      id: "hub",
      type: "profile",
      name: "Hub circle",
      plane: "XY",
      offsetMillimeters: 6,
      suppressed: false,
      profile: {
        type: "circle",
        radiusMillimeters: 12,
        centerMillimeters: [0, 0],
      },
    },
    {
      id: "hub-add",
      type: "extrude",
      name: "Extrude hub",
      profileFeatureId: "hub",
      distanceMillimeters: 3,
      operation: "add",
      suppressed: false,
    },
    {
      id: "bore",
      type: "profile",
      name: "Axle bore",
      plane: "XY",
      offsetMillimeters: -1,
      suppressed: false,
      profile: {
        type: "circle",
        radiusMillimeters: 5,
        centerMillimeters: [0, 0],
      },
    },
    {
      id: "bore-cut",
      type: "extrude",
      name: "Cut axle bore",
      profileFeatureId: "bore",
      distanceMillimeters: 22,
      operation: "cut",
      suppressed: false,
    },
    {
      id: "hole",
      type: "profile",
      name: "Mounting hole",
      plane: "XY",
      offsetMillimeters: -1,
      suppressed: false,
      profile: {
        type: "circle",
        radiusMillimeters: 2.5,
        centerMillimeters: [16, 8],
      },
    },
    {
      id: "hole-cut",
      type: "extrude",
      name: "Cut mounting hole",
      profileFeatureId: "hole",
      distanceMillimeters: 22,
      operation: "cut",
      suppressed: false,
    },
    {
      id: "mirror-x",
      type: "mirror",
      name: "Mirror hole left",
      sourceFeatureId: "hole-cut",
      plane: "YZ",
      offsetMillimeters: 0,
      operation: "cut",
      suppressed: false,
    },
    {
      id: "mirror-y",
      type: "mirror",
      name: "Mirror hole below",
      sourceFeatureId: "hole-cut",
      plane: "XZ",
      offsetMillimeters: 0,
      operation: "cut",
      suppressed: false,
    },
    {
      id: "mirror-xy",
      type: "mirror",
      name: "Mirror fourth hole",
      sourceFeatureId: "mirror-x",
      plane: "XZ",
      offsetMillimeters: 0,
      operation: "cut",
      suppressed: false,
    },
  ];
  return {
    format: "aether-part",
    formatVersion: 3,
    documentId,
    name: "Train cart wheel — test dimensions",
    units: "millimeter",
    features,
  };
}

/** The wheel exercise with selectively rounded flange/web and chamfered rim. */
export function createFinishedWheelExample(
  documentId = "wheel-example",
): PartDocument {
  const document = createWheelExample(documentId);
  document.features.splice(
    2,
    0,
    {
      id: "flange-round",
      name: "Flange round",
      type: "fillet",
      radiusMillimeters: 0.6,
      edgePlane: { plane: "XY", offsetMillimeters: 3 },
      suppressed: false,
    },
    {
      id: "rim-chamfer",
      name: "Rim chamfer",
      type: "chamfer",
      radiusMillimeters: 0.3,
      edgePlane: { plane: "XY", offsetMillimeters: 18 },
      suppressed: false,
    },
    {
      id: "web-round",
      name: "Web round",
      type: "fillet",
      radiusMillimeters: 0.6,
      edgePlane: { plane: "XY", offsetMillimeters: 6 },
      suppressed: false,
    },
  );
  const revolve = document.features[1];
  if (revolve.type === "revolve") revolve.bodyId = `${documentId}:body-1`;
  document.bodyProperties = {
    [`${documentId}:body-1`]: { name: "Wheel", visible: true },
  };
  return document;
}
