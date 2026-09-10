import {
  PART_FILE_EXTENSION,
  serializePartDocument,
  type PartDocument,
} from "@aether/core/document";

export { parsePartDocument, serializePartDocument } from "@aether/core/document";

function safeFileStem(name: string): string {
  return (
    name.trim().replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") ||
    "Part"
  );
}

export async function savePartDocument(
  partDocument: PartDocument,
): Promise<string> {
  const contents = serializePartDocument(partDocument);
  const suggestedName = `${safeFileStem(partDocument.name)}${PART_FILE_EXTENSION}`;
  const pickerWindow = window as Window & {
    showSaveFilePicker?: (options: unknown) => Promise<{
      createWritable(): Promise<{
        write(data: string): Promise<void>;
        close(): Promise<void>;
      }>;
    }>;
  };
  if (pickerWindow.showSaveFilePicker) {
    const handle = await pickerWindow.showSaveFilePicker({
      suggestedName,
      types: [
        {
          description: "Aether CAD Part",
          accept: { "application/json": [PART_FILE_EXTENSION] },
        },
      ],
    });
    const writable = await handle.createWritable();
    await writable.write(contents);
    await writable.close();
    return suggestedName;
  }

  const url = URL.createObjectURL(
    new Blob([contents], { type: "application/json;charset=utf-8" }),
  );
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = suggestedName;
  anchor.click();
  URL.revokeObjectURL(url);
  return suggestedName;
}
