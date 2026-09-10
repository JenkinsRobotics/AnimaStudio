# Shared browser session

The host serves `account.js` and `account.css` at `/suite/` and includes them in hosted application HTML. Each front end provides a `data-aether-account` slot. One framework-neutral account control projects the signed-in host identity, profile picture and appearance preference into every application. It calls the canonical host APIs; it does not store passwords or duplicate account data in browser storage.

Core UI tokens own the visual palette. Dark blue-grey remains the product default; light/system are per-user preferences. Product renderers retain control of 3D viewport appearance.
