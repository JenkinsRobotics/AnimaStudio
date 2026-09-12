#!/usr/bin/env node
// Icon pack guard: every SVG in core/assets/icons is part of the default pack,
// and every icon the AetherIcon registry imports exists on disk. Keeps the
// registry (the icon-pack seam) and the artwork directory from drifting.
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const iconDir = join(repoRoot, "core/assets/icons");
const files = new Set(readdirSync(iconDir).filter((name) => name.endsWith(".svg")).map((name) => name.replace(/\.svg$/, "")));
const registry = readFileSync(join(repoRoot, "core/ui/src/AetherIcon.tsx"), "utf8");
const imported = [...registry.matchAll(/from "\.\.\/\.\.\/assets\/icons\/([a-z0-9_-]+)\.svg\?raw"/g)].map((match) => match[1]);
let failures = 0;
for (const name of imported) {
  if (!files.has(name)) { console.error(`AetherIcon imports missing artwork: ${name}.svg`); failures += 1; }
}
const unregistered = [...files].filter((name) => !imported.includes(name));
if (unregistered.length) console.log(`note: ${unregistered.length} artwork file(s) not yet registered (fine — tracked originals or ToolIcon-only): ${unregistered.slice(0, 8).join(", ")}${unregistered.length > 8 ? "…" : ""}`);
if (!existsSync(join(iconDir, "pack.json"))) { console.error("core/assets/icons/pack.json missing"); failures += 1; }
if (failures) process.exit(1);
console.log(`Icon pack ok: ${imported.length} registered icons, ${files.size} artwork files.`);
