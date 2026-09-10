export type Feature = {
  id: string;
  name: string;
  kind: string;
  suppressed?: boolean;
  depthMm?: number;
};
export type ElementTab = {
  id: string;
  name: string;
  kind: 'part' | 'assembly' | 'drawing';
};
export type DisplayStyle =
  | 'Shaded with edges'
  | 'Shaded'
  | 'Hidden edges visible'
  | 'Wireframe';
export type ViewName =
  | 'Isometric'
  | 'Top'
  | 'Front'
  | 'Right'
  | 'Left'
  | 'Back'
  | 'Bottom';
export type ViewportHandle = {
  snap: (view: ViewName) => void;
  fit: () => void;
};
export const initialFeatures: Feature[] = [
  { id: 's1', name: 'Sketch 1', kind: 'Sketch' },
  { id: 'e1', name: 'Extrude 1', kind: 'Extrude', depthMm: 25 },
  { id: 's2', name: 'Sketch 2', kind: 'Sketch' },
  { id: 'h1', name: 'Hole 1', kind: 'Hole' },
  { id: 'f1', name: 'Fillet 1', kind: 'Fillet' },
];
