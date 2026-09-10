import { layoutStore } from '../components/layout/layout-store';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CADWorkspace } from '../components/cad/CADWorkspace';
const nav = vi.hoisted(() => ({ snap: vi.fn(), fit: vi.fn() }));
vi.mock('../components/cad/CADViewport', async () => {
  const React = await import('react');
  return {
    CADViewport: React.forwardRef(function Stub(
      p: { planes: boolean[]; hidden: boolean[] },
      ref,
    ) {
      React.useImperativeHandle(ref, () => nav);
      return (
        <div
          data-testid="viewport"
          data-planes={p.planes.join(',')}
          data-hidden={p.hidden.join(',')}
        />
      );
    }),
  };
});
beforeEach(() => {
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      disconnect() {}
    },
  );
  layoutStore.resetAll();
});
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
describe('CAD workspace interactions', () => {
  it('commits and cancels sketches without duplicate feature names', async () => {
    const user = userEvent.setup();
    render(<CADWorkspace />);
    await user.click(screen.getByTitle('Sketch'));
    expect(nav.snap).toHaveBeenCalledWith('Top');
    expect(screen.getAllByTitle('Finish sketch')).toHaveLength(2);
    await user.click(screen.getAllByTitle('Finish sketch')[0]);
    expect(screen.getByText('Sketch 3')).toBeDefined();
    await user.click(screen.getByTitle('Sketch'));
    await user.click(screen.getAllByTitle('Cancel sketch')[0]);
    expect(screen.queryByText('Sketch 4')).toBeNull();
  });
  it('edits an extrusion and supports undo and redo', async () => {
    const user = userEvent.setup();
    render(<CADWorkspace />);
    await user.dblClick(screen.getByText('Extrude 1'));
    const depth = screen.getByLabelText('Depth');
    expect((depth as HTMLInputElement).value).toBe('25');
    await user.clear(depth);
    await user.type(depth, '40');
    await user.click(screen.getByRole('button', { name: 'Apply' }));
    await user.dblClick(screen.getByText('Extrude 1'));
    expect((screen.getByLabelText('Depth') as HTMLInputElement).value).toBe(
      '40',
    );
    await user.click(screen.getByTitle('Cancel feature'));
    await user.click(screen.getByTitle('Undo (Ctrl+Z)'));
    await user.dblClick(screen.getByText('Extrude 1'));
    expect((screen.getByLabelText('Depth') as HTMLInputElement).value).toBe(
      '25',
    );
    await user.click(screen.getByTitle('Cancel feature'));
    await user.click(screen.getByTitle('Redo (Ctrl+Y)'));
    await user.dblClick(screen.getByText('Extrude 1'));
    expect((screen.getByLabelText('Depth') as HTMLInputElement).value).toBe(
      '40',
    );
  });
  it('handles P and F only outside editable controls', async () => {
    const user = userEvent.setup();
    render(<CADWorkspace />);
    await user.keyboard('p');
    expect(screen.getByTestId('viewport').dataset.planes).toBe(
      'false,false,false',
    );
    await user.keyboard('f');
    expect(nav.fit).toHaveBeenCalledOnce();
    await user.click(screen.getByLabelText('Filter features and parts'));
    await user.keyboard('pf');
    expect(screen.getByTestId('viewport').dataset.planes).toBe(
      'false,false,false',
    );
    expect(nav.fit).toHaveBeenCalledOnce();
  });
  it('changes the assembly ribbon while preserving the viewport node', async () => {
    const user = userEvent.setup();
    render(<CADWorkspace />);
    const node = screen.getByTestId('viewport');
    await user.click(screen.getByRole('tab', { name: /Assembly 1/ }));
    expect(screen.getByTitle('Fastened')).toBeDefined();
    expect(screen.queryByTitle('Extrude')).toBeNull();
    expect(screen.getByTestId('viewport')).toBe(node);
    await user.click(screen.getByRole('tab', { name: /Part Studio 1/ }));
    expect(screen.getByTitle('Extrude')).toBeDefined();
  });
  it('suppresses a feature and toggles part visibility', async () => {
    const user = userEvent.setup();
    render(<CADWorkspace />);
    fireEvent.contextMenu(screen.getByText('Extrude 1'), {
      clientX: 100,
      clientY: 240,
    });
    await user.click(screen.getByRole('menuitem', { name: 'Suppress' }));
    expect(screen.getByTestId('viewport').dataset.hidden).toBe('true,false');
    await user.click(screen.getByTitle('Hide Part 2'));
    expect(screen.getByTestId('viewport').dataset.hidden).toBe('true,true');
  });
  it('rejects invalid extrusion depth and keeps the dialog open', async () => {
    const user = userEvent.setup();
    render(<CADWorkspace />);
    await user.click(screen.getByTitle('Extrude'));
    await user.clear(screen.getByLabelText('Depth'));
    await user.type(screen.getByLabelText('Depth'), '-5');
    expect(
      (
        screen.getByRole('button', {
          name: 'Apply',
        }) as HTMLButtonElement
      ).disabled,
    ).toBe(true);
    expect(screen.getByRole('alert').textContent).toContain('depth');
  });
});
