# Aether Studio administration workspace

React frontend for `core/host`, built from shared Core UI controls, vectors and
`core/ui/tokens/home.css`. The home/admin layout follows the supplied charcoal
sidebar reference; product workbenches retain their editing layouts.

Build: `npm ci && npm run build`. Launch through the
[Studio host](../core/host/README.md); it provides same-origin authentication and
all administration endpoints. `npm run dev` proxies `/api` to the local host for
development, but use the real host for authentication end-to-end checks.

Community plugins are explicitly future support. No sample administrative data,
fake statistics, external telemetry, cloud login or fabricated news feed is used.
