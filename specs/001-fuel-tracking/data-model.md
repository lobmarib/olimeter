# Phase 1 Design: Data Model

**Date**: 2026-02-27 | **Status**: Complete | **Input**: Spec + Phase 0 Research

---

## Entity Relationship Overview

```
User (n) ──┬──→ (1) Dispensing Request ──→ (1) Dispensing Record ──┐
           │                                                         │
           ├──→ (1) Quota Limit Rule                                 │
           │                                                         ├──→ Measuring Device
           └──→ (1) Mobile Proxy Permission                          │
                                                    ┌────────────────┘
                                  Measuring Device ─┤
                                       (1)           ├──→ WiFi Configuration
                                         │           └──→ BLE Session Log
                                         │
                                         └──→ Device Audit Trail
```

---

## Entity 1: User

**Purpose**: Represents authenticated users who can request fuel dispensing and view history.

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | Unique user identifier |
| `username` | VARCHAR(100) | UNIQUE, NOT NULL | Login credential |
| `email` | VARCHAR(100) | UNIQUE, NOT NULL | Contact + notifications |
| `full_name` | VARCHAR(200) | | |
| `password_hash` | VARCHAR(255) | NOT NULL | bcrypt(password) |
| `role` | ENUM | NOT NULL, DEFAULT='user' | 'user', 'supervisor', 'admin' |
| `facility_id` | UUID | FK(Facility), NOT NULL | Which facility user belongs to |
| `quota_config_json` | JSONB | | Custom quota rules specific to this user; overrides role-based defaults |
| `is_active` | BOOLEAN | DEFAULT TRUE | Soft delete (false = disabled) |
| `last_login` | TIMESTAMP | | Last successful authentication |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Account creation time |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | Last modified time |

**Validations**:
- `email` must be valid email format
- `username` length ≥ 3 characters, alphanumeric + underscore
- `password_hash` never exposed in API responses
- `facility_id` must reference existing facility

**Examples**:
```json
{
  "id": "user-a1b2c3d4",
  "username": "alice_supervisor",
  "email": "alice@facility1.com",
  "full_name": "Alice Johnson",
  "role": "supervisor",
  "facility_id": "fac-xyz789",
  "quota_config_json": {
    "monthly_limit_liters": 500,
    "daily_limit_liters": 50,
    "override_reason": "Senior manager"
  },
  "is_active": true,
  "created_at": "2026-01-15T08:00:00Z"
}
```

---

## Entity 2: Quota Limit Rule

**Purpose**: Flexible quota enforcement rules (user-specific, role-based, daily, monthly, custom).

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | Unique rule identifier |
| `facility_id` | UUID | FK(Facility), NOT NULL | Scope to facility |
| `rule_type` | ENUM | NOT NULL | 'user_specific', 'role_based', 'daily', 'monthly', 'custom' |
| `applies_to_user_id` | UUID | FK(User), nullable | If type='user_specific', target user |
| `applies_to_role` | VARCHAR(50) | nullable | If type='role_based', target role |
| `time_period` | ENUM | nullable | If type='daily'/'monthly', period type |
| `max_liters` | NUMERIC(10,2) | NOT NULL | Maximum liters allowed |
| `enforcement_action` | ENUM | DEFAULT='reject' | 'reject' (deny), 'warn' (allow but flag) |
| `custom_condition_json` | JSONB | nullable | For complex rules (e.g., "never on weekends") |
| `is_active` | BOOLEAN | DEFAULT TRUE | |
| `priority` | INT | | Resolution order when multiple rules match; higher wins |
| `created_at` | TIMESTAMP | DEFAULT NOW() | |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | |

**Validation Rules** (application logic):
- If user has multiple overlapping rules (role-based + user-specific), apply most restrictive
- `max_liters` > 0 always
- Exactly one of `applies_to_user_id` or `applies_to_role` or `time_period` or `custom_condition_json` not null

**Examples**:
```json
[
  {
    "id": "rule-1",
    "facility_id": "fac-xyz789",
    "rule_type": "role_based",
    "applies_to_role": "user",
    "max_liters": 50,
    "priority": 1,
    "time_period": "daily"
  },
  {
    "id": "rule-2",
    "facility_id": "fac-xyz789",
    "rule_type": "user_specific",
    "applies_to_user_id": "user-a1b2c3d4",
    "max_liters": 1000,
    "priority": 10,
    "time_period": "monthly"
  }
]
```

