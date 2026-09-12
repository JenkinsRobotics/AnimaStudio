// SPIKE setup: initialize the PlaneGCS WASM module and register the comparison
// hook, so every solve the sketch suite performs is also run through FreeCAD's
// solver and recorded. Deleted with the spike.
import { initPlanegcsSpike, recordComparison } from "./planegcs-spike";

await initPlanegcsSpike();
(globalThis as Record<string, unknown>).__aetherSolverComparison = recordComparison;
