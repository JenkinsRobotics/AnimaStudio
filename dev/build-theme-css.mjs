#!/usr/bin/env node
// Generates core/ui/tokens/tokens.css from a theme manifest.
// Usage: node dev/build-theme-css.mjs [themeId]   (default: aether-default)
// A theme is data: both modes plus geometry/type. Widget CSS consumes only
// the emitted variables, so new themes are new manifests — no rule changes.
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const themesDir = join(repoRoot, "core/assets/themes");
const defaultId = "aether-default";
const load = (id) => JSON.parse(readFileSync(join(themesDir, `${id}.json`), "utf8"));
const theme = load(defaultId);
const otherIds = readdirSync(themesDir)
  .filter((name) => name.endsWith(".json") && name !== `${defaultId}.json`)
  .map((name) => name.replace(/\.json$/, ""));

const line = ([name, value]) => `  --aether-${name}: ${value};`;
const notes = {
  "focus-halo": `  /* Focus halo — disabled suite-wide (Jonathan, 2026-09-10): fields glowed,
     buttons never did. Every application point references this token;
     \`grep aether-focus-halo\` lists them. Re-enable per subtree by overriding. */`,
  "color-shadow": `  /* Elevation shadows are always shadow-dark; never derive them from bg-app
     or they invert into light-mode halos over dark surfaces. */`,
  "size-topbar": `  /* Jonathan 2026-09-10: home-style bar is the standard */`,
  "size-row": `  /* Constant-geometry contract: rows are size-row tall with a fixed
     size-icon-slot leading column on a size-grid rhythm — sidebars, toolbars,
     and tables build from these same blocks. */`,
};
const emit = (entries) => entries.map((entry) => (notes[entry[0]] ? `${notes[entry[0]]}\n${line(entry)}` : line(entry))).join("\n");

const css = `/* GENERATED from core/assets/themes/${defaultId}.json — do not edit by hand.
   Edit the manifest and run: node dev/build-theme-css.mjs
   Widget CSS consumes ONLY these variables; apps may re-theme by overriding
   them on :root or any subtree. */
:root {
${emit(Object.entries(theme.modes.dark))}

${emit(Object.entries(theme.geometry))}

${emit(Object.entries(theme.font))}
}

/* Light mode of the ${theme.name} theme. Colors only — geometry and type are
   shared between modes. The appearance bootstrap applies this class. */
.aether-light-theme,
.aether-light-theme .aether-home-theme {
${emit(Object.entries(theme.modes.light))}
}
`;
// Installed (non-default) themes emit side by side as scoped classes; the
// runtime selects one by putting aether-theme-<id> on <html>. Each theme
// ships both modes, so the appearance system keeps working inside any theme.
const installed = otherIds.map((id) => {
  const entry = load(id);
  return `
/* ${entry.name} (${id}) */
.aether-theme-${id} {
${emit(Object.entries(entry.modes.dark))}
}
.aether-theme-${id}.aether-light-theme,
.aether-theme-${id} .aether-home-theme.aether-light-theme,
.aether-theme-${id}.aether-light-theme .aether-home-theme {
${emit(Object.entries(entry.modes.light))}
}`;
}).join("\n");

writeFileSync(join(repoRoot, "core/ui/tokens/tokens.css"), css + installed);
console.log(`tokens.css generated from ${defaultId} (${Object.keys(theme.modes.dark).length} dark, ${Object.keys(theme.modes.light).length} light tokens; ${otherIds.length} installed theme(s))`);
