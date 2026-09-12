#!/usr/bin/env node
// Shared-widget guard: product CSS must not restyle shared components.
// Appearance belongs to core/ui; products compose components and pass options.
// A product may still key off its OWN class on a shared element (e.g.
// `.library-nav.aui-sidebar--collapsed .library-create`) — those read as
// composition, so only selectors whose *last* simple selector is an .aui-*
// class are reported.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const roots = ["Aether CAD/src", "studio/src", "aether-animation/web/src"];
const cssFiles = [];
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === "dist") continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (name.endsWith(".css")) cssFiles.push(path);
  }
};
for (const root of roots) {
  try { walk(join(repoRoot, root)); } catch { /* app not present */ }
}
let findings = 0;
for (const file of cssFiles) {
  readFileSync(file, "utf8").split("\n").forEach((line, index) => {
    const selector = line.split("{")[0];
    if (!/\.aui-/.test(selector) || !line.includes("{")) return;
    const offenders = selector.split(",").map((part) => part.trim()).filter((part) => {
      const last = part.split(/[\s>+~]+/).filter(Boolean).at(-1) ?? "";
      // Last element styled is a shared widget class with no product class on it.
      return /\.aui-/.test(last) && !/\.(cad|library|studio|setup|anim)[a-z-]*\b/.test(last);
    });
    if (!offenders.length) return;
    findings += 1;
    console.log(`${file.replace(repoRoot + "/", "")}:${index + 1}: ${offenders.join(", ")}`);
  });
}
console.log(findings
  ? `\n${findings} product rule(s) restyle shared widgets. Move the behavior into core/ui (component option) and delete the override.`
  : "No product CSS restyles shared widgets.");
