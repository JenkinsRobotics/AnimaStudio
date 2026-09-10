export async function api<T>(path: string, body?: object): Promise<T> {
  const response = await fetch(
    path,
    body
      ? {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        }
      : {},
  );
  const data = await response.json();
  if (!response.ok)
    throw new Error(data.error ?? "The request could not be completed.");
  if (body && ["/api/login", "/api/logout", "/api/profile", "/api/setup", "/api/password"].includes(path))
    document.dispatchEvent(new Event("aether-account-refresh"));
  return data as T;
}
