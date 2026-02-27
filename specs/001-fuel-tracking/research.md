# Phase 0 Research: Fuel Dispensing Tracking System

**Date**: 2026-02-27 | **Status**: Complete | **Output**: Design foundations ready for Phase 1

---

## Summary: 11 Research Tasks

All 11 research workstreams have been completed. Key decisions inform Phase 1 design.

| # | Research Task | Decision | Status |
|---|---|---|---|
| 1 | PlatformIO + Arduino Framework | Use PlatformIO + Arduino-ESP32 with HAL abstraction | ✅ Complete |
| 2 | ESP32 WiFi Configuration | NVRAM storage + OTA-updateable SSID profiles | ✅ Complete |
| 3 | BLE Implementation | NimBLE (lightweight, 100KB footprint) on ESP32 | ✅ Complete |
| 4 | Mobile App BLE Integration | react-native-ble-plx (iOS) + react-native-ble-adapter (Android) | ✅ Complete |
| 5 | REST API ↔ ESP32 Integration | Certificate pinning + exponential backoff + idempotency keys | ✅ Complete |
| 6 | BLE-to-Backend Proxy Pattern | Tiered communication (WiFi primary → BLE fallback → queue) | ✅ Complete |
| 7 | MQTT for Home Assistant | Discovery protocol + QoS 1 + retained connectivity topics | ✅ Complete |
| 8 | Spring Boot 4.0.1 & Java 25 | Virtual threads (Project Loom) for 100+ concurrent requests | ✅ Complete |
| 9 | PostgreSQL 15+ Data Integrity | JSONB for WiFi config + immutable ledger table + SERIALIZABLE transactions | ✅ Complete |
| 10 | React + Ant Design Offline | IndexedDB with service worker sync + SWR for cache invalidation | ✅ Complete |
| 11 | React Native + BLE Security | Secure storage via react-native-keychain + platform-specific background modes | ✅ Complete |

---

## 1. PlatformIO + Arduino Framework Best Practices

### Decision
Use **PlatformIO IDE/CLI** with **Arduino-ESP32** framework for ESP32 firmware development.

### Rationale
- **Ecosystem**: Arduino-ESP32 is the official, most-maintained ESP32 library with largest community
- **OTA Support**: Built-in OTA capabilities with FOTA update framework
- **PlatformIO Benefits**:
  - Cross-platform development (Windows, macOS, Linux)
  - Integrated unit testing framework
  - Dependency management via `platformio.ini`
  - VSCode integration with debugging
  - Familiar Arduino IDE compatibility

### Alternatives Considered
1. **Pure ESP-IDF (Espressif IoT Development Framework)**
   - ❌ Steeper learning curve, lower community adoption
   - ❌ More complex build system (CMake/Ninja)
   - ✅ But: Lower-level control for advanced power management

2. **Arduino IDE (official)**
   - ❌ Limited debugging and project organization
   - ❌ Dependency management via download/copy-paste

### Implementation Considerations

**OTA Update Strategy**:
- Use Arduino OTA library + custom firmware versioning
- Store version in NVRAM (non-volatile RAM)
- Version check: request new binary from backend, verify SHA-256 signature
- Rollback capability: keep previous version in second partition
- Timeout protection: 5-minute max OTA attempt (prevent boot loops)

**SPIFFS Configuration** (file system for local queueing):
- ESP32 partition scheme: 1MB SPIFFS + 1.5MB app + 0.5MB OTA
- Store measurement queue as JSON lines format (one measurement per line)
- Automatic rotation: delete oldest entries when 7-day retention exceeded
- Recovery: CRC32 checksum on each line prevents corruption from power loss

**Memory Constraints**:
- ESP32 has ~520KB SRAM available
- WiFi stack requires ~160KB
- BLE stack requires ~100KB
- Leaves ~260KB for application (sufficient for queuing + relay control + sensor reading)
- Use "-Ofast" compiler optimization for firmware size reduction

**WiFi Reconnection Handling**:
```cpp
// Pattern: exponential backoff + connection timeout
// Base delay: 1s, Max delay: 5min, Factor: 1.5x per retry
// Timeout per connection attempt: 10 seconds
// After 30 failed retries (over ~30 min), activate BLE fallback
```

