# OliMeeter - Fuel Dispensing Tracking System

A comprehensive fuel/oil dispensing tracking system with IoT integration. ESP32 devices measure fuel volume through relay-controlled pumps, communicate via REST API (WiFi) and BLE (mobile bridge fallback), enforce flexible quota management, and provide immutable audit trails.

## Architecture

```
┌─────────────┐    REST/MQTT     ┌──────────────┐     SQL      ┌────────────┐
│  ESP32       │ ◄──────────────►│   Backend    │ ◄───────────►│ PostgreSQL │
│  Firmware    │     (WiFi)      │  Spring Boot │              │   15+      │
└──────┬───────┘                 └──────┬───────┘              └────────────┘
       │ BLE                            │ REST
       ▼                                ▼
┌─────────────┐    REST          ┌──────────────┐
│  Mobile App │ ────────────────►│   Frontend   │
│ React Native│  (BLE bridge)    │  React + Ant │
└─────────────┘                  └──────────────┘
```

| Component | Tech Stack | Purpose |
|-----------|-----------|---------|
| **ESP32 Firmware** | C/C++, PlatformIO, Arduino-ESP32, NimBLE | Relay control, fuel metering, offline queue |
| **Backend** | Java 25, Spring Boot 4.0.1, PostgreSQL 15+, Flyway | REST API, quota enforcement, immutable ledger |
| **Frontend** | TypeScript 5.9, React 19.2.4, Ant Design 6.2.0, Vite | Web UI for dispensing requests and history |
| **Mobile** | TypeScript, React Native 0.76+, BLE | Mobile UI, BLE bridge to ESP32 when WiFi unavailable |
| **Shared** | TypeScript | Common types and MQTT topic constants |

## Project Structure

```
olimeeter/
├── esp32-firmware/          # PlatformIO ESP32 project
│   ├── platformio.ini       # Build config & dependencies
│   ├── src/                 # Firmware source (C/C++)
│   └── test/                # PlatformIO unit tests
├── backend/                 # Spring Boot REST API
│   ├── build.gradle.kts     # Gradle build (Java 25)
│   └── src/main/
│       ├── java/com/olimeeter/fuel/
│       │   ├── models/      # JPA entities
│       │   ├── services/    # Business logic
│       │   ├── api/         # REST controllers
│       │   ├── repository/  # Data access
│       │   ├── config/      # Security, CORS, MQTT
│       │   └── util/        # Checksum, idempotency
│       └── resources/
│           ├── application.yaml
│           └── db/migration/ # Flyway SQL migrations
├── frontend/                # React web application
│   ├── package.json
│   ├── vite.config.ts
│   └── src/
│       ├── components/      # Reusable UI components
│       ├── pages/           # Route pages
│       ├── services/        # API client (SWR)
│       └── types/           # TypeScript definitions
├── mobile/                  # React Native mobile app
│   ├── package.json
│   └── src/
│       ├── screens/         # App screens
│       ├── services/        # API, BLE, offline queue
│       └── navigation/      # React Navigation
├── shared/                  # Common TypeScript types
│   ├── types/               # Model & API type definitions
│   └── constants/           # MQTT topics
└── specs/                   # Feature specifications
    └── 001-fuel-tracking/   # Spec, plan, data model, contracts, tasks
```

## Prerequisites

| Tool | Version | Required For |
|------|---------|-------------|
| **Java** | 25+ | Backend |
| **Gradle** | 9.3+ (or use wrapper) | Backend build |
| **Node.js** | 20 LTS+ | Frontend, Mobile, Shared |
| **PostgreSQL** | 15+ | Backend database |
| **Docker** | Latest | Local PostgreSQL & MQTT broker |
| **PlatformIO CLI** | Latest | ESP32 firmware build |
| **Python** | 3.9+ | PlatformIO dependency |

## Local Development Setup

### 1. Database (PostgreSQL)

Start PostgreSQL via Docker:

```bash
docker run -d \
  --name olimeeter-db \
  -e POSTGRES_DB=olimeeter \
  -e POSTGRES_USER=olimeeter \
  -e POSTGRES_PASSWORD=olimeeter \
  -p 5432:5432 \
  postgres:15
```

