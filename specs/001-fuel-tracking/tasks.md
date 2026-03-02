# Tasks: Fuel Dispensing Tracking

**Input**: Design documents from `/specs/001-fuel-tracking/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in spec — test tasks omitted. Add tests per story if needed.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **ESP32 Firmware**: `esp32-firmware/` (PlatformIO project)
- **Backend**: `backend/` (Spring Boot 4.0.1, Java 25, Gradle)
- **Frontend**: `frontend/` (React 19.2.4, TypeScript 5.9, Vite)
- **Mobile**: `mobile/` (React Native 0.76+)
- **Shared**: `shared/` (common types/constants)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, build tooling, and directory structure for all 4 platforms

- [x] T001 Create top-level project directory structure per plan.md (esp32-firmware/, backend/, frontend/, mobile/, shared/)
- [x] T002 [P] Initialize ESP32 PlatformIO project with Arduino-ESP32 framework in esp32-firmware/platformio.ini
- [x] T003 [P] Initialize Spring Boot 4.0.1 backend with Gradle 9.3.0 in backend/build.gradle.kts
- [x] T004 [P] Initialize React 19.2.4 + TypeScript 5.9 frontend with Vite in frontend/package.json
- [x] T005 [P] Initialize React Native 0.76+ mobile project in mobile/package.json
- [x] T006 [P] Create shared TypeScript types package in shared/types/api.ts and shared/types/models.ts
- [x] T007 [P] Create shared constants in shared/constants/mqtt-topics.ts

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Backend Foundation

- [x] T008 Configure PostgreSQL datasource and Flyway migrations framework in backend/src/main/resources/application.yaml
- [x] T009 Create Flyway migration V1__Create_core_schema.sql with Facility, User, MeasuringDevice tables in backend/src/main/resources/db/migration/
- [x] T010 Create Flyway migration V2__Create_dispensing_schema.sql with DispensingRequest, DispensingRecord (immutable), DeviceAuditTrail tables in backend/src/main/resources/db/migration/
- [x] T011 Create Flyway migration V3__Create_quota_and_config_schema.sql with QuotaLimitRule, WiFiConfiguration, BLESessionLog, MobileProxyPermission tables in backend/src/main/resources/db/migration/
- [x] T012 [P] Implement Spring Security config with JWT authentication in backend/src/main/java/com/olimeeter/fuel/config/SecurityConfig.java
- [x] T013 [P] Implement WebConfig (CORS, virtual threads) in backend/src/main/java/com/olimeeter/fuel/config/WebConfig.java
- [x] T014 [P] Create ChecksumUtil (SHA-256 validation) in backend/src/main/java/com/olimeeter/fuel/util/ChecksumUtil.java
- [x] T015 [P] Create IdempotencyUtil (UUID deduplication) in backend/src/main/java/com/olimeeter/fuel/util/IdempotencyUtil.java
- [x] T016 [P] Create base JPA entities: Facility in backend/src/main/java/com/olimeeter/fuel/models/Facility.java
- [x] T017 [P] Create base JPA entity: User in backend/src/main/java/com/olimeeter/fuel/models/User.java
- [x] T018 [P] Create base JPA entity: MeasuringDevice in backend/src/main/java/com/olimeeter/fuel/models/MeasuringDevice.java
- [x] T019 [P] Create base JPA entity: QuotaLimitRule in backend/src/main/java/com/olimeeter/fuel/models/QuotaLimitRule.java
- [x] T020 Create FuelTrackingApplication main class in backend/src/main/java/com/olimeeter/fuel/FuelTrackingApplication.java

### ESP32 Foundation

- [x] T021 [P] Create config.h with WiFi, backend URL, device ID, and BLE settings in esp32-firmware/src/config.h
- [x] T022 [P] Create main.cpp entry point with setup/loop skeleton in esp32-firmware/src/main.cpp

### Frontend Foundation

- [x] T023 [P] Configure Vite build with Ant Design 6.2.0 and React Router in frontend/vite.config.ts
- [x] T024 [P] Create App.tsx with routing skeleton in frontend/src/App.tsx
- [x] T025 [P] Create REST API client service with SWR hooks in frontend/src/services/api.ts
- [x] T026 [P] Create TypeScript type definitions matching backend models in frontend/src/types/models.ts and frontend/src/types/api.ts

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Authorized User Requests Fuel Dispensing (Priority: P1) MVP

**Goal**: User submits dispensing request with destination, backend validates quota and returns approved/rejected with max_liters remaining balance

**Independent Test**: Submit dispensing request → receive approval/rejection with correct max_liters based on quota rules

### Implementation for User Story 1

- [ ] T027 [P] [US1] Create DispensingRequest JPA entity in backend/src/main/java/com/olimeeter/fuel/models/DispensingRequest.java
- [ ] T028 [P] [US1] Create DispensingRequestRepository in backend/src/main/java/com/olimeeter/fuel/repository/DispensingRequestRepository.java
- [ ] T029 [P] [US1] Create QuotaRuleRepository with custom queries for finding applicable rules in backend/src/main/java/com/olimeeter/fuel/repository/QuotaRuleRepository.java
- [ ] T030 [US1] Implement QuotaService with remaining balance calculation and most-restrictive-rule enforcement in backend/src/main/java/com/olimeeter/fuel/services/QuotaService.java
- [ ] T031 [US1] Implement DispensingService with request creation, quota check, approval/rejection logic in backend/src/main/java/com/olimeeter/fuel/services/DispensingService.java
- [ ] T032 [US1] Implement DispensingController (POST /api/v1/dispensing-requests, GET /api/v1/dispensing-requests) per contracts/dispensing-request.openapi.yaml in backend/src/main/java/com/olimeeter/fuel/api/DispensingController.java
- [ ] T033 [P] [US1] Create DispenseRequestForm component in frontend/src/components/DispenseRequestForm.tsx
- [ ] T034 [US1] Create DispensingPage with form integration in frontend/src/pages/DispensingPage.tsx
- [ ] T035 [US1] Wire DispensingPage route in frontend/src/App.tsx

**Checkpoint**: User Story 1 fully functional — user can request dispensing and receive approval/rejection

---

## Phase 4: User Story 2 — IoT Device Measures and Records Fuel Consumption (Priority: P1)

**Goal**: ESP32 controls relay, measures fuel volume, auto-cuts at max_liters, queues measurements offline

**Independent Test**: Approve dispensing request → ESP32 activates relay → measures fuel → cuts at limit → queues if offline

### Implementation for User Story 2

- [ ] T036 [P] [US2] Implement relay_control.cpp/.h (activate/deactivate relay, hard cutoff at max_liters) in esp32-firmware/src/relay_control.cpp and esp32-firmware/src/relay_control.h
- [ ] T037 [P] [US2] Implement meter_sensor.cpp/.h (pulse counting, volume calculation) in esp32-firmware/src/meter_sensor.cpp and esp32-firmware/src/meter_sensor.h
- [ ] T038 [P] [US2] Implement offline_queue.cpp/.h (SPIFFS/LittleFS queue, 7-day retention, CRC32) in esp32-firmware/src/offline_queue.cpp and esp32-firmware/src/offline_queue.h
- [ ] T039 [US2] Implement rest_api_client.cpp/.h (POST measurements, cert pinning, exponential backoff, idempotency keys) in esp32-firmware/src/rest_api_client.cpp and esp32-firmware/src/rest_api_client.h
- [ ] T040 [US2] Integrate relay + sensor + queue + REST client in esp32-firmware/src/main.cpp (dispensing lifecycle: activate → measure → cutoff → report)
- [ ] T041 [P] [US2] Create DeviceController with relay activate/deactivate endpoints (POST /api/v1/devices/{id}/relay/activate, /deactivate) in backend/src/main/java/com/olimeeter/fuel/api/DeviceController.java
- [ ] T042 [P] [US2] Create DeviceSyncService for relay command dispatch in backend/src/main/java/com/olimeeter/fuel/services/DeviceSyncService.java
- [ ] T043 [P] [US2] Create DeviceAuditTrail JPA entity in backend/src/main/java/com/olimeeter/fuel/models/DeviceAuditTrail.java
- [ ] T044 [US2] Update DispensingService to send relay activation signal upon approval in backend/src/main/java/com/olimeeter/fuel/services/DispensingService.java

**Checkpoint**: User Story 2 fully functional — ESP32 dispenses fuel under backend control

---

## Phase 5: User Story 3 — System Records Fuel Dispensing to Database (Priority: P1)

**Goal**: Backend receives ESP32 measurements, validates checksum/idempotency, persists immutable dispensing records atomically

**Independent Test**: Simulate ESP32 POST /measurements → verify record in DB with all metadata, reject duplicates and corrupted data

### Implementation for User Story 3

- [ ] T045 [P] [US3] Create DispensingRecord JPA entity (immutable, append-only) in backend/src/main/java/com/olimeeter/fuel/models/DispensingRecord.java
- [ ] T046 [P] [US3] Create DispensingRecordRepository with consumption queries in backend/src/main/java/com/olimeeter/fuel/repository/DispensingRecordRepository.java
- [ ] T047 [US3] Implement MeasurementService with checksum validation, idempotency check, atomic persist in backend/src/main/java/com/olimeeter/fuel/services/MeasurementService.java
- [ ] T048 [US3] Implement MeasurementController (POST /api/v1/measurements) per contracts/measurements.openapi.yaml in backend/src/main/java/com/olimeeter/fuel/api/MeasurementController.java
- [ ] T049 [US3] Create Flyway migration V4__Add_immutability_triggers.sql (prevent UPDATE/DELETE on dispensing_records) in backend/src/main/resources/db/migration/

**Checkpoint**: User Story 3 fully functional — measurements persist with full integrity guarantees

---

## Phase 6: User Story 4 — User Views Dispensing History (Priority: P2)

**Goal**: User views their dispensing history with date filtering and sorting via web UI

**Independent Test**: Query user's dispensing records → display filtered/sorted history with all metadata

### Implementation for User Story 4

- [ ] T050 [P] [US4] Implement HistoryController (GET /api/v1/users/{id}/dispensing-history with date range, sort, pagination) in backend/src/main/java/com/olimeeter/fuel/api/HistoryController.java
- [ ] T051 [P] [US4] Create HistoryTable component with date filter and sort in frontend/src/components/HistoryTable.tsx
- [ ] T052 [US4] Create HistoryPage with API integration in frontend/src/pages/HistoryPage.tsx
- [ ] T053 [US4] Wire HistoryPage route in frontend/src/App.tsx

**Checkpoint**: User Story 4 fully functional — users can view and filter their dispensing history

---

## Phase 7: User Story 5 — Administrator Views All Dispensing Activity (Priority: P3)

**Goal**: Admin views system-wide dispensing statistics, filter by device/user/time

**Independent Test**: Admin queries aggregated dispensing data → sees all users' activity with correct aggregations

### Implementation for User Story 5

- [ ] T054 [P] [US5] Implement AdminController (GET /api/v1/admin/dispensing-summary, GET /api/v1/admin/devices) in backend/src/main/java/com/olimeeter/fuel/api/AdminController.java
- [ ] T055 [P] [US5] Create AdminDashboard component with aggregated statistics in frontend/src/components/AdminDashboard.tsx
- [ ] T056 [US5] Create AdminPage with dashboard integration in frontend/src/pages/AdminPage.tsx
- [ ] T057 [US5] Wire AdminPage route in frontend/src/App.tsx

**Checkpoint**: User Story 5 fully functional — admin has full system visibility

---

## Phase 8: ESP32 Advanced Communication (Cross-Cutting)

**Purpose**: WiFi management, BLE fallback, MQTT integration, OTA updates

- [ ] T058 [P] Implement WiFi manager with NVRAM SSID profiles and automatic fallback in esp32-firmware/src/wifi_manager.cpp and esp32-firmware/src/wifi_manager.h
- [ ] T059 [P] Implement BLE peripheral with NimBLE GATT services (measurement, relay command, status) in esp32-firmware/src/ble_service.cpp and esp32-firmware/src/ble_service.h
- [ ] T060 [P] Implement MQTT client for Home Assistant (measurement events, relay state, connectivity) in esp32-firmware/src/mqtt_client.cpp and esp32-firmware/src/mqtt_client.h
- [ ] T061 [P] Implement OTA updater with version check and rollback in esp32-firmware/src/ota_updater.cpp and esp32-firmware/src/ota_updater.h
- [ ] T062 Integrate WiFi manager + BLE fallback + MQTT + OTA into main loop in esp32-firmware/src/main.cpp

---

## Phase 9: Mobile App & BLE Proxy (Cross-Cutting)

**Purpose**: React Native mobile app with BLE bridge capability

- [ ] T063 [P] Create mobile App.tsx with React Navigation in mobile/src/App.tsx
- [ ] T064 [P] Create mobile REST API client service in mobile/src/services/api.ts
- [ ] T065 [P] Create BLE service with ESP32 scanning and connection in mobile/src/services/ble.ts
- [ ] T066 [P] Create offline queue service (AsyncStorage, 24h retention) in mobile/src/services/offline.ts
- [ ] T067 [P] Create DispensingScreen with BLE fallback UI in mobile/src/screens/DispensingScreen.tsx
- [ ] T068 [P] Create HistoryScreen in mobile/src/screens/HistoryScreen.tsx
- [ ] T069 Implement BLE proxy controller on backend (POST /api/v1/ble-proxy/measurements) in backend/src/main/java/com/olimeeter/fuel/api/BLEProxyController.java
- [ ] T070 Create MobileProxyPermission JPA entity in backend/src/main/java/com/olimeeter/fuel/models/MobileProxyPermission.java
- [ ] T071 Configure MQTT publisher in backend for Home Assistant events in backend/src/main/java/com/olimeeter/fuel/config/MqttConfig.java

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T072 [P] Create QuotaDisplay component showing remaining balance in frontend/src/components/QuotaDisplay.tsx
- [ ] T073 [P] Create global Ant Design theming in frontend/src/styles/global.less
- [ ] T074 [P] Add WiFiConfiguration and BLESessionLog JPA entities in backend/src/main/java/com/olimeeter/fuel/models/
- [ ] T075 Security hardening: input validation, rate limiting, CORS tightening across backend controllers
- [ ] T076 Error handling standardization across all backend API endpoints
- [ ] T077 Configure Docker Compose for local development (PostgreSQL, Mosquitto MQTT broker) in docker-compose.yaml

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — MVP entry point
- **US2 (Phase 4)**: Depends on Phase 2 + US1 approval flow
- **US3 (Phase 5)**: Depends on Phase 2 — can parallel with US1/US2
- **US4 (Phase 6)**: Depends on Phase 2 + US3 (needs records to display)
- **US5 (Phase 7)**: Depends on Phase 2 + US3 (needs records to aggregate)
- **ESP32 Advanced (Phase 8)**: Depends on US2 base firmware
- **Mobile (Phase 9)**: Depends on Phase 2 backend APIs
- **Polish (Phase 10)**: Depends on all desired stories complete

### User Story Dependencies

- **US1 (P1)**: After Phase 2 — no other story dependencies
- **US2 (P1)**: After Phase 2 — integrates with US1 approval flow but independently testable
- **US3 (P1)**: After Phase 2 — no other story dependencies
- **US4 (P2)**: After US3 (needs dispensing records to display)
- **US5 (P3)**: After US3 (needs dispensing records to aggregate)

### Within Each User Story

- Models before services
- Services before controllers/endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- T002-T007: All setup tasks run in parallel
- T012-T022: All foundational tasks marked [P] run in parallel (after migrations)
- T023-T026: All frontend foundation tasks in parallel
- T027-T029: US1 models/repos in parallel
- T036-T038: US2 ESP32 modules in parallel
- T045-T046: US3 model/repo in parallel
- T050-T051: US4 backend + frontend in parallel
- T054-T055: US5 backend + frontend in parallel
- T058-T061: All ESP32 advanced modules in parallel

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 + 3)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: US1 — Dispensing Request
4. Complete Phase 4: US2 — IoT Measurement
5. Complete Phase 5: US3 — Database Persistence
6. **STOP and VALIDATE**: Test core dispensing flow end-to-end
7. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test independently → MVP dispensing request
3. Add US2 → Test independently → Hardware control
4. Add US3 → Test independently → Full persistence
5. Add US4 → Test independently → User history
6. Add US5 → Test independently → Admin visibility
7. Add ESP32 Advanced → WiFi/BLE/MQTT/OTA
8. Add Mobile → Cross-platform with BLE proxy

---

## Summary

- **Total tasks**: 77
- **Phase 1 (Setup)**: 7 tasks
- **Phase 2 (Foundation)**: 19 tasks
- **US1 (P1 — Dispensing Request)**: 9 tasks
- **US2 (P1 — IoT Measurement)**: 9 tasks
- **US3 (P1 — DB Persistence)**: 5 tasks
- **US4 (P2 — User History)**: 4 tasks
- **US5 (P3 — Admin Dashboard)**: 4 tasks
- **ESP32 Advanced**: 5 tasks
- **Mobile & BLE Proxy**: 9 tasks
- **Polish**: 6 tasks
- **Parallel opportunities**: 40+ tasks marked [P]
- **Suggested MVP scope**: US1 + US2 + US3 (Phases 1-5, 49 tasks)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
