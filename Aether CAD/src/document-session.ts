/** Accessor over the existing host session; this module never owns another document. */
let context: () => {
  id: string;
  revision: number;
  writable: boolean;
} | null = () => null;
let clean: () => void = () => {};
export function configureDocumentSession(
  getContext: typeof context,
  assertClean: typeof clean,
) {
  context = getContext;
  clean = assertClean;
}
export function documentSession() {
  return context();
}
export function requireSavedDocument() {
  clean();
  const value = context();
  if (!value) throw new Error("Save this document to your server first.");
  return value;
}