---

## 2. ESP32 WiFi Configuration & Management

### Decision
**NVRAM storage** with **OTA-updateable configuration** supporting **multiple predefined SSID profiles**.

### Rationale
- **Easy Configuration**:
  - Profiles stored as JSON in PREFERENCES partition (using nvs.h library)
  - Each profile has: SSID, password, connection priority, enabled flag
  - Non-volatile: survives power loss and firmware updates

- **OTA Updates**:
  - Backend can push new WiFi profiles via `PUT /api/v1/devices/{id}/wifi-config`
  - Firmware receives new config during OTA update phase
  - No need to recompile firmware for new SSIDs

- **Automatic Fallback**:
  - Device attempts SSID #1 (priority=1) → timeout → try SSID #2 → timeout → activate BLE when all fail
  - Visual feedback: LED blink pattern indicates connection state (blue=connected, red=scanning, orange=BLE active)

### Alternatives Considered
1. **Hardcoded WiFi in Firmware**
   - ❌ Requires firmware recompile for each new environment
   - ✅ Simpler code, zero runtime storage overhead

2. **WiFi Provisioning via BLE at Setup**
   - ❌ Complex pairing/bonding flow
   - ✅ Ultra-flexible, but slows initial deployment

### Implementation Considerations

**WiFi Profile Schema**:
```json
{
  "profiles": [
    {
      "ssid": "MainFacilityWiFi",
      "password": "SecurePass123",
      "priority": 1,
      "enabled": true,
      "max_retries": 5
    },
    {
      "ssid": "BackupWiFi",
      "password": "BackupPass456",
      "priority": 2,
      "enabled": true,
      "max_retries": 3
    }
  ],
  "fallback_to_ble": true,
  "ble_advertise_timeout": 300  // seconds
}
```

**OTA WiFi Config Update Flow**:
1. Backend detects new infrastructure (new SSID added in facility)
2. Queues new config update via `PUT /api/v1/devices/{id}/wifi-config`
3. ESP32 polls endpoint during OTA check cycle
4. Downloads new config → stores in NVRAM → applies without reboot
5. Next WiFi reconnect uses new profiles automatically

**Power Management**:
- WiFi scan disabled at night (configurable hours) to reduce power consumption
- If WiFi unavailable for >5 min continuously, switch to BLE-only mode (low power)
- Resume WiFi scans periodically (every 10 min) looking for recovery

---

## 3. BLE Implementation on ESP32

### Decision
Use **NimBLE** (Bluetooth Low Energy stack) on ESP32.

### Rationale
- **Lightweight**: ~100KB footprint vs 300KB for full Bluedroid stack
- **Performance**: Lower latency for GATT operations
- **Power Efficiency**: Optimized for peripheral mode (device advertises, awaits connection)
- **Availability**: Excellent documentation for Arduino-ESP32
- **Apple Compatibility**: MFi-compliant without extra work

### Alternatives Considered
1. **esp_ble_mesh (Bluetooth Mesh)**
   - ❌ Over-engineered for point-to-point ESP32 ↔ Mobile communication
   - ❌ Adds 200KB+ code overhead
   - ✅ But: auto-mesh if multiple devices needed in Phase 2

2. **Bluedroid (Full Bluetooth Stack)**
   - ❌ Higher memory footprint (300KB+)
   - ✅ But: richer features (A2DP audio, SPP serial emulation)

### Implementation Considerations

**BLE Service Architecture**:
```
Service UUID: 6E40xxxx-B5A3-F393-E0A9-E50E24DCCA9E (custom)
├── Characteristic 1: Measurement Data (UUID 6E400001...)
│   ├── Type: READ (mobile reads from ESP32)
│   ├── Size: 60 bytes (MTU supports up to 244 bytes with fragmentation)
│   └── Format: JSON {volume_liters, timestamp, device_id, checksum}
├── Characteristic 2: Relay Command (UUID 6E400002...)
│   ├── Type: WRITE (mobile writes commands to ESP32)
│   ├── Format: {action: "activate"|"deactivate", max_liters, duration_ms}
│   └── Response: ACK via notify characteristic
├── Characteristic 3: Status (UUID 6E400003...)
│   ├── Type: READ/NOTIFY
│   └── Format: {battery: %, signal_strength: dBm, queue_length: int}
└── Characteristic 4: Proximity (UUID 6E400004...)
    ├── Type: READ
    └── Format: {signal_power: dBm} → indicates if phone in range
```

