import { build } from "esbuild";
import { copyFile, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const output = resolve(root, "../../Resources/ThreeJSWeb");
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await build({
  entryPoints: [resolve(root, "src/app.js")],
  outfile: resolve(output, "app.js"),
  bundle: true,
  format: "iife",
  platform: "browser",
  target: ["safari17"],
  minify: true,
  sourcemap: false,
  legalComments: "eof"
});
await copyFile(resolve(root, "src/index.html"), resolve(output, "index.html"));