---

## Entity 3: Dispensing Request

**Purpose**: User's request to dispense fuel; approved/rejected based on quota.

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | Unique request identifier |
| `user_id` | UUID | FK(User), NOT NULL | Who made the request |
| `device_id` | UUID | FK(Device), NOT NULL | Which device to dispense from |
| `requested_liters` | NUMERIC(10,2) | NOT NULL, > 0 | How much the user wants |
| `approved_liters` | NUMERIC(10,2) | nullable | Max liters backend approved |
| `status` | ENUM | NOT NULL, DEFAULT='pending' | 'pending', 'approved', 'rejected', 'dispensing', 'completed' |
| `rejection_reason` | VARCHAR(255) | nullable | If rejected, why (e.g., 'quota_exceeded', 'device_offline') |
| `destination` | VARCHAR(100) | nullable | Where fuel is going (for tracking) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Request creation |
| `approved_at` | TIMESTAMP | nullable | When backend approved |
| `dispensing_started_at` | TIMESTAMP | nullable | When relay activated |
| `dispensing_ended_at` | TIMESTAMP | nullable | When relay deactivated |

**Validation Rules**:
- `requested_liters` ≤ device `tank_capacity`
- `approved_liters` ≤ `requested_liters` always
- `approved_liters` ≥ 0 if status='approved'
- Status transitions: pending → (approved|rejected), approved → dispensing → completed
- Only state changes visible in API responses (no intermediate rejected states)

**Examples**:
```json
{
  "id": "req-abc-123",
  "user_id": "user-a1b2c3d4",
  "device_id": "dev-pump-001",
  "requested_liters": 50.0,
  "approved_liters": 25.0,
  "status": "approved",
  "destination": "Storage Tank A",
  "created_at": "2026-02-27T14:30:00Z",
  "approved_at": "2026-02-27T14:30:05Z"
}
```

---

## Entity 4: Dispensing Record (IMMUTABLE LEDGER)

**Purpose**: Immutable, append-only record of every fuel dispensing event. Never updated/deleted.

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | BIGSERIAL | PRIMARY KEY | Auto-incrementing (for ordering) |
| `dispensing_request_id` | UUID | FK(DispensingRequest), NOT NULL | Link to original request |
| `device_id` | UUID | FK(Device), NOT NULL | Which device dispensed |
| `user_id` | UUID | FK(User), NOT NULL | Which user was dispensing |
| `volume_liters` | NUMERIC(10,2) | NOT NULL | Actual volume measured/dispensed |
| `measurement_timestamp` | TIMESTAMP | NOT NULL | When ESP32 took measurement |
| `backend_received_at` | TIMESTAMP | DEFAULT NOW() | When backend received it |
| `communication_channel` | VARCHAR(20) | | 'wifi' (direct ESP32) or 'ble-proxied' (via mobile) |
| `checksum` | VARCHAR(64) | | SHA-256 of measurement payload (for integrity verification) |
| `idempotency_key` | UUID | UNIQUE, nullable | Deduplication key (prevents duplicate records from retries) |
| `metadata_json` | JSONB | | Additional context: battery%, signal strength, etc. |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Record creation (immutable) |

**Immutability Enforcement**:
- Database trigger prevents UPDATE and DELETE on this table
- Python: `raise_immutable_error()` function in trigger