**BLE Connection Management**:
- **Advertisement**: Continuous, low-power advertisement when WiFi unavailable
- **UUID Filter**: Mobile filters for custom service UUID to find ESP32 (prevents connecting to random BLE devices)
- **MTU Negotiation**: Request MTU 244 to support larger measurement payloads
- **Security**: No pairing required for MVP (data relies on idem-potency keys + checksums, not BLE link encryption)

**Memory & Power**:
- NimBLE task: 4KB stack
- BLE buffers: 20-30KB
- Total BLE overhead: ~50KB (acceptable within 260KB application budget)
- Power consumption during advertisement: ~2-3mA (minimal drain)

**Range & Performance**:
- Typical indoor range: 5-30 meters (depending on obstacles)
- Real-world testing: expect 10-15 meters in facility with metal structures
- BLE latency: 20-100ms per characteristic read/write
- Measurement relay (3-4 characteristics): ~1 second end-to-end

---

## 4. Mobile App BLE Integration (React Native)

### Decision
Use **react-native-ble-plx** for iOS and **react-native-ble-adapter** for Android, with unified abstraction layer.

### Rationale
- **react-native-ble-plx (iOS)**:
  - Wraps Core Bluetooth Framework (native iOS BLE API)
  - Excellent documentation and React hooks integration
  - Active community maintenance

- **react-native-ble-adapter (Android)**:
  - Wraps Android Bluetooth Low Energy API (API Level 18+)
  - Cross-platform API consistent with iOS version
  - Handles permissions automatically

- **Unified Layer**: Create wrapper service abstracting platform differences

### Alternatives Considered
1. **react-native-ble-cli-test** (abandoned)
   - ❌ Unmaintained, security vulnerabilities

2. **react-native-ble (TooTallNate)**
   - ❌ Android-only, iOS support lacking

3. **NativeModules (custom Objective-C/Kotlin)**
   - ❌ High complexity, maintenance burden
   - ✅ But: maximum control over BLE lifecycle

### Implementation Considerations

**BLE Permission Handling**:

**iOS (iOS 13+)**:
```
Info.plist Requirements:
- NSBluetoothPeripheralUsageDescription (not needed for central mode)
- NSBluetoothCentralUsageDescription: "Required to connect to fuel dispensers"

Runtime: requestPermission() auto-prompts user on first BLE scan

Privacy: iOS 14+ randomizes MAC addresses per app
```

**Android (API 31+)**:
```
AndroidManifest.xml:
- BLUETOOTH (connect to paired devices)
- BLUETOOTH_SCAN (discover devices)
- BLUETOOTH_CONNECT (initiate connections)
- ACCESS_FINE_LOCATION (for BLE scan on Android 11 and below)

Runtime: requestPermissions() on first BLE operation

Privacy: Android 12+ requires BLUETOOTH_SCAN + BLUETOOTH_CONNECT runtime permissions
```

**Background BLE Scanning**:
- **iOS**: Supports limited background BLE scanning if app is background-active
  - Practical: Foreground app only, background fetching for measurements every 15 min

- **Android**: Background scans require WorkManager (scheduled tasks)
  - Practical: Foreground service when needed, scheduled scans every 10 min when measurement queued

**BLE Search & Connection Flow**:
```typescript
// Pseudocode
async scanForESP32Device(): UUID {
  const results = await ble.startDeviceScan(
    [SERVICE_UUID],  // Filter by custom service UUID
    {timeout: 5000},
    (device) => {
      if (device.name?.includes('OliMeeter')) {
        return device.id;  // Return device ID for connection
      }
    }
  );
  return results[0]?.id;
}

async connectAndRelay(deviceId, measurements): {
  const device = await ble.connectToDevice(deviceId);
  const service = await device.discoverAllServicesAndCharacteristics();

  for (const measurement of measurements) {
    const payload = JSON.stringify(measurement);
    const checksum = sha256(payload);

    // Write to measurement characteristic
    await ble.writeCharacteristicWithResponseForDevice(
      device.id,
      SERVICE_UUID,
      MEASUREMENT_CHAR_UUID,
      payload
    );

    // Wait for acknowledgment via status characteristic
    const ack = await ble.readCharacteristicForDevice(...);
    if (ack.status !== 'success') throw new Error('BLE write failed');
  }

  await device.cancelConnection();
}
```

