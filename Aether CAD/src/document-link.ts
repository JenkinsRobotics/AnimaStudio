/** Only stable document routing is shareable; never copy fragments/setup tokens. */
export function documentLink(address: string): string | null {
  const source = new URL(address);
  if (!source.searchParams.get("document")) return null;
  const link = new URL("/cad/index.html", source.origin);
  for (const key of ["document", "part", "assembly", "revision"]) {
    const value = source.searchParams.get(key);
    if (value) link.searchParams.set(key, value);
  }
  return link.href;
}
export function documentRevision(address: string): string {
  const revision = new URL(address).searchParams.get("revision");
  return revision && /^\d+$/.test(revision) ? `Revision ${revision}` : "Main";
}
