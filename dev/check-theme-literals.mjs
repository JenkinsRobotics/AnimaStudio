#!/usr/bin/env node
// Theme guard: app CSS must express color through tokens/variables.
// Raw color literals are allowed ONLY where palettes are DEFINED:
// custom-property declarations (--name: …) or a line marked /* literal-ok */.
// Scope today: studio/src. Expand per-app as each stylesheet is tokenized
// (ponytail: CAD + animation sweeps are follow-up packets).
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const roots = [join(repoRoot, "studio/src")];
const colorPattern = /#[0-9a-fA-F]{3,8}\b|rgba?\(/;
let violations = 0;
for (const root of roots) {
  for (const file of readdirSync(root).filter((name) => name.endsWith(".css"))) {
    const path = join(root, file);
    readFileSync(path, "utf8").split("\n").forEach((line, index) => {
      const trimmed = line.trim().replace(/var\([^)]*\)/g, "var()");
      if (!colorPattern.test(trimmed)) return;
      if (trimmed.startsWith("--")) return;
      if (trimmed.includes("literal-ok")) return;
      violations += 1;
      console.log(`${path}:${index + 1}: ${trimmed}`);
    });
  }
}
if (violations) {
  console.error(`\n${violations} raw color literal(s) — route them through --aether-* or scoped theme variables.`);
  process.exit(1);
}
console.log("No raw color literals outside theme variable declarations.");
