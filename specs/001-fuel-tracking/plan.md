# Implementation Plan: Fuel Dispensing Tracking

**Branch**: `001-fuel-tracking` | **Date**: 2026-02-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-fuel-tracking/spec.md`

## Summary

Build a comprehensive fuel/oil dispensing tracking system with IoT integration. ESP32 devices measure fuel volume through relay-controlled pumps with multi-channel communication: REST API (primary WiFi-based sync) + MQTT (Home Assistant) + BLE fallback (via mobile app bridge when WiFi unavailable). System enforces flexible quota management (user/role/daily/monthly), provides immutable audit trails, and ensures zero data loss through offline queueing and checksums. WiFi configuration is user-friendly (OTA-updateable, supports multiple predefined SSIDs). **Identity & Access Management** delegated to **Keycloak** (Apache 2.0): handles user CRUD, role management, JWT issuance, and admin UI. Backend is an OAuth2 resource server validating Keycloak-issued JWTs; ESP32 devices use separate pre-shared API key authentication. Architecture: REST API backend (Spring Boot 4.0.1/Java 25) + Web UI (React 19.2.4) + Mobile app (React Native with BLE service) + IoT firmware (ESP32/PlatformIO with OTA + BLE + WiFi provisioning) + Keycloak IAM.

## Technical Context

**ESP32 Firmware**:
- Language/Version: C/C++ with Arduino framework via PlatformIO framework
- Primary Dependencies: PlatformIO, Arduino-esp32, ArduinoJson, WiFiClientSecure (REST), PubSubClient (MQTT), esp_ble_mesh or NimBLE (BLE)
- Communication Layers (priority order):
  1. WiFi (primary): REST API + MQTT over WiFi for backend sync
  2. BLE (fallback): Bluetooth Low Energy for mobile app bridge when WiFi unavailable
  3. Mobile app acts as bridge: receives data via BLE → transmits to backend via REST → receives response → sends back via BLE
- WiFi Management:
  - OTA-updateable SSID configuration (stored in NVRAM with multiple profiles)
  - Support for predefined WiFi SSIDs list (configured at compile-time or via OTA)
  - Automatic WiFi selection/fallback to next SSID on connection failure
  - Visual/audio feedback on WiFi connection status
- Firmware Updates: Over-The-Air (OTA) with versioning (WiFi-based primary, BLE-based optional fallback)
- BLE Configuration:
  - ESP32 acts as BLE peripheral (mobile phones connect as central)
  - BLE GATT services for: proximity check, measurement data, relay control commands
  - Low power BLE during WiFi connection loss (dynamic power switching)
  - BLE advertisement with device ID and connection strength indicators
- Storage: Local SPIFFS/LittleFS for offline queueing (7-day retention) + NVRAM for WiFi/BLE settings
- Testing: Unit tests via PlatformIO, hardware simulation, BLE simulator on mobile

**Backend**:
- Language/Version: Java 25 with Spring Boot 4.0.1
- Primary Dependencies: Spring Web, Spring Data JPA, Spring Security, spring-boot-starter-oauth2-resource-server, Gradle 9.3.0
- **Authentication**: Keycloak (Apache 2.0) as external IAM; backend validates Keycloak-issued JWTs via OAuth2 resource server configuration
- **Authorization**: Roles (user/supervisor/admin) read from JWT `realm_access.roles` claim — no role column in backend User table
- **User Provisioning**: Auto-create local User profile on first authenticated API call (from JWT sub, preferred_username, email). Admin assigns facility/quota afterward
- **Device Auth**: ESP32 uses pre-shared API key (X-Device-Key header), independent of Keycloak
- Storage: PostgreSQL 15+
- Observability: Structured JSON logging + Spring Boot Actuator health/metrics endpoints
- Testing: JUnit 5, Mockito, TestContainers for integration tests
- Target Platform: Linux server (containerized)
- Performance Goals: Handle 100+ concurrent dispensing requests, <200ms API response, 99.9% availability
- Constraints: Transaction guarantees, immutable ledger, checksums for data integrity
- Scale: Supports 1000+ users, 100+ ESP32 devices

**Frontend**:
- Language/Version: TypeScript 5.9 with React 19.2.4
- Primary Dependencies: Ant Design 6.2.0, React Router, SWR/TanStack Query
- Storage: IndexedDB for offline cache
- Testing: Vitest, React Testing Library
- Target Platform: Modern web browsers
- Performance Goals: <2 second page load, responsive design
- Scale: 1000+ users viewing history/dashboards

**Mobile App**:
- Language/Version: TypeScript/JavaScript with React Native
- Primary Dependencies: React Native 0.76+, React Navigation, react-native-ble-plx (iOS) / react-native-ble-adapter (Android), native modules for auth
- Communication Bridges:
  - REST API client for backend sync (primary when mobile has WiFi)
  - BLE Central role to communicate with ESP32 devices (when WiFi unavailable)
  - Automatic fallback: if WiFi fails, detect nearby ESP32 via BLE scan, establish connection
  - BLE proxy service: proxies ESP32 measurement data & relay commands through mobile to backend
- BLE Capabilities:
  - Background BLE scanning (configurable for power efficiency)
  - BLE GATT client for connecting to ESP32 peripherals
  - Handle BLE connection/disconnection events with user notifications
  - Transmit user's dispensing requests via BLE to ESP32
  - Receive relay activation status & measurement confirmations via BLE
  - Background BLE service for offline measurement queueing
- WiFi/BLE Fallback Logic:
  - Check mobile WiFi connection → if available, use REST API
  - If no mobile WiFi, scan for nearby ESP32 devices via BLE UUID
  - Connect to target device, exchange data (measurement/control commands)
  - Cache data locally if connection drops, retry with exponential backoff
- Testing: Jest, detox for E2E, BLE simulator libraries for unit tests
- Target Platform: iOS 13+ (Core Bluetooth Framework), Android 8+ (Bluetooth API + permissions)
- Performance Goals: <3 second app startup, BLE scan response <500ms, data transmission latency <2s
- Scale: 500+ users, proximity-based ESP32 discovery

**Project Type**: Multi-platform (IoT firmware + backend + web frontend + mobile app)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Principle I - API-First Design**: ✅ PASS
- Backend exposes REST API for frontend/mobile/ESP32 consumption
- MQTT broker for Home Assistant compatibility (separate event stream)

**Principle II - Separation of Concerns**: ✅ PASS
- ESP32 firmware: hardware control + local queueing
- Backend: business logic, quota enforcement, data persistence
- Frontend: user interface, history display
- Mobile: mobile-specific UI, offline cache

**Principle III - Database Versioning**: ✅ PASS
- PostgreSQL 15+ with migrations framework (Flyway/Liquibase)
- All schema changes tracked, immutable ledger for dispensing records

**Principle IV - Testing at Boundaries**: ✅ PASS
- Contract tests for ESP32↔Backend REST API communication
- Integration tests for backend microservices
- E2E tests for user workflows
- Hardware simulation tests for ESP32 firmware

**Principle V - Minimal Complexity**: ✅ PASS
- Single database (PostgreSQL), no complex caching layer
- REST + MQTT for communication (well-understood patterns)
- Standard component libraries (Ant Design, React Navigation)
- Keycloak adds infrastructure (Docker container) but **eliminates** custom auth code (user CRUD, password management, login flows, role management UI)
- Deferred: override workflows, admin dashboards (P2/P3 features)

**Principle VI - Hardware-Backend Synchronization**: ✅ PASS (CRITICAL & ENHANCED)
- Primary: ESP32 sends measurements via REST API over WiFi (standard REST + MQTT)
- Fallback: ESP32 uses BLE to connect to nearby mobile, mobile proxies to backend via REST
- Configuration: WiFi SSID profiles stored in NVRAM, updatable via OTA
- Backend can send activation/revoke commands to ESP32 (WiFi) or via mobile BLE bridge
- Offline fallback: ESP32 caches latest approval for relay activation (WiFi unavailable)
- BLE-proxied measurements include idempotency keys + checksums for integrity
- MQTT topic for Home Assistant: `home_assistant/fueling/device/{device_id}/*` (WiFi primary)

**Principle VII - Data Resilience & Integrity**: ✅ PASS (CRITICAL)
- SHA-256 checksums for measurement validation
- Idempotency keys prevent duplicate processing
- Offline queueing: ESP32 retains measurements 7 days locally
- Atomic transactions for dispensing records
- Immutable ledger with audit trail

## Project Structure

### Documentation (this feature)

```text
specs/001-fuel-tracking/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (implementation strategy)
├── research.md          # Phase 0 output (research findings)
├── data-model.md        # Phase 1 output (entity definitions)
├── quickstart.md        # Phase 1 output (local dev setup)
├── contracts/           # Phase 1 output (API contracts)
│   ├── dispensing-request.openapi.yaml
│   ├── dispensing-record.openapi.yaml
│   └── mqtt-events.schema.json
├── checklists/requirements.md  # Quality checklist
└── tasks.md             # Phase 2 output (implementation tasks)
```

### Source Code (repository root)

**Option 3: Multi-platform (IoT + Backend + Web + Mobile) - SELECTED**

```text
esp32-firmware/                    # PRIORITY 1: IoT firmware with OTA
├── platformio.ini                 # PlatformIO project config (ESP32 dev board config)
├── src/
│   ├── main.cpp                   # Entry point
│   ├── relay_control.cpp/.h       # Relay activation/deactivation logic
│   ├── meter_sensor.cpp/.h        # Fuel pulse counting from meter
│   ├── rest_api_client.cpp/.h     # REST API communication with backend
│   ├── mqtt_client.cpp/.h         # MQTT for Home Assistant compatibility
│   ├── ota_updater.cpp/.h         # Over-The-Air firmware update handler
│   ├── offline_queue.cpp/.h       # Local SPIFFS queue (7-day retention)
│   ├── config.h                   # WiFi, backend URL, device ID settings
│   └── certificates/              # Root CA for HTTPS, optional client certs
└── test/                           # PlatformIO unit tests
    ├── test_relay_control.cpp
    ├── test_meter_sensor.cpp
    └── test_offline_queue.cpp

backend/                           # PRIORITY 2: Spring Boot REST API
├── build.gradle.kts               # Gradle config (Java 25)
├── docker-compose.yaml            # Keycloak + PostgreSQL for local dev
├── src/main/java/
│   └── com/olimeeter/fuel/
│       ├── FuelTrackingApplication.java
│       ├── models/
│       │   ├── User.java              # Domain profile (keycloak_sub PK, no password/role)
│       │   ├── Facility.java
│       │   ├── DispensingRequest.java
│       │   ├── DispensingRecord.java
│       │   ├── MeasuringDevice.java
│       │   └── QuotaLimitRule.java
│       ├── services/
│       │   ├── DispensingService.java
│       │   ├── QuotaService.java
│       │   ├── MeasurementService.java
│       │   ├── UserProvisioningService.java  # Auto-create User from JWT on first login
│       │   └── DeviceSyncService.java
│       ├── api/
│       │   ├── DispensingController.java
│       │   ├── MeasurementController.java
│       │   ├── DeviceController.java
│       │   └── HistoryController.java
│       ├── repository/
│       │   ├── UserRepository.java
│       │   ├── DispensingRequestRepository.java
│       │   ├── DispensingRecordRepository.java
│       │   └── QuotaRuleRepository.java
│       ├── config/
│       │   ├── SecurityConfig.java    # OAuth2 resource server + device API key filter
│       │   ├── WebConfig.java
│       │   └── MqttConfig.java (MQTT publisher)
│       └── util/
│           ├── ChecksumUtil.java (SHA-256)
│           └── IdempotencyUtil.java
├── src/main/resources/
│   ├── application.yaml           # Keycloak issuer-uri, OAuth2 resource server config
│   ├── application-dev.yaml       # H2 in-memory, Flyway disabled, mock data
│   ├── db/migration/ (Flyway migrations)
│   │   ├── V1__Create_core_schema.sql
│   │   ├── V2__Create_dispensing_schema.sql
│   │   └── V3__Create_quota_and_config_schema.sql
│   ├── db/data-dev.sql            # Mock data for dev profile
│   └── mqtt/
│       └── topics.yaml (Home Assistant MQTT mapping)
└── src/test/java/ (JUnit 5, Mockito, TestContainers)
    └── com/olimeeter/fuel/
        ├── services/
        └── api/

frontend/                          # PRIORITY 3: React web UI
├── package.json (React 19.2.4, TypeScript 5.9)
├── vite.config.ts
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── components/
│   │   ├── DispenseRequestForm.tsx
│   │   ├── HistoryTable.tsx
│   │   ├── QuotaDisplay.tsx
│   │   └── AdminDashboard.tsx (P2 feature)
│   ├── pages/
│   │   ├── DispensingPage.tsx
│   │   ├── HistoryPage.tsx
│   │   └── AdminPage.tsx (P3 feature)
│   ├── services/
│   │   ├── api.ts (REST client, SWR hooks)
│   │   └── auth.ts (Keycloak OIDC login/logout via keycloak-js)
│   ├── styles/
│   │   └── global.less (Ant Design theming)
│   └── types/
│       ├── api.ts
│       └── models.ts
└── tests/
    ├── unit/
    ├── integration/ (contract tests for API)
    └── e2e/ (Playwright/Cypress)

mobile/                            # PRIORITY 4: React Native mobile app
├── app.json (React Native config)
├── package.json (React Native 0.76+)
├── src/
│   ├── App.tsx
│   ├── screens/
│   │   ├── DispensingScreen.tsx
│   │   ├── HistoryScreen.tsx
│   │   └── SettingsScreen.tsx
│   ├── services/
│   │   ├── api.ts (REST client)
│   │   ├── auth.ts (Keycloak OIDC via react-native-app-auth)
│   │   └── offline.ts (AsyncStorage cache)
│   ├── types/
│   │   └── models.ts (shared with backend)
│   └── navigation/
│       └── RootNavigator.tsx
├── ios/
│   ├── Podfile (native dependencies)
│   └── Frameworks/
├── android/
│   └── app/build.gradle
└── __tests__/
    ├── unit/
    └── e2e/ (Detox)

shared/                            # Optional: Shared types/utilities
├── types/
│   ├── api.ts (TS interfaces for backend/frontend/mobile)
│   └── models.ts
└── constants/
    └── mqtt-topics.ts (shared between backend MQTT config and frontend subscriptions)
```

**Structure Decision**:
- **ESP32 Firmware (Priority 1)**: PlatformIO project with Arduino framework, OTA capability, REST + MQTT support
- **Backend (Priority 2)**: Spring Boot 4.0.1 (Java 25) with Gradle, PostgreSQL 15+, REST API for all clients, MQTT publisher for Home Assistant
- **Frontend (Priority 3)**: React 19.2.4 + TypeScript 5.9, Ant Design 6.2.0, Vite build tool
- **Mobile (Priority 4)**: React Native for cross-platform iOS/Android
- **Shared (Optional)**: Common types and constants to keep API contracts synchronized

## Phase 0: Research & Unknowns Resolution

**Status**: PENDING (execute with research agents)

### Research Tasks

1. **PlatformIO + Arduino Framework Best Practices**
   - OTA update implementation patterns for ESP32
   - SPIFFS file system for local queueing
   - Memory constraints and optimization techniques
   - WiFi reconnection handling in embedded systems

2. **ESP32 WiFi Configuration & Management**
   - NVRAM storage patterns for WiFi profiles (predefined SSIDs)
   - OTA-updateable WiFi configuration (compile-time vs runtime)
   - WiFi fallback logic (automatic retry with multiple SSIDs)
   - Power management during WiFi connection loss
   - Visual/audio feedback indicators for connection status

3. **BLE Implementation on ESP32 (NimBLE vs esp_ble_mesh)**
   - BLE peripheral mode (GATT services & characteristics) for measurement data
   - BLE advertisement protocol with UUID discovery
   - BLE connection management (pairing, bonding, security)
   - Memory footprint & power consumption tradeoffs
   - BLE range limitations and performance in real-world environments

4. **Mobile App BLE Integration (React Native)**
   - react-native-ble-plx (iOS via Core Bluetooth)
   - react-native-ble-adapter (Android via Bluetooth API)
   - Cross-platform BLE permission handling (iOS vs Android differences)
   - Background BLE scanning and connection state management
   - BLE GATT client operations (read/write characteristics)

5. **REST API ↔ ESP32 Integration (WiFi Primary)**
   - SSL/TLS certificate pinning on embedded devices
   - Exponential backoff retry strategies
   - Idempotency key implementation in embedded context
   - Payload size optimization (bandwidth constraints)

6. **BLE-to-Backend Proxy Pattern (Mobile Bridge)**
   - Mobile app receiving BLE data and proxying to REST backend
   - Relay control commands flowing through mobile (ESP32 ← BLE ← Mobile ← REST ← Backend)
   - Measurement data flowing through mobile (ESP32 → BLE → Mobile → REST → Backend)
   - Handling mobile WiFi unavailability during proxy operation (queue locally)
   - Security implications of proxying (authentication delegation)

7. **MQTT for Home Assistant**
   - Home Assistant MQTT discovery protocol
   - Topic naming conventions for fuel tracking domain
   - QoS levels (0, 1, 2) and persistence trade-offs
   - Shared message structure between REST and MQTT events

8. **Spring Boot 4.0.1 with Java 25 + Keycloak Integration**
   - Virtual threads for concurrent connections (Project Loom)
   - **Keycloak as OAuth2 Authorization Server**: realm/client setup, role mapping (user/supervisor/admin)
   - **spring-boot-starter-oauth2-resource-server**: JWT validation, issuer-uri configuration, role extraction from `realm_access.roles`
   - **User auto-provisioning**: Filter/interceptor to create local User profile on first authenticated API call from JWT claims (sub, preferred_username, email)
   - **Dual auth model**: Keycloak JWT for human users + pre-shared API key filter for ESP32 devices
   - Spring Data JPA best practices for large datasets
   - Handling BLE-proxied requests (trust chain from mobile app)

9. **PostgreSQL 15+ Data Integrity**
   - Immutable ledger table design patterns
   - JSONB support for semi-structured WiFi/BLE config
   - Transaction isolation levels for concurrent dispensing

10. **React + Ant Design Offline Architecture**
    - IndexedDB schema design for dispensing history
    - Sync patterns with backend REST API
    - Conflict resolution strategies

11. **React Native + Home Assistant Integration**
    - MQTT client libraries (if direct MQTT support needed for mobile)
    - Secure token storage (native Keychain/Keystore)
    - Platform-specific background task handling (iOS vs Android)
    - BLE background modes (iOS/Android capability differences)

**Deliverable**: `research.md` with decision rationale for each unknown

---

## Phase 1: Design & Contracts

**Status**: READY (follows Phase 0 completion)

### 1.1 Data Model Design

**Deliverable**: `data-model.md` with entity definitions

Key entities from spec (to be expanded with field details, validation rules, state transitions):

- **Dispensing Request** (user initiates fuel request)
- **Dispensing Record** (immutable ledger of completed dispensing)
- **Measuring Device** (physical ESP32 device metadata)
- **User** (domain profile linked to Keycloak identity via `keycloak_sub`; no password_hash or role column — roles from JWT `realm_access.roles`; auto-provisioned on first login)
- **Quota Limit Rule** (flexible quota configuration)
- **Device Audit Trail** (ESP32 activation/deactivation events)
- **WiFi Configuration** (SSID profiles, OTA-updateable credentials per device)
- **BLE Session** (proxied communication logs from mobile bridge)

### 1.2 API Contracts

**Deliverable**: `contracts/` directory with OpenAPI/JSON Schema

Priority contracts (in order of implementation):

1. **Dispensing Request API** (`dispensing-request.openapi.yaml`)
   - POST `/api/v1/dispensing-requests` (user requests fuel)
   - Response: `{status: "approved"|"rejected", max_liters: number, reason?: string}`

2. **Measurement API** (`dispensing-record.openapi.yaml`)
   - POST `/api/v1/measurements` (ESP32 uploads measurement)
   - Headers: `Device-ID`, `Idempotency-Key`, `X-Checksum` (SHA-256), `Communication-Channel` (wifi|ble-proxied)
   - Payload: `{device_id, volume_liters, timestamp, dispensing_request_id}`

3. **Device Relay Control API** (`device-control.openapi.yaml`)
   - POST `/api/v1/devices/{device_id}/relay/activate` (backend sends activation signal)
   - POST `/api/v1/devices/{device_id}/relay/deactivate` (backend sends stop signal)
   - Response: `{status: "success"|"offline_queued", timestamp}`

4. **WiFi Configuration API** (`wifi-config.openapi.yaml`) - NEW
   - GET `/api/v1/devices/{device_id}/wifi-config` (retrieve current SSID profiles)
   - PUT `/api/v1/devices/{device_id}/wifi-config` (update WiFi profiles)
   - Payload: `{ssid_profiles: [{ssid: string, password: string, priority: int}], update_via_ota: boolean}`
   - Response: `{status: "queued_for_ota"|"applied", affected_devices: int}`

5. **BLE Proxy API** (`ble-proxy.openapi.yaml`) - NEW
   - POST `/api/v1/ble-proxy/measurements` (mobile app proxies ESP32 measurements)
   - Headers: `Mobile-User-ID`, `ESP32-Device-ID`, `Idempotency-Key`, `X-Checksum`
   - Payload: `{measurements: [{volume_liters, timestamp, ...}], relayed_at: timestamp}`
   - POST `/api/v1/ble-proxy/relay-commands` (backend sends commands via mobile)
   - Response: `{commands_queued: int, delivery_status: "pending"|"delivered"}`

6. **MQTT Events Schema** (`mqtt-events.schema.json`)
   - Topic: `home_assistant/fueling/device/{device_id}/measurement` (measurement published)
   - Topic: `home_assistant/fueling/device/{device_id}/relay/{action}` (relay state changed)
   - Topic: `home_assistant/fueling/device/{device_id}/connectivity` (wifi/ble status)
   - Payload: JSON with timestamp, volume, device metadata, channel (wifi|ble)

7. **History Query API** (`history.openapi.yaml`)
   - GET `/api/v1/users/{user_id}/dispensing-history` (user views their history)
   - Query params: `?start_date=`, `?end_date=`, `?limit=`, `?offset=`

8. **Admin Dashboard API** (`admin.openapi.yaml`)
   - GET `/api/v1/admin/dispensing-summary` (aggregated statistics)
   - GET `/api/v1/admin/devices` (all device status including connectivity: wifi/ble/offline)

### 1.3 Local Development Setup

**Deliverable**: `quickstart.md` with step-by-step local dev environment

Quickstart will include:
- Prerequisites: Docker, VSCode extensions, Java 25, Node.js LTS, PlatformIO CLI, ESP32 simulator
- Services: PostgreSQL container, **Keycloak container** (with pre-configured realm, clients, and test users), MQTT broker (Mosquitto), Bluetooth simulator for testing
- Keycloak setup: Dev realm with olimeeter client, test users (admin, supervisor, driver) with roles, redirect URIs for frontend/mobile
- Database initialization: Flyway migrations
- Frontend dev server: Vite with hot reload
- Backend dev server: Gradle bootRun (with BLE proxy endpoints)
- ESP32 emulation: PlatformIO simulator or physical ESP32 dev board via USB
- WiFi configuration setup: Mock WiFi profiles in NVRAM simulator
- BLE testing:
  - ESP32 BLE peripheral simulator (advertising measurement service)
  - React Native BLE client test harness (connecting as central)
  - BLE data exchange simulation (measurement → mobile → backend)
  - Mobile WiFi failover testing (WiFi on/off toggles)
- MQTT subscriber for testing: mosquitto_sub CLI examples for connectivity topics

### 1.4 Agent Context Update

**Deliverable**: Updated `claude-agent-context.md` for future development

Run after design complete:
```bash
.specify/scripts/bash/update-agent-context.sh claude
```

This script will add:
- Technology stack summary (ESP32/PlatformIO with BLE, Spring Boot, React, React Native)
- API contract locations (including new WiFi config & BLE proxy endpoints)
- Database schema reference (including WiFi Configuration & BLE Session entities)
- MQTT topic mapping (including connectivity topics for WiFi/BLE status)
- Architecture decisions rationale (multi-channel communication strategy)
- BLE/WiFi fallback strategy diagram (primary WiFi → fallback BLE bridge)

---

## Next Steps

1. **Complete Phase 0**: Run research agents for unknowns resolution → `research.md`
2. **Complete Phase 1**: Generate data-model.md, contracts/, quickstart.md
3. **Execute Phase 2**: Run `/speckit.tasks` to generate task list (`tasks.md`)
4. **Begin Implementation**: Start with Keycloak IAM setup, then backend auth integration, then ESP32 firmware

---

## Implementation Priority

Per user specification, execution order prioritizes OTA capability, multi-channel WiFi/BLE communication, and ESP32 robustness:

1. **Phase 2.0-0**: **Keycloak IAM Setup** (Docker container, realm configuration, client registration, test users with roles, realm export for reproducible dev setup)
2. **Phase 2.0-1**: **Backend Auth Integration** (OAuth2 resource server config, JWT validation with Keycloak issuer-uri, role extraction from `realm_access.roles`, device API key filter, user auto-provisioning service)
3. **Phase 2.0-2**: ESP32 Firmware Foundation (relay control, meter sensor, OTA)
4. **Phase 2.0-3**: ESP32 WiFi Management (provisioning, SSID profiles, OTA config updates)
5. **Phase 2.0-4**: ESP32 BLE Implementation (peripheral mode, GATT services for measurements)
6. **Phase 2.0-5**: ESP32 Communication Layers (REST API client + BLE + offline queueing)
7. **Phase 2.0-6**: ESP32 MQTT Integration (Home Assistant topics, connectivity status)
8. **Phase 2.1**: Mobile App BLE Service (React Native BLE client, WiFi/BLE fallback detection)
9. **Phase 2.1-2**: Backend BLE Proxy API (WiFi config endpoint, BLE measurement relay)
10. **Phase 2.2**: Backend REST API (dispensing requests, measurements, quota, device management)
11. **Phase 2.3**: Frontend Web UI (dispensing form, history display, Keycloak login redirect)
12. **Phase 2.4**: Admin Features (P2/P3 user stories, device connectivity dashboard)

**Critical Additions** (user requirements):
- **Keycloak** handles all user CRUD, password management, role assignment, and login flows — no custom auth UI needed
- Backend auto-provisions local User profile on first authenticated API call (from JWT sub, preferred_username, email)
- Roles read from JWT `realm_access.roles` per request — no role column in backend User table
- ESP32 devices authenticated via pre-shared API key (X-Device-Key header), independent of Keycloak
- WiFi configuration must be OTA-updateable with predefined SSID profiles
- Mobile device used for dispensing request acts as BLE bridge when WiFi unavailable
- Mobile app transmits ESP32 data to backend via REST, receives commands, relays back via BLE
- Structured JSON logging + Spring Boot Actuator for observability (no external stack in MVP)

This order ensures IAM infrastructure is established first, then hardware-backend multi-channel synchronization is robust before frontend complexity increases.