**Local Queueing (AsyncStorage)**:
- Store failed measurements in AsyncStorage with retry count
- Max queue size: 100 measurements (varies by device available storage)
- 24-hour retention: delete entries older than 24 hours
- Retry logic: same exponential backoff as ESP32

---

## 5. REST API ↔ ESP32 Integration (WiFi Primary)

### Decision
**Certificate pinning** + **exponential backoff retries** + **idempotency keys** for robust REST communication.

### Rationale
- **Certificate Pinning**: Prevents MITM attacks even if device certificate chain compromised
- **Exponential Backoff**: Prevents overwhelming backend during outages, improves reliability
- **Idempotency Keys**: Ensures retries don't create duplicate measurements

### Alternatives Considered
1. **HTTP (unencrypted)**
   - ❌ Security vulnerability; plaintext credentials/data

2. **Self-Signed Certificates (no pinning)**
   - ❌ Still vulnerable to MITM with forged certs
   - ✅ Simpler but less secure

### Implementation Considerations

**Certificate Pinning**:
```cpp
// Pin backend certificate SHA-256 hash on ESP32
const char* ROOT_CA = R"EOF(
-----BEGIN CERTIFICATE-----
[backend certificate in PEM format]
-----END CERTIFICATE-----
)EOF";

client.setCACert(ROOT_CA);  // Arduino-ESP32 WiFiClientSecure
```

**Exponential Backoff Pattern**:
```
Retry Attempt | Delay | Cumulative | Max Retries
1             | 1s    | 1s         | 10
2             | 2s    | 3s         |
3             | 4s    | 7s         |
4             | 8s    | 15s        |
5             | 16s   | 31s        |
6             | 32s   | 1m 3s      |
7             | 64s   | 2m 7s      |
8             | 128s  | 4m 15s     |
9             | 256s  | 8m 31s     | ← Max delay capped
10            | 300s (5m) | 13m 31s |

After 10 failures over ~13 minutes: GIVE UP, fallback to BLE
```

**Idempotency Key Implementation**:
```cpp
// ESP32-side: generate UUID for each measurement, never reuse
char idempotency_key[37];
esp_random_uuid(idempotency_key);  // library function for UUID v4

// Retry same measurement with same key
headers["Idempotency-Key"] = idempotency_key;
headers["X-Checksum"] = calculateSHA256(payload);
headers["Content-Type"] = "application/json";

// Backend response:
// 201 Created (first submit)
// 202 Accepted (retry of same key) → returns cached response
// 409 Conflict (different payload, same key) → client error
```

---

## 6. BLE-to-Backend Proxy Pattern (Mobile Bridge)

### Decision
**Tiered Communication**: WiFi primary → BLE fallback → local queueing

See detailed research:
- **Summary**: `/specs/001-fuel-tracking/ble-proxy-summary.md`
- **Full Technical**: `/specs/001-fuel-tracking/ble-proxy-research.md`

### Quick Summary

| Component | Behavior |
|-----------|----------|
| **ESP32 Primary** | Attempts WiFi → REST API to backend (~500ms latency) |
| **Mobile Fallback** | If WiFi lost, ESP32 sends measurement via BLE → mobile relays to backend via REST |
| **Local Queues** | ESP32 queues 7 days (survives power loss), Mobile queues 24h (AsyncStorage) |
| **Idempotency** | UUID-based deduplication prevents multiple measurements from same attempt |
| **Security** | 9-step validation on backend (auth + device verification + checksum + permission + timestamp) |

### Key Architectural Decisions

