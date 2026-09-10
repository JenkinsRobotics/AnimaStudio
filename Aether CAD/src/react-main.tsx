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
void import("./main");
