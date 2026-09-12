import { dxfTags } from "./tags";
import { expandedDxfEntities } from "./blocks";
/** Used layers only; inventory does not require decoding unsupported entities. */
export function dxfLayers(
  text: string,
): { name: string; entityCount: number }[] {
  const layers = new Map<string, number>();
  for (const entity of expandedDxfEntities(dxfTags(text)))
    layers.set(entity.layer, (layers.get(entity.layer) ?? 0) + 1);
  return [...layers].map(([name, entityCount]) => ({ name, entityCount }));
}
