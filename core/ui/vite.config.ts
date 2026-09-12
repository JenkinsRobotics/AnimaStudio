/// <reference types="vitest/config" />
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The engine lives in the CAD product (Aether CAD/engine). The gallery demos
// the real pipeline, so it resolves @aether/core straight from that source —
// npm's symlink alone is not enough because the target sits outside this
// project root.
const engine = fileURLToPath(new URL("../../Aether CAD/engine/src/", import.meta.url));

export default defineConfig({
  root: "gallery",
  base: "./",
  plugins: [react()],
  resolve: {
    alias: [
      { find: "@aether/core/units", replacement: `${engine}units.ts` },
      { find: /^@aether\/core\/(.+)$/, replacement: `${engine}$1/index.ts` },
      { find: "@aether/core", replacement: `${engine}index.ts` },
    ],
  },
  server: { fs: { allow: ["..", engine] } },
  build: { outDir: "../dist", emptyOutDir: true },
  test: {
    root: ".",
    environment: "jsdom",
    globals: true,
    include: ["src/**/*.test.tsx"],
  },
});
