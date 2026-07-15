// Per-board servo signal backend. This is the ONLY per-board seam:
// the protocol state machine (protocol.cpp) never touches hardware
// directly. AVR uses the bundled Servo library; ESP32 uses LEDC PWM at
// 50 Hz so no third-party library is needed. See servo_backend.cpp.
#pragma once

#include <stdint.h>

// Start emitting a servo signal on `pin`. `min_us`/`max_us` bound the
// pulse range (the AVR Servo library clamps writes to its attach range;
// the protocol layer never sends a pulse outside it anyway).
void servoBackendAttach(uint8_t channel, uint8_t pin, uint16_t min_us, uint16_t max_us);

// Update the pulse width on an attached channel.
void servoBackendWrite(uint8_t channel, uint8_t pin, uint16_t pulse_us);

// Stop emitting a servo signal (detach) and leave the line quiet.
void servoBackendDetach(uint8_t channel, uint8_t pin);
