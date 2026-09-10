let capture: (() => Promise<string>) | null = null;
export function configureDocumentPrint(provider: () => Promise<string>) {
  capture = provider;
}
export async function printDocument(name: string) {
  if (!capture) throw new Error("Wait for the viewport to finish loading.");
  const preview = window.open("", "_blank");
  if (!preview)
    throw new Error(
      "Allow a print-preview window for this site, then try again.",
    );
  try {
    preview.document.title = name;
    const heading = preview.document.createElement("h1");
    heading.textContent = name;
    const caption = preview.document.createElement("p");
    caption.textContent = "Aether CAD · current viewport · not to scale";
    const image = preview.document.createElement("img");
    image.alt = name;
    image.style.cssText = "width:100%;max-height:80vh;object-fit:contain";
    const style = preview.document.createElement("style");
    style.textContent =
      "body{font:14px system-ui;margin:24px}h1{font-size:20px}@page{size:landscape;margin:12mm}";
    preview.document.head.append(style);
    preview.document.body.append(heading, caption, image);
    image.src = await capture();
    await image.decode();
    preview.focus();
    preview.print();
  } catch (e) {
    preview.close();
    throw e;
  }
}
