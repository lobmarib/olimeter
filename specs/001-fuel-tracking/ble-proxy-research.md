# Research: BLE-to-REST Proxy Pattern for Mobile App Integration

**Date**: 2026-02-27
**Context**: OliMeeter Fuel Dispensing Tracking System
**Scope**: Mobile app acting as BLE bridge between ESP32 device and REST backend
**Status**: Research Complete

---

## Executive Summary

The BLE-to-REST proxy pattern is **recommended** for your system as a **fallback communication channel** when the ESP32 device loses WiFi connectivity but remains in Bluetooth range of the mobile device. This document analyzes the architecture, security implications, failure handling, and implementation considerations.

**Key Finding**: The proxy pattern is viable with proper authentication delegation, local queueing at both ends, and idempotency guarantees. Complexity is managed through layered fallback logic and clear request/response contracts.

---

## 1. Architecture Overview

### Primary vs. Fallback Flows

```
SCENARIO 1: Normal Operation (WiFi Available)
ESP32 --[WiFi/REST]--> Backend
Mobile App --[WiFi/REST]--> Backend

SCENARIO 2: WiFi Unavailable (BLE Bridge Active)
ESP32 --[BLE]--> Mobile App --[WiFi/REST]--> Backend
Mobile App --[BLE]--> ESP32 (relay commands from backend)
```

### Data Flow Sequence

#### 1.1 Measurement Relay (ESP32 → Backend via Mobile BLE)

```
Step 1: ESP32 measures fuel dispensing
   └─ Records: volume_liters, timestamp, dispensing_request_id
   └─ Generates: idempotency_key (UUID), checksum (SHA-256)
   └─ Stores locally if can't send via WiFi

Step 2: Mobile app detects nearby ESP32 via BLE scan
   └─ UUID-based discovery (ServiceUUID known in app config)
   └─ Establishes BLE peripheral connection

Step 3: Mobile reads measurements from ESP32 BLE GATT characteristic
   └─ Measurement data + metadata transferred over BLE

Step 4: Mobile proxies to backend via REST API
   └─ POST /api/v1/ble-proxy/measurements
   └─ Headers include:
      - Mobile-User-ID (identifies which user's device proxying)
      - ESP32-Device-ID (identifies source device)
      - Idempotency-Key (from ESP32 measurement)
      - X-Checksum (SHA-256, recalculated on mobile)
      - Communication-Channel: "ble-proxied"
   └─ Payload: measurements array with all metadata

Step 5: Backend validates & deduplicates (idempotency key)
   └─ Checksum validated
   └─ Idempotency key prevents duplicate processing
   └─ If duplicate: return HTTP 202 Accepted (already processed)
   └─ If new: create dispensing record, return HTTP 201

Step 6: Mobile notifies ESP32 via BLE
   └─ Read confirmation characteristic or send notification
   └─ ESP32 removes successfully transmitted measurements from local queue

Step 7: Backend publishes to MQTT (optional Home Assistant sync)
   └─ Topic: home_assistant/fueling/device/{device_id}/measurement
   └─ Payload includes: channel="ble-proxied"
```

#### 1.2 Command Relay (Backend → ESP32 via Mobile BLE)

```
Step 1: Backend approves dispensing request
   └─ User initiated fuel request
   └─ Quota validated, approval granted

Step 2: Backend sends relay activation command to ESP32
   └─ POST /api/v1/devices/{device_id}/relay/activate
   └─ Destination: Direct WiFi REST if available
   └─ Fallback: Queue for mobile BLE relay

Step 3: Mobile app has pending BLE command from backend
   └─ Subscribe to backend command channel
   └─ Query: GET /api/v1/ble-proxy/commands?esp32_device_id=XX&limit=1
   └─ Or: Push notification to mobile (optional)

Step 4: Mobile writes command to ESP32 via BLE
   └─ Write to BLE GATT characteristic
   └─ Command: {action: "activate", request_id, timestamp}
   └─ Checksum calculated on mobile

Step 5: ESP32 receives command via BLE
   └─ Validates checksum
   └─ Activates relay if valid
   └─ Queues for confirmation when WiFi available

Step 6: ESP32 confirms command execution
   └─ Via WiFi: POST /api/v1/devices/{device_id}/relay/status
   └─ Via BLE: Mobile reads status characteristic, proxies to backend
```

### State Machine: BLE Proxy Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  IDLE: Normal WiFi Operation                                │
│  ├─ ESP32: WiFi connected, measurements sent directly       │
│  ├─ Mobile: REST API only, BLE scanner disabled             │
│  └─ Transition: WiFi lost → BLE_SCAN_PENDING               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  BLE_SCAN_PENDING: WiFi unavailable, searching for ESP32    │
│  ├─ Mobile: Start BLE scan for known device UUIDs           │
│  ├─ Duration: 10 seconds (configurable, power trade-off)    │
│  ├─ Cache: Previous devices' addresses for faster reconnect │
│  └─ Transition: Device found → BLE_CONNECTING              │
│                 Scan timeout → OFFLINE                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  BLE_CONNECTING: Establishing BLE connection                │
│  ├─ Mobile: Connect to ESP32 peripheral (10 sec timeout)    │
│  ├─ ESP32: Advertising BLE service                          │
│  └─ Transition: Connection success → BLE_SYNCING            │
│                 Connection timeout → BLE_SCAN_PENDING       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  BLE_SYNCING: Connected, exchanging data                     │
│  ├─ Mobile: Read queued measurements from ESP32             │
│  ├─ Mobile: Relay to backend via REST                       │
│  ├─ Mobile: Check for pending backend commands              │
│  ├─ Mobile: Write commands to ESP32                         │
│  └─ Transition: WiFi restored → IDLE                        │
│                 BLE connection lost → BLE_SCAN_PENDING      │
│                 Sync complete, no data → IDLE (or stay)     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  OFFLINE: No WiFi, no BLE connection available              │
│  ├─ Mobile: Local queue enabled for measurements            │
│  ├─ ESP32: Local queue active (7-day retention)             │
│  ├─ Mobile: Periodic WiFi check every 30 seconds            │
│  └─ Transition: WiFi restored → IDLE                        │
│                 BLE device found → BLE_SCAN_PENDING         │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Decision: BLE-to-REST Proxy for Fallback Communication

