// Aether UI — one widget per file, importable like a class.
// Product-free by rule: widgets take data and emit events; they never
// name a product concept or call an engine verb.
export { Button, type ButtonProps } from "./Button";
export { IconButton, type IconButtonProps } from "./IconButton";
export { Ribbon, RibbonGroup, RibbonTool, type RibbonToolProps } from "./Ribbon";
export { Rail, RailButton, type RailButtonProps } from "./Rail";
export { Tabs, type TabsProps } from "./Tabs";
export { Tree, type TreeNode, type TreeProps } from "./Tree";
export { DockPanel, type DockPanelProps } from "./DockPanel";
export { PanelHeading } from "./PanelHeading";
export { TextField, type TextFieldProps } from "./TextField";
export { Dialog, type DialogProps } from "./Dialog";
export { StatusBar, StatusDot, type StatusKind } from "./StatusBar";
export { ViewportCanvas, type ViewportCanvasProps } from "./ViewportCanvas";
export {
  WorkspaceShell,
  FloatingPanel,
  LayoutPresetButton,
  nextLayoutPreset,
  type LayoutPreset,
  type WorkspacePanel,
  type WorkspaceShellProps,
  type FloatingPanelProps,
} from "./WorkspaceShell";
export { DocumentBar, type DocumentBarProps } from "./DocumentBar";
