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

## Phase 3: Keycloak IAM & Auth Integration

**Purpose**: Set up Keycloak as external IAM, refactor backend to OAuth2 resource server, add user auto-provisioning, add device API key filter. This phase replaces custom JWT auth (T012) with Keycloak-based authentication.

**CRITICAL**: Must complete before user story implementation — auth model changes affect all endpoints.

### Keycloak Infrastructure

- [x] T027 Create docker-compose.yaml with Keycloak 26+ and PostgreSQL containers for local dev in backend/docker-compose.yaml
- [x] T028 Configure Keycloak dev realm "olimeeter" with client "olimeeter-app" (public client, authorization code + PKCE), roles (user, supervisor, admin), and test users (admin, alice_supervisor, bob_driver, carol_operator, dave_north) via realm export JSON in backend/keycloak/olimeeter-realm.json
- [x] T029 Update backend/docker-compose.yaml to import realm JSON on Keycloak startup via KEYCLOAK_IMPORT environment variable

### Backend Auth Refactoring

- [x] T030 Add spring-boot-starter-oauth2-resource-server dependency to backend/build.gradle.kts and remove jjwt dependencies (io.jsonwebtoken)
- [x] T031 Configure OAuth2 resource server with Keycloak issuer-uri in backend/src/main/resources/application.yaml (spring.security.oauth2.resourceserver.jwt.issuer-uri)
- [x] T032 Refactor SecurityConfig to use OAuth2 resource server JWT validation with Keycloak role extraction from realm_access.roles claim in backend/src/main/java/com/olimeeter/fuel/config/SecurityConfig.java
- [x] T033 [P] Implement DeviceApiKeyFilter as a OncePerRequestFilter for ESP32 device authentication via X-Device-Key header on /api/v1/measurements and /api/v1/devices/** endpoints in backend/src/main/java/com/olimeeter/fuel/config/DeviceApiKeyFilter.java
- [x] T034 Register DeviceApiKeyFilter in SecurityConfig filter chain (before OAuth2 filter for device endpoints) in backend/src/main/java/com/olimeeter/fuel/config/SecurityConfig.java

### User Entity Refactoring (Keycloak Integration)

- [x] T035 Refactor User JPA entity: change id to keycloak_sub (String PK from JWT sub claim), remove password_hash and role fields, add keycloak_username and keycloak_email fields in backend/src/main/java/com/olimeeter/fuel/models/User.java
- [x] T036 Create Flyway migration V4__Refactor_user_for_keycloak.sql to alter users table: drop password_hash and role columns, change id to VARCHAR keycloak_sub PK, add keycloak_username and keycloak_email in backend/src/main/resources/db/migration/
- [x] T037 Create UserRepository with findByKeycloakSub query in backend/src/main/java/com/olimeeter/fuel/repository/UserRepository.java
- [x] T038 Implement UserProvisioningService that auto-creates local User profile from JWT claims (sub, preferred_username, email) on first authenticated API call in backend/src/main/java/com/olimeeter/fuel/services/UserProvisioningService.java
- [x] T039 Create UserProvisioningFilter (OncePerRequestFilter) that calls UserProvisioningService for every authenticated Keycloak request, registers in SecurityConfig filter chain in backend/src/main/java/com/olimeeter/fuel/config/UserProvisioningFilter.java

### Dev Profile Updates

- [x] T040 Update application-dev.yaml and data-dev.sql to align with Keycloak user model: remove password_hash/role from mock users, use keycloak_sub as ID, add keycloak_username/keycloak_email in backend/src/main/resources/

### Frontend Auth (Keycloak OIDC)

- [x] T041 [P] Add keycloak-js dependency to frontend/package.json and create Keycloak auth service with init/login/logout/token refresh in frontend/src/services/auth.ts
- [x] T042 [P] Update frontend/src/services/api.ts to use Keycloak token from auth service instead of localStorage JWT
- [x] T043 Wrap frontend/src/App.tsx with Keycloak auth provider, redirect unauthenticated users to Keycloak login

### Observability

- [x] T044 [P] Configure structured JSON logging (logback-spring.xml with JSON encoder) in backend/src/main/resources/logback-spring.xml
- [x] T045 [P] Enable Spring Boot Actuator with health and metrics endpoints in backend/src/main/resources/application.yaml

**Checkpoint**: Keycloak IAM fully integrated — all API endpoints secured via Keycloak JWT or device API key, users auto-provisioned on first login

---

## Phase 4: User Story 1 — Authorized User Requests Fuel Dispensing (Priority: P1) MVP

**Goal**: User submits dispensing request with destination, backend validates quota and returns approved/rejected with max_liters remaining balance

**Independent Test**: Submit dispensing request → receive approval/rejection with correct max_liters based on quota rules

### Implementation for User Story 1

- [ ] T046 [P] [US1] Create DispensingRequest JPA entity in backend/src/main/java/com/olimeeter/fuel/models/DispensingRequest.java
- [ ] T047 [P] [US1] Create DispensingRequestRepository in backend/src/main/java/com/olimeeter/fuel/repository/DispensingRequestRepository.java
- [ ] T048 [P] [US1] Create QuotaRuleRepository with custom queries for finding applicable rules by user/role/facility in backend/src/main/java/com/olimeeter/fuel/repository/QuotaRuleRepository.java
- [ ] T049 [US1] Implement QuotaService with remaining balance calculation and most-restrictive-rule enforcement in backend/src/main/java/com/olimeeter/fuel/services/QuotaService.java
- [ ] T050 [US1] Implement DispensingService with request creation, quota check, approval/rejection logic, facility-assignment check (403 if no facility) in backend/src/main/java/com/olimeeter/fuel/services/DispensingService.java
- [ ] T051 [US1] Implement DispensingController (POST /api/v1/dispensing-requests, GET /api/v1/dispensing-requests) per contracts/dispensing-request.openapi.yaml in backend/src/main/java/com/olimeeter/fuel/api/DispensingController.java
- [ ] T052 [P] [US1] Create DispenseRequestForm component in frontend/src/components/DispenseRequestForm.tsx
- [ ] T053 [US1] Create DispensingPage with form integration in frontend/src/pages/DispensingPage.tsx
- [ ] T054 [US1] Wire DispensingPage route in frontend/src/App.tsx

**Checkpoint**: User Story 1 fully functional — user can request dispensing and receive approval/rejection

---

## Phase 5: User Story 2 — IoT Device Measures and Records Fuel Consumption (Priority: P1)

**Goal**: ESP32 controls relay, measures fuel volume, auto-cuts at max_liters, queues measurements offline

**Independent Test**: Approve dispensing request → ESP32 activates relay → measures fuel → cuts at limit → queues if offline

### Implementation for User Story 2

- [ ] T055 [P] [US2] Implement relay_control.cpp/.h (activate/deactivate relay, hard cutoff at max_liters) in esp32-firmware/src/relay_control.cpp and esp32-firmware/src/relay_control.h
- [ ] T056 [P] [US2] Implement meter_sensor.cpp/.h (pulse counting, volume calculation) in esp32-firmware/src/meter_sensor.cpp and esp32-firmware/src/meter_sensor.h
- [ ] T057 [P] [US2] Implement offline_queue.cpp/.h (SPIFFS/LittleFS queue, 7-day retention, CRC32) in esp32-firmware/src/offline_queue.cpp and esp32-firmware/src/offline_queue.h
- [ ] T058 [US2] Implement rest_api_client.cpp/.h (POST measurements with X-Device-Key header, cert pinning, exponential backoff, idempotency keys) in esp32-firmware/src/rest_api_client.cpp and esp32-firmware/src/rest_api_client.h
- [ ] T059 [US2] Integrate relay + sensor + queue + REST client in esp32-firmware/src/main.cpp (dispensing lifecycle: activate → measure → cutoff → report)
- [ ] T060 [P] [US2] Create DeviceController with relay activate/deactivate endpoints (POST /api/v1/devices/{id}/relay/activate, /deactivate) in backend/src/main/java/com/olimeeter/fuel/api/DeviceController.java
- [ ] T061 [P] [US2] Create DeviceSyncService for relay command dispatch in backend/src/main/java/com/olimeeter/fuel/services/DeviceSyncService.java
- [ ] T062 [P] [US2] Create DeviceAuditTrail JPA entity in backend/src/main/java/com/olimeeter/fuel/models/DeviceAuditTrail.java
- [ ] T063 [US2] Update DispensingService to send relay activation signal upon approval in backend/src/main/java/com/olimeeter/fuel/services/DispensingService.java

**Checkpoint**: User Story 2 fully functional — ESP32 dispenses fuel under backend control

---

## Phase 6: User Story 3 — System Records Fuel Dispensing to Database (Priority: P1)

**Goal**: Backend receives ESP32 measurements, validates checksum/idempotency, persists immutable dispensing records atomically

**Independent Test**: Simulate ESP32 POST /measurements → verify record in DB with all metadata, reject duplicates and corrupted data

### Implementation for User Story 3

- [ ] T064 [P] [US3] Create DispensingRecord JPA entity (immutable, append-only) in backend/src/main/java/com/olimeeter/fuel/models/DispensingRecord.java
- [ ] T065 [P] [US3] Create DispensingRecordRepository with consumption queries (daily/monthly totals by user) in backend/src/main/java/com/olimeeter/fuel/repository/DispensingRecordRepository.java
- [ ] T066 [US3] Implement MeasurementService with checksum validation, idempotency check, atomic persist, device auth verification in backend/src/main/java/com/olimeeter/fuel/services/MeasurementService.java
- [ ] T067 [US3] Implement MeasurementController (POST /api/v1/measurements) per contracts/measurements.openapi.yaml in backend/src/main/java/com/olimeeter/fuel/api/MeasurementController.java
- [ ] T068 [US3] Create Flyway migration V5__Add_immutability_triggers.sql (prevent UPDATE/DELETE on dispensing_records and device_audit_trail) in backend/src/main/resources/db/migration/

**Checkpoint**: User Story 3 fully functional — measurements persist with full integrity guarantees

---

## Phase 7: User Story 4 — User Views Dispensing History (Priority: P2)

**Goal**: User views their dispensing history with date filtering and sorting via web UI

**Independent Test**: Query user's dispensing records → display filtered/sorted history with all metadata

### Implementation for User Story 4

- [ ] T069 [P] [US4] Implement HistoryController (GET /api/v1/users/{id}/dispensing-history with date range, sort, pagination) in backend/src/main/java/com/olimeeter/fuel/api/HistoryController.java
- [ ] T070 [P] [US4] Create HistoryTable component with date filter and sort in frontend/src/components/HistoryTable.tsx
- [ ] T071 [US4] Create HistoryPage with API integration in frontend/src/pages/HistoryPage.tsx
- [ ] T072 [US4] Wire HistoryPage route in frontend/src/App.tsx

**Checkpoint**: User Story 4 fully functional — users can view and filter their dispensing history

---

## Phase 8: User Story 5 — Administrator Views All Dispensing Activity (Priority: P3)

**Goal**: Admin views system-wide dispensing statistics, filter by device/user/time

**Independent Test**: Admin queries aggregated dispensing data → sees all users' activity with correct aggregations

### Implementation for User Story 5

- [ ] T073 [P] [US5] Implement AdminController (GET /api/v1/admin/dispensing-summary, GET /api/v1/admin/devices) with admin role check from JWT realm_access.roles in backend/src/main/java/com/olimeeter/fuel/api/AdminController.java
- [ ] T074 [P] [US5] Create AdminDashboard component with aggregated statistics in frontend/src/components/AdminDashboard.tsx
- [ ] T075 [US5] Create AdminPage with dashboard integration in frontend/src/pages/AdminPage.tsx
- [ ] T076 [US5] Wire AdminPage route with admin role guard in frontend/src/App.tsx

**Checkpoint**: User Story 5 fully functional — admin has full system visibility

---

## Phase 9: ESP32 Advanced Communication (Cross-Cutting)

**Purpose**: WiFi management, BLE fallback, MQTT integration, OTA updates

- [ ] T077 [P] Implement WiFi manager with NVRAM SSID profiles and automatic fallback in esp32-firmware/src/wifi_manager.cpp and esp32-firmware/src/wifi_manager.h
- [ ] T078 [P] Implement BLE peripheral with NimBLE GATT services (measurement, relay command, status, proximity) in esp32-firmware/src/ble_service.cpp and esp32-firmware/src/ble_service.h
- [ ] T079 [P] Implement MQTT client for Home Assistant (measurement events, relay state, connectivity) in esp32-firmware/src/mqtt_client.cpp and esp32-firmware/src/mqtt_client.h
- [ ] T080 [P] Implement OTA updater with version check and rollback in esp32-firmware/src/ota_updater.cpp and esp32-firmware/src/ota_updater.h
- [ ] T081 Integrate WiFi manager + BLE fallback + MQTT + OTA into main loop in esp32-firmware/src/main.cpp

---

## Phase 10: Mobile App & BLE Proxy (Cross-Cutting)

**Purpose**: React Native mobile app with BLE bridge capability and Keycloak OIDC auth

- [ ] T082 [P] Create mobile App.tsx with React Navigation in mobile/src/App.tsx
- [ ] T083 [P] Create mobile Keycloak auth service using react-native-app-auth (PKCE flow) in mobile/src/services/auth.ts
- [ ] T084 [P] Create mobile REST API client service with Keycloak token injection in mobile/src/services/api.ts
- [ ] T085 [P] Create BLE service with ESP32 scanning and connection in mobile/src/services/ble.ts
- [ ] T086 [P] Create offline queue service (AsyncStorage, 24h retention) in mobile/src/services/offline.ts
- [ ] T087 [P] Create DispensingScreen with BLE fallback UI in mobile/src/screens/DispensingScreen.tsx
- [ ] T088 [P] Create HistoryScreen in mobile/src/screens/HistoryScreen.tsx
- [ ] T089 Implement BLE proxy controller on backend (POST /api/v1/ble-proxy/measurements) with mobile user JWT auth in backend/src/main/java/com/olimeeter/fuel/api/BLEProxyController.java
- [ ] T090 Create MobileProxyPermission JPA entity in backend/src/main/java/com/olimeeter/fuel/models/MobileProxyPermission.java
- [ ] T091 Configure MQTT publisher in backend for Home Assistant events in backend/src/main/java/com/olimeeter/fuel/config/MqttConfig.java

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T092 [P] Create QuotaDisplay component showing remaining balance in frontend/src/components/QuotaDisplay.tsx
- [ ] T093 [P] Create global Ant Design theming in frontend/src/styles/global.less
- [ ] T094 [P] Add WiFiConfiguration and BLESessionLog JPA entities in backend/src/main/java/com/olimeeter/fuel/models/
- [ ] T095 Security hardening: input validation, rate limiting, CORS tightening across backend controllers
- [ ] T096 Error handling standardization across all backend API endpoints (consistent error response format)
- [ ] T097 Update shared/types/models.ts and shared/types/api.ts to reflect Keycloak User model changes (keycloak_sub, no password/role)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately [COMPLETE]
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories [COMPLETE]
- **Keycloak IAM (Phase 3)**: Depends on Phase 2 — BLOCKS all user stories (refactors auth model) [COMPLETE]
- **US1 (Phase 4)**: Depends on Phase 3 — MVP entry point
- **US2 (Phase 5)**: Depends on Phase 3 + US1 approval flow
- **US3 (Phase 6)**: Depends on Phase 3 — can parallel with US1/US2
- **US4 (Phase 7)**: Depends on Phase 3 + US3 (needs records to display)
- **US5 (Phase 8)**: Depends on Phase 3 + US3 (needs records to aggregate)
- **ESP32 Advanced (Phase 9)**: Depends on US2 base firmware
- **Mobile (Phase 10)**: Depends on Phase 3 backend APIs + Keycloak auth
- **Polish (Phase 11)**: Depends on all desired stories complete

### User Story Dependencies

- **US1 (P1)**: After Phase 3 — no other story dependencies
- **US2 (P1)**: After Phase 3 — integrates with US1 approval flow but independently testable
- **US3 (P1)**: After Phase 3 — no other story dependencies
- **US4 (P2)**: After US3 (needs dispensing records to display)
- **US5 (P3)**: After US3 (needs dispensing records to aggregate)

### Within Each User Story

- Models before services
- Services before controllers/endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- T002-T007: All setup tasks run in parallel [COMPLETE]
- T012-T022: All foundational tasks marked [P] run in parallel [COMPLETE]
- T023-T026: All frontend foundation tasks in parallel [COMPLETE]
- T027-T029: Keycloak infrastructure tasks sequential
- T030-T034: Backend auth refactoring (T033 parallel with T030-T032)
- T035-T039: User entity refactoring sequential
- T041-T042: Frontend auth tasks in parallel
- T044-T045: Observability tasks in parallel
- T046-T048: US1 models/repos in parallel
- T055-T057: US2 ESP32 modules in parallel
- T064-T065: US3 model/repo in parallel
- T069-T070: US4 backend + frontend in parallel
- T073-T074: US5 backend + frontend in parallel
- T077-T080: All ESP32 advanced modules in parallel
- T082-T088: Mobile app screens and services in parallel

---

## Implementation Strategy

### MVP First (Keycloak + User Stories 1 + 2 + 3)

1. Complete Phase 1: Setup [DONE]
2. Complete Phase 2: Foundational [DONE]
3. Complete Phase 3: Keycloak IAM & Auth Integration (CRITICAL — changes auth model)
4. Complete Phase 4: US1 — Dispensing Request
5. Complete Phase 5: US2 — IoT Measurement
6. Complete Phase 6: US3 — Database Persistence
7. **STOP and VALIDATE**: Test core dispensing flow end-to-end
8. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready [DONE]
2. Keycloak IAM → Auth model ready with user provisioning [DONE]
3. Add US1 → Test independently → MVP dispensing request
4. Add US2 → Test independently → Hardware control
5. Add US3 → Test independently → Full persistence
6. Add US4 → Test independently → User history
7. Add US5 → Test independently → Admin visibility
8. Add ESP32 Advanced → WiFi/BLE/MQTT/OTA
9. Add Mobile → Cross-platform with BLE proxy + Keycloak OIDC

### Parallel Team Strategy

With multiple developers:

1. Team completes Keycloak IAM together (Phase 3)
2. Once Phase 3 is done:
   - Developer A: User Story 1 (backend + frontend)
   - Developer B: User Story 2 (ESP32 firmware)
   - Developer C: User Story 3 (backend persistence)
3. Stories complete and integrate independently

---

## Summary

- **Total tasks**: 97
- **Phase 1 (Setup)**: 7 tasks [COMPLETE]
- **Phase 2 (Foundation)**: 19 tasks [COMPLETE]
- **Phase 3 (Keycloak IAM)**: 19 tasks [COMPLETE]
- **US1 (P1 — Dispensing Request)**: 9 tasks
- **US2 (P1 — IoT Measurement)**: 9 tasks
- **US3 (P1 — DB Persistence)**: 5 tasks
- **US4 (P2 — User History)**: 4 tasks
- **US5 (P3 — Admin Dashboard)**: 4 tasks
- **ESP32 Advanced**: 5 tasks
- **Mobile & BLE Proxy**: 10 tasks
- **Polish**: 6 tasks
- **Parallel opportunities**: 45+ tasks marked [P]
- **Suggested MVP scope**: Phase 3 + US1 + US2 + US3 (Phases 3-6, 42 tasks)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story independently completable and testable
- Phase 3 (Keycloak) replaces custom JWT auth from Phase 2 T012 with OAuth2 resource server
- User entity refactored: keycloak_sub as PK, no password_hash or role column
- Dual auth: Keycloak JWT for humans, X-Device-Key for ESP32 devices
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
