import { createCenterRectangleSketch } from "../sketch/index";
import {
  LEGACY_PART_DOCUMENT_FORMAT,
  PART_DOCUMENT_FORMAT,
  PART_DOCUMENT_VERSION,
  validatePartDocument,
  type PartDocument,
} from "./part-document";

export function serializePartDocument(document: PartDocument): string {
  validatePartDocument(document);
  return `${JSON.stringify(document, null, 2)}\n`;
}

export function parsePartDocument(text: string): PartDocument {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new Error("The selected file is not valid JSON.");
  }
  const migrated = migratePartDocument(value);
  validatePartDocument(migrated);
  return migrated;
}

export function migratePartDocument(value: unknown): unknown {
  if (!value || typeof value !== "object") return value;
  const record = value as Record<string, unknown>;
  const format =
    record.format === LEGACY_PART_DOCUMENT_FORMAT
      ? PART_DOCUMENT_FORMAT
      : record.format;
  if (format !== PART_DOCUMENT_FORMAT) return value;
  if (record.formatVersion !== 1) return { ...record, format, formatVersion: record.formatVersion === 2 ? PART_DOCUMENT_VERSION : record.formatVersion };
  const features = Array.isArray(record.features)
    ? record.features.map((feature) => {
        if (!feature || typeof feature !== "object") return feature;
        const item = feature as Record<string, unknown>;
        if (item.type !== "sketch") return feature;
        const profile = item.profile as Record<string, unknown> | undefined;
        if (
          !profile ||
          typeof item.id !== "string" ||
          typeof profile.widthMillimeters !== "number" ||
          typeof profile.heightMillimeters !== "number"
        ) {
          return feature;
        }
        return {
          ...createCenterRectangleSketch(
            item.id,
            item.plane === "XZ" || item.plane === "YZ" ? item.plane : "XY",
            profile.widthMillimeters,
            profile.heightMillimeters,
            true,
          ),
          name: typeof item.name === "string" ? item.name : "Sketch 1",
          suppressed:
            typeof item.suppressed === "boolean" ? item.suppressed : false,
        };
      })
    : record.features;
  return {
    ...record,
    format,
    formatVersion: PART_DOCUMENT_VERSION,
    features,
  };
}
