// Anima Wire Protocol v0 — device-side state machine.
//
// Core-agnostic: no Arduino calls here; hardware goes through
// servo_backend.h. Behavior mirrors animacore/sim.py line by line:
// channels start disabled after CFG until EN; STOP/failsafe leave them
// disabled until re-enabled; FRM frames are atomic; retargeting starts
// from the current (in-flight) value; ERR messages are hyphenated
// tokens; only successfully parsed commands refresh the heartbeat.
//
// No dynamic allocation: fixed channel table, in-place field splitting.

#include "protocol.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "servo_backend.h"

// ERR,<code>,<msg> codes, matching animacore/wire.py.
#define ERR_PARSE 1
#define ERR_BAD_CHANNEL 2
#define ERR_BAD_VALUE 3
#define ERR_NOT_CONFIGURED 4

#define DEFAULT_FAILSAFE_MS 2000UL
#define DEFAULT_NEUTRAL 0.5f

// Longest legal command: FRM addressing every channel = 2 + 12 fields.
#define MAX_FIELDS (2 + ANIMA_MAX_CHANNELS)

struct Channel {
  bool configured;
  bool enabled;
  uint8_t pin;
  uint16_t min_us;
  uint16_t max_us;
  bool invert;
  float neutral;
  uint32_t failsafe_ms;
  float value;
  // Active motion; duration 0 means idle.
  uint32_t motion_start_ms;
  uint32_t motion_duration_ms;
  float motion_start_value;
  float motion_target_value;
  uint16_t last_pulse_us;  // last width written; 0 = nothing written yet
};

static Channel channels[ANIMA_MAX_CHANNELS];
static uint32_t lastRxMs;

// Reply helpers -------------------------------------------------------------

static void writeOk(char *reply, size_t reply_size) {
  snprintf(reply, reply_size, "OK");
}

// Always "returns" false so handlers can `return fail(...)`.
static bool fail(char *reply, size_t reply_size, uint8_t code, const char *message) {
  snprintf(reply, reply_size, "ERR,%u,%s", (unsigned)code, message);
  return false;
}

// Strict parsers (reject trailing junk, like Python int()/float()) ----------

static bool parseLong(const char *raw, long *out) {
  if (raw == NULL || *raw == '\0') {
    return false;
  }
  char *end = NULL;
  const long value = strtol(raw, &end, 10);
  if (end == raw || *end != '\0') {
    return false;
  }
  *out = value;
  return true;
}

static bool parseFloat(const char *raw, float *out) {
  if (raw == NULL || *raw == '\0') {
    return false;
  }
  char *end = NULL;
  const float value = (float)strtod(raw, &end);
  if (end == raw || *end != '\0') {
    return false;
  }
  *out = value;
  return true;
}

// Channel state -------------------------------------------------------------

static uint16_t channelPulseUs(const Channel &channel) {
  const float value = channel.invert ? (1.0f - channel.value) : channel.value;
  const float pulse =
      (float)channel.min_us + ((float)(channel.max_us - channel.min_us) * value);
  return (uint16_t)(pulse + 0.5f);
}

static void channelAdvanceTo(Channel &channel, uint32_t now_ms) {
  if (channel.motion_duration_ms == 0) {
    return;
  }
  const uint32_t elapsed_ms = now_ms - channel.motion_start_ms;
  if (elapsed_ms >= channel.motion_duration_ms) {
    channel.value = channel.motion_target_value;
    channel.motion_duration_ms = 0;
  } else if (elapsed_ms > 0) {
    const float progress = (float)elapsed_ms / (float)channel.motion_duration_ms;
    channel.value = channel.motion_start_value +
                    ((channel.motion_target_value - channel.motion_start_value) *
                     progress);
  }
}

// Disable output and cancel any active motion (value freezes) — the
// shared behavior of EN,<ch>,0, STOP, and the failsafe.
static void channelHalt(uint8_t index) {
  Channel &channel = channels[index];
  if (channel.enabled) {
    servoBackendDetach(index, channel.pin);
  }
  channel.enabled = false;
  channel.motion_duration_ms = 0;
  channel.last_pulse_us = 0;
}

