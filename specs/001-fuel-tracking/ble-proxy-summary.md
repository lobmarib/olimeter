# BLE-to-REST Proxy Pattern: Executive Summary

**Context**: OliMeeter Fuel Dispensing Tracking System
**Date**: 2026-02-27
**Status**: Recommended for MVP Implementation

---

## Decision: Tiered Communication with BLE Proxy Fallback

**SELECTED ARCHITECTURE:**

The mobile app MUST implement a BLE-to-REST proxy bridge that activates as a fallback when the ESP32 device loses WiFi connectivity, enabling measurement relay and command delivery through the mobile device's WiFi connection.

**Communication Priority Order:**
1. **Primary**: ESP32 → WiFi REST API → Backend (direct, fastest, <500ms)
2. **Secondary**: ESP32 ↔ MQTT → Backend (async event stream, WiFi primary)
3. **Tertiary**: ESP32 ↔ BLE ↔ Mobile App → REST API → Backend (fallback when WiFi unavailable)
4. **Local Queueing**: ESP32 (7-day retention) + Mobile (24-hour retention) for offline resilience

---

## Rationale: Why This Design

### 1. Solves Core System Requirements

| Requirement | How Proxy Solves |
|---|---|
| **Zero Data Loss** | 3-layer queueing (ESP32 7-day + Mobile 24h + Backend atomic transactions) prevents data loss across network failures |
| **Offline Resilience** | Measurements reach backend even before WiFi restored; mobile becomes secondary transport layer |
| **Multi-Channel Redundancy** | 3 independent communication paths ensure at least one is functional at any given time |
| **Cost-Effective** | Leverages existing mobile devices; avoids expensive cellular modems in ESP32 hardware |
| **Rapid Sync** | Mobile nearby in facility can relay measurements within seconds; user-initiated sync, not waiting for WiFi recovery |

### 2. Trust Chain: Authentication Delegation Without Compromise

```
Trust Model:
┌─────────────────────────────────────────────┐
│ Mobile User (JWT authenticated)             │
│ └─ Proves: Identity via token              │
├─────────────────────────────────────────────┤
│ ESP32 Device (verified by Backend)          │
│ └─ Proves: Device ID + idempotency key      │
├─────────────────────────────────────────────┤
│ Measurement Payload (checksum validated)    │
│ └─ Proves: Data integrity via SHA-256       │
├─────────────────────────────────────────────┤
│ Backend Validation (ALL must pass)          │
│ └─ Checks: User auth + device registry      │
│           + checksum + deduplication        │
│           + permission boundary             │
└─────────────────────────────────────────────┘
```

**Result**: Mobile acts as verified relay (not owner), while backend independently validates data source.

### 3. Idempotency Prevents Duplicates

- ESP32 assigns UUID-based idempotency key at measurement creation
- Mobile relays with idempotency key in header
- Backend deduplicates by key (not content)
- Result: If mobile retries proxy (WiFi unstable), only ONE dispensing record created

**Example Timeline**:
```
T0:   ESP32 measures 5.2L, generates UUID abc-123
T0+5s: BLE proxy to mobile succeeds, backend creates record #001
T0+10s: Mobile WiFi unstable, retries same measurement → HTTP 202 "already processed"
        Result: Still only record #001, no duplicate despite retry
T1:   ESP32 WiFi restored, retries same measurement (same UUID) → HTTP 202 duplicate
      Result: No duplicate via WiFi either; single authoritative record
```

### 4. Layered Failure Handling

```
Failure Mode                    | Layer 1 (ESP32) | Layer 2 (Mobile BLE) | Layer 3 (Local Queue)
─────────────────────────────────────────────────────────────────────────────────────
WiFi blip (5 seconds)           | Auto-retry 1s   | Fallback BLE        | N/A
WiFi down (30 minutes)          | Queue locally   | Relay via BLE proof | Activate if BLE in range
No BLE in range                 | Queue 7 days    | N/A                 | Survives power loss
Mobile WiFi unstable during     | N/A             | Exponential backoff  | Local AsyncStorage
 proxy relay                    |                 | 1s→5m max           | 24-hour retention
Both WiFi & BLE down            | Queue 7 days    | Queue 24h           | Retry when network restored
All systems recover             | Process queues  | Process queues      | Single authoritative order
```

