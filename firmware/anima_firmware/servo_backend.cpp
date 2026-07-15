// Per-board servo signal generation. Everything above this file is
// core-agnostic; only pulse emission differs between boards.

#include "servo_backend.h"

#include <Arduino.h>

#include "config.h"

#ifdef ESP32

// ESP32: LEDC PWM at 50 Hz, 16-bit duty — standard hobby-servo signal
// with ~0.3 us resolution, no third-party library. Uses the pin-based
// LEDC API of esp32 core 3.x (ledcAttach/ledcWrite/ledcDetach).

static const uint32_t kLedcFrequencyHz = 50;
static const uint8_t kLedcResolutionBits = 16;
static const uint32_t kLedcPeriodUs = 1000000UL / kLedcFrequencyHz;  // 20000

void servoBackendAttach(uint8_t channel, uint8_t pin, uint16_t min_us, uint16_t max_us) {
  (void)channel;
  (void)min_us;
  (void)max_us;
  ledcAttach(pin, kLedcFrequencyHz, kLedcResolutionBits);
}

void servoBackendWrite(uint8_t channel, uint8_t pin, uint16_t pulse_us) {
  (void)channel;
  const uint32_t duty =
      ((uint32_t)pulse_us << kLedcResolutionBits) / kLedcPeriodUs;
  ledcWrite(pin, duty);
}

void servoBackendDetach(uint8_t channel, uint8_t pin) {
  (void)channel;
  ledcDetach(pin);
  // Leave the signal line driven low, not floating: a floating input can
  // read as pulses to some servo electronics.
  pinMode(pin, OUTPUT);
  digitalWrite(pin, LOW);
}

#else  // AVR (and other cores shipping the standard Servo library)

#include <Servo.h>

static Servo servos[ANIMA_MAX_CHANNELS];

void servoBackendAttach(uint8_t channel, uint8_t pin, uint16_t min_us, uint16_t max_us) {
  // Passing CFG's pulse range makes the library's internal clamp agree
  // with the configured range (its default is 544..2400).
  servos[channel].attach(pin, min_us, max_us);
}

void servoBackendWrite(uint8_t channel, uint8_t pin, uint16_t pulse_us) {
  (void)pin;
  servos[channel].writeMicroseconds(pulse_us);
}

void servoBackendDetach(uint8_t channel, uint8_t pin) {
  servos[channel].detach();
  pinMode(pin, OUTPUT);
  digitalWrite(pin, LOW);
}

#endif
