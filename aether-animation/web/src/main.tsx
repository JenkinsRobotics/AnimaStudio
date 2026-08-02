import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "@aether/ui/tokens.css";
import "@aether/ui/widgets.css";
import "./app.css";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>
);