### Decision Statement

**The mobile app MUST act as a BLE-to-REST proxy when the ESP32 device:
1. Loses WiFi connectivity
2. Has pending measurements in local queue
3. Remains in Bluetooth range of the mobile device**

**IMPORTANT**: The BLE proxy is specifically:
- **Fallback**, not primary (primary is WiFi/REST or MQTT)
- **Asynchronous**, not real-time (measurements are queued, not streaming)
- **Bridge-only**, not storage (mobile does not store measurements permanently)
- **Stateless**, not connected (each sync operation is independent)

---

## 3. Rationale

### Why This Architecture

#### 3.1 Solves Key System Requirements

| Requirement | How BLE Proxy Solves |
|---|---|
| **Zero data loss** | ESP32 queues locally 7 days; mobile acts as secondary relay when WiFi unavailable |
| **Offline resilience** | Measurement data reaches backend even before WiFi restored, via mobile BLE bridge |
| **Rapid measurements** | Mobile nearby + WiFi available = fast sync; avoids waiting for WiFi auto-recovery |
| **Multi-channel redundancy** | 3 channels: WiFi/REST (primary), MQTT (secondary), BLE/mobile (tertiary) |
| **Cost-effective IoT** | No expensive cellular modem in ESP32; leverages existing mobile devices |

#### 3.2 Trust Chain: Who Owns the Data?

```
┌─────────────────────────────────────────────────────────────┐
│  TRUST HIERARCHY (Backend Verification)                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ESP32 measurement (via WiFi)                                │
│  └─ Signed by: Device ID, timestamp, idempotency key        │
│  └─ Verified by: Backend checks device authorization        │
│  └─ Trust Level: HIGH (direct device-to-backend)            │
│                                                               │
│  Mobile APP proxies ESP32 measurement (via BLE → REST)       │
│  └─ Signed by: ESP32-Device-ID, Mobile-User-ID, Idempotency │
│  └─ Verified by: Backend checks:                             │
│     1. Mobile user is authenticated (token)                  │
│     2. ESP32 device is known & valid                         │
│     3. Idempotency key not previously processed              │
│     4. Checksum matches payload                              │
│     5. Channel = "ble-proxied" (auditability)                │
│  └─ Trust Level: MEDIUM (authentication delegation)          │
│                                                               │
│  Backend sends activation command via mobile BLE relay       │
│  └─ Signed by: Backend signature, timestamp, request_id      │
│  └─ Verified by: Mobile checks JWT signature on command      │
│  └─ ESP32 validates command comes from backend (cached key)  │
│  └─ Trust Level: MEDIUM (command delegation through mobile)  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

#### 3.3 Data Integrity Throughout Proxy

```
ESP32 Measurement
├─ Data: volume_liters, timestamp, device_id, request_id
├─ Integrity Check: SHA-256 checksum calculated by ESP32
├─ Idempotency Key: UUID generated by ESP32
└─ Transport: BLE (unencrypted but short-range & proximity-based)

Mobile Bridge
├─ Receives via BLE: measurement + checksum + idempotency key
├─ VALIDATES: Recalculates SHA-256, compares with received
├─ If valid: Proxies to backend REST API
├─ If invalid: Rejects, requests retransmission (BLE notification)
├─ Headers added: Mobile-User-ID, ESP32-Device-ID, Communication-Channel
└─ Transport: WiFi REST (TLS/encrypted)