### 2. MQTT Broker (Mosquitto) - Optional

Required only for Home Assistant integration testing:

```bash
docker run -d \
  --name olimeeter-mqtt \
  -p 1883:1883 \
  eclipse-mosquitto:2 \
  mosquitto -c /mosquitto-no-auth.conf
```

### 3. Backend

**Option A: Dev profile (recommended for quick start — no PostgreSQL needed)**

Uses an H2 in-memory database with mock data pre-loaded (2 facilities, 5 users, 4 devices, sample dispensing records):

```bash
cd backend
./gradlew bootRun --args='--spring.profiles.active=dev'
```

H2 console available at `http://localhost:8080/h2-console` (JDBC URL: `jdbc:h2:mem:olimeeter`, user: `sa`, no password).

All mock user passwords: `password123`

| User | Role | Facility |
|------|------|----------|
| `admin` | admin | Central Storage Depot |
| `alice_supervisor` | supervisor | Central Storage Depot |
| `bob_driver` | user | Central Storage Depot |
| `carol_operator` | user | Central Storage Depot |
| `dave_north` | user | North Warehouse |

**Option B: PostgreSQL profile (production-like)**

Requires a running PostgreSQL instance. Flyway runs migrations automatically.

```bash
cd backend
./gradlew bootRun
```

The backend starts on `http://localhost:8080`.

**Verify**: `curl http://localhost:8080/actuator/health`

### 4. Frontend

```bash
cd frontend

# Install dependencies
npm install

# Start dev server with hot reload
npm run dev
```

The frontend starts on `http://localhost:3000` and proxies `/api/*` requests to the backend at `:8080`.

### 5. ESP32 Firmware

```bash
cd esp32-firmware

# Install PlatformIO CLI (if not installed)
pip install platformio

# Build firmware
pio run

# Upload to connected ESP32 via USB
pio run --target upload

# Monitor serial output
pio device monitor --baud 115200

# Run unit tests
pio test
```

**Configuration**: Edit `src/config.h` to set WiFi credentials, backend URL, and device ID for your environment.

### 6. Mobile App

```bash
cd mobile

# Install dependencies
npm install

# iOS (macOS only, requires Xcode)
npx pod-install ios
npx react-native run-ios

# Android (requires Android SDK)
npx react-native run-android

# Start Metro bundler only
npx react-native start
```

## Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/dispensing-requests` | Request fuel dispensing (returns approval + max_liters) |
| `GET` | `/api/v1/dispensing-requests` | List user's recent requests |
| `POST` | `/api/v1/measurements` | ESP32 uploads fuel measurement |
| `POST` | `/api/v1/devices/{id}/relay/activate` | Activate device relay |
| `POST` | `/api/v1/devices/{id}/relay/deactivate` | Deactivate device relay |
| `GET` | `/api/v1/users/{id}/dispensing-history` | User's dispensing history |
| `GET` | `/api/v1/admin/dispensing-summary` | Admin aggregated statistics |

API contracts are in `specs/001-fuel-tracking/contracts/`.

## Database Migrations

Migrations run automatically via Flyway on backend startup. To run manually:

```bash
cd backend
./gradlew flywayMigrate
```

| Migration | Tables Created |
|-----------|---------------|
| V1 | `facilities`, `users`, `measuring_devices` |
| V2 | `dispensing_requests`, `dispensing_records`, `device_audit_trail` |
| V3 | `quota_limit_rules`, `wifi_configurations`, `ble_session_logs`, `mobile_proxy_permissions` |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | dev default | JWT signing key (min 256 bits for production) |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://localhost:5432/olimeeter` | Database URL |
| `SPRING_DATASOURCE_USERNAME` | `olimeeter` | Database user |
| `SPRING_DATASOURCE_PASSWORD` | `olimeeter` | Database password |

## Feature Specification

Full design documentation is in `specs/001-fuel-tracking/`:

- **spec.md** - Feature specification with user stories (P1-P3)
- **plan.md** - Implementation plan with tech stack decisions
- **data-model.md** - Entity definitions (10 entities)
- **contracts/** - OpenAPI specs for REST endpoints
- **research.md** - Phase 0 research decisions
- **tasks.md** - Implementation task list (77 tasks, 10 phases)