static void haltAllChannels() {
  for (uint8_t index = 0; index < ANIMA_MAX_CHANNELS; index++) {
    if (channels[index].configured) {
      channelHalt(index);
    }
  }
}

// `raw` → validated channel index. On failure writes the ERR reply.
static bool parseChannel(const char *raw, uint8_t *out, char *reply, size_t reply_size) {
  long channel = 0;
  if (!parseLong(raw, &channel)) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  if (channel < 0 || channel >= ANIMA_MAX_CHANNELS) {
    return fail(reply, reply_size, ERR_BAD_CHANNEL, "bad-channel");
  }
  *out = (uint8_t)channel;
  return true;
}

// `raw` → normalized 0..1 value. Unparsable is ERR,1; out of range
// (including NaN) is ERR,3 — same split as sim.py's _parse_value.
static bool parseValue(const char *raw, float *out, char *reply, size_t reply_size) {
  float value = 0.0f;
  if (!parseFloat(raw, &value)) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  if (!(value >= 0.0f && value <= 1.0f)) {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-value");
  }
  *out = value;
  return true;
}

// Command handlers -----------------------------------------------------------
// Each returns true if the command was accepted (refreshes the
// heartbeat) and has always written the reply line.

static bool handleHello(char **fields, int field_count, char *reply, size_t reply_size) {
  if (field_count != 2) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  long version = 0;
  if (!parseLong(fields[1], &version)) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  if (version != ANIMA_PROTOCOL_VERSION) {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-protocol-version");
  }
  snprintf(reply, reply_size, "ANIMA,%d,%s,%d", ANIMA_PROTOCOL_VERSION,
           ANIMA_DEVICE_NAME, ANIMA_MAX_CHANNELS);
  return true;
}

static bool handleCfg(char **fields, int field_count, char *reply, size_t reply_size) {
  if (field_count < 3) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  uint8_t index = 0;
  if (!parseChannel(fields[1], &index, reply, reply_size)) {
    return false;
  }
  if (strcmp(fields[2], "servo") != 0) {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-channel-type");
  }

  // k=v fields against the closed key set; duplicates and unknowns are
  // rejected, never last-write-wins (Wire_Protocol.md Strictness).
  static const char *const kKnownKeys[] = {"pin",    "min_us",  "max_us",
                                           "invert", "neutral", "failsafe_ms"};
  const int kKeyCount = 6;
  const char *values[6] = {NULL, NULL, NULL, NULL, NULL, NULL};

  for (int field = 3; field < field_count; field++) {
    char *separator = strchr(fields[field], '=');
    if (separator == NULL || separator[1] == '\0') {
      return fail(reply, reply_size, ERR_PARSE, "parse");
    }
    *separator = '\0';
    const char *raw = separator + 1;
    int key = 0;
    while (key < kKeyCount && strcmp(fields[field], kKnownKeys[key]) != 0) {
      key++;
    }
    if (key == kKeyCount) {
      return fail(reply, reply_size, ERR_PARSE, "unknown-key");
    }
    if (values[key] != NULL) {
      return fail(reply, reply_size, ERR_PARSE, "duplicate-key");
    }
    values[key] = raw;
  }

  if (values[0] == NULL) {
    return fail(reply, reply_size, ERR_PARSE, "missing-pin");
  }
  if (values[1] == NULL) {
    return fail(reply, reply_size, ERR_PARSE, "missing-min_us");
  }
  if (values[2] == NULL) {
    return fail(reply, reply_size, ERR_PARSE, "missing-max_us");
  }

  long pin = 0;
  long min_us = 0;
  long max_us = 0;
  if (!parseLong(values[0], &pin) || !parseLong(values[1], &min_us) ||
      !parseLong(values[2], &max_us)) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  // Hardware bound (firmware-only; the simulator has no pins): a pin
  // must fit the backend's uint8_t pin space.
  if (pin < 0 || pin > 255) {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-pin");
  }
  // Hardware bound: pulses must fit one 50 Hz servo period.
  if (min_us < 0 || max_us > 20000 || min_us >= max_us) {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-pulse-range");
  }

  bool invert = false;
  if (values[3] != NULL) {
    if (strcmp(values[3], "0") == 0) {
      invert = false;
    } else if (strcmp(values[3], "1") == 0) {
      invert = true;
    } else {
      return fail(reply, reply_size, ERR_BAD_VALUE, "bad-invert");
    }
  }

  float neutral = DEFAULT_NEUTRAL;
  if (values[4] != NULL && !parseValue(values[4], &neutral, reply, reply_size)) {
    return false;
  }

  long failsafe_ms = DEFAULT_FAILSAFE_MS;
  if (values[5] != NULL) {
    if (!parseLong(values[5], &failsafe_ms)) {
      return fail(reply, reply_size, ERR_PARSE, "parse");
    }
    // Hardware bound: a negative deadline is meaningless on a real clock.
    if (failsafe_ms < 0) {
      return fail(reply, reply_size, ERR_BAD_VALUE, "bad-value");
    }
  }

  // Reconfiguring detaches first; like the simulator, CFG always leaves
  // the channel disabled at its neutral value with no motion.
  channelHalt(index);
  Channel &channel = channels[index];
  channel.configured = true;
  channel.pin = (uint8_t)pin;
  channel.min_us = (uint16_t)min_us;
  channel.max_us = (uint16_t)max_us;
  channel.invert = invert;
  channel.neutral = neutral;
  channel.failsafe_ms = (uint32_t)failsafe_ms;
  channel.value = neutral;
  writeOk(reply, reply_size);
  return true;
}

