// Measure real layout in a real browser. jsdom has no layout engine, so CSS
// sizing bugs (a panel that stops short of the bottom edge) cannot be unit
// tested — this drives Playwright's cached headless shell over CDP using
// Node's built-in WebSocket, so it adds no dependency to the repo.
//
//   node dev/measure-layout.mjs http://localhost:5301/ '(() => ...)()'
//
// The second argument is evaluated in the page and its value printed as JSON.
// ponytail: fixed settle delay instead of readiness polling — pass a
// promise-returning expression when a flow needs longer.

import { spawn } from "node:child_process";
import { homedir } from "node:os";

const SHELL = `${homedir()}/Library/Caches/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-mac-arm64/chrome-headless-shell`;
const [url, expression] = process.argv.slice(2);
const port = 9333;
const proc = spawn(SHELL, [
  `--remote-debugging-port=${port}`, "--window-size=1440,900",
  "--no-first-run", "--disable-gpu", "--hide-scrollbars", "about:blank",
], { stdio: "ignore" });

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
let ws, id = 0;
const pending = new Map();
const send = (method, params) => new Promise((resolve) => {
  const message = ++id;
  pending.set(message, resolve);
  ws.send(JSON.stringify({ id: message, method, params }));
});

try {
  // The browser-level endpoint has no Page/Runtime domain — attach to the page.
  let page;
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      page = targets.find((target) => target.type === "page");
      if (page) break;
    } catch { /* not listening yet */ }
    await wait(250);
  }
  ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) pending.get(message.id)(message.result);
  };
  await send("Page.enable");
  await send("Page.navigate", { url });
  await wait(6000);
  const { result, exceptionDetails } = await send("Runtime.evaluate", {
    expression, returnByValue: true, awaitPromise: true,
  });
  console.log(exceptionDetails ? JSON.stringify(exceptionDetails.exception, null, 2) : JSON.stringify(result.value, null, 2));
} finally {
  ws?.close();
  proc.kill();
}