Backend Validation
├─ Receives: All headers + measurement payload + checksum
├─ VALIDATES:
│  1. JWT token from mobile (Mobile-User-ID)
│  2. Device ID known & active (ESP32-Device-ID)
│  3. Checksum matches (SHA-256)
│  4. Idempotency key not seen before (deduplication)
│  5. Volume is physically realistic (> 0, < tank capacity)
│  6. Timestamp is recent (not more than 24 hours old)
├─ If any validation fails: Reject (HTTP 400), log reason
├─ If all pass: Create dispensing record (ATOMIC transaction)
└─ Response: Return original idempotency key for audit trail
```

---

## 4. Alternatives Considered

### 4.1 Alternative 1: No BLE Proxy (WiFi Only)

**Description**: ESP32 only communicates via WiFi. No mobile BLE bridge.

**Pros**:
- Simpler architecture
- No mobile app complexity
- No authentication delegation concerns

**Cons**:
- Data loss if WiFi unavailable > 24 hours
- No way to recover measurements once ESP32 queue fills
- Violates "Zero data loss" principle in constitution
- Failed measurements not recoverable if device reboots

**Verdict**: ❌ **Rejected** - violates data resilience requirement

---

### 4.2 Alternative 2: Cellular Backhaul in ESP32

**Description**: ESP32 includes a cellular modem (4G LTE) for direct backend communication when WiFi fails.

**Pros**:
- Direct measurement transmission (no mobile proxy needed)
- Real-time relay activation
- Simpler trust model

**Cons**:
- Hardware cost (+$50-100 per device)
- ESP32 power consumption increases 5x (cellular modem always-on)
- Cellular plan cost per device
- Not suitable for deployments in areas without cellular coverage
- Over-engineered for most use cases (fuel tracking at facilities with WiFi)

**Verdict**: ❌ **Over-scoped** - adds cost without necessity; BLE proxy is lighter

---

### 4.3 Alternative 3: NRF24L01+ Radio for Direct Device-to-Device Mesh

**Description**: ESP32 uses 2.4 GHz radio (NRF24L01+) to mesh with other ESP32 devices to reach WiFi gateway.

**Pros**:
- No mobile app required
- Can extend range beyond single device
- Low power compared to WiFi

**Cons**:
- Requires multiple ESP32 devices (only works if >1 device in facility)
- Mesh networking is complex & unreliable
- No existing devices to mesh with in initial deployment
- Mobile phone already on-site for fuel request; why not use it?

**Verdict**: ❌ **Over-complex** - assumes multi-device mesh; single device starting

---

### 4.4 Alternative 4: HTTP/HTTP Long-Polling from Mobile

**Description**: Mobile app periodically polls backend for pending commands instead of subscription.

**Pros**:
- No push notification infrastructure needed
- Simpler mobile implementation

**Cons**:
- High latency (5-10 second poll interval = slow command delivery)
- Higher backend load (constant polling)
- Battery drain on mobile (wakeups every 5 seconds)
- Not real-time acceptable for relay activation safety

**Verdict**: ❌ **Inefficient** - BLE + push is better; see Alternative 6 for optimization

---

### 4.5 Alternative 5: MQTT on Mobile App Directly

**Description**: Mobile app subscribes to MQTT broker instead of polling REST backend.

**Pros**:
- Lower latency command delivery (publish/subscribe)
- Lower backend load (MQTT pub/sub model)
- Mobile battery efficient (event-driven, not polling)

**Cons**:
- MQTT broker must be accessible from mobile WiFi (firewall/NAT issues)
- Credential management on mobile (MQTT username/password vs JWT)
- Not all facilities firewalls allow MQTT (often blocks port 1883/8883)
- Still need REST API for other operations (history, user auth)
- Adds complexity of dual protocol support

**Verdict**: ⚠️ **Possible Enhancement** - but not recommended for MVP; REST-based polling with exponential backoff sufficient. Can add MQTT bridge later.

---

### 4.6 Alternative 6: WebSocket for Full-Duplex from Mobile

**Description**: Mobile maintains WebSocket connection to backend for bidirectional commands.

**Pros**:
- True real-time command delivery
- No polling overhead
- Mobile acts as always-connected relay

**Cons**:
- WebSocket infrastructure overhead on backend (connection pooling, session management)
- Mobile battery drain (persistent connection)
- Requires mobile user to accept permission for background connectivity
- Over-engineered for asynchronous measurement relay

**Verdict**: ⚠️ **Future Enhancement** - too complex for Phase 1; simpler REST polling sufficient for initial implementation

---

## 5. Security Implications of Proxying

### 5.1 Authentication Delegation Model

```
WITHOUT Proxy (Direct):
┌─────────────────────────────────────────────────────────────┐
│  Mobile User A (Authenticated)                              │
│  └─ Token: JWT from backend (Mobile-User-ID = user_a)       │
│  └─ Owns: data directly sent by user_a                      │
└─────────────────────────────────────────────────────────────┘

WITH Proxy (BLE Bridge):
┌─────────────────────────────────────────────────────────────┐
│  Mobile User A (Authenticated)                              │
│  └─ Token: JWT from backend (Mobile-User-ID = user_a)       │
│  └─ Proxies: data from ESP32 Device D                       │
│  └─ Question: Can User A send data claiming it's from D?    │
│  └─ Question: Does Backend trust User A owns Device D?      │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Threat Model: BLE Proxy Attack Vectors

| Attack Vector | Threat | Mitigation |
|---|---|---|
| **Replay Attacks** | Attacker captures BLE measurement, resends via mobile REST multiple times | Idempotency key: Backend deduplicates by UUID from ESP32 |
| **Forgery** | Mobile app fabricates ESP32 measurement (fake volume) | Device ID verification: Backend checks device is valid; Checksum: SHA-256 must match |
| **Proxy Impersonation** | Attacker creates fake mobile app, sends fake measurements as Device D | JWT token validation: Only authenticated mobile users can proxy; BLE MAC address pinning (optional) |
| **Man-in-Middle (BLE)** | Attacker intercepts BLE communication between mobile and ESP32 | BLE range is short (~10 meters); Physical proximity required; Checksum validates payload |
| **Man-in-Middle (WiFi)** | Attacker intercepts REST API call from mobile to backend | TLS/HTTPS enforced; Certificate pinning on mobile; Domain validation |
| **Unauthorized Device Access** | Mobile user proxies for a device they don't own | Backend checks: User should have permission to proxy for that device ID (new permission model) |
| **Quota Circumvention via Mobile** | User bypasses quota by proxying through multiple mobile devices | Quota checks at backend (idempotency key + device_id); multiple devices just increase transmission count, not volume |
| **Measurement Tampering** | Mobile modifies volume_liters in transit (BLE → REST) | Checksum validation: If mobile tampers, checksum will not match; Request rejected |

### 5.3 Trust Chain Validation Rules

**Backend MUST validate ALL of the following before accepting proxied measurement:**