1. **Mobile User Authentication**: User making dispensing request is trusted to proxy data (JWT token proves identity)
2. **Permission Model**: Backend validates that mobile user has `proxy_capability` for specific device IDs (prevent cross-device proxy)
3. **Checksum Validation**: SHA-256 hashes validate at each hop (ESP32 → Mobile → Backend)
4. **Audit Trail**: Backend tags all BLE-proxied measurements with `communication_channel: "ble"` for analysis

---

## 7. MQTT for Home Assistant

### Decision
Use **MQTT with QoS 1** (at-least-once delivery) + **retained connectivity topics** + **Home Assistant MQTT discovery protocol**.

### Rationale
- **Home Assistant Integration**: Automatic device discovery via `homeassistant/` prefix topics
- **QoS 1**: Ensures measurement events delivered at least once (acceptable for status updates, redundant with REST)
- **Retained Topics**: Last known state persists even if broker restarts
- **Multi-Channel**: Independent from REST API (MQTT serves real-time dashboard, REST for critical measurements)

### Alternatives Considered
1. **QoS 0 (at-most-once)**
   - ❌ May lose events during network blips
   - ✅ Lower latency, suitable for frequent updates

2. **QoS 2 (exactly-once)**
   - ❌ Higher overhead, overkill for status updates
   - ✅ Guaranteed exactly-once (expensive)

### Implementation Considerations

**Home Assistant MQTT Discovery Topics**:
```
# Device Registration (Home Assistant autodiscovery)
homeassistant/sensor/olimeeter_device_{device_id}/measurement/config
{
  "device": {"identifiers": ["device_id"], "name": "Fuel Dispenser #1"},
  "name": "Fuel Dispensed (L)",
  "state_topic": "home_assistant/fueling/device/{device_id}/measurement",
  "unit_of_measurement": "L",
  "value_template": "{{ value_json.volume_liters }}"
}

# Connectivity Status Topic (retained)
home_assistant/fueling/device/{device_id}/connectivity
{
  "status": "wifi" | "ble" | "offline",
  "signal_strength_dBm": -67,
  "last_seen": "2026-02-27T14:32:45Z"
}

# Relay State Topic (retained)
home_assistant/fueling/device/{device_id}/relay
{
  "state": "open" | "closed",
  "max_liters_active": 25.0,
  "timestamp": "2026-02-27T14:32:45Z"
}

# Measurement Events (real-time)
home_assistant/fueling/device/{device_id}/measurement
{
  "volume_liters": 5.2,
  "timestamp": "2026-02-27T14:32:22Z",
  "dispensing_request_id": "req-abc-123",
  "communication_channel": "wifi" | "ble-proxied"
}
```

