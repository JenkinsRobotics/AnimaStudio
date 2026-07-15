// Anima Wire Protocol v0 — device-side state machine (core-agnostic).
// Normative contract: dev/docs/roadmap/Wire_Protocol.md.
// Reference semantics: anima_studio/sim.py (the Python simulator); this
// implementation mirrors it, including error codes and message tokens.
#pragma once

#include <stddef.h>
#include <stdint.h>

// Reset all protocol state. Call once from setup().
void protocolInit(uint32_t now_ms);

// Handle one complete host→device line (newline already stripped;
// `line` is modified in place). Writes the single reply line, without
// a trailing newline, into `reply`. Successfully handled commands
// refresh the failsafe heartbeat; ERR replies never do.
void protocolHandleLine(char *line, uint32_t now_ms, char *reply, size_t reply_size);

// Reply for a line that overflowed the RX buffer: ERR,1 — and, like
// every ERR, it does not refresh the failsafe heartbeat.
void protocolLineOverflow(char *reply, size_t reply_size);

// Advance device-side motion, apply the per-channel failsafe, and push
// pulse widths to the servo backend. Call every loop() pass.
void protocolUpdate(uint32_t now_ms);
