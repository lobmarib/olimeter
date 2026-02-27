# Implementation Plan: Fuel Dispensing Tracking

**Branch**: `001-fuel-tracking` | **Date**: 2026-02-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-fuel-tracking/spec.md`

## Summary

Build a comprehensive fuel/oil dispensing tracking system with IoT integration. ESP32 devices measure fuel volume through relay-controlled pumps, transmit data via REST API to backend, and support MQTT for Home Assistant compatibility. System enforces flexible quota management (user/role/daily/monthly), provides immutable audit trails, and ensures zero data loss through offline queueing and checksums. Architecture: REST API backend (Spring Boot 4.0.1/Java 25) + Web UI (React 19.2.4) + Mobile app (React Native) + IoT firmware (ESP32/PlatformIO with OTA updates).

## Technical Context

**ESP32 Firmware**:
- Language/Version: C/C++ with Arduino framework via PlatformIO framework
- Primary Dependencies: PlatformIO, Arduino-esp32, ArduinoJson, WiFiClientSecure (REST), PubSubClient (MQTT)
- Communication: REST API (primary backend sync) + MQTT (Home Assistant compatibility)
- Firmware Updates: Over-The-Air (OTA) with versioning
- Storage: Local SPIFFS/LittleFS for offline queueing (7-day retention)
- Testing: Unit tests via PlatformIO, hardware simulation

**Backend**:
- Language/Version: Java 25 with Spring Boot 4.0.1
- Primary Dependencies: Spring Web, Spring Data JPA, Spring Security, Gradle 9.3.0
- Storage: PostgreSQL 15+
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
- Primary Dependencies: React Native 0.76+, React Navigation, native modules for auth
- Testing: Jest, detox for E2E
- Target Platform: iOS 13+, Android 8+
- Performance Goals: <3 second app startup, offline capability
- Scale: 500+ users

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
- Deferred: override workflows, admin dashboards (P2/P3 features)

**Principle VI - Hardware-Backend Synchronization**: ✅ PASS (CRITICAL)
- ESP32 sends measurements via REST API (primary)
- Backend can send activation/revoke commands to ESP32
- Offline fallback: ESP32 caches latest approval for relay activation
- MQTT topic for Home Assistant: `home_assistant/fueling/device/{device_id}/*`

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
├── src/main/java/
│   └── com/olimeeter/fuel/
│       ├── FuelTrackingApplication.java
│       ├── models/
│       │   ├── DispensingRequest.java
│       │   ├── DispensingRecord.java
│       │   ├── MeasuringDevice.java
│       │   └── QuotaLimitRule.java
│       ├── services/
│       │   ├── DispensingService.java
│       │   ├── QuotaService.java
│       │   ├── MeasurementService.java
│       │   └── DeviceSyncService.java
│       ├── api/
│       │   ├── DispensingController.java
│       │   ├── MeasurementController.java
│       │   ├── DeviceController.java
│       │   └── HistoryController.java
│       ├── repository/
│       │   ├── DispensingRequestRepository.java
│       │   ├── DispensingRecordRepository.java
│       │   └── QuotaRuleRepository.java
│       ├── config/
│       │   ├── SecurityConfig.java
│       │   ├── WebConfig.java
│       │   └── MqttConfig.java (MQTT publisher)
│       └── util/
│           ├── ChecksumUtil.java (SHA-256)
│           └── IdempotencyUtil.java
├── src/main/resources/
│   ├── application.yaml (config for Spring Boot)
│   ├── db/migration/ (Flyway migrations)
│   │   ├── V1__Create_dispensing_schema.sql
│   │   └── V2__Add_quota_rules.sql
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
│   │   └── auth.ts
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
│   │   ├── auth.ts (native secure storage)
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

2. **REST API ↔ ESP32 Integration**
   - SSL/TLS certificate pinning on embedded devices
   - Exponential backoff retry strategies
   - Idempotency key implementation in embedded context
   - Payload size optimization (bandwidth constraints)

3. **MQTT for Home Assistant**
   - Home Assistant MQTT discovery protocol
   - Topic naming conventions for fuel tracking domain
   - QoS levels (0, 1, 2) and persistence trade-offs
   - Shared message structure between REST and MQTT events

4. **Spring Boot 4.0.1 with Java 25**
   - Virtual threads for concurrent connections (Project Loom)
   - Spring Security 6.x authentication/authorization patterns
   - Spring Data JPA best practices for large datasets

5. **PostgreSQL 15+ Data Integrity**
   - Immutable ledger table design patterns
   - JSONB support for semi-structured quota rules
   - Transaction isolation levels for concurrent dispensing

6. **React + Ant Design Offline Architecture**
   - IndexedDB schema design for dispensing history
   - Sync patterns with backend REST API
   - Conflict resolution strategies

7. **React Native + Home Assistant Integration**
   - MQTT client libraries for React Native
   - Secure token storage (native Keychain/Keystore)
   - Platform-specific background task handling

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
- **User** (authorization context, quota assignments)
- **Quota Limit Rule** (flexible quota configuration)
- **Device Audit Trail** (ESP32 activation/deactivation events)

### 1.2 API Contracts

**Deliverable**: `contracts/` directory with OpenAPI/JSON Schema

Priority contracts (in order of implementation):

1. **Dispensing Request API** (`dispensing-request.openapi.yaml`)
   - POST `/api/v1/dispensing-requests` (user requests fuel)
   - Response: `{status: "approved"|"rejected", max_liters: number, reason?: string}`

2. **Measurement API** (`dispensing-record.openapi.yaml`)
   - POST `/api/v1/measurements` (ESP32 uploads measurement)
   - Headers: `Device-ID`, `Idempotency-Key`, `X-Checksum` (SHA-256)
   - Payload: `{device_id, volume_liters, timestamp, dispensing_request_id}`

3. **Device Relay Control API** (`device-control.openapi.yaml`)
   - POST `/api/v1/devices/{device_id}/relay/activate` (backend sends activation signal)
   - POST `/api/v1/devices/{device_id}/relay/deactivate` (backend sends stop signal)
   - Response: `{status: "success"|"offline_queued", timestamp}`

4. **MQTT Events Schema** (`mqtt-events.schema.json`)
   - Topic: `home_assistant/fueling/device/{device_id}/measurement` (measurement published)
   - Topic: `home_assistant/fueling/device/{device_id}/relay/{action}` (relay state changed)
   - Payload: JSON with timestamp, volume, device metadata

5. **History Query API** (`history.openapi.yaml`)
   - GET `/api/v1/users/{user_id}/dispensing-history` (user views their history)
   - Query params: `?start_date=`, `?end_date=`, `?limit=`, `?offset=`

6. **Admin Dashboard API** (`admin.openapi.yaml`)
   - GET `/api/v1/admin/dispensing-summary` (aggregated statistics)
   - GET `/api/v1/admin/devices` (all device status)

### 1.3 Local Development Setup

**Deliverable**: `quickstart.md` with step-by-step local dev environment

Quickstart will include:
- Prerequisites: Docker, VSCode extensions, Java 25, Node.js LTS, PlatformIO CLI
- Services: PostgreSQL container, MQTT broker (Mosquitto), optional reverse proxy (Nginx)
- Database initialization: Flyway migrations
- Frontend dev server: Vite with hot reload
- Backend dev server: Gradle bootRun
- ESP32 emulation: PlatformIO simulator (if available) or QEMU
- MQTT subscriber for testing: mosquitto_sub CLI examples

### 1.4 Agent Context Update

**Deliverable**: Updated `claude-agent-context.md` for future development

Run after design complete:
```bash
.specify/scripts/bash/update-agent-context.sh claude
```

This script will add:
- Technology stack summary (ESP32/PlatformIO, Spring Boot, React, React Native)
- API contract locations
- Database schema reference
- MQTT topic mapping
- Architecture decisions rationale

---

## Next Steps

1. **Complete Phase 0**: Run research agents for unknowns resolution → `research.md`
2. **Complete Phase 1**: Generate data-model.md, contracts/, quickstart.md
3. **Execute Phase 2**: Run `/speckit.tasks` to generate task list (`tasks.md`)
4. **Begin Implementation**: Start with Priority 1 (ESP32 firmware) per user requirements

---

## Implementation Priority

Per user specification, execution order prioritizes OTA capability and ESP32 robustness:

1. **Phase 2.0-1**: ESP32 Firmware Foundation (relay control, meter sensor, OTA)
2. **Phase 2.0-2**: ESP32 Communication Layers (REST API client + offline queueing)
3. **Phase 2.0-3**: ESP32 MQTT Integration (Home Assistant compatibility)
4. **Phase 2.1**: Backend REST API (dispensing requests, measurements, quota)
5. **Phase 2.2**: Frontend Web UI (dispensing form, history display)
6. **Phase 2.3**: Mobile App (React Native sync)
7. **Phase 2.4**: Admin Features (P2/P3 user stories)

This order ensures hardware-backend synchronization is robust before frontend complexity increases.