---

## Alternatives Considered

### Alternative 1: WiFi Only (No BLE Proxy)

**Description**: ESP32 communicates exclusively via WiFi. No mobile bridge needed.

**Pros**:
- Simpler app development (no BLE complexity)
- Fewer security concerns (fewer trust boundaries)
- Familiar REST-only pattern

**Cons**:
- ❌ Violates "Zero Data Loss" principle: Queue exhaustion after 7 days with no WiFi = data loss
- ❌ User frustration: Can't recover measurements trapped on ESP32 if WiFi unavailable >7 days
- ❌ System vulnerability: No failover when facility WiFi fails for extended period
- ❌ Hampers adoption: Users dislike "offline" feeling; proxy gives control back

**Verdict**: **Rejected** - constitutionally violates data resilience requirement

---

### Alternative 2: Cellular Modem in ESP32

**Description**: Add 4G LTE modem to each ESP32 device for direct backend communication when WiFi fails.

**Pros**:
- Direct measurement transmission (no proxy trust complexity)
- Real-time relay activation across any coverage area
- No mobile device dependency

**Cons**:
- ❌ Hardware cost: +$50-100 per device (e.g., SIM8000A module)
- ❌ Power consumption: 5x increase (cellular modem in standby still draws 10-30mA)
- ❌ Operational cost: Monthly SIM plans per device (e.g., $5-15/month × 100 devices)
- ❌ Overkill for fuel facility: Most facilities have WiFi; cellular is hedge for rare scenarios
- ❌ Complexity: Requires modem library, antenna tuning, power management
- ❌ Maintenance: SIM expiration, carrier compatibility, global vs regional plans

**Verdict**: **Over-scoped** for MVP. Consider as Phase 3 enhancement if business case warrants (global deployments, high facility count).

---

### Alternative 3: Device-to-Device Mesh (NRF24L01+)

**Description**: ESP32 devices mesh via 2.4 GHz radio to reach WiFi-connected gateway device.

**Pros**:
- Extended range beyond single device (up to 500m per hop in line-of-sight)
- No cellular cost
- Low power compared to WiFi

**Cons**:
- ❌ Requires multiple ESP32 devices in proximity (only works with >1 device deployed)
- ❌ Mesh networking is complex & unreliable (routing failures, broadcast storms)
- ❌ Doesn't solve initial deployment (single fuel pump locations start with 1 ESP32)
- ❌ Why not use mobile? Already on-site for fuel dispensing user; cheaper device cost
- ❌ Debugging nightmare: Hard to troubleshoot mesh connectivity issues in field

**Verdict**: **Over-engineered** for MVP. Only viable if deploying 100+ devices in single facility (mesh becomes cost-effective). Single facilities → BLE proxy simpler.

---

### Alternative 4: Mobile Polling (HTTP Long-Polling)

**Description**: Mobile app periodically polls `GET /api/v1/commands/pending?for_device=X` instead of maintaining subscription.

**Pros**:
- Standard HTTP pattern (no WebSocket/MQTT infrastructure)
- Simpler backend implementation (no connection state)

**Cons**:
- ❌ **High latency**: 5-10 second poll interval = slow relay activation (safety concern for fuel dispenser)
- ❌ **Thundering herd**: 1000 users polling every 5s = 200 requests/second backend load
- ❌ **Battery drain**: Mobile wakes up every 5s (poor UX on battery-constrained devices)
- ❌ **Inefficient**: Most polls return empty (no pending commands)

**Verdict**: **Inefficient** for real-time relay control. BLE measurement relay + subscription-based command delivery better.

---

### Alternative 5: MQTT Direct on Mobile

**Description**: Mobile app subscribes directly to MQTT broker instead of polling REST API.

**Pros**:
- Event-driven (commands delivered instantly via pub/sub)
- Lower backend load (MQTT fan-out vs polling requests)
- Mobile battery efficient (no polling wakeups)

**Cons**:
- ❌ Deployment complexity: MQTT broker must be accessible through facility firewalls (often blocked on port 1883/8883)
- ❌ Authentication complexity: MQTT credentials (username/password) vs REST JWT tokens
- ❌ Dual protocol overhead: Mobile now uses both REST (history, auth) + MQTT (commands)
- ❌ Not available in MVP auth layer: Current system uses JWT, not MQTT auth
- ❌ Out-of-scope for Phase 1: Adds unnecessary complexity beyond MVP

