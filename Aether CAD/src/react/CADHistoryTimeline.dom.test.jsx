import { createRequire } from 'node:module';
import React, { act } from 'react';
import { beforeAll, beforeEach, afterEach, afterAll, expect, it, vi } from 'vitest';
const require = createRequire(new URL('../../../core/ui/package.json', import.meta.url));
const { JSDOM } = require('jsdom');
let dom, container, root, Timeline, cadWorkspace, actions, unlisten;
const items = [
  { id: 'history/feature/s1', label: 'Sketch 1', description: 'Sketch feature', icon: 'S' },
  { id: 'history/feature/e1', label: 'Extrude 1', description: 'Solid feature', icon: 'E' },
  { id: 'history/feature/p1', label: 'Plane 1', description: 'Rolled back', icon: 'P' },
  { id: 'history/mate/m1', label: 'Fastened Mate 1', description: '', icon: 'M' },
];
beforeAll(async () => {
  dom = new JSDOM('<!doctype html><html><body></body></html>', { url: 'http://localhost/cad/index.html', pretendToBeVisual: true });
  for (const key of ['window','document','navigator','HTMLElement','Element','Node','Event','MouseEvent','KeyboardEvent','localStorage','location']) vi.stubGlobal(key, dom.window[key]);
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  Timeline = (await import('./CADHistoryTimeline')).CADHistoryTimeline;
  cadWorkspace = (await import('../cad-workspace-store')).cadWorkspace;
});
beforeEach(async () => {
  actions = [];
  unlisten = cadWorkspace.registerActionHandler((action) => actions.push(action));
  container = document.createElement('div'); document.body.append(container);
  const { createRoot } = await import('react-dom/client'); root = createRoot(container);
  await act(async () => root.render(<Timeline items={items} rollbackIndex={2} />));
});
afterEach(async () => { await act(async () => root.unmount()); container.remove(); unlisten(); });
afterAll(() => { dom.window.close(); vi.unstubAllGlobals(); });
const byLabel = (label) => [...container.querySelectorAll('button')].find((b) => b.getAttribute('aria-label') === label);

it('renders icons only with names in tooltips, dims rolled-back features, skips non-features', () => {
  const chips = container.querySelectorAll('.cad-history-chip');
  expect(chips).toHaveLength(3);
  expect(byLabel('Sketch 1').textContent).toBe('S');
  expect(container.textContent).not.toContain('Sketch 1');
  expect(byLabel('Plane 1').className).toContain('cad-history-chip--dimmed');
  expect(byLabel('Sketch 1').className).not.toContain('dimmed');
  const strip = container.querySelector('.cad-history-strip');
  expect([...strip.children].indexOf(container.querySelector('.cad-history-marker'))).toBe(2);
});

it('playback controls and marker keys dispatch rollback actions; chips activate history', async () => {
  await act(async () => byLabel('Roll back one feature').click());
  expect(actions.at(-1)).toEqual({ type: 'item-action', id: 'rollback-bar', actionID: 'rollback-back' });
  await act(async () => byLabel('Roll forward to end').click());
  expect(actions.at(-1)).toEqual({ type: 'item-action', id: 'rollback-bar', actionID: 'rollback-end' });
  const marker = container.querySelector('.cad-history-marker');
  await act(async () => marker.dispatchEvent(new dom.window.KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true })));
  expect(actions.at(-1)).toEqual({ type: 'item-action', id: 'rollback-bar', actionID: 'rollback-forward' });
  await act(async () => byLabel('Extrude 1').click());
  expect(actions.at(-1)).toEqual({ type: 'activate-history', id: 'history/feature/e1' });
});

it('start controls disable at zero with the marker before all chips', async () => {
  await act(async () => root.render(<Timeline items={items} rollbackIndex={0} />));
  expect(byLabel('Roll back to start').disabled).toBe(true);
  const strip = container.querySelector('.cad-history-strip');
  expect(strip.firstElementChild.className).toBe('cad-history-marker');
});