```java
// Pseudo-code for backend validation
public void validateProxiedMeasurement(MeasurementRequest request, MobileUser mobileUser) {
    // 1. Mobile user is authenticated (JWT token valid)
    assert(mobileUser.isAuthenticated() && mobileUser.tokenNotExpired());

    // 2. Mobile user has permission to proxy for target device
    Device device = deviceRepository.findById(request.getEsp32DeviceId());
    assert(device != null, "Device not found");
    assert(mobileUser.hasPermissionFor(device),
        "Mobile user not authorized to proxy for this device");

    // 3. Device is active and known to backend
    assert(device.isActive(), "Device is inactive");
    assert(device.getStatus() != DECOMMISSIONED, "Device decommissioned");

    // 4. Checksum validates payload integrity
    String calculatedChecksum = sha256(request.getPayload());
    assert(calculatedChecksum.equals(request.getXChecksum()),
        "Checksum mismatch - payload corrupted or tampered");

    // 5. Idempotency key prevents duplicate processing
    if (idempotencyKeyRepository.exists(request.getIdempotencyKey())) {
        logger.info("Duplicate measurement, returning cached response");
        return DUPLICATE_ACCEPTED; // HTTP 202
    }

    // 6. Volume is physically realistic
    assert(request.getVolumeLiters() > 0, "Negative volume detected");
    assert(request.getVolumeLiters() <= device.getMaxCapacity(),
        "Volume exceeds device capacity");

    // 7. Timestamp is recent (not from future, not too old)
    long ageSeconds = System.currentTimeMillis() - request.getTimestamp();
    assert(ageSeconds >= 0 && ageSeconds <= 86400,
        "Timestamp out of acceptable range (future or >24h old)");

    // 8. Communication channel is tracked for compliance
    assert(request.getCommunicationChannel() == "ble-proxied",
        "Channel mismatch annotation");

    // 9. Dispensing request is valid and matches measurement
    DispensingRequest dispensingReq = dispensingRequestRepository
        .findById(request.getDispensingRequestId());
    assert(dispensingReq != null, "Dispensing request not found");
    assert(dispensingReq.getStatus() == APPROVED, "Request not approved");
    assert(dispensingReq.getDeviceId() == device.getId(), "Device mismatch");

    // 10. Volume does not exceed approved limit
    assert(request.getVolumeLiters() <= dispensingReq.getMaxLiters(),
        "Volume exceeds approved limit");

    logger.info("All validations passed for proxied measurement");
    return VALIDATION_PASSED;
}
```

### 5.4 Mobile Device as Trusted Device vs. Untrusted Proxy

**Assumption**: Mobile user is already authenticated to the system for their own dispensing requests. Can they reliably proxy data?

**Answer**: YES, with backend verification above. Mobile acts as **authentication bearer** (user authenticated with JWT), but **device data authenticity must be verified independently**:

1. **Mobile Authentication**: ✅ JWT token proves mobile user is legitimate
2. **Device Data Integrity**: ✅ Checksum + device ID + idempotency key prove data source
3. **Permission Boundary**: ⚠️ **NEW PERMISSION TYPE NEEDED**: `proxy_permission`

#### New Permission Model Required

```
Before (simple):
- User can "dispense_fuel" (user-level action)

After (with proxy):
- User can "dispense_fuel" (original action)
- User can "proxy_for_device[device_id]" (new proxy-specific permission)
- Or: User can "proxy_for_all_devices_in_location[location_id]" (group permission)

Backend enforces:
if (measurementIsProxied) {
    assert(user.hasPermission("proxy_for_device_" + esp32DeviceId));
}
```

**Recommended**: Device-specific or location-specific proxy permissions. Don't allow any authenticated user to proxy for any device.

---

## 6. Implementation Considerations

### 6.1 Mobile App: BLE-to-REST Bridge Logic

#### State Management

```typescript
// Mobile App State (React Context)
interface MobileProxyState {
  // WiFi Status
  wifiConnected: boolean;
  wifiSSID?: string;

  // BLE Status
  bleAvailable: boolean;
  bleEnabled: boolean;
  connectedDevices: Map<string, ESP32Device>; // UUID -> device

  // Pending Operations
  pendingMeasurements: Measurement[]; // Queue of unsent measurements
  pendingCommands: Command[]; // Commands from backend awaiting relay to ESP32

  // Sync State
  lastMeasurementSync?: Date;
  lastCommandCheck?: Date;
  syncInProgress: boolean;

  // Error Handling
  lastError?: {
    type: 'ble' | 'rest' | 'validation';
    message: string;
    timestamp: Date;
  };
}
```

#### BLE Scanning & Connection

```typescript
// Pseudo-code: Mobile app scans for ESP32 devices
async function startBLEProxyIfNeeded() {
  const wifiConnected = await NetworkInfo.isConnected();

  if (!wifiConnected) {
    // WiFi down, start BLE scan
    const devices = await scanForESP32Devices();

    for (const device of devices) {
      // Connect to each device
      const connected = await connectToDevice(device.uuid);

      if (connected) {
        // Read queued measurements
        const measurements = await readMeasurements(device);

        // Relay to backend
        for (const measurement of measurements) {
          try {
            const response = await backendAPI.proxyMeasurement({
              esp32_device_id: device.id,
              measurement: measurement,
              communication_channel: 'ble-proxied',
              relayed_at: new Date().toISOString()
            });

            if (response.status === 'accepted' || response.status === 'duplicate') {
              // Notify ESP32 to remove from queue
              await notifyMeasurementSent(device, measurement.idempotency_key);
            }
          } catch (error) {
            console.error(`Failed to relay measurement: ${error}`);
            // Measurement stays in ESP32 queue, will retry on next sync
          }
        }

        // Check for pending commands from backend
        const commands = await backendAPI.getPendingCommands({
          esp32_device_id: device.id,
          mobile_user_id: currentUser.id
        });

        // Relay commands to ESP32
        for (const command of commands) {
          try {
            await writeCommand(device, command);
            await backendAPI.confirmCommandDelivery(command.id);
          } catch (error) {
            console.error(`Failed to relay command: ${error}`);
            // Command stays pending, will retry on next sync
          }
        }

        // Disconnect
        await disconnectDevice(device.uuid);
      }
    }
  }
}
```

