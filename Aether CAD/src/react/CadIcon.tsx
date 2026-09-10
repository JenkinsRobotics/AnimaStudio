import { AetherIcon, type AetherIconProps } from "@aether/ui";

export type CadIconName =
  | "assembly"
  | "chevron"
  | "connector"
  | "fit"
  | "folder"
  | "history"
  | "items"
  | "mate"
  | "model"
  | "search"
  | "sketch"
  | "step"
  | "view";

interface CadIconProps extends Omit<AetherIconProps, "name"> {
  name: CadIconName;
}

/** Product vocabulary adapter; vector geometry is shared in core/assets/icons. */
export function CadIcon(props: CadIconProps) { return <AetherIcon {...props} />; }