static bool handleFrm(char **fields, int field_count, uint32_t now_ms, char *reply,
                      size_t reply_size) {
  if (field_count < 3) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  long duration_ms = 0;
  if (!parseLong(fields[1], &duration_ms)) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  if (duration_ms < 0) {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-duration");
  }

  // Validate every target before applying any: a frame is atomic.
  uint8_t target_channels[ANIMA_MAX_CHANNELS];
  float target_values[ANIMA_MAX_CHANNELS];
  bool seen[ANIMA_MAX_CHANNELS] = {false};
  int target_count = 0;

  for (int field = 2; field < field_count; field++) {
    char *separator = strchr(fields[field], ':');
    if (separator == NULL) {
      return fail(reply, reply_size, ERR_PARSE, "parse");
    }
    *separator = '\0';
    uint8_t index = 0;
    if (!parseChannel(fields[field], &index, reply, reply_size)) {
      return false;
    }
    if (seen[index]) {
      return fail(reply, reply_size, ERR_PARSE, "duplicate-channel");
    }
    seen[index] = true;
    if (!channels[index].configured) {
      return fail(reply, reply_size, ERR_NOT_CONFIGURED, "not-configured");
    }
    if (!parseValue(separator + 1, &target_values[target_count], reply, reply_size)) {
      return false;
    }
    target_channels[target_count] = index;
    target_count++;
  }

  for (int target = 0; target < target_count; target++) {
    Channel &channel = channels[target_channels[target]];
    if (duration_ms == 0) {
      channel.value = target_values[target];
      channel.motion_duration_ms = 0;
    } else {
      // Retargeting starts from the current in-flight value.
      channelAdvanceTo(channel, now_ms);
      channel.motion_start_ms = now_ms;
      channel.motion_duration_ms = (uint32_t)duration_ms;
      channel.motion_start_value = channel.value;
      channel.motion_target_value = target_values[target];
    }
  }
  writeOk(reply, reply_size);
  return true;
}

