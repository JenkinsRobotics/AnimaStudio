import { mkdir, readFile, writeFile } from "node:fs/promises";

const endpoint = process.env.CDP_ENDPOINT ?? "http://127.0.0.1:9222";
const pageURL = process.env.APP_URL ?? "http://127.0.0.1:5173/";
const fixtures = process.argv.slice(2);
const testingPartAuthoring = process.env.E2E_PART === "1";
if (fixtures.length === 0 && !testingPartAuthoring) {
  throw new Error("Pass at least one STEP fixture path or set E2E_PART=1");
}

const target = await fetch(`${endpoint}/json/new?${encodeURIComponent(pageURL)}`, {
  method: "PUT",
}).then((response) => response.json());
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

let sequence = 0;
const pending = new Map();
socket.addEventListener("message", (event) => {
  const message = JSON.parse(String(event.data));
  if (!message.id) return;
  const handler = pending.get(message.id);
  if (!handler) return;
  pending.delete(message.id);
  if (message.error) handler.reject(new Error(message.error.message));
  else handler.resolve(message.result);
});

function send(method, params = {}) {
  const id = ++sequence;
  const response = new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
  socket.send(JSON.stringify({ id, method, params }));
  return response;
}

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
await send("Page.enable");
await send("Runtime.enable");
await send("DOM.enable");
await send("Emulation.setDeviceMetricsOverride", {
  width: Number(process.env.E2E_WIDTH ?? 1440),
  height: Number(process.env.E2E_HEIGHT ?? 900),
  deviceScaleFactor: 1,
  mobile: false,
});
await wait(2_000);

async function pickerNode() {
  const document = await send("DOM.getDocument", { depth: -1 });
  const result = await send("DOM.querySelector", {
    nodeId: document.root.nodeId,
    selector: "#step-picker",
  });
  return result.nodeId;
}

async function partPickerNode() {
  const document = await send("DOM.getDocument", { depth: -1 });
  const result = await send("DOM.querySelector", {
    nodeId: document.root.nodeId,
    selector: "#part-picker",
  });
  return result.nodeId;
}

async function snapshot(label) {
  const result = await send("Runtime.evaluate", {
    expression: `({
      label: ${JSON.stringify(label)},
      status: document.querySelector('#status-message')?.textContent,
      documentCount: document.querySelectorAll('.document-row').length,
      partCount: document.querySelectorAll('.part-row').length,
      bodyCount: Number(document.querySelector('#part-count')?.textContent ?? 0),
      featureCount: document.querySelectorAll('.feature-row').length,
      featureKinds: [...document.querySelectorAll('.feature-row')].map(node => node.dataset.featureKind),
      activePartName: document.querySelector('#part-name')?.value,
      selectedPartCount: document.querySelectorAll('.part-row.selected').length,
      hiddenPartCount: document.querySelectorAll('[data-toggle-part-visible][aria-label^="Show"]').length,
      connectorCount: document.querySelectorAll('.connector-row').length,
      mateCount: document.querySelectorAll('.mate-row').length,
      cylinderAxisCandidates: Number(document.querySelector('#metrics')?.dataset.cylinderAxisCandidates ?? 0),
      analyticCenterCandidates: Number(document.querySelector('#metrics')?.dataset.analyticCenterCandidates ?? 0),
      listedNames: [...document.querySelectorAll('.part-row b')].map(node => node.textContent),
      connectorToolDisabled: document.querySelector('#connector-tool')?.disabled,
      canvasCount: document.querySelectorAll('canvas').length,
      hoverText: document.querySelector('#hover-card:not(.hidden)')?.textContent,
      viewportSize: [document.querySelector('#viewport')?.clientWidth, document.querySelector('#viewport')?.clientHeight],
      viewCubeFaceCount: document.querySelectorAll('[data-camera-view]').length,
      activeBrowserPanel: document.querySelector('.browser-panel.active')?.dataset.panel,
      visibleReferenceCount: document.querySelectorAll('.reference-visibility.visible').length
    })`,
    returnByValue: true,
  });
  return result.result.value;
}

