import { createRequire } from "node:module";
import {
  afterAll,
  beforeAll,
  beforeEach,
  afterEach,
  expect,
  it,
  vi,
} from "vitest";
import React, { act } from "react";
import { unitCatalog } from "@aether/core/units";
import { configureDocumentSession } from "../document-session";
const require = createRequire(
  new URL("../../../core/ui/package.json", import.meta.url),
);
const { JSDOM } = require("jsdom");
let root;
let container;
let Settings;
let calls = [];
let dirty = false;
const metadata = () => ({
  id: "file-1",
  name: "Wheel.acad",
  revision: 5,
  writable: true,
  scope: "personal",
  parent: null,
  settings: {
    description: "Wheel description",
    workspaceName: "Main",
    workspaceDescription: "",
    revisionManaged: true,
    units: Object.fromEntries(
      Object.entries(unitCatalog).map(([key, value]) => [
        key,
        { unit: value.default, decimals: 3 },
      ]),
    ),
  },
  items: [
    {
      id: "workspace",
      kind: "workspace",
      name: "Main",
      description: "",
      category: "Workspace",
    },
  ],
  deleted: [{ id: "part-2", kind: "part", name: "Deleted hub" }],
  updates: [],
  upgradeDocuments: {},
  upgradeNeeded: false,
  featureVersion: 3,
});
beforeAll(async () => {
  const dom = new JSDOM("<!doctype html><html><body></body></html>", {
    url: "http://localhost/cad/index.html?document=file-1",
    pretendToBeVisual: true,
  });
  for (const key of [
    "window",
    "document",
    "navigator",
    "HTMLElement",
    "Element",
    "Node",
    "HTMLInputElement",
    "Event",
    "MouseEvent",
    "KeyboardEvent",
  ])
    vi.stubGlobal(key, dom.window[key]);
  vi.stubGlobal(
    "requestAnimationFrame",
    dom.window.requestAnimationFrame.bind(dom.window),
  );
  vi.stubGlobal(
    "cancelAnimationFrame",
    dom.window.cancelAnimationFrame.bind(dom.window),
  );
  vi.stubGlobal("IS_REACT_ACT_ENVIRONMENT", true);
  Settings = (await import("./CADDocumentSettings")).CADDocumentSettings;
});
beforeEach(async () => {
  calls = [];
  dirty = false;
  vi.stubGlobal("location", {
    href: "http://localhost/cad/index.html?document=file-1",
    pathname: "/cad/index.html",
    search: "?document=file-1",
    assign: vi.fn(),
  });
  configureDocumentSession(
    () => ({ id: "file-1", revision: 5, writable: true }),
    () => {
      if (dirty) throw new Error("Save your current edits first.");
    },
  );
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url, options) => {
      const data = JSON.parse(options.body);
      const action = url.split("/").at(-1);
      calls.push({ action, data });
      return {
        ok: true,
        json: async () =>
          action === "cad_metadata"
            ? metadata()
            : action === "list"
              ? {
                  files: [
                    {
                      id: "folder-1",
                      name: "Wheels",
                      kind: "folder",
                      writable: true,
                    },
                    {
                      id: "other",
                      name: "Other owner",
                      kind: "folder",
                      writable: false,
                    },
                  ],
                }
              : { id: "copy-1", revision: 6 },
      };
    }),
  );
  container = document.createElement("div");
  document.body.append(container);
  const { createRoot } = await import("react-dom/client");
  root = createRoot(container);
});
afterEach(async () => {
  await act(async () => root.unmount());
  container.remove();
});
afterAll(() => vi.unstubAllGlobals());
async function render(action) {
  await act(async () => {
    root.render(<Settings action={action} onClose={() => {}} />);
  });
}
async function click(label) {
  const button = Array.from(document.querySelectorAll("button")).find(
    (b) => b.textContent?.trim() === label,
  );
  expect(button).toBeTruthy();
  await act(async () => button.click());
}
it("persists selected workspace units with the optimistic revision", async () => {
  await render("units");
  const select = document.querySelector("#unit-length");
  expect(select).toBeTruthy();
  await act(async () => {
    select.value = "in";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await click("Save");
  const request = calls.find((c) => c.action === "cad_operation");
  expect(request.data.units.length.unit).toBe("in");
  expect(request.data.expected_revision).toBe(5);
  expect(location.assign).toHaveBeenCalled();
});
it("navigates an owned destination folder and sends move to the backend", async () => {
  await render("move");
  expect(document.body.textContent).not.toContain("Other owner");
  await click("▱ Wheels");
  await click("Move here");
  expect(calls.find((c) => c.action === "cad_operation")?.data).toMatchObject({
    operation: "move",
    parent: "folder-1",
  });
});
it("restores a deleted project tab with its original identity", async () => {
  await render("restore");
  await click("Restore");
  expect(calls.find((c) => c.action === "cad_operation")?.data).toMatchObject({
    operation: "restore_item",
    item_id: "part-2",
    expected_revision: 5,
  });
});
it("keeps dirty edits intact instead of reloading after a metadata change", async () => {
  dirty = true;
  await render("details");
  await click("Save");
  expect(calls.some((c) => c.action === "cad_operation")).toBe(false);
  expect(document.body.textContent).toContain("Save your current edits first");
  expect(location.assign).not.toHaveBeenCalled();
});
it("opens a printable viewport page with escaped document text", async () => {
  const preview = new JSDOM("<html><head></head><body></body></html>").window;
  preview.focus = vi.fn();
  preview.print = vi.fn();
  preview.close = vi.fn();
  preview.HTMLImageElement.prototype.decode = vi.fn(async () => {});
  vi.spyOn(window, "open").mockReturnValue(preview);
  const { configureDocumentPrint, printDocument } =
    await import("../document-print");
  configureDocumentPrint(async () => "data:image/png;base64,AAAA");
  await printDocument("<Wheel>");
  expect(preview.document.querySelector("h1").textContent).toBe("<Wheel>");
  expect(preview.document.querySelector("img").src).toBe(
    "data:image/png;base64,AAAA",
  );
  expect(preview.document.body.textContent).toContain("not to scale");
  expect(preview.print).toHaveBeenCalled();
});
it("applies properties without closing, then reloads the saved document on close", async () => {
  await render("properties");
  await click("Apply");
  expect(calls.find(c => c.action === "cad_operation")?.data.operation).toBe("properties");
  expect(location.assign).not.toHaveBeenCalled();
  await click("Close");
  expect(location.assign).toHaveBeenCalled();
});
