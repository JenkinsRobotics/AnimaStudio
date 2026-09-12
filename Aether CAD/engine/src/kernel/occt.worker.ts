import initOpenCascade from "replicad-opencascadejs";
import wasmUrl from "replicad-opencascadejs/src/replicad_single.wasm?url";
import type { OpenCascadeInstance } from "replicad-opencascadejs";
import { importSTEP, setOC } from "replicad";
import type {
  ImportedModelData,
  WorkerRequest,
  WorkerResponse,
} from "../contracts/index";
import { evaluatePartDocument } from "./part-evaluator";
import { buildPartGeometry } from "./part-geometry";

let initialized: Promise<void> | undefined;

async function ensureInitialized(): Promise<void> {
  if (!initialized) {
    initialized = (async () => {
      const response = await fetch(wasmUrl);
      if (!response.ok) throw new Error(`Could not fetch OCCT WASM (${response.status})`);
      const wasmBinary = await response.arrayBuffer();
      // The generated package declaration omits Emscripten's optional module
      // arguments even though the runtime accepts them. Passing wasmBinary
      // makes worker startup deterministic under Vite instead of relying on
      // Emscripten to reconstruct the emitted asset URL.
      const initialize = initOpenCascade as unknown as (options: {
        wasmBinary: ArrayBuffer;
      }) => Promise<OpenCascadeInstance>;
      const oc = await initialize({ wasmBinary });
      setOC(oc);
    })();
  }
  await initialized;
}

async function importModel(
  sourceName: string,
  bytes: ArrayBuffer,
): Promise<ImportedModelData> {
  await ensureInitialized();
  const started = performance.now();
  const imported = await importSTEP(new Blob([bytes]));
  const sourceDocumentId = crypto.randomUUID();
  try {
    return {
      sourceName,
      // One imported STEP document is one independently movable Part. The
      // complete shape keeps assembly sub-solids in their source coordinates
      // and, unlike Replicad's per-solid browser wrappers, reliably exposes
      // analytic faces on curved CAD. Import separate STEP files when the
      // operator needs separately movable Parts.
      parts: [buildPartGeometry(imported, sourceDocumentId, sourceName, 0)],
      parseMilliseconds: performance.now() - started,
    };
  } finally {
    imported.delete();
  }
}

self.onmessage = async (event: MessageEvent<WorkerRequest>) => {
  const request = event.data;
  try {
    const model =
      request.type === "import-step"
        ? await importModel(request.sourceName, request.bytes)
        : (await ensureInitialized(), evaluatePartDocument(request.document));
    const transfer: Transferable[] = [];
    for (const part of model.parts) {
      transfer.push(
        part.vertices.buffer,
        part.normals.buffer,
        part.triangles.buffer,
        part.edgeLines.buffer,
      );
    }
    const response: WorkerResponse = {
      type: request.type === "import-step" ? "imported" : "part-evaluated",
      requestId: request.requestId,
      model,
    };
    self.postMessage(response, { transfer });
  } catch (error) {
    const response: WorkerResponse = {
      type: "error",
      requestId: request.requestId,
      message: error instanceof Error ? error.message : String(error),
    };
    self.postMessage(response);
  }
};

ensureInitialized()
  .then(() => {
    const response: WorkerResponse = { type: "ready" };
    self.postMessage(response);
  })
  .catch((error) => {
    const response: WorkerResponse = {
      type: "error",
      message: error instanceof Error ? error.message : String(error),
    };
    self.postMessage(response);
  });

