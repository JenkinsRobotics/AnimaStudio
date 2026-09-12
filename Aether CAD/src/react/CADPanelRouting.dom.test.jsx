import { createRequire } from 'node:module';
import React, { act } from 'react';
import { beforeAll, beforeEach, afterEach, afterAll, expect, it, vi } from 'vitest';
import { cadPresentation } from '../cad-presentation-store';
import { cadWorkspace } from '../cad-workspace-store';
const require = createRequire(new URL('../../../core/ui/package.json', import.meta.url));
const { JSDOM } = require('jsdom');
let root, container, Shell, unlisten, dom;
beforeAll(async () => {
  dom = new JSDOM('<!doctype html><html><body></body></html>', {url:'http://localhost/cad/index.html', pretendToBeVisual:true});
  for (const key of ['window','document','navigator','HTMLElement','Element','Node','HTMLInputElement','Event','MouseEvent','KeyboardEvent','localStorage','location']) vi.stubGlobal(key,dom.window[key]);
  vi.stubGlobal('requestAnimationFrame',dom.window.requestAnimationFrame.bind(dom.window));
  vi.stubGlobal('cancelAnimationFrame',dom.window.cancelAnimationFrame.bind(dom.window));
  vi.stubGlobal('ResizeObserver',class { observe() {} disconnect() {} unobserve() {} });
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT',true);
  Shell=(await import('./AetherCADShell')).AetherCADShell;
});
beforeEach(async () => {
  cadPresentation.patch({activePanel:'items',startScreen:'workspace',workspaceMode:'modeling',workspaceLayout:'docked',panelPlacements:{browser:'docked',inspector:'docked',bottom:'hidden'}});
  unlisten=cadPresentation.registerActionHandler(action => {
    if(action.type==='set-panel-placement') cadPresentation.patch({panelPlacements:{...cadPresentation.snapshot().panelPlacements,[action.panel]:action.placement}});
    if(action.type==='select-panel') cadPresentation.patch({activePanel:action.panel});
  });
  container=document.createElement('div');document.body.append(container);
  const {createRoot}=await import('react-dom/client'); root=createRoot(container);
  await act(async()=>root.render(<Shell/>));
});
afterEach(async()=>{await act(async()=>root.unmount());container.remove();unlisten();});
afterAll(()=>{dom.window.close();vi.unstubAllGlobals();});
const railButton = label => [...container.querySelectorAll('.aui-rail button')].find(b=>b.getAttribute('aria-label')===label);
async function click(label){const button=railButton(label);expect(button).toBeTruthy();await act(async()=>button.click());}
function isVisible(node) { return !!node && !node.closest('[hidden]'); }
it('switches Feature tree → History → Version control → Feature tree without stacking or losing state',async()=>{
  expect(isVisible(container.querySelector('[data-panel="items"]'))).toBe(true);
  await click('History');
  expect(isVisible(container.querySelector('[aria-label="Feature history sidebar"]'))).toBe(true);
  expect(isVisible(container.querySelector('[data-panel="items"]'))).toBe(false);
  await click('Version control');
  expect(isVisible(container.querySelector('[aria-label="Saved version control"]'))).toBe(true);
  expect(isVisible(container.querySelector('[aria-label="Feature history sidebar"]'))).toBe(false);
  await click('Feature tree');
  expect(isVisible(container.querySelector('[data-panel="items"]'))).toBe(true);
  expect(isVisible(container.querySelector('[aria-label="Saved version control"]'))).toBe(false);
});
it('ribbon category changes preserve the chosen left view and right appearance is independent',async()=>{
  await click('History');
  for(const label of ['Sketch','3D Tools','Assembly','View']) {
    const tab=container.querySelector(`.cad-ribbon-navigation [aria-label="${label}"]`);
    expect(tab).toBeTruthy();await act(async()=>tab.click());
    expect(isVisible(container.querySelector('[aria-label="Feature history sidebar"]'))).toBe(true);
    expect(cadPresentation.snapshot().activePanel).toBe('items');
  }
  await click('Appearance');
  const appearance=container.querySelector('[data-panel="visualization"]');
  expect(isVisible(appearance)).toBe(true);
  expect(appearance.closest('.aui-shell-side--right')).toBeTruthy();
  expect(isVisible(container.querySelector('[aria-label="Feature history sidebar"]'))).toBe(true);
  await click('Parameters');
  expect(isVisible(appearance)).toBe(false);
  expect(isVisible(container.querySelector('[data-panel="parameters"]'))).toBe(true);
});

it('right-click on a feature row opens the Onshape-style context menu with working and greyed rows', async () => {
  const { cadWorkspace } = await import('../cad-workspace-store');
  await act(async () => cadWorkspace.publish({
    itemNodes: [{ id: 'feature/sketch/s1', label: 'Sketch 1', actions: [{ id: 'edit-feature', label: 'Edit Sketch 1', icon: '✎' }] }],
    selectedItemIDs: new Set(), expandedItemIDs: new Set(), historyItems: [], rollbackIndex: 0,
    connectorItems: [], mateItems: [], problemItems: [], inspectorSections: [], selectedConnectorIDs: new Set(), partCount: 1,
  }));
  const row = [...container.querySelectorAll('.aui-tree-row')].find((el) => el.textContent.includes('Sketch 1'));
  expect(row).toBeTruthy();
  await act(async () => row.dispatchEvent(new dom.window.MouseEvent('contextmenu', { bubbles: true, clientX: 60, clientY: 120 })));
  const menu = document.querySelector('[role="menu"]');
  expect(menu).toBeTruthy();
  const menuItem = (label) => [...menu.querySelectorAll('[role="menuitem"],[role="menuitemradio"]')].find((el) => el.textContent.includes(label));
  expect(menuItem('Rename')).toBeTruthy();
  expect(menuItem('Edit Sketch 1')).toBeTruthy();
  const section = menuItem('Section view…');
  expect(section?.getAttribute('aria-disabled') ?? String(section?.disabled)).toMatch(/true/);
  const actions = [];
  const stop = cadWorkspace.registerActionHandler((a) => actions.push(a));
  await act(async () => menuItem('Edit Sketch 1').click());
  expect(actions.at(-1)).toEqual({ type: 'item-action', id: 'feature/sketch/s1', actionID: 'edit-feature' });
  expect(document.querySelector('[role="menu"]')).toBeNull();
  stop();
});

// Delete over the tree is the only way to remove a feature without opening its
// dialog, so the key has to reach an action — and must not steal Backspace from
// a row being renamed.
it('sends Delete over the feature tree to the selected feature, but not from a rename field', async () => {
  const actions = [];
  const unregister = cadWorkspace.registerActionHandler(action => { actions.push(action); });
  await act(async () => cadWorkspace.publish({
    ...cadWorkspace.snapshot(),
    itemNodes: [{ id: 'feature/extrude/e1', label: 'Extrude 1' }],
    selectedItemIDs: new Set(['feature/extrude/e1']),
  }));
  const list = container.querySelector('#parts-list');
  const press = target => act(async () => target.dispatchEvent(
    new dom.window.KeyboardEvent('keydown', { key: 'Delete', bubbles: true }),
  ));
  await press(list);
  expect(actions).toContainEqual({ type: 'item-action', id: 'feature/extrude/e1', actionID: 'delete-feature' });

  actions.length = 0;
  const field = document.createElement('input');
  list.append(field);
  await press(field);
  expect(actions).toEqual([]);
  unregister();
});