#### Local Offline Queue

```typescript
// Mobile app queues measurements when both WiFi and BLE unavailable
async function queueMeasurementLocally(measurement: Measurement) {
  const db = await openAsyncStorage();

  const key = `pending_measurement_${measurement.idempotency_key}`;
  await db.set(key, JSON.stringify({
    measurement,
    queued_at: new Date().toISOString(),
    retry_count: 0
  }));

  // Set retry timer
  await scheduleRetry(measurement.idempotency_key, 5000); // 5s delay
}

async function processMobileQueue() {
  const db = await openAsyncStorage();
  const keys = await db.getAllKeys();

  for (const key of keys) {
    if (key.startsWith('pending_measurement_')) {
      const item = JSON.parse(await db.get(key));
      const { measurement, retry_count } = item;

      // If can reach backend, send immediately
      if (await canReachBackend()) {
        try {
          await backendAPI.proxyMeasurement(measurement);
          await db.remove(key); // Success, remove from queue
        } catch (error) {
          // Exponential backoff retry
          if (retry_count < 5) {
            item.retry_count++;
            await db.set(key, JSON.stringify(item));
          } else {
            // Give up after 5 retries
            console.error(`Discarding measurement after 5 retries: ${measurement.idempotency_key}`);
            await db.remove(key);
          }
        }
      }
    }
  }
}
```

### 6.2 ESP32: BLE GATT Services for Proxy

#### BLE Service Structure

```cpp
// ESP32 BLE Service for Mobile Proxy
class MeasurementService {
public:
  // Service UUID: well-known (e.g., 550e8400-e29b-41d4-a716-446655440000)
  static constexpr const char* SERVICE_UUID = "550e8400-e29b-41d4-a716-446655440000";

  // Characteristics
  struct {
    // Characteristic 1: Measurement Queue (Read by mobile, Write notifications)
    // UUID: 550e8400-e29b-41d4-a716-446655440001
    // Properties: Read, Notify
    // Format: JSON-serialized Measurement array (max 512 bytes per BLE notification)
    // Encoding: {
    //   "measurements": [
    //     { "volume_liters": 5.2, "timestamp": 1234567890,
    //       "device_id": "esp32-001", "idempotency_key": "uuid-xxx",
    //       "checksum": "sha256-hex", "dispensing_request_id": "req-001" }
    //   ]
    // }

    // Characteristic 2: Command Inbox (Write by mobile, Read by ESP32)
    // UUID: 550e8400-e29b-41d4-a716-446655440002
    // Properties: Write, Read
    // Format: JSON command
    // Encoding: {
    //   "action": "activate" | "stop" | "status",
    //   "request_id": "req-001",
    //   "max_liters": 10.0,
    //   "timestamp": 1234567890,
    //   "signature": "jwt-from-backend"
    // }

    // Characteristic 3: Device Status (Read by mobile)
    // UUID: 550e8400-e29b-41d4-a716-446655440003
    // Properties: Read, Notify
    // Format: Device metadata
    // Encoding: {
    //   "device_id": "esp32-001",
    //   "firmware_version": "2.1.0",
    //   "relay_state": "on" | "off",
    //   "queue_size": 3,
    //   "last_sync": 1234567890,
    //   "battery_level": 85,
    //   "signal_strength": -65
    // }
  } characteristics;
};
```

#### BLE MTU & Fragmentation

**Issue**: BLE has limited packet size (MTU = 20-23 bytes default, can negotiate up to 251 bytes).

**Solution**:
1. **Negotiate MTU**: Mobile app requests MTU 251 during connection setup
2. **Chunk Large Measurements**: If measurement JSON > MTU, send multiple notifications
3. **Use Sequence Numbers**: Each chunk includes `seq_num` and `total_chunks` for reassembly

```cpp
// Pseudo-code: ESP32 sends chunked measurement
void notifyMeasurementChunked() {
  String measurementJson = serializeMeasurements();

  const int MTU = 251 - 3; // 248 bytes usable (3 bytes overhead)
  const int totalChunks = (measurementJson.length() + MTU - 1) / MTU;

  for (int chunk = 0; chunk < totalChunks; chunk++) {
    int start = chunk * MTU;
    int end = min(start + MTU, measurementJson.length());
    String chunkData = measurementJson.substring(start, end);

    String notification = buildChunkedNotification(
      chunk,           // seq_num
      totalChunks,     // total_chunks
      chunkData        // payload
    );

    pCharacteristic->setValue(notification);
    pCharacteristic->notify();
    delay(50); // Rate limit notifications
  }
}
```

---

## 7. Handling Mobile WiFi Unavailability

### 7.1 Failure Modes

| Scenario | Mobile WiFi | ESP32 WiFi | Action |
|---|---|---|---|
| Normal | ✅ Available | ✅ Available | Direct REST: ESP32 → Backend |
| WiFi Blip | ⚠️ Intermittent | ❌ Down | Mobile bridges via BLE |
| Mobile Roaming | ❌ Lost | ✅ Available | ESP32 continues alone (queues) |
| Both Down | ❌ Down | ❌ Down | Both queue locally |
| BLE Only | ❌ Down | ⚠️ No WiFi | BLE proxy, mobile queue locally |

### 7.2 Queue Strategy: Two Levels

```
Level 1: ESP32 Local Queue (7-day retention)
├─ Measurements not sent via WiFi/REST
├─ Stored in SPIFFS with retry count
├─ Prioritize oldest measurements on retry
└─ Survive power loss if using NVRAM + SPIFFS

Level 2: Mobile App Local Queue (24-hour retention)
├─ Measurements received via BLE, failed REST relay
├─ Stored in AsyncStorage (React Native)
├─ Retry with exponential backoff
└─ Clear on successful relay or 24-hour timeout
```

