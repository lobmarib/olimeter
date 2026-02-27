<!--
SYNC IMPACT REPORT
==================
Version: 1.0.0 → 1.1.0 → 1.1.1 → 1.2.0 → 1.3.0 (MINOR: Data Resilience & Corruption Protection)
Ratified: 2026-02-20
Last Amended: 2026-02-24

CHANGES SUMMARY:
- Type: Amendment - Data Integrity & Resilience Policy
- Added mandatory data corruption detection and loss prevention mechanisms
- Covers all communication channels: ESP32 ↔ Backend, Frontend ↔ Backend, Mobile ↔ Backend
- Enforces transactional consistency and offline-first patterns

PRINCIPLES (7 total - 1 NEW):
✅ I. API-First Design - Define contracts before implementation
✅ II. Separation of Concerns - hardware (ESP32), backend, web, mobile, database separated
✅ III. Database Schema Versioning - Track all schema changes in migrations
✅ IV. Testing Requirements - Backend: unit & integration; Web/Mobile: component tests; ESP32: device tests
✅ V. Minimal Complexity - No premature abstraction
✅ VI. Hardware-Backend Synchronization - Meter readings sync bidirectionally with guaranteed delivery
✅ VII. Data Resilience & Integrity - NEW (Zero data loss, corruption detection, offline resilience)

SECTIONS:
✅ Code Organization - `/backend` `/web` `/mobile` `/esp32` `/database`
✅ Development Workflow - API-first, contract-driven, deployment ordered
✅ Technology Stack - Backend, Frontend, Mobile, IoT/ESP32, Database
✅ Data Integrity & Resilience - NEW (Checksum validation, transaction guarantees, offline queuing)
✅ Governance - Amendment procedures with semantic versioning

INTEGRITY MECHANISMS:
- All transmissions: Checksum (SHA-256) or HMAC for corruption detection
- ESP32: Local queue for failed transmissions + exponential backoff (max 7 days retention)
- Backend: Idempotency keys to prevent duplicate processing
- Transactions: All meter reading writes atomic (database transaction guarantees)
- Offline resilience: Frontend/Mobile queue writes locally until backend available
- Data recovery: Full audit trail of all changes (immutable ledger per meter)

TEMPLATE SYNC STATUS:
✅ .specify/templates/plan-template.md - Extended (Resilience patterns in Technical Context)
✅ .specify/templates/spec-template.md - Aligned (FR requirements include offline-first and data validation)
✅ .specify/templates/tasks-template.md - Aligned (Task templates include resilience testing phases)

DEFERRED ITEMS: None

NEXT STEPS:
1. Run /speckit.plan for feature specs
2. Constitution Check validates Data Resilience + all 7 principles
3. Tasks include chaos testing: network failure, corruption injection, offline scenarios
-->

# OliMeeter Constitution

## Core Principles

### I. API-First Design
Backend API MUST define contracts before frontend/mobile implementation begins. All client-server communication through RESTful endpoints with documented request/response schemas. Breaking API changes require version bumping.

### II. Separation of Concerns
Code MUST be organized by domain: ESP32 firmware, backend services, web app, mobile app, and database migrations kept separate. Each tier has independent deployment cycle and can be tested in isolation. ESP32 and backend communicate exclusively through documented REST/MQTT APIs.

### III. Database Schema Versioning
All schema changes MUST be tracked in migrations. No direct database modifications outside version control. Migrations MUST be reversible when possible. Schema changes require corresponding backend and client coordination.

### IV. Testing Requirements
Backend: unit tests for business logic, integration tests for API endpoints. Web/Mobile: component tests for UI logic. All PRs require passing tests before merge.

### V. Minimal Complexity
Start with essential features only. No premature abstraction or over-architecting. Prefer simple solutions over framework magic.

### VI. Hardware-Backend Synchronization
Meter readings from ESP32 MUST be transmitted to backend with guaranteed delivery. Backend MUST validate and persist all readings. ESP32 MUST retry failed transmissions with exponential backoff. Clock synchronization between ESP32 and backend MUST be maintained for accurate timestamping. State conflicts MUST be resolved with backend as authoritative source.

### VII. Data Resilience & Integrity
Zero data loss is non-negotiable. All data transmissions MUST be protected against corruption and loss. All communication channels (ESP32→Backend, Frontend→Backend, Mobile→Backend) MUST implement: (1) Checksum or HMAC validation on all transmissions (SHA-256 minimum), (2) Idempotency keys to prevent duplicate processing, (3) Atomic database transactions for all writes, (4) Local offline queues with exponential backoff retry (max 7-day retention for ESP32), (5) Complete audit trail of all meter readings (immutable ledger). Network failures and power loss MUST NOT result in lost or corrupted data.

## Code Organization

Monorepo or multi-repo structure with clear boundaries:
- `/backend` - REST API, business logic, database connectivity
- `/web` - Web application frontend
- `/mobile` - Mobile application code
- `/esp32` - IoT firmware for meter device (Arduino/C++, PlatformIO project)
- `/database` - Schema migrations and initialization scripts

## Technology Stack

All layers MUST use the specified technology versions. Deviations require amendment.