**Verdict**: **Future Enhancement** - Consider in Phase 3 after REST proxy proven. MQTT subscription pattern superior to polling, but not MVP-critical.

---

### Alternative 6: WebSocket Full-Duplex (mobile ↔ backend)

**Description**: Mobile maintains persistent WebSocket connection to backend for bidirectional command/measurement flow.

**Pros**:
- True real-time (commands delivered instantly)
- No polling overhead
- Full-duplex (mobile can push measurements, backend can push commands simultaneously)

**Cons**:
- ❌ Infrastructure overhead: WebSocket session pooling, connection tracking on backend
- ❌ Mobile battery drain: Persistent connection even when idle (vs on-demand BLE scanning)
- ❌ Requires OS permission: Background socket connectivity on iOS restrictive
- ❌ Over-engineered for asynchronous measurements (don't need video-game latency for fuel measurements)
- ❌ Increases backend scaling complexity (100+ persistent mobile connections challenging)

**Verdict**: **Future Enhancement** - Overkill for MVP. REST polling suitable for Phase 1 command relay. Upgrade to WebSocket if real-time requirements increase (e.g., admin dashboard monitoring).

---

## Implementation Considerations

### A. Handling Failures & Retries

#### A.1 ESP32 Local Queue Strategy

```
Local Queue Lifecycle (ESP32 SPIFFS):
┌─────────────────────────────────────┐
│ Measurement Created                  │
│ └─ Store: {volume, timestamp, uuid}  │
├─────────────────────────────────────┤
│ Attempt WiFi Send                    │
│ ├─ Success → Remove from queue       │
│ ├─ Fail (timeout) → Keep in queue    │
│ └─ Fail (network error) → Retry 1s   │
├─────────────────────────────────────┤
│ BLE Proxy Available                  │
│ ├─ Mobile connects via BLE           │
│ └─ Transfer from queue to mobile     │
├─────────────────────────────────────┤
│ 7-Day Expiration                     │
│ ├─ If still in queue after 7 days    │
│ └─ Log warning, mark stale, stop     │
│    retrying (avoid infinite queue)   │
├─────────────────────────────────────┤
│ Power Loss                           │
│ ├─ Queue persists in SPIFFS          │
│ ├─ Resume on power restoration       │
│ └─ Timestamp preserved (UTC)         │
└─────────────────────────────────────┘

Retry Logic (Exponential Backoff):
Attempt 1: 1 second
Attempt 2: 2 seconds
Attempt 3: 4 seconds
Attempt 4: 8 seconds
Attempt 5: 16 seconds
Attempt 6: 32 seconds
Attempt 7: 64 seconds (1 minute)
Attempt 8-∞: 5 minutes (capped)

Max retries: 7 days ÷ 5-minute intervals = ~2000 attempts
```

#### A.2 Mobile Local Queue (Offline Cache)

```
Mobile Queue Lifecycle (AsyncStorage):
┌─────────────────────────────────────┐
│ Measurement Received from ESP32 BLE  │
│ └─ Cache locally (AsyncStorage)      │
├─────────────────────────────────────┤
│ Attempt REST Proxy to Backend        │
│ ├─ Success → Remove from cache       │
│ ├─ Fail (timeout) → Keep in cache    │
│ └─ Fail (network) → Retry exp backoff│
├─────────────────────────────────────┤
│ 24-Hour Expiration                   │
│ ├─ If still in cache after 24h       │
│ └─ Discard (assume stale)            │
├─────────────────────────────────────┤
│ App Restart                          │
│ ├─ Persist queue to AsyncStorage     │
│ ├─ Resume sync on app reload         │
│ └─ No data loss across restarts      │
└─────────────────────────────────────┘

Retry Logic (Same Exponential Backoff):
Attempt 1: 1 second
Attempt 2: 2 seconds
Attempt 3: 4 seconds
...
Attempt 8+: 5 minutes (capped)

Max retries: 24 hours ÷ 5-minute intervals = ~288 attempts
```

#### A.3 Checksum Failure Recovery

```
BLE Checksum Mismatch:
T0:   Mobile reads measurement from ESP32 BLE
T0+1s: Mobile calculates SHA-256(payload)
       Compares: calculated != received
       Action: Send BLE notification "CHECKSUM_FAIL"
T0+2s: ESP32 receives failure notification
       Action: Retransmit same measurement
T0+3s: Mobile reads again, checksum now valid
       Action: Relay to backend via REST
T0+4s: Backend receives, validates checksum
       Action: Create dispensing record

If checksum fails 3 times in succession:
├─ Log permanent error with measurement details
├─ Skip this measurement (corrupted)
├─ Move to next measurement in ESP32 queue
└─ Alert user/admin of possible device hardware issue
```

#### A.4 Idempotency Deduplication

```
Backend Idempotency Store:
┌──────────────────────────────────┐
│ Idempotency Table                │
├──────────────────────────────────┤
│ Column: idempotency_key (PK)     │
│ Column: response_status (201/202)│
│ Column: response_body (JSON)     │
│ Column: created_at (TTL: 24h)    │
├──────────────────────────────────┤
│ On duplicate request:             │
│ SELECT response_body              │
│ WHERE idempotency_key = 'abc-123' │
│ Return: Cached HTTP response      │
│ Status: 202 Accepted              │
│ Increment: duplicate_counter      │
│ Log: "Duplicate via [channel]"    │
└──────────────────────────────────┘

Idempotency Key Flow:
ESP32:
  uuid_abc_123 = generate UUID()
  measurement = {volume: 5.2, uuid: uuid_abc_123, ...}

Mobile (BLE Proxy):
  Headers: Idempotency-Key: uuid_abc_123

Backend:
  if exists(idempotency_key = 'uuid_abc_123'):
    return CACHED_RESPONSE (HTTP 202)  # Already processed
  else:
    create_dispensing_record(measurement)
    cache_response(idempotency_key, RESPONSE)
    return HTTP 201 Create

Timeline (Mobile Retries):
T0+5s:  First attempt → HTTP 201 Created (response cached)
T0+10s: Retry (WiFi unstable) → HTTP 202 Accepted (from cache)
T0+15s: Retry again → HTTP 202 Accepted (from cache)
Result: Only ONE dispensing record, all retries return success
```

---

### B. WiFi Unavailability Detection

#### B.1 Active Connectivity Monitoring (Mobile App)

```typescript
// Don't just check "WiFi radio enabled" - verify actual connectivity
import { NetworkInfo } from '@react-native-network-info/react-native-network-info';

async function isBackendReachable(): Promise<boolean> {
  try {
    const response = await fetch('https://backend.example.com/health', {
      timeout: 5000  // 5 second timeout
    });
    return response.status === 200;
  } catch (error) {
    return false;
  }
}

// Fallback trigger (not just passive WiFi detection)
if (!isBackendReachable()) {
  console.log('Backend unreachable, triggering BLE proxy scan');
  await triggerBLEProxyScan();  // Start BLE search for ESP32
}
```

#### B.2 BLE Scan Constraints (Power Efficiency)

```
BLE Scan Profile (Battery vs Latency Trade-off):

On-Demand Scan (User Triggered):
├─ Duration: 10 seconds (continuous)
├─ Power: ~100mA (noticeable drain)
├─ Latency: <1 second device discovery
├─ Trigger: Manual button "Sync with Device"

Periodic Background Scan (Low Power):
├─ Duration: 1 second every 30 seconds
├─ Power: ~5mA average (background overhead)
├─ Latency: Up to 30 seconds to discover device
├─ Trigger: Automatic when WiFi down > 30 seconds

Aggressive Background Scan (Critical):
├─ Duration: 3 seconds every 10 seconds
├─ Power: ~15mA average (battery noticeable)
├─ Latency: <10 seconds device discovery
├─ Trigger: Active dispensing in progress, WiFi lost

iOS Background Limitation:
├─ iOS restricts background BLE scanning
├─ Workaround: User places device on table, app in background
├─ Needs "Uses Bluetooth LE accessories" capability
├─ Alternative: Keep app in foreground during proxy operation

Android Background Limitation:
├─ Android allows background BLE scanning
├─ Permission: "android.permission.BLUETOOTH_SCAN"
├─ Power optimization: Alarms & work scheduling
```

---

### C. Security Validation Pipeline

#### C.1 Backend Request Validation Checklist

```java
@PostMapping("/api/v1/ble-proxy/measurements")
public ResponseEntity<?> proxyMeasurement(
    @RequestBody MeasurementProxyRequest request,
    Authentication auth) {

  MobileUser mobileUser = (MobileUser) auth.getPrincipal();

  // VALIDATION #1: Mobile User Authenticated
  if (!auth.isAuthenticated() || mobileUser.isTokenExpired()) {
    return UNAUTHORIZED;  // HTTP 401
  }
  logger.info("✓ Mobile user {} authenticated", mobileUser.getId());

  // VALIDATION #2: Device Exists & Active
  Device device = deviceRepository.findById(request.getEsp32DeviceId());
  if (device == null || !device.isActive()) {
    return NOT_FOUND;  // HTTP 404
  }
  logger.info("✓ Device {} found and active", device.getId());

  // VALIDATION #3: Proxy Permission Check
  if (!mobileUser.hasPermission("proxy_for_device_" + device.getId())) {
    return FORBIDDEN;  // HTTP 403
  }
  logger.info("✓ Mobile user has proxy permission for device");

  // VALIDATION #4: Checksum Integrity
  String calculatedChecksum = calculateSHA256(request.getPayload());
  if (!calculatedChecksum.equals(request.getHeader("X-Checksum"))) {
    return BAD_REQUEST;  // HTTP 400 - "CHECKSUM_MISMATCH"
  }
  logger.info("✓ Checksum validated");

  // VALIDATION #5: Idempotency Deduplication
  String idempotencyKey = request.getHeader("Idempotency-Key");
  IdempotencyRecord existing = idempotencyStore.get(idempotencyKey);
  if (existing != null) {
    logger.info("✓ Idempotency key duplicate, returning cached response");
    return existing.getResponse();  // HTTP 202 Accepted
  }

  // VALIDATION #6: Physical Realism
  double volumeLiters = request.getVolumeLiters();
  if (volumeLiters <= 0 || volumeLiters > device.getCapacity()) {
    return BAD_REQUEST;  // HTTP 400 - "INVALID_VOLUME"
  }
  logger.info("✓ Volume {} is physically realistic", volumeLiters);

  // VALIDATION #7: Timestamp Freshness
  long ageSeconds = (System.currentTimeMillis() - request.getTimestamp()) / 1000;
  if (ageSeconds < 0 || ageSeconds > 86400) {  // 24 hours
    return BAD_REQUEST;  // HTTP 400 - "STALE_TIMESTAMP"
  }
  logger.info("✓ Timestamp age {} seconds acceptable", ageSeconds);

  // VALIDATION #8: Dispensing Request Match
  DispensingRequest dispensingRequest = requestRepository
      .findById(request.getDispensingRequestId());
  if (dispensingRequest == null || !dispensingRequest.isApproved()) {
    return BAD_REQUEST;  // HTTP 400 - "REQUEST_NOT_APPROVED"
  }
  if (!dispensingRequest.getDeviceId().equals(device.getId())) {
    return BAD_REQUEST;  // HTTP 400 - "DEVICE_MISMATCH"
  }
  logger.info("✓ Dispensing request matched and approved");

  // VALIDATION #9: Volume Limit Enforcement
  if (volumeLiters > dispensingRequest.getMaxLiters()) {
    return BAD_REQUEST;  // HTTP 400 - "VOLUME_EXCEEDS_LIMIT"
  }
  logger.info("✓ Volume within approved limit");

  // ✅ ALL VALIDATIONS PASSED - Safe to persist
  logger.info("✅ All validations passed for proxied measurement");

  DispensingRecord record = createDispensingRecord(
    device, mobileUser, dispensingRequest, volumeLiters, request.getTimestamp()
  );

  idempotencyStore.cache(idempotencyKey, CREATED_RESPONSE);

  publishToMQTT(record, channel="ble-proxied");

  return CREATED;  // HTTP 201
}
```

#### C.2 Permission Model Update

```sql
-- New permission table for proxy operations
CREATE TABLE mobile_proxy_permissions (
  id SERIAL PRIMARY KEY,
  mobile_user_id INT NOT NULL REFERENCES users(id),
  esp32_device_id VARCHAR(50) NOT NULL REFERENCES measuring_devices(device_id),
  permission_type ENUM('proxy_single_device', 'proxy_location_all'),
  location_id INT REFERENCES locations(id),  -- If proxy_location_all
  granted_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP NULL,  -- NULL = no expiration
  granted_by INT REFERENCES users(id),  -- Admin who granted permission
  UNIQUE(mobile_user_id, esp32_device_id, permission_type)
);

-- Check before accepting proxy request
SELECT EXISTS (
  SELECT 1 FROM mobile_proxy_permissions
  WHERE mobile_user_id = ?
    AND esp32_device_id = ?
    AND (expires_at IS NULL OR expires_at > NOW())
    AND permission_type = 'proxy_single_device'
);
```

---

### D. Data Flow Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│ WiFi Available Scenario (Normal)                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  [ESP32 Device]                                                          │
│       │                                                                  │
│       │ Measure 5.2L                                                    │
│       ├─ Assign UUID abc-123                                            │
│       ├─ Calculate SHA-256 checksum                                     │
│       └─ Attempt WiFi REST                                              │
│            │                                                            │
│            └──► POST /api/v1/measurements                             │
│                 Headers: Device-ID, Idempotency-Key: abc-123, X-Checksum
│                      │                                                 │
│                      │ [Backend Validation]                            │
│                      │ ├─ Device active ✓                              │
│                      │ ├─ Checksum valid ✓                             │
│                      │ ├─ Idempotency key new ✓                        │
│                      │ └─ Create dispensing record                      │
│                      │                                                 │
│                      └──► HTTP 201 CREATED                              │
│                           Cache idempotency key                         │
│                           Publish MQTT (channel: wifi)                  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ WiFi Unavailable, BLE Proxy Scenario                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  [ESP32 Device] (WiFi DOWN)                                              │
│       │                                                                  │
│       │ Measure 5.2L                                                    │
│       ├─ Assign UUID def-456                                            │
│       ├─ Calculate SHA-256 checksum                                     │
│       ├─ Attempt WiFi → FAIL (no WiFi)                                  │
│       ├─ Store in local queue (SPIFFS)                                  │
│       └─ Advertise BLE service (GATT)                                    │
│            │                                                            │
│            │ [BLE Connection Established]                               │
│            │                                                            │
│            └──► [Mobile App] (WiFi UP)                                 │
│                 │                                                      │
│                 ├─ Scan for ESP32 via UUID                             │
│                 ├─ Connect to BLE peripheral                           │
│                 ├─ Read MEASUREMENT characteristic                     │
│                 │  (receives: {vol, ts, uuid, checksum})               │
│                 ├─ Validate checksum locally                           │
│                 ├─ Store in AsyncStorage (offline queue)               │
│                 │                                                      │
│                 └──► POST /api/v1/ble-proxy/measurements               │
│                      Headers:                                          │
│                      - Authorization: Bearer <JWT>                     │
│                      - Mobile-User-ID: user-789                        │
│                      - ESP32-Device-ID: esp32-001                      │
│                      - Idempotency-Key: def-456                        │
│                      - X-Checksum: (recalculated)                      │
│                      - Communication-Channel: ble-proxied              │
│                           │                                            │
│                           │ [Backend Validation]                       │
│                           │ ├─ JWT token valid ✓                       │
│                           │ ├─ Device exists ✓                         │
│                           │ ├─ Proxy permission exists ✓               │
│                           │ ├─ Checksum valid ✓                        │
│                           │ ├─ Idempotency key new ✓                   │
│                           │ ├─ Volume realistic ✓                      │
│                           │ ├─ Timestamp fresh ✓                       │
│                           │ └─ Create dispensing record                 │
│                           │    (channel: ble-proxied)                  │
│                           │                                            │
│                      ◄────┴─── HTTP 201 CREATED                         │
│                      │    Cache idempotency key                         │
│                      │    Publish MQTT (channel: ble-proxied)           │
│                      │                                                  │
│                      └─ Remove from AsyncStorage queue                  │
│                         Send BLE notification to ESP32:                 │
│                         "Measurement confirmed, UUID: def-456"          │
│                      │                                                  │
│                      └──► [ESP32] (receives confirmation)              │
│                           ├─ Remove UUID def-456 from local queue      │
│                           └─ Wait for next measurement                  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│ Device Relay Activation via BLE Proxy (Reverse Direction)                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  [Backend] (User approved dispensing request)                            │
│       │                                                                  │
│       ├─ Try direct WiFi: POST /api/v1/devices/esp32-001/relay/activate
│       │  → TIMEOUT (WiFi won't connect)                                 │
│       │                                                                  │
│       └─ Queue for BLE proxy relay:                                      │
│            INSERT pending_commands ...                                  │
│                                                                           │
│            [Mobile App] (polls for commands)                             │
│                 │                                                      │
│                 ├─ GET /api/v1/ble-proxy/commands                       │
│                 │  ?esp32_device_id=esp32-001&mobile_user_id=user-789   │
│                 │       │                                               │
│                 │       └──► HTTP 200 OK                                │
│                 │            body: {commands: [{action: activate, ...}]}│
│                 │                                                      │
│                 ├─ Verify signature (JWT from backend)                  │
│                 ├─ Connect to ESP32 via BLE                             │
│                 ├─ Write to COMMAND characteristic:                     │
│                 │  {action: activate, max_liters: 10.0, signature: JWT}│
│                 │       │                                               │
│                 │       └──► [ESP32] (receives via BLE)                 │
│                 │            ├─ Validate signature                      │
│                 │            ├─ Activate relay                          │
│                 │            └─ Notify mobile: "Relay activated"        │
│                 │                                                      │
│                 ├─ Receive confirmation notification                    │
│                 └─ POST /api/v1/ble-proxy/commands/{cmd_id}/confirmed   │
│                      └──► Backend records: "Command delivered via BLE"  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### E. Testing Strategy

#### E.1 Unit Tests (Each Layer)

```
Backend Tests:
├─ Idempotency validation (same key returns cached response)
├─ Checksum validation (mismatch returns HTTP 400)
├─ Permission boundary (unauthorized user rejected)
├─ Duplicate detection (no record created on retry)
└─ Timestamp validation (future date rejected)

Mobile Tests:
├─ BLE read with checksum validation
├─ REST proxy with idempotency header
├─ WiFi status monitoring trigger
├─ AsyncStorage queue persistence
└─ Exponential backoff calculation

ESP32 Tests:
├─ GATT characteristic write
├─ BLE notification fragmentation (MTU > 251 bytes)
├─ Local SPIFFS queue persistence
├─ Checksum generation (SHA-256)
└─ Retry logic exponential backoff
```

#### E.2 Integration Tests (End-to-End)

```
Scenario 1: Normal WiFi Operation
├─ Setup: ESP32 WiFi connected, mobile WiFi connected
├─ Action: Measure 5.2L on ESP32
├─ Verify: Dispensing record created in backend DB
└─ Latency: <500ms measurement reach backend

Scenario 2: WiFi Down → BLE Proxy
├─ Setup: Simulate WiFi loss on ESP32
├─ Action: Measure 5.2L on ESP32
├─ Verify: Measurement queued locally on ESP32
├─ Action: Mobile app scans, connects BLE, relays measurement
├─ Verify: Dispensing record created without duplicate
└─ Latency: <5s measurement reach backend via BLE proxy

Scenario 3: Mobile Retries (WiFi Unstable)
├─ Setup: BLE connected, mobile WiFi intermittent
├─ Action: First relay attempt fails (timeout)
├─ Verify: Measurement stays in AsyncStorage queue
├─ Action: Backoff 2s, retry REST proxy → succeeds
├─ Verify: Only ONE dispensing record (idempotency key prevents duplicate)
└─ Latency: ~2-3s total despite retry

Scenario 4: Checksum Mismatch
├─ Setup: Simulate BLE corruption during transmission
├─ Action: Mobile reads measurement with wrong checksum
├─ Verify: Mobile rejects (checksum validation fails)
├─ Verify: Not relayed to backend
├─ Action: ESP32 retransmits measurement (correct this time)
├─ Verify: Mobile validates, relays successfully
└─ No false data reaches backend

Scenario 5: Relay Activation via BLE
├─ Setup: ESP32 WiFi down, backend needs to activate relay
├─ Action: Backend queues activation command
├─ Action: Mobile polls, receives command, connects BLE
├─ Action: Mobile writes command to ESP32 COMMAND characteristic
├─ Verify: ESP32 activates relay
├─ Verify: Fuel flows only when approved
└─ Safety: No unauthorized relay activation possible
```

---

### F. Audit Trail & Compliance

#### F.1 Measurement Tracking

```sql
-- All measurements tagged with communication channel
INSERT INTO dispensing_records (
  device_id, volume_liters, timestamp, user_id, request_id,
  communication_channel,  -- NEW: "wifi", "mqtt", "ble-proxied"
  relayed_by_mobile_user_id,  -- NEW: if ble-proxied, who relayed
  idempotency_key,
  checksum,
  created_at
) VALUES (
  'esp32-001', 5.2, 1234567890, 'user-789', 'req-001',
  'ble-proxied',  -- Audit: identifies proxy vs direct
  'user-789',  -- Mobile user who acted as bridge
  'abc-123-uuid',  -- For deduplication
  'sha256-hex',  -- For integrity verification
  NOW()
);

-- Query: Find all measurements that came via BLE proxy
SELECT * FROM dispensing_records
WHERE communication_channel = 'ble-proxied'
ORDER BY created_at DESC;

-- Query: Find all measurements relayed by specific user
SELECT * FROM dispensing_records
WHERE relayed_by_mobile_user_id = 'user-789'
  AND communication_channel = 'ble-proxied';
```

#### F.2 Compliance Report

```
Audit Questions Answered:

Q: "Which measurements came via mobile BLE bridge?"
A: SELECT * WHERE communication_channel = 'ble-proxied'

Q: "Did deduplication work? (No duplicates on retry)"
A: SELECT idempotency_key, COUNT(*)
   FROM dispensing_records
   GROUP BY idempotency_key
   HAVING COUNT(*) > 1;  -- Should be empty

Q: "Were all checksums validated?"
A: All records have non-null checksum field; sampling confirms
   Backend validation logic checks before INSERT

Q: "What's the audit trail of a specific device?"
A: SELECT * FROM dispensing_records
   WHERE device_id = 'esp32-001'
   ORDER BY created_at;

Q: "Can we trace who proxy-relayed each measurement?"
A: Yes, relayed_by_mobile_user_id column tracks mobile user
   Can cross-reference with JWT token logs for accountability
```

---

## Summary: Key Success Factors

### Must-Have Implementation Details

1. **Idempotency Keys**: UUID-based, not hash-based; stored at backend with 24-hour TTL
2. **Checksums**: SHA-256 calculated by ESP32, validated by mobile, recalculated by backend
3. **Permission Boundary**: New `mobile_proxy_permissions` table; backend verifies before accepting
4. **Local Queues**: ESP32 (7-day SPIFFS), Mobile (24-hour AsyncStorage), indexed by idempotency key
5. **Exponential Backoff**: 1s → 2s → 4s → 8s → 16s → 32s → 64s → 5min (capped)
6. **Audit Trail**: All proxied measurements tagged with `communication_channel: "ble-proxied"`
7. **BLE GATT Services**: Measurement (Read+Notify), Command (Write+Read), Status (Read+Notify)
8. **Backend Validation Pipeline**: 9-step validation (auth, device, permission, checksum, dedup, volume, timestamp, request, limit)

### Risk Mitigations

| Risk | Mitigation |
|---|---|
| Mobile fabricates fake measurements | Backend validates device ID independently; checksum must match payload |
| Duplicate measurements on retry | Idempotency key deduplication at backend guarantees single record |
| Data corruption in BLE transmission | Checksum validation at each hop (ESP32 → Mobile verified, Mobile → Backend verified) |
| Unauthorized mobile user proxies device | New proxy permission model; backend checks permission before accepting |
| Mobile offline during proxy relay | AsyncStorage queue (24h) + exponential backoff; backend dedupes if retried later |
| ESP32 queue fills (>7 days no WiFi) | Expected event; measurements discarded with log warning (compliance with constitution's "7-day max") |
| WiFi recovery while BLE proxy in progress | Deduplication handles both WiFi + BLE relay of same measurement; only one record created |

---

**Status**: Ready for Phase 1 (Design & Contracts)

**Next Steps**:
1. Review security validation pipeline with stakeholders
2. Finalize permission model for mobile proxy authorization
3. Design BLE GATT service UUIDs and characteristics
4. Create API contracts for `/api/v1/ble-proxy/*` endpoints
5. Begin backend implementation of idempotency store + deduplication
