#ifndef CONFIG_H
#define CONFIG_H

// ============================================================================
// Device Identity
// ============================================================================
#define DEVICE_ID       "dev-pump-001"
#define DEVICE_NAME     "Fuel Pump A"
#define FIRMWARE_VERSION "0.1.0"

// ============================================================================
// WiFi Configuration (defaults - overridden by NVRAM profiles)
// ============================================================================
#define WIFI_SSID_1     "FacilityNet"
#define WIFI_PASS_1     "changeme"
#define WIFI_SSID_2     "BackupWiFi"
#define WIFI_PASS_2     "changeme"

#define WIFI_CONNECT_TIMEOUT_MS     10000   // 10s per connection attempt
#define WIFI_MAX_RETRIES            30      // Before BLE fallback
#define WIFI_SCAN_INTERVAL_MS       60000   // 60s between scans when disconnected

// ============================================================================
// Backend REST API
// ============================================================================
#define BACKEND_HOST    "192.168.1.100"
#define BACKEND_PORT    8080
#define BACKEND_USE_SSL false

#define API_MEASUREMENTS_PATH   "/api/v1/measurements"
#define API_RELAY_ACTIVATE_PATH "/api/v1/devices/" DEVICE_ID "/relay/activate"
#define API_RELAY_DEACTIVATE_PATH "/api/v1/devices/" DEVICE_ID "/relay/deactivate"

// Retry configuration (exponential backoff)
#define REST_RETRY_BASE_MS      1000    // 1s initial delay
#define REST_RETRY_MAX_MS       300000  // 5 min max delay
#define REST_RETRY_FACTOR       2.0
#define REST_MAX_RETRIES        10

// ============================================================================
// MQTT (Home Assistant)
// ============================================================================
#define MQTT_BROKER_HOST    "192.168.1.100"
#define MQTT_BROKER_PORT    1883
#define MQTT_CLIENT_ID      "olimeeter-" DEVICE_ID
#define MQTT_TOPIC_PREFIX   "home_assistant/fueling/device/" DEVICE_ID

// ============================================================================
// BLE Configuration (NimBLE)
// ============================================================================
#define BLE_DEVICE_NAME         "OliMeeter-" DEVICE_ID
#define BLE_SERVICE_UUID        "6E400000-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHAR_MEASUREMENT    "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHAR_RELAY_CMD      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHAR_STATUS         "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHAR_PROXIMITY      "6E400004-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_ADVERTISE_TIMEOUT_S 300     // 5 min advertising before giving up
#define BLE_MTU_SIZE            244     // Negotiated MTU for larger payloads

// ============================================================================
// Hardware Pins
// ============================================================================
#define RELAY_PIN           GPIO_NUM_26 // Relay control output
#define METER_PULSE_PIN     GPIO_NUM_27 // Fuel pulse input (interrupt)
#define LED_STATUS_PIN      GPIO_NUM_2  // Built-in LED for status

// ============================================================================
// Meter Sensor
// ============================================================================
#define PULSES_PER_LITER    450         // Calibration: pulses per liter of fuel
#define METER_DEBOUNCE_MS   5           // Debounce time for pulse counting

// ============================================================================
// Dispensing
// ============================================================================
#define SESSION_TIMEOUT_MS      1800000 // 30 min max dispensing session
#define HARD_CUTOFF_MARGIN_L    0.1     // Cut relay 0.1L before max_liters

// ============================================================================
// Offline Queue (SPIFFS/LittleFS)
// ============================================================================
#define QUEUE_FILE_PATH     "/queue.jsonl"
#define QUEUE_MAX_AGE_DAYS  7           // Delete entries older than 7 days
#define QUEUE_MAX_SIZE_KB   512         // Max queue file size

// ============================================================================
// OTA Updates
// ============================================================================
#define OTA_CHECK_INTERVAL_MS   3600000 // Check for updates every hour
#define OTA_TIMEOUT_MS          300000  // 5 min max OTA attempt

#endif // CONFIG_H