### Backend Stack
- **Framework**: Spring Boot 4.0.1 (latest stable)
- **Language**: Java 25
- **Build Tool**: Gradle 9.3.0 with Kotlin DSL
- **Docker Integration**: Docker Java SDK (docker-java)
- **API Documentation**: SpringDoc OpenAPI (Swagger UI)
- **Testing**: JUnit 5, Mockito, Spring Test

### Frontend Stack (Web)
- **Framework**: React 19.2.4 with TypeScript 5.9
- **UI Library**: Ant Design 6.2.0 (latest stable)
- **State Management**: React Query for server state, Context API for UI state
- **HTTP Client**: Axios with TypeScript types
- **Build Tool**: Vite for development and production builds
- **Testing**: Vitest, React Testing Library

### Mobile Stack
- **Framework**: React Native (cross-platform iOS/Android)
- **Language**: TypeScript (same as web for consistency)
- **State Management**: React Query for server state, Context API for UI state
- **HTTP Client**: Axios with TypeScript types
- **Testing**: Jest, React Native Testing Library

### IoT/ESP32 Stack
- **Microcontroller**: ESP32 (WiFi + Bluetooth capable)
- **Language**: C++ with Arduino Core
- **IDE/Build**: PlatformIO toolchain (VSCode extension) or Arduino IDE
- **Connectivity**: WiFi for Backend communication
- **Protocol**: HTTPS/REST or MQTT for data transmission
- **Libraries**: Arduino HTTPClient, PubSubClient (for MQTT), ArduinoJSON
- **Testing**: Unit tests with PlatformIO testing framework, integration tests with backend

### Database Stack
- **Database**: PostgreSQL 15+ (open-source SQL database)
- **Query Language**: SQL with prepared statements (no SQL injection vulnerabilities)
- **Migrations**: Flyway or Liquibase for schema versioning from backend
- **ORM** (optional in backend): Spring Data JPA with Hibernate as persistence provider

### Technology Rationale
- **Java 25**: Latest stable release with modern language features and optimizations
- **Spring Boot**: Mature ecosystem, built-in conventions reduce boilerplate
- **PostgreSQL**: Reliable open-source RDBMS with strong JSONB support for flexible schemas
- **React + TypeScript**: Type safety reduces bugs, consistent web + mobile codebase
- **React Native**: Single codebase for iOS/Android, shared business logic with web
- **ESP32**: Cost-effective, WiFi-capable microcontroller; Arduino ecosystem enables rapid prototyping
- **PlatformIO**: Cross-platform firmware development with integrated testing and dependency management

## Data Integrity & Resilience

All layers MUST implement resilience patterns to guarantee zero data loss.

### Corruption Detection
- **Transmission Checksums**: All API requests/responses MUST include SHA-256 checksum in headers
- **HMAC Signing**: Critical operations (meter readings) MUST be HMAC-signed with backend secret
- **Validation**: Receivers MUST validate checksums before processing and reject corrupted payloads

### Guaranteed Delivery
- **Idempotency Keys**: All write operations MUST include idempotency key (UUID). Backend deduplicates by key, NOT by content
- **Atomic Transactions**: All meter reading inserts into database MUST be atomic (transaction COMMIT/ROLLBACK)
- **No Partial Writes**: Database triggers MUST prevent partial meter data persistence

### Offline Resilience
- **Local Queuing**: ESP32 MUST queue failed transmissions locally (SQLite or similar). Max 7-day retention
- **Frontend/Mobile**: MUST implement local state persistence (React Query cache, Redux persist, AsyncStorage)
- **Retry Strategy**: Exponential backoff: 1s → 2s → 4s → 8s → 16s → 32s → 1min → 5min → repeat
- **Maximum Retries**: ESP32 retries for 7 days; backend clients for 24 hours or until user action

### Audit & Recovery
- **Immutable Ledger**: All meter readings in database MUST be immutable (no UPDATE, only INSERT)
- **Change Tracking**: Every write operation MUST log: timestamp, operation type, old value, new value, actor
- **Data Recovery**: In case of corruption, full audit trail enables reconstruction to last known-good state

## Development Workflow

1. Changes start with documented requirements
2. Backend API contracts MUST be defined first (including ESP32 endpoints, idempotency key requirements)
3. Backend implementation precedes client (web/mobile/ESP32) implementation
4. Schema changes require migration files
5. All code changes include tests:
   - Backend: unit tests, integration tests, resilience tests (network failure injection, corruption scenarios)
   - ESP32: firmware tests, retry logic tests, offline queue tests
   - Web/Mobile: component tests, offline state tests
6. Code review verifies: architecture consistency, technology stack adherence, Hardware-Backend Sync principle, Data Resilience principle (checksums, idempotency, local queuing)
7. Deployment: database migrations first, then backend (with resilience layers), then ESP32 firmware, finally web/mobile clients

## Governance

This constitution supersedes all other development guidelines. Amendments require documentation of the change rationale and impact assessment on existing services. Version increments follow semantic versioning: MAJOR for principle changes, MINOR for clarifications, PATCH for non-semantic updates.

**Version**: 1.3.0 | **Ratified**: 2026-02-20 | **Last Amended**: 2026-02-24
