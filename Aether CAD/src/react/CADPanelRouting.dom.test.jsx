import { createRequire } from 'node:module';
import React, { act } from 'react';
import { beforeAll, beforeEach, afterEach, afterAll, expect, it, vi } from 'vitest';
import { cadPresentation } from '../cad-presentation-store';
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
it('switches Model → History → Version control → Model without stacking or losing state',async()=>{
  expect(isVisible(container.querySelector('[data-panel="items"]'))).toBe(true);
  await click('History');
  expect(isVisible(container.querySelector('[aria-label="Feature history sidebar"]'))).toBe(true);
  expect(isVisible(container.querySelector('[data-panel="items"]'))).toBe(false);
  await click('Version control');
  expect(isVisible(container.querySelector('[aria-label="Saved version control"]'))).toBe(true);
  expect(isVisible(container.querySelector('[aria-label="Feature history sidebar"]'))).toBe(false);
  await click('Model');
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
