// SPIKE config: initializes the PlaneGCS WASM module before the sketch suite
// runs, so the synchronous solver seam can compare against it.
// Run: AETHER_SOLVER=compare AETHER_SOLVER_REPORT=<file> \
//        npx vitest run --config vitest.spike.config.ts src/sketch
// Deleted with the spike.
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    setupFiles: ["./src/sketch/solver/planegcs-setup.ts"],
    // One worker: every comparison appends to a single report file.
    pool: "threads",
    poolOptions: { threads: { singleThread: true } },
  },
});