static bool handleEn(char **fields, int field_count, char *reply, size_t reply_size) {
  if (field_count != 3) {
    return fail(reply, reply_size, ERR_PARSE, "parse");
  }
  uint8_t index = 0;
  if (!parseChannel(fields[1], &index, reply, reply_size)) {
    return false;
  }
  Channel &channel = channels[index];
  if (!channel.configured) {
    return fail(reply, reply_size, ERR_NOT_CONFIGURED, "not-configured");
  }
  if (strcmp(fields[2], "1") == 0) {
    if (!channel.enabled) {
      channel.enabled = true;
      servoBackendAttach(index, channel.pin, channel.min_us, channel.max_us);
      channel.last_pulse_us = channelPulseUs(channel);
      servoBackendWrite(index, channel.pin, channel.last_pulse_us);
    }
  } else if (strcmp(fields[2], "0") == 0) {
    channelHalt(index);
  } else {
    return fail(reply, reply_size, ERR_BAD_VALUE, "bad-value");
  }
  writeOk(reply, reply_size);
  return true;
}

// Line dispatch ---------------------------------------------------------------

static bool dispatch(char *line, uint32_t now_ms, char *reply, size_t reply_size) {
  // Split on commas in place. A line with more fields than any legal
  // command is rejected up front (fixed-size field table, no heap).
  char *fields[MAX_FIELDS];
  int field_count = 0;
  fields[field_count++] = line;
  for (char *cursor = line; *cursor != '\0'; cursor++) {
    if (*cursor == ',') {
      *cursor = '\0';
      if (field_count >= MAX_FIELDS) {
        return fail(reply, reply_size, ERR_PARSE, "parse");
      }
      fields[field_count++] = cursor + 1;
    }
  }

  const char *command = fields[0];
  if (strcmp(command, "HELLO") == 0) {
    return handleHello(fields, field_count, reply, reply_size);
  }
  if (strcmp(command, "CFG") == 0) {
    return handleCfg(fields, field_count, reply, reply_size);
  }
  if (strcmp(command, "FRM") == 0) {
    return handleFrm(fields, field_count, now_ms, reply, reply_size);
  }
  if (strcmp(command, "EN") == 0) {
    return handleEn(fields, field_count, reply, reply_size);
  }
  if (strcmp(command, "STOP") == 0 && field_count == 1) {
    haltAllChannels();
    writeOk(reply, reply_size);
    return true;
  }
  if (strcmp(command, "PING") == 0 && field_count == 1) {
    snprintf(reply, reply_size, "PONG");
    return true;
  }
  return fail(reply, reply_size, ERR_PARSE, "parse");
}

// Public API ------------------------------------------------------------------

void protocolInit(uint32_t now_ms) {
  memset(channels, 0, sizeof(channels));
  lastRxMs = now_ms;
}

void protocolHandleLine(char *line, uint32_t now_ms, char *reply, size_t reply_size) {
  // Strip a trailing carriage return ("\r\n" hosts).
  size_t length = strlen(line);
  while (length > 0 && line[length - 1] == '\r') {
    line[--length] = '\0';
  }
  if (dispatch(line, now_ms, reply, reply_size)) {
    // Only a successfully parsed command refreshes the failsafe
    // heartbeat — line noise must never keep a servo armed.
    lastRxMs = now_ms;
  }
}

void protocolLineOverflow(char *reply, size_t reply_size) {
  fail(reply, reply_size, ERR_PARSE, "line-too-long");
}

void protocolUpdate(uint32_t now_ms) {
  const uint32_t silence_ms = now_ms - lastRxMs;
  for (uint8_t index = 0; index < ANIMA_MAX_CHANNELS; index++) {
    Channel &channel = channels[index];
    if (!channel.configured) {
      continue;
    }
    channelAdvanceTo(channel, now_ms);
    if (channel.enabled && silence_ms >= channel.failsafe_ms) {
      channelHalt(index);
    }
    if (channel.enabled) {
      const uint16_t pulse_us = channelPulseUs(channel);
      if (pulse_us != channel.last_pulse_us) {
        channel.last_pulse_us = pulse_us;
        servoBackendWrite(index, channel.pin, pulse_us);
      }
    }
  }
}
