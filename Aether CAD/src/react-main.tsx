import "@aether/ui/tokens.css";
import "@aether/ui/widgets.css";
import "./style.css";
import "./react/shapr-shell.css";
import { StrictMode } from "react";
import { flushSync } from "react-dom";
import { createRoot } from "react-dom/client";
import { AetherCADShell } from "./react/AetherCADShell";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("Missing #app root");

flushSync(() => {
  createRoot(app).render(
    <StrictMode>
      <AetherCADShell />
    </StrictMode>,
  );
});

// The existing CAD controller binds after React commits the stable shell.
// This keeps the OCCT worker and Three.js/WebGPU viewport imperative and
// persistent while React owns every piece of application chrome.
//
// The shell renders before the controller loads, so a controller failure
// would otherwise look like a healthy app with an empty document. Announce
// it instead: the tray shows the failure and the panels say why.
import("./main").catch(async (error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error("Aether CAD controller failed to start:", error);
  const { cadPresentation } = await import("./cad-presentation-store");
  cadPresentation.patch({
    backendState: "failed",
    backendLabel: "Controller failed to start",
    statusMessage: `Aether CAD could not start: ${message}. Reload the page; if it repeats, this is a bug — the console has the stack.`,
    statusTone: "error",
  });
});