**Validation Rules**:
- `volume_liters` ≥ 0
- `measurement_timestamp` ≤ `backend_received_at` (can't receive before measurement)
- `backend_received_at` - `measurement_timestamp` ≤ 24 hours (flag old measurements as anomalies)
- `checksum` validates payload integrity server-side (recalculate, must match)
- `idempotency_key` NOT NULL = proxied via mobile; NULL = direct WiFi

**Examples**:
```json
{
  "id": 1001,
  "dispensing_request_id": "req-abc-123",
  "device_id": "dev-pump-001",
  "user_id": "user-a1b2c3d4",
  "volume_liters": 25.05,
  "measurement_timestamp": "2026-02-27T14:32:22Z",
  "backend_received_at": "2026-02-27T14:32:25Z",
  "communication_channel": "wifi",
  "checksum": "a1b2c3d4e5f6...",
  "idempotency_key": null,
  "metadata_json": {
    "battery_percent": 78,
    "signal_strength_dbm": -65,
    "queue_depth": 0
  },
  "created_at": "2026-02-27T14:32:25Z"
}
```

---

## Entity 5: Measuring Device

**Purpose**: Physical ESP32 device that controls relay and measures fuel.

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | Unique device identifier (baked into firmware) |
| `device_name` | VARCHAR(100) | NOT NULL | Human-readable name (e.g., "Pump A - Tank 1") |
| `facility_id` | UUID | FK(Facility), NOT NULL | Which facility device is in |
| `device_model` | VARCHAR(50) | | Hardware model (e.g., "ESP32-S3 DevKit") |
| `firmware_version` | VARCHAR(20) | | Current firmware version (e.g., "v2.1.0") |
| `mac_address` | VARCHAR(17) | UNIQUE, nullable | WiFi MAC address (for identification) |
| `ble_uuid` | VARCHAR(36) | UNIQUE, nullable | BLE service UUID |
| `tank_capacity_liters` | NUMERIC(10,2) | NOT NULL | Physical tank max capacity |
| `current_queue_depth` | INT | DEFAULT 0 | How many measurements queued locally (for monitoring) |
| `last_communication_at` | TIMESTAMP | | Last successful WiFi or BLE contact |
| `last_wifi_connection_at` | TIMESTAMP | | Last WiFi sync (NULL if never connected) |
| `last_ble_contact_at` | TIMESTAMP | | Last BLE proxy (NULL if never) |
| `connectivity_status` | ENUM | DEFAULT='unknown' | 'online_wifi', 'online_ble', 'offline', 'unknown' |
| `battery_percent` | INT | nullable | Last known battery level (0-100) |
| `signal_strength_dbm` | INT | nullable | Last known WiFi or BLE signal (dBm) |
| `is_paused` | BOOLEAN | DEFAULT FALSE | If TRUE, reject all dispensing requests (maintenance mode) |
| `location_lat` | NUMERIC(10,8) | nullable | GPS coordinates if available |
| `location_lng` | NUMERIC(11,8) | nullable | |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Device registration |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | Metadata updates (location, version, etc.) |

**Validation Rules**:
- `tank_capacity_liters` > 0
- `device_name` unique per facility
- `battery_percent` ∈ [0, 100]
- `signal_strength_dbm` ∈ [-120, -20] (valid dBm range)

**Examples**:
```json
{
  "id": "dev-pump-001",
  "device_name": "Fuel Pump A",
  "facility_id": "fac-xyz789",
  "device_model": "ESP32-S3 DevKit",
  "firmware_version": "v2.1.0",
  "tank_capacity_liters": 1000.0,
  "connectivity_status": "online_wifi",
  "battery_percent": 78,
  "signal_strength_dbm": -62,
  "last_communication_at": "2026-02-27T14:35:00Z",
  "last_wifi_connection_at": "2026-02-27T14:35:00Z"
}
```

---

## Entity 6: WiFi Configuration

**Purpose**: Updatable WiFi profiles for devicesfieldNameResolverancialized via OTA.

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | Unique config identifier |
| `device_id` | UUID | FK(MeasuringDevice), NOT NULL | Which device this config applies to |
| `ssid_profiles` | JSONB | NOT NULL | Array of SSID profiles (see schema below) |
| `fallback_to_ble` | BOOLEAN | DEFAULT TRUE | If WiFi fails, enable BLE fallback |
| `ble_advertise_timeout_seconds` | INT | DEFAULT 300 | How long to advertise before giving up |
| `wifi_scan_interval_seconds` | INT | DEFAULT 60 | How often to scan for WiFi (power trade-off) |
| `config_version` | INT | DEFAULT 1 | For OTA versioning (prevent downgrade) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | |

**SSID Profile Schema** (JSONB array):
```json
{
  "ssid_profiles": [
    {
      "ssid": "MainFacilityWiFi",
      "password": "encrypted_password_hash",  // encrypted in DB
      "priority": 1,
      "enabled": true,
      "max_retries": 5
    },
    {
      "ssid": "BackupWiFi",
      "password": "encrypted_password_hash",
      "priority": 2,
      "enabled": true,
      "max_retries": 3
    }
  ]
}
```

**Validation Rules**:
- `ssid_profiles` array length ≥ 1 and ≤ 5
- Each SSID priority unique within array
- Passwords encrypted in transit (HTTPS) and at rest (encrypted in DB)
- `ble_advertise_timeout_seconds` ∈ [30, 3600]

**Examples**:
```json
{
  "id": "cfg-wifi-001",
  "device_id": "dev-pump-001",
  "ssid_profiles": [
    {
      "ssid": "FacilityNet",
      "priority": 1,
      "enabled": true,
      "max_retries": 5
    }
  ],
  "fallback_to_ble": true,
  "config_version": 1,
  "updated_at": "2026-02-27T14:00:00Z"
}
```

---

## Entity 7: BLE Session Log

**Purpose**: Audit trail of BLE-proxied communications (for debugging and compliance).

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | Unique session identifier |
| `mobile_user_id` | UUID | FK(User), NOT NULL | Which mobile user was relaying |
| `device_id` | UUID | FK(MeasuringDevice), NOT NULL | Which ESP32 device data came from |
| `session_start_at` | TIMESTAMP | NOT NULL | When connection established |
| `session_end_at` | TIMESTAMP | nullable | When connection closed (NULL = still active) |
| `measurements_count` | INT | DEFAULT 0 | How many measurements relayed in this session |
| `data_bytes_transferred` | INT | | Total bytes through BLE |
| `status` | ENUM | | 'active', 'completed', 'failed', 'timeout' |
| `failure_reason` | VARCHAR(255) | nullable | If failed, why |
| `signal_strength_dbm` | INT | nullable | Last observed signal strength |
| `round_trip_latency_ms` | INT | nullable | BLE characteristic read latency in ms |
| `metadata_json` | JSONB | | Extra info (mobile device model, BLE MTU negotiated, etc.) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Session creation |

**Examples**:
```json
{
  "id": "ble-sess-001",
  "mobile_user_id": "user-a1b2c3d4",
  "device_id": "dev-pump-001",
  "session_start_at": "2026-02-27T14:32:00Z",
  "session_end_at": "2026-02-27T14:32:15Z",
  "measurements_count": 3,
  "status": "completed",
  "signal_strength_dbm": -65,
  "round_trip_latency_ms": 145,
  "metadata_json": {
    "mobile_device": "iPhone 15 Pro",
    "ble_mtu": 244,
    "retries": 0
  }
}
```

---

## Entity 8: Device Audit Trail

**Purpose**: Log of relay activation/deactivation events (for independent verification).

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | BIGSERIAL | PRIMARY KEY | |
| `device_id` | UUID | FK(MeasuringDevice), NOT NULL | Which device |
| `event_type` | ENUM | NOT NULL | 'relay_opened', 'relay_closed', 'hard_cutoff', 'timeout', 'manual_stop', 'error' |
| `dispensing_request_id` | UUID | FK(DispensingRequest), nullable | Associated request (NULL if maintenance) |
| `max_liters_approved` | NUMERIC(10,2) | nullable | What was approved |
| `actual_volume_dispensed` | NUMERIC(10,2) | nullable | Actual volume when relay closed |
| `trigger_source` | ENUM | | 'backend_api', 'ble_command', 'local_timeout', 'hard_limit_reached', 'manual' |
| `timestamp` | TIMESTAMP | NOT NULL | When event occurred |
| `backend_received_at` | TIMESTAMP | DEFAULT NOW() | When backend logged it |
| `metadata_json` | JSONB | | Context (error messages, reason for timeout, etc.) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | |

**Immutability**: Append-only, like Dispensing Record.

**Examples**:
```json
[
  {
    "id": 2001,
    "device_id": "dev-pump-001",
    "event_type": "relay_closed",
    "dispensing_request_id": "req-abc-123",
    "max_liters_approved": 25.0,
    "trigger_source": "backend_api",
    "timestamp": "2026-02-27T14:32:05Z"
  },
  {
    "id": 2002,
    "device_id": "dev-pump-001",
    "event_type": "hard_cutoff",
    "dispensing_request_id": "req-abc-123",
    "actual_volume_dispensed": 25.05,
    "trigger_source": "hard_limit_reached",
    "timestamp": "2026-02-27T14:32:22Z"
  }
]
```

---

## Entity 9: Mobile Proxy Permission

**Purpose**: Control which users can proxy measurements for which devices (authorization).

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | |
| `user_id` | UUID | FK(User), NOT NULL | Mobile user who can proxy |
| `device_id` | UUID | FK(MeasuringDevice), NOT NULL | Which ESP32 device they can proxy for |
| `permission_type` | ENUM | DEFAULT='proxy' | 'proxy' (relay measurements), 'command' (send relay commands) |
| `is_active` | BOOLEAN | DEFAULT TRUE | |
| `granted_by_user_id` | UUID | FK(User), nullable | Which admin/supervisor granted this |
| `created_at` | TIMESTAMP | DEFAULT NOW() | |

**Validation Rules**:
- Users can only proxy for devices in their same facility
- Permissions granted by supervisors/admins only
- One permission row per (user, device) pair

**Examples**:
```json
{
  "id": "perm-001",
  "user_id": "user-a1b2c3d4",
  "device_id": "dev-pump-001",
  "permission_type": "proxy",
  "is_active": true,
  "granted_by_user_id": "user-supervisor-123",
  "created_at": "2026-02-27T10:00:00Z"
}
```

---

## Entity 10: Facility

**Purpose**: Grouping entity for devices, users, and quotas (multi-tenant).

**Fields**:

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | UUID | PRIMARY KEY | |
| `facility_name` | VARCHAR(200) | UNIQUE, NOT NULL | |
| `location_address` | VARCHAR(500) | | |
| `timezone` | VARCHAR(50) | DEFAULT 'UTC' | For quota "daily" calculations |
| `manager_user_id` | UUID | FK(User), nullable | Primary facility manager |
| `is_active` | BOOLEAN | DEFAULT TRUE | |
| `created_at` | TIMESTAMP | DEFAULT NOW() | |

**Examples**:
```json
{
  "id": "fac-xyz789",
  "facility_name": "Central Storage Depot",
  "location_address": "123 Main St, City, Country",
  "timezone": "Europe/Lisbon",
  "manager_user_id": "user-supervisor-123",
  "created_at": "2026-01-01T00:00:00Z"
}
```

---

## Key Relationships & Queries

**Find today's consumption by user**:
```sql
SELECT SUM(volume_liters) as daily_total
FROM dispensing_records
WHERE user_id = $1
  AND DATE(backend_received_at) = CURRENT_DATE
  AND DATE(measurement_timestamp) = CURRENT_DATE;
```

**Find measurements via BLE proxy**:
```sql
SELECT *
FROM dispensing_records
WHERE communication_channel = 'ble-proxied'
  AND backend_received_at > NOW() - INTERVAL '24 hours'
ORDER BY backend_received_at DESC;
```

**Check device connectivity status**:
```sql
SELECT
  id,
  device_name,
  connectivity_status,
  CASE
    WHEN last_wifi_connection_at > NOW() - INTERVAL '5 minutes' THEN 'online_wifi'
    WHEN last_ble_contact_at > NOW() - INTERVAL '5 minutes' THEN 'online_ble'
    ELSE 'offline'
  END as current_status
FROM measuring_devices
WHERE facility_id = $1;
```

**Detect duplicate measurements via idempotency**:
```sql
SELECT idempotency_key, COUNT(*) as count
FROM dispensing_records
WHERE idempotency_key IS NOT NULL
GROUP BY idempotency_key
HAVING COUNT(*) > 1;  -- Should be empty always!
```

---

## Phase 1 Complete: Data Model

All 10 entities defined with:
- ✅ Field validation rules
- ✅ State transitions & constraints
- ✅ Immutability enforcement (ledger tables)
- ✅ Security considerations (password hashing, encrypted WiFi credentials)
- ✅ Audit capabilities (timestamps, user tracking, BLE sessions)
- ✅ Example queries for common operations

**Next**: Create API contracts (contracts/) for CRUD operations on these entities.
