<!--
SYNC IMPACT REPORT
==================
Version: 1.0.0 → 1.1.0 → 1.1.1 → 1.2.0 (MINOR: IoT/ESP32 layer added)
Ratified: 2026-02-20
Last Amended: 2026-02-24

CHANGES SUMMARY:
- Type: Amendment - Architecture Extension
- Added ESP32 IoT hardware layer for meter reading
- New communication channel: ESP32 ← (sensor) → Backend REST API
- Enforces data consistency between hardware and application layers

PRINCIPLES (6 total - 1 NEW):
✅ I. API-First Design - Define contracts before implementation
✅ II. Separation of Concerns - NOW INCLUDES: hardware (ESP32), backend, web, mobile, database
✅ III. Database Schema Versioning - Track all schema changes in migrations
✅ IV. Testing Requirements - Backend: unit & integration; Web/Mobile: component tests; ESP32: device tests
✅ V. Minimal Complexity - No premature abstraction
✅ VI. Hardware-Backend Synchronization - NEW (Meter readings must sync bidirectionally)

SECTIONS:
✅ Code Organization - NOW INCLUDES: `/esp32` for IoT firmware
✅ Development Workflow - Updated (Add ESP32 API contract definition step)
✅ Technology Stack - EXTENDED (Backend connectivity, MQTT/REST for ESP32, firmware framework)
✅ Governance - Amendment procedures with semantic versioning

TECHNOLOGY ADDITIONS:
- ESP32 Firmware: Arduino/C++, PlatformIO toolchain, Arduino IDE compatible
- Connectivity: WiFi, HTTPS/MQTT for Backend communication
- Sensor Interface: Digital pulse input from meter device
- Data Format: JSON over REST/MQTT (consistent with web/mobile)

TEMPLATE SYNC STATUS:
✅ .specify/templates/plan-template.md - Extended (Technical Context includes ESP32 firmware version)
✅ .specify/templates/spec-template.md - Aligned (FR requirements now include IoT data sync)
✅ .specify/templates/tasks-template.md - Aligned (Task templates account for firmware + backend integration)

DEFERRED ITEMS: None

NEXT STEPS:
1. Run /speckit.plan after feature specs are defined
2. Constitution Check validates API-First + Hardware Sync principles
3. Tasks include firmware testing alongside backend integration tests
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

## Development Workflow

1. Changes start with documented requirements
2. Backend API contracts MUST be defined first (including ESP32 endpoints)
3. Backend implementation precedes client (web/mobile/ESP32) implementation
4. Schema changes require migration files
5. All code changes include tests (backend unit/integration, ESP32 firmware tests)
6. Code review verifies architecture consistency, technology stack adherence, and Hardware-Backend Sync principle
7. Deployment: database migrations first, then backend, then ESP32 firmware, finally web/mobile clients

## Governance

This constitution supersedes all other development guidelines. Amendments require documentation of the change rationale and impact assessment on existing services. Version increments follow semantic versioning: MAJOR for principle changes, MINOR for clarifications, PATCH for non-semantic updates.

**Version**: 1.2.0 | **Ratified**: 2026-02-20 | **Last Amended**: 2026-02-24
