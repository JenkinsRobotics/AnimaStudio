// Anima firmware v0 — open device-side implementation of the Anima
// Wire Protocol (dev/docs/roadmap/Wire_Protocol.md), Anima's equivalent
// of the Bottango firmware. Boards: AVR (Uno & friends, Servo.h) and
// ESP32 (LEDC PWM, no third-party library). See firmware/README.md.
//
// This file owns the transport only: newline-framed serial lines in,
// one reply line out. All protocol semantics live in protocol.cpp.

#include "config.h"
#include "protocol.h"

static char lineBuffer[ANIMA_LINE_BUFFER_SIZE];
static size_t lineLength = 0;
static bool lineOverflowed = false;
static char replyBuffer[ANIMA_REPLY_BUFFER_SIZE];

void setup() {
  Serial.begin(115200);
  protocolInit(millis());
}

void loop() {
  while (Serial.available() > 0) {
    const char incoming = (char)Serial.read();
    if (incoming == '\n') {
      if (lineOverflowed) {
        // Oversized line: ERR,1 and resync. Never refreshes the heartbeat.
        protocolLineOverflow(replyBuffer, sizeof(replyBuffer));
      } else {
        lineBuffer[lineLength] = '\0';
        protocolHandleLine(lineBuffer, millis(), replyBuffer, sizeof(replyBuffer));
      }
      Serial.print(replyBuffer);
      Serial.print('\n');
      lineLength = 0;
      lineOverflowed = false;
    } else if (lineLength < sizeof(lineBuffer) - 1) {
      lineBuffer[lineLength++] = incoming;
    } else {
      lineOverflowed = true;
    }
  }
  protocolUpdate(millis());
}
