import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname } from "node:path";
import { pathToFileURL } from "node:url";

const source = process.argv[2];
if (!source) throw new Error("Usage: npm run smoke:step -- /path/to/model.step");

// The Replicad OCCT bundle is generated as classic Emscripten JavaScript even
// though npm exposes it as ESM. Supply its expected Node globals for this
// command-line smoke test; the browser build uses the explicit wasmBinary path.
const corePackageURL = new URL("../../core/engine/package.json", import.meta.url);
const coreRequire = createRequire(corePackageURL);
const openCascadePath = coreRequire.resolve("replicad-opencascadejs");
const replicadURL = new URL("./node_modules/replicad/dist/replicad.js", corePackageURL);
globalThis.require = coreRequire;
globalThis.__dirname = dirname(openCascadePath);
const [{ default: initOpenCascade }, { importSTEP, setOC }] = await Promise.all([
  import(pathToFileURL(openCascadePath).href),
  import(replicadURL.href),
]);
try {
  const wasmBytes = await readFile(
    new URL("./replicad_single.wasm", pathToFileURL(openCascadePath)),
  );
  const oc = await initOpenCascade({ wasmBinary: wasmBytes });
  setOC(oc);
  const bytes = await readFile(source);
  const shape = await importSTEP(new Blob([bytes]));
  const faces = shape.faces;
  const surfaceCounts = new Map();
  let analyticCandidates = 0;

  for (const face of faces) {
    const type = face.geomType;
    surfaceCounts.set(type, (surfaceCounts.get(type) ?? 0) + 1);
    analyticCandidates += 1 + face.edges.length * 3;
    face.delete();
  }

  const mesh = shape.mesh({ tolerance: 0.08, angularTolerance: 0.12 });
  console.log(
    JSON.stringify(
      {
        source,
        faces: faces.length,
        surfaces: Object.fromEntries(surfaceCounts),
        retainedFaceGroups: mesh.faceGroups.length,
        triangles: mesh.triangles.length / 3,
        minimumInferredCandidates: analyticCandidates,
      },
      null,
      2,
    ),
  );

  shape.delete();
} catch (error) {
  console.error(`STEP smoke failed: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
}