const states = [await snapshot("initial")];
if (process.env.E2E_SHELL === "1") {
  await send("Runtime.evaluate", {
    expression: `(() => {
      document.querySelector('[data-browser-panel="parameters"]')?.click();
      document.querySelector('[data-browser-panel="items"]')?.click();
      document.querySelector('[data-reference-id="top-plane"]')?.click();
      document.querySelector('[data-camera-view="front"]')?.click();
    })()`,
  });
  await wait(150);
  states.push(await snapshot("CAD shell interactions"));
}
if (testingPartAuthoring) {
  await send("Runtime.evaluate", {
    expression: "document.querySelector('#rebuild-part')?.click()",
  });
  await wait(3_000);
  states.push(await snapshot("part created"));
  await send("Runtime.evaluate", {
    expression: `(() => {
      document.querySelector('#part-name').value = 'Long Bracket';
      document.querySelector('#part-width').value = '90';
      document.querySelector('#part-height').value = '45';
      document.querySelector('#part-depth').value = '16';
      document.querySelector('#rebuild-part').click();
    })()`,
  });
  await wait(3_000);
  states.push(await snapshot("part rebuilt"));

  const downloadPath = `/tmp/aether-cad-e2e-${Date.now()}`;
  await mkdir(downloadPath, { recursive: true });
  await send("Browser.setDownloadBehavior", {
    behavior: "allow",
    downloadPath,
  });
  await send("Runtime.evaluate", {
    expression: `(() => {
      Object.defineProperty(window, 'showSaveFilePicker', {
        value: undefined,
        configurable: true
      });
      document.querySelector('#save-part').click();
    })()`,
  });
  await wait(800);
  const savedPartPath = `${downloadPath}/Long-Bracket.cadpart`;
  const savedPartDocument = JSON.parse(await readFile(savedPartPath, "utf8"));
  if (
    savedPartDocument.format !== "aether-part" ||
    savedPartDocument.features?.map((feature) => feature.type).join(",") !==
      "sketch,extrude"
  ) {
    throw new Error("Downloaded .cadpart did not preserve editable feature history");
  }
  await send("DOM.setFileInputFiles", {
    files: [savedPartPath],
    nodeId: await partPickerNode(),
  });
  await wait(2_000);
  states.push(await snapshot("part reopened"));
}
for (const fixture of fixtures) {
  await send("DOM.setFileInputFiles", {
    files: [fixture],
    nodeId: await pickerNode(),
  });
  await wait(4_000);
  states.push(await snapshot(fixture));
}

if (process.env.E2E_TREE === "1") {
  await send("Runtime.evaluate", {
    expression: "document.querySelector('.part-row')?.click()",
  });
  await wait(100);
  states.push(await snapshot("tree selection"));
  await send("Runtime.evaluate", {
    expression: "document.querySelector('[data-toggle-part-visible]')?.click()",
  });
  await wait(100);
  states.push(await snapshot("tree hidden"));
  await send("Runtime.evaluate", {
    expression: "document.querySelector('[data-toggle-part-visible]')?.click()",
  });
  await wait(100);
  states.push(await snapshot("tree visible"));
}
if (process.env.E2E_SHELL === "1") {
  const shellState = states.find((state) => state.label === "CAD shell interactions");
  if (
    shellState?.viewCubeFaceCount !== 6 ||
    shellState?.activeBrowserPanel !== "items" ||
    shellState?.visibleReferenceCount !== 1
  ) {
    throw new Error(`Expected interactive CAD shell controls: ${JSON.stringify(shellState)}`);
  }
}

