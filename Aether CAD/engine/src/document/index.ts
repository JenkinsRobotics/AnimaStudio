export { resolvePlaneFrame, principalFrame, canonicalPlaneXDirection, validatePlaneDefinition, type PlaneDefinition, type PlaneReference, type PointReference, type AxisReference } from "./construction-planes";
export * from "./part-document";
// Solid feature types + construction-plane frames are engine truth every feature
// editor needs. They were reachable only by deep relative path, which pushed
// consumers past the package boundary (or into redeclaring them).
export * from "./solid-features";
export * from "./tree-organization";
export {evaluateDocumentVariables,type DocumentVariable} from "./variables";
export * from "./part-serialization";

export * from "./file-types";

export * from "./feature-history";

export { resolveProfileDrawing, profileSketchFrame } from "./profile-projection";

export { referenceProfileContour } from "./profile-contour-reference";
export { identifyProfileContours } from "./profile-contour-identities";

export { updatePartDocumentVariables } from "./update-variables";

export { createSketchClipboard, serializeSketchClipboard, parseSketchClipboard, pasteSketchClipboard, type SketchClipboard } from "./sketch-clipboard";
