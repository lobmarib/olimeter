#include <Arduino.h>
#include "config.h"

// Forward declarations for modules (implemented in later phases)
// #include "relay_control.h"
// #include "meter_sensor.h"
// #include "rest_api_client.h"
// #include "offline_queue.h"
// #include "mqtt_client.h"
// #include "wifi_manager.h"
// #include "ble_service.h"
// #include "ota_updater.h"

// ============================================================================
// State
// ============================================================================

enum DeviceState {
    STATE_IDLE,
    STATE_WIFI_CONNECTING,
    STATE_READY,
    STATE_DISPENSING,
    STATE_ERROR
};

static DeviceState currentState = STATE_IDLE;

// ============================================================================
// Setup
// ============================================================================

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("=================================");
    Serial.printf("OliMeeter Firmware %s\n", FIRMWARE_VERSION);
    Serial.printf("Device: %s (%s)\n", DEVICE_NAME, DEVICE_ID);
    Serial.println("=================================");

    // Initialize status LED
    pinMode(LED_STATUS_PIN, OUTPUT);
    digitalWrite(LED_STATUS_PIN, LOW);

    // Initialize relay pin (OFF = relay open = no fuel flow)
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, LOW);

    // Initialize meter pulse input
    pinMode(METER_PULSE_PIN, INPUT_PULLUP);

    // TODO Phase 4 (US2): Initialize relay_control, meter_sensor, offline_queue
    // TODO Phase 8: Initialize wifi_manager, ble_service, mqtt_client, ota_updater

    // Attempt WiFi connection
    currentState = STATE_WIFI_CONNECTING;
    WiFi.begin(WIFI_SSID_1, WIFI_PASS_1);

    Serial.print("Connecting to WiFi");
    unsigned long startMs = millis();
    while (WiFi.status() != WL_CONNECTED && (millis() - startMs) < WIFI_CONNECT_TIMEOUT_MS) {
        delay(500);
        Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\nWiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
        currentState = STATE_READY;
        digitalWrite(LED_STATUS_PIN, HIGH);
    } else {
        Serial.println("\nWiFi connection failed. Will retry in loop.");
        currentState = STATE_IDLE;
    }
}

// ============================================================================
// Main Loop
// ============================================================================

void loop() {
    // Reconnect WiFi if disconnected
    if (WiFi.status() != WL_CONNECTED && currentState != STATE_WIFI_CONNECTING) {
        currentState = STATE_WIFI_CONNECTING;
        digitalWrite(LED_STATUS_PIN, LOW);
        WiFi.reconnect();
    }

    if (WiFi.status() == WL_CONNECTED && currentState == STATE_WIFI_CONNECTING) {
        currentState = STATE_READY;
        digitalWrite(LED_STATUS_PIN, HIGH);
        Serial.println("WiFi reconnected.");
    }

    // TODO Phase 4 (US2): Poll meter sensor, manage dispensing lifecycle
    // TODO Phase 8: Process offline queue, check OTA updates, handle BLE

    delay(100); // Main loop tick rate ~10Hz
}
