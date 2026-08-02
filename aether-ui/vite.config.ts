/// <reference types="vitest/config" />
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  root: "gallery",
  plugins: [react()],
  build: { outDir: "../dist", emptyOutDir: true },
  test: {
    root: ".",
    environment: "jsdom",
    globals: true,
    include: ["src/**/*.test.tsx"],
  },
});