### 7.3 Exponential Backoff for Proxy Retry

```typescript
// Mobile app retry strategy for proxied measurements
function calculateBackoffDelay(retryCount: number): number {
  const baseDelay = 1000; // 1 second
  const maxDelay = 5 * 60 * 1000; // 5 minutes

  const delay = baseDelay * Math.pow(2, retryCount);
  return Math.min(delay, maxDelay); // Cap at 5 minutes
}

// Example progression:
// Retry 0: 1s
// Retry 1: 2s
// Retry 2: 4s
// Retry 3: 8s
// Retry 4: 16s
// Retry 5: 32s
// Retry 6: 64s (1m 4s)
// Retry 7+: 5m (capped)
```

### 7.4 Detecting "Mobile WiFi Unavailability"

```typescript
// Mobile app detects WiFi status changes
import { useNetworkState } from '@react-native-network-info/react-native-network-info';

function MonitorNetworkStatus() {
  const networkState = useNetworkState();
  const [wifiStatus, setWifiStatus] = useState<'connected' | 'disconnected' | 'verifying'>('disconnected');

  useEffect(() => {
    if (!networkState.isConnected) {
      setWifiStatus('disconnected');
      console.log('WiFi disconnected, triggering BLE proxy scan');
      triggerBLEProxyScan();
    } else if (networkState.type === 'wifi') {
      setWifiStatus('verifying');
      // Verify HTTP connectivity, not just WiFi radio available
      verifyBackendConnectivity()
        .then(() => setWifiStatus('connected'))
        .catch(() => {
          setWifiStatus('disconnected');
          triggerBLEProxyScan();
        });
    }
  }, [networkState]);

  return null;
}

async function verifyBackendConnectivity(): Promise<void> {
  try {
    const response = await fetch('https://backend.example.com/health', {
      timeout: 5000
    });
    if (response.status !== 200) throw new Error('health check failed');
  } catch (error) {
    throw new Error(`Backend unreachable: ${error}`);
  }
}
```

---

## 8. Idempotency & Checksums in Proxied Requests

### 8.1 Idempotency Key Design

**Goal**: Prevent duplicate measurements if mobile retries proxy request.

```
Idempotency Key Generation (ESP32):
├─ UUID v4 (random) assigned at measurement time
├─ NOT based on content (hash-based would group duplicates)
├─ Unique per measurement event (even if same volume/time)
├─ Transmitted with measurement through all layers

Backend Deduplication:
├─ Store mapping: idempotency_key → response
├─ Retention: Keep for 24 hours minimum
├─ On duplicate request:
│   ├─ Return cached response (HTTP 202 Accepted)
│   ├─ No second dispensing record created
│   ├─ Audit log: "Duplicate idempotency key, returned cached"
└─ On new key: Process normally, cache response for future duplicates
```

#### Idempotency Key Lifecycle

```
Time     ESP32          Mobile         Backend
────────────────────────────────────────────────
T0       Generate UUID (abc-123)
T0+1s    Measure 5.2L, create measurement with UUID
         Store: {volume, timestamp, uuid, checksum}
T0+2s    Attempt WiFi send → FAIL (WiFi down)
         Queue locally
T0+5s    [BLE connection established with mobile]
T0+6s    Mobile reads measurement from ESP32
         Gets: {volume, timestamp, uuid, checksum}
T0+7s    Mobile attempts REST proxy → SUCCESS
         POST /api/v1/ble-proxy/measurements
         Headers: Idempotency-Key: abc-123
         Response: HTTP 201 Created
         Backend stores: uuid → {http 201 response}
T0+8s    Mobile notifies ESP32: "measurement sent"
         ESP32 removes from local queue
T0+10s   [WiFi restored to ESP32]
         ESP32 retries WiFi send with same measurement
         POST /api/v1/measurements
         Headers: Idempotency-Key: abc-123
         Backend lookup: uuid abc-123 found in cache
         Response: HTTP 202 Accepted (duplicate)
         Log: "Duplicate via WiFi, already processed via BLE-proxy"
         Result: Only ONE dispensing record created for this measurement
```

### 8.2 Checksum Validation (SHA-256)

**Purpose**: Detect corruption in measurement data (BLE → Mobile → REST).

```cpp
// ESP32: Calculate checksum for measurement
void generateMeasurementChecksum() {
  String payload = serializeJSON({
    "device_id": this->device_id,
    "volume_liters": this->volume_liters,
    "timestamp": this->timestamp,
    "dispensing_request_id": this->request_id,
    "idempotency_key": this->idempotency_key
  });

  // Use mbedTLS for SHA-256 (built into Arduino ESP32 core)
  unsigned char hash[32];
  mbedtls_sha256(
    (unsigned char*) payload.c_str(),
    payload.length(),
    hash,
    0
  );

  // Convert to hex string
  char checksum[65];
  for (int i = 0; i < 32; i++) {
    sprintf(&checksum[i * 2], "%02x", hash[i]);
  }

  this->checksum = String(checksum);
}

// Send measurement with checksum via BLE
void notifyMeasurement() {
  String jsonData = measurementToJson();
  pCharacteristic->setValue(jsonData + "|" + this->checksum);
  pCharacteristic->notify();
}
```

