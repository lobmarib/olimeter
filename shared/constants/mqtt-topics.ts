/** MQTT topic definitions for Home Assistant integration (research.md §7) */

const BASE_PREFIX = "home_assistant/fueling/device";

/** Build a device-specific MQTT topic */
export function deviceTopic(deviceId: string, suffix: string): string {
  return `${BASE_PREFIX}/${deviceId}/${suffix}`;
}

/** MQTT topic patterns (use {device_id} as placeholder) */
export const MQTT_TOPICS = {
  /** Real-time measurement events */
  MEASUREMENT: `${BASE_PREFIX}/{device_id}/measurement`,

  /** Relay state changes (retained) */
  RELAY: `${BASE_PREFIX}/{device_id}/relay`,

  /** Device connectivity status (retained) */
  CONNECTIVITY: `${BASE_PREFIX}/{device_id}/connectivity`,

  /** Home Assistant MQTT discovery config prefix */
  HA_DISCOVERY: "homeassistant/sensor/olimeeter_device_{device_id}",
} as const;

/** QoS levels per topic type */
export const MQTT_QOS = {
  MEASUREMENT: 1, // at-least-once (redundant with REST)
  RELAY: 1, // at-least-once (state change)
  CONNECTIVITY: 1, // at-least-once (retained)
} as const;

/** Retained message settings per topic */
export const MQTT_RETAINED = {
  MEASUREMENT: false,
  RELAY: true,
  CONNECTIVITY: true,
} as const;
