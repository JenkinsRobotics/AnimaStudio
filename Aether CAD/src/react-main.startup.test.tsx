import { expect, test, vi } from "vitest";
import { cadPresentation } from "./cad-presentation-store";

/** The shell renders before the controller loads, so a controller failure must
 * announce itself instead of leaving a healthy-looking empty app. */
test("a controller import failure puts the app into a visible failed state", async () => {
  const failure = new Error("boom");
  const error = vi.spyOn(console, "error").mockImplementation(() => {});
  await Promise.reject(failure).catch(async (thrown: unknown) => {
    const message = thrown instanceof Error ? thrown.message : String(thrown);
    console.error("Aether CAD controller failed to start:", thrown);
    cadPresentation.patch({
      backendState: "failed",
      backendLabel: "Controller failed to start",
      statusMessage: `Aether CAD could not start: ${message}. Reload the page; if it repeats, this is a bug — the console has the stack.`,
      statusTone: "error",
    });
  });
  const snapshot = cadPresentation.snapshot();
  expect(snapshot.backendState).toBe("failed");
  expect(snapshot.backendLabel).toBe("Controller failed to start");
  expect(snapshot.statusMessage).toContain("boom");
  expect(snapshot.statusTone).toBe("error");
  expect(error).toHaveBeenCalled();
  error.mockRestore();
});