```typescript
// Mobile: Validate checksum before relay
function validateChecksum(measurement: Measurement, receivedChecksum: string): boolean {
  const crypto = require('crypto');

  const payload = JSON.stringify({
    device_id: measurement.device_id,
    volume_liters: measurement.volume_liters,
    timestamp: measurement.timestamp,
    dispensing_request_id: measurement.dispensing_request_id,
    idempotency_key: measurement.idempotency_key
  });

  const calculatedChecksum = crypto
    .createHash('sha256')
    .update(payload)
    .digest('hex');

  if (calculatedChecksum !== receivedChecksum) {
    console.error(`Checksum mismatch! Calculated: ${calculatedChecksum}, Received: ${receivedChecksum}`);
    return false;
  }

  return true;
}

// Relay to backend with checksum header
async function proxyMeasurement(measurement: Measurement, checksum: string) {
  const response = await fetch('https://backend.example.com/api/v1/ble-proxy/measurements', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${mobileUserToken}`,
      'Mobile-User-ID': currentUser.id,
      'ESP32-Device-ID': measurement.device_id,
      'Idempotency-Key': measurement.idempotency_key,
      'X-Checksum': checksum,
      'Communication-Channel': 'ble-proxied'
    },
    body: JSON.stringify({
      measurement: measurement,
      relayed_at: new Date().toISOString()
    })
  });

  return response.json();
}
```

```java
// Backend: Validate checksum
@PostMapping("/api/v1/ble-proxy/measurements")
public ResponseEntity<?> proxyMeasurement(
    @RequestBody MeasurementProxyRequest request,
    @RequestHeader("X-Checksum") String receivedChecksum,
    @RequestHeader("Idempotency-Key") String idempotencyKey,
    Authentication auth) {

  // Recalculate checksum
  String payload = objectMapper.writeValueAsString(request.getMeasurement());
  String calculatedChecksum = calculateSHA256(payload);

  // Validate
  if (!calculatedChecksum.equals(receivedChecksum)) {
    logger.warn("Checksum mismatch for idempotency key: {}", idempotencyKey);
    return ResponseEntity
      .badRequest()
      .body(new ErrorResponse("CHECKSUM_MISMATCH", "Data corruption detected"));
  }

  // Checksum valid, proceed with deduplication & storage
  return processMeasurement(request, auth);
}
```

### 8.3 Checksum Mismatch Recovery

```
Scenario: Mobile receives ESP32 measurement, checksum fails validation

Timeline:
T0: Mobile reads measurement from ESP32 via BLE
T0+1s: Mobile validates checksum → FAILS
  ├─ Data corrupted in BLE transmission
  ├─ OR ESP32 sent wrong checksum
  ├─ Do NOT relay to backend (would fail backend checksum too)

Actions:
├─ Log error with measurement details
├─ Send BLE notification to ESP32: "CHECKSUM_FAIL"
├─ ESP32 response: Retransmit measurement
├─ Mobile receives again, recalculates checksum
├─ If passes: Relay to backend
├─ If fails again:
│   ├─ Log retry attempt
│   ├─ After 3 failures: Mark as unrecoverable
│   ├─ ESP32 should move to next measurement in queue
│   └─ Corrupted measurement discarded (rare, BLE has low error rate)
```

---

## 9. Summary: Architecture Decision

### 9.1 Selected Architecture

```
PRIMARY (WiFi Available):
ESP32 --[WiFi/REST + MQTT]--> Backend

FALLBACK 1 (WiFi Down, BLE Available):
ESP32 --[BLE]--> Mobile App --[WiFi/REST]--> Backend
                  ↑            ↓
              Local Queue   Local Queue