if (process.env.E2E_MATE === "1" && fixtures.length >= 2) {
  await send("Runtime.evaluate", {
    expression: "document.querySelector('#connector-tool').click()",
  });
  const rectResult = await send("Runtime.evaluate", {
    expression: "document.querySelector('.viewport-canvas').getBoundingClientRect().toJSON()",
    returnByValue: true,
  });
  const rect = rectResult.result.value;
  const points = [
    [rect.left + rect.width * 0.43, rect.top + rect.height * 0.4],
    [rect.left + rect.width * 0.71, rect.top + rect.height * 0.65],
  ];
  for (const [index, [x, y]] of points.entries()) {
    await send("Runtime.evaluate", {
      expression: `(() => {
        const canvas = document.querySelector('.viewport-canvas');
        canvas.dispatchEvent(new PointerEvent('pointermove', {
          bubbles: true, clientX: ${x}, clientY: ${y},
          pointerId: 1, pointerType: 'mouse', buttons: 0
        }));
      })()`,
    });
    await wait(200);
    states.push(await snapshot(`connector hover ${index + 1}`));
    if (index === 0) {
      const candidateScreenshot = await send("Page.captureScreenshot", { format: "png" });
      await writeFile(
        "/tmp/aether-cad-candidates.png",
        Buffer.from(candidateScreenshot.data, "base64"),
      );
    }
    await send("Runtime.evaluate", {
      expression: `(() => {
        const canvas = document.querySelector('.viewport-canvas');
        canvas.dispatchEvent(new PointerEvent('pointerdown', {
          bubbles: true, clientX: ${x}, clientY: ${y}, button: 0,
          pointerId: 1, pointerType: 'mouse', buttons: 1
        }));
        canvas.dispatchEvent(new PointerEvent('pointerup', {
          bubbles: true, clientX: ${x}, clientY: ${y}, button: 0,
          pointerId: 1, pointerType: 'mouse', buttons: 0
        }));
      })()`,
    });
    await wait(300);
    states.push(await snapshot(`connector click ${index + 1}`));
  }
  states.push(await snapshot("connectors placed"));
  await send("Runtime.evaluate", {
    expression: `document.querySelector('#mate-tool').click();
      document.querySelectorAll('[data-pick-connector]')[0]?.click()`,
  });
  await wait(100);
  // The first pick deliberately re-renders the connector list, so resolve the
  // second button again rather than clicking a detached DOM node.
  await send("Runtime.evaluate", {
    expression: "document.querySelectorAll('[data-pick-connector]')[1]?.click()",
  });
  await wait(500);
  states.push(await snapshot("mate applied"));
}

const finalState = states.at(-1);
if (!testingPartAuthoring && finalState.partCount !== fixtures.length) {
  throw new Error(
    `Expected ${fixtures.length} imported Parts, found ${finalState.partCount}: ${finalState.status}`,
  );
}
if (testingPartAuthoring) {
  if (
    finalState.bodyCount !== 1 ||
    finalState.featureCount !== 3 ||
    finalState.activePartName !== "Long Bracket" ||
    finalState.featureKinds.join(",") !== "sketch,extrude,body"
  ) {
    throw new Error(
      `Expected one rebuilt Body with Sketch/Extrude/Body tree: ${JSON.stringify(finalState)}`,
    );
  }
}
if (process.env.E2E_MATE === "1") {
  if (finalState.connectorCount !== 2 || finalState.mateCount !== 1) {
    throw new Error(
      `Expected 2 connectors and 1 Fastened mate, found ${finalState.connectorCount}/${finalState.mateCount}: ${finalState.status}`,
    );
  }
}
if (process.env.E2E_TREE === "1") {
  const selected = states.find((state) => state.label === "tree selection");
  const hidden = states.find((state) => state.label === "tree hidden");
  const visible = states.find((state) => state.label === "tree visible");
  if (selected?.selectedPartCount !== 1) {
    throw new Error("Expected the Items tree to select one Part");
  }
  if (hidden?.hiddenPartCount !== 1 || visible?.hiddenPartCount !== 0) {
    throw new Error("Expected the Items tree visibility control to hide and show a Part");
  }
}
if (
  process.env.EXPECT_CYLINDER_STATIONS === "1" &&
  finalState.cylinderAxisCandidates < 3
) {
  throw new Error(
    `Expected a trimmed cylinder to expose at least 3 axis stations, found ${finalState.cylinderAxisCandidates}`,
  );
}
if (
  process.env.EXPECT_ANALYTIC_CENTERS === "1" &&
  finalState.analyticCenterCandidates < 1
) {
  throw new Error("Expected at least one exact analytic center candidate");
}

const screenshot = await send("Page.captureScreenshot", { format: "png" });
await writeFile("/tmp/aether-cad-e2e.png", Buffer.from(screenshot.data, "base64"));
process.stdout.write(`${JSON.stringify(states, null, 2)}\n`);
socket.close();