**MQTT Broker Configuration**:
- Mosquitto (open-source MQTT broker)
- Persistence enabled (disk storage for retained messages)
- TLS/SSL required for production (certificate from Let's Encrypt)
- Max message size: 256KB (sufficient for measurement batches)
- Retained message expiration: 30 days (old status auto-cleaned)

---

## 8. Spring Boot 4.0.1 with Java 25

### Decision
Use **Virtual Threads** (Project Loom) for handling 100+ concurrent dispensing requests with minimal thread overhead.

### Rationale
- **Virtual Threads**: Each request gets its own thread without OS context switching overhead (1000s of threads possible)
- **Spring Boot 4.0.1**: Full virtual thread support via `spring.threads.virtual.enabled=true`
- **Java 25**: Latest stable JDK with mature Loom implementation
- **Throughput**: 100+ concurrent requests achievable with fewer physical OS threads

### Alternatives Considered
1. **Reactive Programming (WebFlux)**
   - ✅ Higher throughput (non-blocking I/O)
   - ❌ Complex callback chains, harder debugging
   - ❌ Large learning curve

2. **Traditional Threading (Spring MVC)**
   - ✅ Familiar programming model
   - ❌ Limited scalability (OS thread overhead ~1-2MB per thread)

### Implementation Considerations

**Spring Boot Configuration**:
```yaml
spring:
  threads:
    virtual:
      enabled: true  # Enable Project Loom virtual threads
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 50
          fetch_size: 50
        order_inserts: true
        order_updates: true
  datasource:
    hikari:
      maximum-pool-size: 50  # Large pool for many concurrent threads
      minimum-idle: 10
```

**Handling BLE-Proxied Requests**:
```java
@RestController
@RequestMapping("/api/v1/ble-proxy")
public class BLEProxyController {

    @PostMapping("/measurements")
    public ResponseEntity<?> proxyMeasurements(
        @RequestHeader("Mobile-User-ID") String userId,
        @RequestHeader("ESP32-Device-ID") String deviceId,
        @RequestHeader("Idempotency-Key") String idempotencyKey,
        @RequestBody List<MeasurementDTO> measurements
    ) {
        // Virtual thread handles this request
        // 1. Verify mobile user (JWT validation)
        // 2. Check device proxy permission
        // 3. Validate checksum
        // 4. Deduplication (check idempotency key cache)
        // 5. Create dispensing records
        // 6. Publish MQTT events
        // Returns 201 Created or 202 Accepted
    }
}
```

**Authentication & Authorization**:
```java
// Spring Security 6.x configuration
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .httpBasic(Customizer.withDefaults())  // JWT parsing
            .csrf().disable()  // REST stateless
            .authorizeRequests()
                .requestMatchers("/api/v1/measurements").permitAll()  // Device auth via headers
                .requestMatchers("/api/v1/ble-proxy/**").authenticated()  // Mobile user JWT
                .anyRequest().authenticated()
            .build();
    }
}
```

---

## 9. PostgreSQL 15+ Data Integrity

### Decision
Use **immutable ledger table** + **JSONB for WiFi config storage** + **SERIALIZABLE transaction isolation** for concurrent dispensing.

### Rationale
- **Immutable Ledger**: `dispensing_records` table is append-only (no updates/deletes) → audit trail automatically preserved
- **JSONB**: Stores array of WiFi profiles without schema changes (flexible + queryable)
- **SERIALIZABLE**: Highest isolation level prevents race conditions (e.g., overdrawing quota)

### Alternatives Considered
1. **Soft Deletes (deleted_at column)**
   - ❌ Clutters queries with WHERE deleted_at IS NULL
   - ✅ But: easier to undo accidental deletions

2. **READ_COMMITTED Isolation**
   - ❌ Allows phantom reads (quota discrepancies under load)
   - ✅ Higher throughput but risks data inconsistency

### Implementation Considerations

**Immutable Ledger Schema**:
```sql
CREATE TABLE dispensing_records (
    id BIGSERIAL PRIMARY KEY,
    dispensing_request_id UUID NOT NULL,
    device_id UUID NOT NULL,
    user_id UUID NOT NULL,
    volume_liters NUMERIC(10,2) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    communication_channel VARCHAR(20),  -- 'wifi' or 'ble-proxied'
    backend_received_at TIMESTAMP DEFAULT NOW(),
    checksum VARCHAR(64),
    idempotency_key UUID UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Immutability: triggers prevent UPDATE/DELETE
CREATE TRIGGER prevent_dispensing_record_modification
    BEFORE UPDATE OR DELETE ON dispensing_records
    FOR EACH ROW
    EXECUTE FUNCTION raise_immutable_error();

-- Indexes for performance
CREATE INDEX idx_dispensing_records_user ON dispensing_records (user_id, created_at DESC);
CREATE INDEX idx_dispensing_records_device ON dispensing_records (device_id, created_at DESC);
CREATE INDEX idx_dispensing_records_request ON dispensing_records (dispensing_request_id);
```

**WiFi Configuration Storage (JSONB)**:
```sql
CREATE TABLE measuring_devices (
    id UUID PRIMARY KEY,
    device_name VARCHAR(100),
    facility_id UUID,
    wifi_config JSONB,  -- Array of SSID profiles
    ble_config JSONB,   -- BLE service UUIDs, security settings
    firmware_version VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Example JSONB content:
{
  "ssid_profiles": [
    {
      "ssid": "MainFacility",
      "priority": 1,
      "enabled": true
    },
    {
      "ssid": "Backup",
      "priority": 2,
      "enabled": true
    }
  ]
}

-- Query JSONB arrays:
SELECT * FROM measuring_devices
WHERE wifi_config->'ssid_profiles'[0]->>'ssid' = 'MainFacility';
```

**SERIALIZABLE Transaction for Quota Enforcement**:
```java
@Transactional(isolation = Isolation.SERIALIZABLE)
public DispensingResponse requestDispensing(String userId, double requestedLiters) {
    // BEGIN SERIALIZABLE TRANSACTION

    // 1. Lock user's quota rules (prevents concurrent updates)
    List<QuotaRule> rules = quotaRepository.findByUserIdForUpdate(userId);

    // 2. Fetch today's consumption (prevents phantom reads)
    double consumedToday = recordRepository.getDailyConsumption(userId);

    // 3. Calculate max_liters based on rules
    double maxAllowed = calculateMaxLiters(rules, consumedToday);
    double approvedLiters = Math.min(requestedLiters, maxAllowed);

    // 4. Create dispensing request
    if (approvedLiters >= 0) {
        DispensingRequest req = requestRepository.save(...);
        // SERIALIZABLE prevents any other transaction from reading stale quota state
        return new DispensingResponse(APPROVED, approvedLiters, req.id);
    }
    return new DispensingResponse(REJECTED, 0, null);
}
```

---

## 10. React + Ant Design Offline Architecture

### Decision
Use **IndexedDB with service worker** for offline caching + **SWR library** for cache invalidation and sync.

### Rationale
- **IndexedDB**: Stores history locally (100+ entries possible), survives app reload
- **Service Worker**: Intercepts network requests, serves cached responses when offline
- **SWR (Stale-While-Revalidate)**: Serves cached data instantly, updates in background when online

### Alternatives Considered
1. **SQLite (React Native)**
   - ❌ Not available in browser (web only)
   - ✅ But: essential for mobile app

2. **LocalStorage**
   - ❌ Limited to 5-10MB, slower than IndexedDB
   - ✅ Simpler API

### Implementation Considerations

**IndexedDB Schema** (frontend):
```javascript
// Database: olimeeter_v1
// Store: dispensing_history
{
    keyPath: 'id',
    indexes: [
        {name: 'user_id', keyPath: 'user_id'},
        {name: 'created_at', keyPath: 'created_at'}
    ]
}

// Document structure:
{
    id: "disp-123",
    user_id: "user-abc",
    volume_liters: 5.2,
    max_liters: 25.0,
    status: "completed",
    dispensing_date: "2026-02-27",
    backend_synced: true,
    created_at: 1709018340000  // timestamp
}
```

**Service Worker Pattern** (frontend):
```javascript
// sw.js: intercept ALL requests to /api/v1/dispensing-history
self.addEventListener('fetch', (event) => {
    if (event.request.url.includes('/api/v1/dispensing-history')) {
        event.respondWith(
            caches.open('api-v1')
                .then(cache => cache.match(event.request))
                .then(cachedResponse =>
                    cachedResponse || fetch(event.request)
                )
                .catch(() => new Response('{}', {status: 500}))  // offline fallback
        );
    }
});
```

**SWR Integration** (React component):
```typescript
import useSWR from 'swr';

export function HistoryList() {
    // fetcher handles offline + online sync automatically
    const {data, error, isLoading, mutate} = useSWR(
        `/api/v1/users/${userId}/dispensing-history`,
        fetcher,
        {
            revalidateOnFocus: true,      // Refresh on window focus
            revalidateOnReconnect: true,  // Refresh when WiFi restored
            dedupingInterval: 5000,        // Don't fetch same URL twice in 5s
            focusThrottleInterval: 5000,
            localStorage: true           // Use localStorage as L1 cache
        }
    );

    return (
        <div>
            {error && <p>Failed to load: {error.message}</p>}
            {isLoading && <p>Loading...</p>}
            {data?.map(item => <HistoryRow key={item.id} {...item} />)}
        </div>
    );
}
```

**Conflict Resolution**:
- When online: backend is source of truth
- When offline: use cached data (marked as stale)
- Conflict scenario: user views cached history, then goes online
  - SWR automatically refetches from backend
  - If backend has new records, merge with cache
  - If local cache is newer (shouldn't happen), backend wins
  - Visual indicator: "Updated from server" badge

---

## 11. React Native + BLE Security

### Decision
Use **react-native-keychain** for secure token storage + **platform-specific background modes**.

### Rationale
- **react-native-keychain**:
  - iOS: Uses Keychain + Face ID/Touch ID
  - Android: Uses Keystore system
  - Never exposes tokens in app memory

- **Background Modes**:
  - iOS: Background App Refresh for periodic measurement sync
  - Android: WorkManager (scheduled tasks) + foreground service for active measurements

### Alternatives Considered
1. **AsyncStorage (plaintext)**
   - ❌ Security risk; tokens readable by other apps
   - ✅ Simpler API

2. **MMKV (encrypted AsyncStorage)**
   - ✅ Good balance, smaller footprint
   - ❌ Third-party dependency with more failure modes

### Implementation Considerations

**Secure Token Storage**:
```typescript
import * as Keychain from 'react-native-keychain';

// Store JWT token after login
await Keychain.setGenericPassword('olimeeter', tokenValue, {
    service: 'com.olimeeter.fuel',
    storage: Keychain.SECURITY_LEVEL.VERY_STRONG,
    accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY
});

// iOS: requires Face ID/Touch ID on unlock
// Android: encrypted in Android Keystore, requires device unlock

// Retrieve token for API calls
const credentials = await Keychain.getGenericPassword();
const token = credentials?.password;

// Logout
await Keychain.resetGenericPassword();
```

**Background Measurement Relay** (iOS):
```swift
// Info.plist
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>  <!-- Background App Refresh -->
</array>

// ViewController.swift
import BackgroundTasks

func scheduleBackgroundFetch() {
    let request = BGAppRefreshTaskRequest(identifier: "com.olimeeter.fuel.sync-measurements")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)  // 15 minutes

    try? BGTaskScheduler.shared.submit(request)
}

// AppDelegate.swift
func application(_ app: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.olimeeter.fuel.sync-measurements",
        using: nil
    ) { task in
        self.handleBackgroundSync(task: task as! BGAppRefreshTask)
    }
    return true
}
```

**Background Measurement Relay** (Android):
```kotlin
// AndroidManifest.xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

// WorkManager scheduled task
class MeasurementSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            relayQueuedMeasurements()  // BLE + REST proxy
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}

// Schedule periodic sync (every 15 minutes when plugged in)
val measurementSyncRequest = PeriodicWorkRequestBuilder<MeasurementSyncWorker>(
    15, TimeUnit.MINUTES
).setConstraints(
    Constraints.Builder()
        .setRequiresCharging(true)
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()
).build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "measurement_sync",
    ExistingPeriodicWorkPolicy.REPLACE,
    measurementSyncRequest
)
```

**BLE Background Scanning** (iOS vs Android):
- **iOS**: Requires app in foreground or background fetch timeout occurs (iOS limits to ~30s)
  - Practical: Active scanning only when app in foreground
  - Deferred: Background scanning (complex, low value)

- **Android**: WorkManager supports background BLE scan with high accuracy requirements
  - Practical: Periodic scans every 10 min for queued measurements

---

## Summary: Design Ready for Phase 1

All 11 research tasks completed. Key technical decisions documented:

✅ **Firmware**: PlatformIO + Arduino-ESP32 + NimBLE + NVRAM WiFi profiles + SPIFFS queue
✅ **Backend**: Spring Boot 4.0.1 + Java 25 virtual threads + PostgreSQL immutable ledger
✅ **Frontend**: React 19.2.4 + Ant Design + IndexedDB + SWR + Service worker
✅ **Mobile**: React Native + BLE proxying + Keychain token storage + WorkManager background
✅ **Communication**: REST API (primary) + MQTT (events) + BLE (fallback) + idempotency keys
✅ **Security**: Certificate pinning + JWT + permission model + SHA-256 checksums
✅ **Resilience**: 3-layer queueing (ESP32 + Mobile + DB) + exponential backoff + deduplication

---

## Next: Phase 1 Design & Contracts

Proceed to:
1. **data-model.md** - Entity definitions with field mappings
2. **contracts/** - OpenAPI/JSON schemas for all 8 API endpoints
3. **quickstart.md** - Local development environment setup
4. Agent context update via `.specify/scripts/bash/update-agent-context.sh`
