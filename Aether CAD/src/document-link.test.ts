import { describe, expect, it } from "vitest";
import { documentLink, documentRevision } from "./document-link";
describe("document sharing routes", () => {
  it("keeps the project item and revision without transient parameters or secrets", () => {
    expect(documentLink("https://studio.test/cad/index.html?document=wheel&part=hub&revision=4&new=part&token=secret#setup=secret")).toBe("https://studio.test/cad/index.html?document=wheel&part=hub&revision=4");
    expect(documentLink("https://studio.test/cad/index.html?document=p&assembly=a")).toBe("https://studio.test/cad/index.html?document=p&assembly=a");
    expect(documentLink("https://studio.test/cad/index.html?new=part")).toBeNull();
  });
  it("distinguishes the working document from an immutable revision", () => {
    expect(documentRevision("https://studio.test/cad/?document=a")).toBe("Main");
    expect(documentRevision("https://studio.test/cad/?document=a&revision=4")).toBe("Revision 4");
  });
});
