import {
  CADDocumentSettings,
  loadDocumentMetadata,
} from "./CADDocumentSettings";
import { applyDocumentUnits } from "../document-preferences";
import { printDocument } from "../document-print";
import { useEffect, useState } from "react";
import {
  AetherIcon,
  Button,
  Dialog,
  IconButton,
  MenuButton,
  TextField,
} from "@aether/ui";
import { cadCommands } from "../cad-command-registry";
import { cadPresentation } from "../cad-presentation-store";
import { documentLink, documentRevision } from "../document-link";

export function CADDocumentControls({
  name,
  partOpen,
}: {
  name: string;
  partOpen: boolean;
}) {
  const [message, setMessage] = useState("");
  const [fallbackLink, setFallbackLink] = useState("");
  const [settingsAction, setSettingsAction] = useState<string | null>(null);
  const [workspaceName, setWorkspaceName] = useState("Main");
  useEffect(() => {
    if (
      typeof location !== "undefined" &&
      new URLSearchParams(location.search).has("document")
    )
      void loadDocumentMetadata()
        .then((meta) => {
          setWorkspaceName(meta.settings.workspaceName);
          applyDocumentUnits(meta.settings.units);
        })
        .catch(() => {});
  }, [name]);
  const address =
    typeof location === "undefined" ? "http://localhost/" : location.href;
  const link = documentLink(address);
  const revision =
    documentRevision(address) === "Main"
      ? workspaceName
      : documentRevision(address);
  const assembly = new URL(address).searchParams.has("assembly");
  const copyLink = async () => {
    // Read at click time: Save may have assigned the document its first server ID.
    const current = documentLink(location.href);
    if (!current) {
      setMessage("Save the document to your server first.");
      return;
    }
    try {
      if (!navigator.clipboard?.writeText)
        throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(current);
      setMessage("Link copied");
    } catch {
      setFallbackLink(current);
      setMessage("Select and copy the link below.");
    }
  };
  return (
    <>
      <MenuButton
        label="Document controls"
        placement="bottom-start"
        className="cad-document-menu"
        items={[
          {
            id: "save",
            label: "Save document",
            disabled:
              (!partOpen && !assembly) ||
              new URL(address).searchParams.has("revision"),
          },
          { id: "open", label: "Open Part…" },
          { id: "import", label: "Import STEP…" },
          { id: "details", label: "Document details…", separatorBefore: true },
          { id: "export", label: "Export…", disabled: !partOpen },
          { id: "rename", label: "Rename document…", separatorBefore: true },
          { id: "move", label: "Move to…" },
          { id: "restore", label: "Restore deleted workspaces…" },
          { id: "copy", label: "Copy workspace…", separatorBefore: true },
          { id: "update", label: "Update workspace…" },
          { id: "units", label: "Workspace units…" },
          { id: "properties", label: "Workspace properties…" },
          { id: "print", label: "Print…", separatorBefore: true },
          { id: "close", label: "Close document", separatorBefore: true },
        ]}
        onSelect={(id) => {
          if (id === "save") {
            if (assembly)
              cadPresentation.dispatch({ type: "save-assembly-workspace" });
            else cadCommands.execute("save-part");
          }
          if (id === "open") cadCommands.execute("open-part");
          if (id === "import") cadCommands.execute("insert-step");
          if (
            [
              "details",
              "rename",
              "move",
              "restore",
              "copy",
              "update",
              "units",
              "properties",
            ].includes(id)
          )
            setSettingsAction(id);
          if (id === "print")
            void printDocument(name).catch((e) => setMessage(e.message));
          if (id === "export")
            cadPresentation.dispatch({
              type: "show-start-dialog",
              dialog: "export",
            });
          if (id === "close") {
            if (location.pathname.startsWith("/cad/")) location.assign("/cad/");
            else
              cadPresentation.dispatch({
                type: "show-start-screen",
                screen: "home",
              });
          }
        }}
      >
        <AetherIcon name="menu" />
      </MenuButton>
      <div className="cad-document-identity">
        <strong id="document-name" title={name}>
          {name}
        </strong>
      </div>
      <span
        className="cad-document-revision"
        title={
          new URL(address).searchParams.has("revision")
            ? "Read-only saved revision"
            : "Current working document"
        }
      >
        {revision}
      </span>
      <IconButton
        label="Copy document link"
        disabled={!link}
        title={
          link
            ? "Copy link to this document — existing permissions apply"
            : "Save to the server to get a document link"
        }
        onClick={() => void copyLink()}
      >
        <AetherIcon name="link" />
      </IconButton>
      <span className="cad-link-feedback" role="status" aria-live="polite">
        {message}
      </span>
      {settingsAction && (
        <CADDocumentSettings
          action={settingsAction}
          onClose={() => setSettingsAction(null)}
        />
      )}
      <Dialog
        open={Boolean(fallbackLink)}
        title="Copy document link"
        onClose={() => setFallbackLink("")}
        actions={<Button onClick={() => setFallbackLink("")}>Done</Button>}
      >
        <p>
          Automatic clipboard access is unavailable. Select this link and copy
          it.
        </p>
        <TextField
          aria-label="Document link"
          value={fallbackLink}
          readOnly
          onFocus={(event) => event.currentTarget.select()}
        />
      </Dialog>
    </>
  );
}
