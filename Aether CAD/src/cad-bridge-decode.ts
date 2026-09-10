export type JsonRecord = Record<string, unknown>;

export class ProjectionDecodeError extends Error {
  constructor(
    readonly path: string,
    message: string,
  ) {
    super(`${path}: ${message}`);
    this.name = "ProjectionDecodeError";
  }
}

export function record(value: unknown, path: string): JsonRecord {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new ProjectionDecodeError(path, "expected object");
  }
  return value as JsonRecord;
}

export function array(value: unknown, path: string): readonly unknown[] {
  if (!Array.isArray(value)) {
    throw new ProjectionDecodeError(path, "expected array");
  }
  return value;
}

export function string(value: unknown, path: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new ProjectionDecodeError(path, "expected non-empty string");
  }
  return value;
}

export function text(value: unknown, path: string): string {
  if (typeof value !== "string") {
    throw new ProjectionDecodeError(path, "expected string");
  }
  return value;
}

export function nullableString(value: unknown, path: string): string | null {
  return value === null ? null : string(value, path);
}

export function boolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") {
    throw new ProjectionDecodeError(path, "expected boolean");
  }
  return value;
}

export function number(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ProjectionDecodeError(path, "expected finite number");
  }
  return value;
}

export function nullableNumber(value: unknown, path: string): number | null {
  return value === null ? null : number(value, path);
}

export function oneOf<T extends string>(
  value: unknown,
  values: readonly T[],
  path: string,
): T {
  const candidate = string(value, path);
  if (!values.includes(candidate as T)) {
    throw new ProjectionDecodeError(
      path,
      `expected one of ${values.join(", ")}`,
    );
  }
  return candidate as T;
}

export function tuple(
  value: unknown,
  length: number,
  path: string,
): readonly number[] {
  const values = array(value, path);
  if (values.length !== length) {
    throw new ProjectionDecodeError(path, `expected ${length} numbers`);
  }
  values.forEach((item, index) => number(item, `${path}[${index}]`));
  return values as readonly number[];
}

export function stringArray(value: unknown, path: string): void {
  array(value, path).forEach((item, index) => string(item, `${path}[${index}]`));
}