FALLBACK 2 (WiFi Down, BLE Unavailable, Later Sync):
ESP32 --[Local Queue 7-day]--> (when WiFi restored) --> Backend
Mobile --[Local Queue 24h]----> (when WiFi restored) --> Backend
```

### 9.2 Key Design Principles

| Principle | Implementation |
|---|---|
| **Zero Data Loss** | 3-layer queueing: ESP32 7-day, Mobile 24-hour, Backend atomic transactions |
| **Idempotency** | UUID-based deduplication at backend; mobile proxy includes idempotency-key header |
| **Integrity** | SHA-256 checksums on all transmissions; recalculated at each hop (BLE, Mobile, Backend) |
| **Security** | JWT token validation, device ID verification, permission boundary check before proxy acceptance |
| **Reliability** | Exponential backoff retry (1s → 5m max); fallback detection automatic; state machine tracked |
| **Auditability** | All proxied measurements labeled with `communication_channel: "ble-proxied"` for audit trail |

### 9.3 What This Solves

✅ **Requirement**: Measurement data reaching backend even when WiFi temporarily unavailable
✅ **Requirement**: Relay commands reaching ESP32 even when WiFi temporarily unavailable
✅ **Requirement**: Zero duplicates across multiple retry attempts (idempotency)
✅ **Requirement**: No data corruption (checksums validated at each hop)
✅ **Requirement**: Secure delegation of operations (JWT + device ID verification)

### 9.4 What This Doesn't (and Should Not) Solve

❌ **Not for**: Real-time streaming (asynchronous relays, not live streams)
❌ **Not for**: Permanently offline operation (2-3 hours max effective range for BLE + battery)
❌ **Not for**: Mobile as primary storage (bridge-only, not persistent data holder)
❌ **Not for**: Encryption of BLE transmission (short range, physical proximity required)

---

## 10. Implementation Checklist

### Phase 2.1: Mobile BLE Proxy

- [ ] React Native project created with BLE library (react-native-ble-plx)
- [ ] BLE scan implemented for ESP32 device discovery (UUID-based)
- [ ] BLE connection establishment with error handling
- [ ] BLE GATT characteristic read for measurement data
- [ ] Checksum validation (SHA-256) on BLE data
- [ ] REST API client for `POST /api/v1/ble-proxy/measurements`
- [ ] Mobile local queue for offline measurements (AsyncStorage)
- [ ] Exponential backoff retry logic
- [ ] WiFi status monitoring & automatic BLE fallback trigger
- [ ] Error handling: BLE connection drop, mid-transmission loss
- [ ] Unit tests: BLE read/write, checksum validation, retry logic
- [ ] E2E tests: WiFi loss → BLE sync → data reaches backend

### Phase 2.2: Backend BLE Proxy Endpoint

- [ ] `POST /api/v1/ble-proxy/measurements` endpoint implemented
- [ ] Idempotency key validation (UUID deduplication)
- [ ] Checksum validation (SHA-256)
- [ ] Mobile user authentication (JWT token)
- [ ] ESP32 device verification (Device ID valid & active)
- [ ] Permission check: Mobile user authorized to proxy for device
- [ ] Dispensing request matching & validation
- [ ] Volume boundary check (> 0, ≤ approved max_liters)
- [ ] Atomic transaction for dispensing record creation
- [ ] Response: HTTP 201 for new, HTTP 202 for duplicate
- [ ] Audit logging: `communication_channel: "ble-proxied"`
- [ ] Integration tests: Valid proxy, duplicate proxy, invalid checksum, unauthorized user

### Phase 2.3: Backend Command Relay Endpoint

- [ ] `GET /api/v1/ble-proxy/commands` endpoint for mobile polling
- [ ] Command queue stored for pending relay to ESP32
- [ ] Mobile polling with Mobile-User-ID & ESP32-Device-ID filters
- [ ] Command format: {action, request_id, max_liters, signature}
- [ ] Backend signature (JWT) for command authenticity
- [ ] Integration tests: Command queuing, mobile retrieval, backend confirmation

### Phase 2.4: ESP32 BLE GATT Services

- [ ] BLE peripheral mode initialization
- [ ] Service UUID advertisement
- [ ] Characteristic 1: Measurement queue (Read + Notify)
- [ ] Characteristic 2: Command inbox (Write + Read)
- [ ] Characteristic 3: Device status (Read + Notify)
- [ ] BLE MTU negotiation (request 251 bytes)
- [ ] Chunked notification for large measurements (fragmentation handling)
- [ ] Checksum calculation & transmission with measurements
- [ ] Command signature validation (JWT verification)
- [ ] Local queue reference: "measurement sent" notification from mobile
- [ ] Unit tests: BLE read/write, chunking, checksum generation
- [ ] Integration tests: Mobile ↔ ESP32 BLE communication

### Phase 2.5: End-to-End Testing

- [ ] Test scenario: WiFi available → measurement sent directly
- [ ] Test scenario: WiFi down → BLE proxy → measurement reaches backend via mobile
- [ ] Test scenario: Both WiFi & BLE down → both queue locally
- [ ] Test scenario: Mobile retries BLE proxy → idempotency prevents duplicate
- [ ] Test scenario: Checksum mismatch → measurement rejected
- [ ] Test scenario: Mobile permission boundary → unauthorized user cannot proxy
- [ ] Test scenario: Relay activation via BLE from backend
- [ ] Performance test: BLE latency, ESP32 power consumption during proxy
- [ ] Chaos test: Network failure during proxy, BLE disconnection mid-transfer

---

## 11. Recommendations Summary

### DO (Best Practices)

✅ **DO** implement idempotency keys as UUID (random, not hash-based)
✅ **DO** validate checksums at every hop (BLE, Mobile, Backend)
✅ **DO** use exponential backoff (1s → 5m) for retry, not fixed intervals
✅ **DO** separate permission model for proxy (specific device authorization)
✅ **DO** label all proxied measurements with channel="ble-proxied" for auditability
✅ **DO** implement both ESP32 7-day queue and Mobile 24-hour queue
✅ **DO** monitor WiFi status actively (don't wait for timeout)
✅ **DO** negotiate BLE MTU 251 bytes for efficiency
✅ **DO** cache recent backend commands for mobile polling (~1 minute TTL)

### DON'T (Anti-Patterns)

❌ **DON'T** use content-hash as idempotency key (groups duplicates of same volume)
❌ **DON'T** trust mobile app without backend verification (always validate independently)
❌ **DON'T** allow any authenticated user to proxy for any device (permission boundaries)
❌ **DON'T** encrypt BLE transmission (short range, physical proximity inherent security)
❌ **DON'T** store measurements permanently on mobile (bridge-only pattern)
❌ **DON'T** use fixed retry intervals (causes thundering herd on backend)
❌ **DON'T** skip checksum validation on mobile (relay BLE errors to ESP32)
❌ **DON'T** forget audit trail (always tag proxied requests with channel metadata)

---

## 12. References & Further Reading

### BLE Implementation
- [BLE Spec: GATT Profile](https://www.bluetooth.com/specifications/gatt/)
- [React Native BLE PLX](https://github.com/dotintent/react-native-ble-plx)
- [ESP32 NimBLE Documentation](https://github.com/espressif/esp-idf/tree/master/components/bt/esp_ble_mesh)

### Idempotency Patterns
- [Idempotency Keys RFC Draft](https://tools.ietf.org/html/draft-idempotency-header-last-modified-07)
- [AWS SQS Deduplication](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html)

### Mobile Proxy Patterns
- [Mobile Backend as a Service (MBaaS)](https://en.wikipedia.org/wiki/Backend_as_a_service)
- [Transparency Proxy Pattern](https://en.wikipedia.org/wiki/Proxy_server#Transparent_proxy)

### Data Integrity
- [SHA-256 Specification](https://csrc.nist.gov/publications/detail/fips/180-4/final)
- [Checksum vs HMAC](https://security.stackexchange.com/questions/51959/what-are-the-differences-between-a-checksum-hmac-and-a-digital-signature)

---

**Document Complete**

Next steps: Review with stakeholders, then proceed to Phase 1 (Data Model Design & API Contracts).
