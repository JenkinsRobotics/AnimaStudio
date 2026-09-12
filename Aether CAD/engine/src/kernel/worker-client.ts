import type {
  ImportedModelData,
  WorkerRequest,
  WorkerResponse,
} from "../contracts/index";
import type { PartDocument } from "../document/index";

interface PendingRequest {
  resolve: (model: ImportedModelData) => void;
  reject: (error: Error) => void;
}

export class OCCTWorkerClient {
  private readonly worker = new Worker(
    new URL("./occt.worker.ts", import.meta.url),
    { type: "module" },
  );
  private readonly pending = new Map<number, PendingRequest>();
  private nextRequestId = 1;
  private readyResolve: (() => void) | undefined;
  private readyReject: ((error: Error) => void) | undefined;
  readonly ready = new Promise<void>((resolve, reject) => {
    this.readyResolve = resolve;
    this.readyReject = reject;
  });

  constructor() {
    this.worker.onmessage = (event: MessageEvent<WorkerResponse>) => {
      const response = event.data;
      if (response.type === "ready") {
        this.readyResolve?.();
        return;
      }
      if (response.type === "error" && response.requestId === undefined) {
        this.readyReject?.(new Error(response.message));
        return;
      }
      if (response.type === "error") {
        const pending = this.pending.get(response.requestId ?? -1);
        if (!pending) return;
        this.pending.delete(response.requestId ?? -1);
        pending.reject(new Error(response.message));
        return;
      }
      const pending = this.pending.get(response.requestId);
      if (!pending) return;
      this.pending.delete(response.requestId);
      pending.resolve(response.model);
    };
    this.worker.onerror = (event) => {
      const error = new Error(event.message || "OCCT worker failed");
      this.readyReject?.(error);
      for (const request of this.pending.values()) request.reject(error);
      this.pending.clear();
    };
  }

  async importSTEP(file: File): Promise<ImportedModelData> {
    await this.ready;
    const requestId = this.nextRequestId++;
    const bytes = await file.arrayBuffer();
    const promise = new Promise<ImportedModelData>((resolve, reject) => {
      this.pending.set(requestId, { resolve, reject });
    });
    const request: WorkerRequest = {
      type: "import-step",
      requestId,
      sourceName: file.name,
      bytes,
    };
    this.worker.postMessage(request, [bytes]);
    return promise;
  }

  async evaluatePart(document: PartDocument): Promise<ImportedModelData> {
    await this.ready;
    const requestId = this.nextRequestId++;
    const promise = new Promise<ImportedModelData>((resolve, reject) => {
      this.pending.set(requestId, { resolve, reject });
    });
    const request: WorkerRequest = {
      type: "evaluate-part",
      requestId,
      document,
    };
    this.worker.postMessage(request);
    return promise;
  }

  dispose(): void {
    this.worker.terminate();
  }
}

