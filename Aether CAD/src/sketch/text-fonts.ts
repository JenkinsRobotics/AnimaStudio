import shapingLicense from "../../../core/assets/licenses/harfbuzzjs.txt?url";
import regular from "../../../core/assets/fonts/noto-sans/NotoSans-Regular.ttf?url";
import bold from "../../../core/assets/fonts/noto-sans/NotoSans-Bold.ttf?url";
import italic from "../../../core/assets/fonts/noto-sans/NotoSans-Italic.ttf?url";
import boldItalic from "../../../core/assets/fonts/noto-sans/NotoSans-BoldItalic.ttf?url";
import license from "../../../core/assets/fonts/noto-sans/LICENSE?url";
const fonts = [
  { label: "Noto Sans — Regular", url: regular },
  { label: "Noto Sans — Bold", url: bold },
  { label: "Noto Sans — Italic", url: italic },
  { label: "Noto Sans — Bold italic", url: boldItalic },
];
/** Bundled font assets are served by the installation, never a third-party CDN. */
export function mountTextFonts(
  parent: HTMLElement,
  callbacks: {
    start: () => void;
    loaded: (bytes: ArrayBuffer) => void;
    error: (message: string) => void;
  },
) {
  const select = document.createElement("select"),
    link = document.createElement("a");
  select.setAttribute("aria-label", "Bundled text font");
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Embedded / custom font";
  select.append(placeholder);
  fonts.forEach((font, i) => {
    const option = document.createElement("option");
    option.value = String(i);
    option.textContent = font.label;
    select.append(option);
  });
  link.href = license;
  link.textContent = "Noto Sans font license";
  link.target = "_blank";
  link.rel = "noopener";
  const shapingLink = document.createElement("a");
  shapingLink.href = shapingLicense;
  shapingLink.textContent = "Text shaping license";
  shapingLink.target = "_blank";
  shapingLink.rel = "noopener";
  parent.append(select, link, shapingLink);
  let generation = 0,
    disposed = false,
    controller: AbortController | undefined;
  const cancel = () => {
    ++generation;
    controller?.abort();
    controller = undefined;
    select.value = "";
  };
  select.onchange = async () => {
    const font = fonts[Number(select.value)];
    if (!select.value || !font) {
      cancel();
      return;
    }
    controller?.abort();
    controller = new AbortController();
    const request = ++generation;
    callbacks.start();
    try {
      const response = await fetch(font.url, { signal: controller.signal });
      if (!response.ok)
        throw Error(`Unable to load ${font.label} (${response.status}).`);
      const bytes = await response.arrayBuffer();
      if (!disposed && request === generation) callbacks.loaded(bytes);
    } catch (error) {
      if (!disposed && request === generation)
        callbacks.error((error as Error).message);
    }
  };
  return {
    useDefault() {
      select.value = "0";
      select.dispatchEvent(new Event("change"));
    },
    cancel,
    dispose() {
      disposed = true;
      cancel();
      select.remove();
      link.remove();
      shapingLink.remove();
    },
  };
}
