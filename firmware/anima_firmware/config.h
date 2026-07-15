// Anima firmware v0 — compile-time configuration.
#pragma once

#include <stddef.h>
#include <stdint.h>

// ponytail: fixed channel ceiling. 12 matches the AVR Servo library's
// per-timer limit on the ATmega328 (Uno) and keeps every buffer static;
// raise per-board (and re-check RAM) when a robot actually needs more.
#define ANIMA_MAX_CHANNELS 12

#define ANIMA_PROTOCOL_VERSION 0

#ifndef ANIMA_DEVICE_NAME
#ifdef ESP32
#define ANIMA_DEVICE_NAME "anima-esp32"
#else
#define ANIMA_DEVICE_NAME "anima-avr"
#endif
#endif

// Longest legal line: FRM with all 12 channels ≈ 8 + 12 * 8 = 104 bytes.
// Anything that does not fit is answered ERR,1 and the parser resyncs at
// the next newline. No dynamic allocation anywhere.
#define ANIMA_LINE_BUFFER_SIZE 192

// Longest reply: "ERR,3,bad-protocol-version" (26) / ANIMA handshake (~24).
#define ANIMA_REPLY_BUFFER_SIZE 48
