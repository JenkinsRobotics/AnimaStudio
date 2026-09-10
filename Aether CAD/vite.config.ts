/// <reference types="vitest/config" />
import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  resolve: {
    dedupe: ["react", "react-dom"],
  },
  optimizeDeps: {
    exclude: ["replicad-opencascadejs", "harfbuzzjs"],
  },
  server: {
    proxy: {
      "/rpc": "http://127.0.0.1:8787",
    },
    fs: {
      allow: [".", "../core"],
    },
  },
  worker: {
    format: "es",
  },
  test: {
    include: ["src/**/*.test.ts", "src/**/*.test.tsx", "src/**/*.test.jsx"],
  },
});
