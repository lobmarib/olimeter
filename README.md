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
| **Docker** / **Docker Compose** | Latest | Local PostgreSQL, Keycloak & MQTT broker |
| **PlatformIO CLI** | Latest | ESP32 firmware build |
| **Python** | 3.9+ | PlatformIO dependency |

## Local Development Setup

### 1. Infrastructure (Docker Compose)

Start PostgreSQL, Keycloak, and Mosquitto together:

```bash
cd backend
docker compose up -d
```

This starts:
- **PostgreSQL 15** on port `5432` (database: `olimeeter`, user/password: `olimeeter`)
- **Keycloak 26** on port `8180` (admin console: `http://localhost:8180`, admin/admin)
- **Mosquitto MQTT** on port `1883`

Keycloak auto-imports the `olimeeter` realm with pre-configured clients, roles, and test users on first startup.

### 2. Backend

**Option A: Dev profile (recommended for quick start — no PostgreSQL or Keycloak needed)**

Uses an H2 in-memory database with mock data pre-loaded (2 facilities, 5 users, 4 devices, sample dispensing records). Requires Keycloak running for JWT validation (start with `docker compose up keycloak -d`).

```bash
cd backend
./gradlew bootRun --args='--spring.profiles.active=dev'
```

H2 console available at `http://localhost:8080/h2-console` (JDBC URL: `jdbc:h2:mem:olimeeter`, user: `sa`, no password).

**Option B: PostgreSQL profile (production-like)**

Requires a running PostgreSQL instance and Keycloak. Flyway runs migrations automatically.

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

| Migration | Description |
|-----------|-------------|
| V1 | `facilities`, `users`, `measuring_devices` |
| V2 | `dispensing_requests`, `dispensing_records`, `device_audit_trail` |
| V3 | `quota_limit_rules`, `wifi_configurations`, `ble_session_logs`, `mobile_proxy_permissions` |
| V4 | Refactor `users` for Keycloak (keycloak_sub PK, drop password/role, update all FKs) |

## Keycloak (Identity & Access Management)

OliMeeter uses [Keycloak](https://www.keycloak.org/) (Apache 2.0) for authentication and authorization. Users authenticate via OpenID Connect (OIDC) with Authorization Code + PKCE flow.

### Local Development

Keycloak is included in the Docker Compose setup and auto-imports the `olimeeter` realm on first startup:

```bash
cd backend
docker compose up keycloak -d
```

- **Admin Console**: `http://localhost:8180` (username: `admin`, password: `admin`)
- **Realm**: `olimeeter`
- **Client**: `olimeeter-app` (public client, PKCE)

**Test Users** (all passwords: `password123`):

| Username | Role | Facility |
|----------|------|----------|
| `admin` | admin | Central Storage Depot |
| `alice_supervisor` | supervisor | Central Storage Depot |
| `bob_driver` | user | Central Storage Depot |
| `carol_operator` | user | Central Storage Depot |
| `dave_north` | user | North Warehouse |

**Realm Roles**: `admin`, `supervisor`, `user`

The realm export is at `backend/keycloak/olimeeter-realm.json`. To regenerate after changes in the Keycloak admin console:

```bash
docker exec olimeeter-keycloak /opt/keycloak/bin/kc.sh export \
  --dir /tmp/export --realm olimeeter
docker cp olimeeter-keycloak:/tmp/export/olimeeter-realm.json backend/keycloak/olimeeter-realm.json
```

### Production Deployment

For production, deploy Keycloak as a standalone service with its own PostgreSQL database:

1. **Deploy Keycloak** using the [official Docker image](https://quay.io/repository/keycloak/keycloak) or the [Keycloak Operator](https://www.keycloak.org/operator/installation) for Kubernetes:

   ```bash
   docker run -d \
     --name keycloak \
     -e KC_DB=postgres \
     -e KC_DB_URL=jdbc:postgresql://your-db-host:5432/keycloak \
     -e KC_DB_USERNAME=keycloak \
     -e KC_DB_PASSWORD=<strong-password> \
     -e KC_HOSTNAME=auth.yourdomain.com \
     -e KEYCLOAK_ADMIN=admin \
     -e KEYCLOAK_ADMIN_PASSWORD=<strong-admin-password> \
     -p 8443:8443 \
     quay.io/keycloak/keycloak:26.0 start
   ```

2. **Import the realm** on first startup or via the admin console:
   - Import `backend/keycloak/olimeeter-realm.json` as a starting point
   - Update redirect URIs in the `olimeeter-app` client to match your production domain
   - Remove test users and create real users via the admin console or user self-registration

3. **Configure the backend** to point to your production Keycloak:

   ```bash
   export KEYCLOAK_ISSUER_URI=https://auth.yourdomain.com/realms/olimeeter
   ```

4. **Production checklist**:
   - Enable HTTPS (Keycloak requires TLS in production mode)
   - Set strong admin passwords
   - Configure email for password reset / user self-registration
   - Set up database backups for the Keycloak database
   - Consider clustering for high availability
   - Review and restrict CORS, redirect URIs, and web origins

### Auth Architecture

```
┌──────────┐    OIDC/PKCE    ┌──────────┐
│ Frontend │ ◄──────────────►│ Keycloak │
│ (React)  │   login/token   │ IAM      │
└────┬─────┘                 └──────────┘
     │ Bearer JWT                  │
     ▼                             │ JWT validation
┌──────────┐     issuer-uri   ─────┘
│ Backend  │ (validates JWT signature via Keycloak JWKS endpoint)
│ (Spring) │
└──────────┘

ESP32 devices use a pre-shared API key (X-Device-Key header) — no Keycloak.
```

- **Human users**: Keycloak JWT → roles from `realm_access.roles` claim
- **ESP32 devices**: `X-Device-Key` + `Device-ID` headers → `ROLE_DEVICE` authority
- **User auto-provisioning**: Local User profile created on first authenticated API call from JWT claims

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KEYCLOAK_ISSUER_URI` | `http://localhost:8180/realms/olimeeter` | Keycloak realm issuer URI for JWT validation |
| `DEVICE_API_KEY` | `dev-device-secret-change-in-production` | Pre-shared API key for ESP32 device auth |
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
- **tasks.md** - Implementation task list (97 tasks, 11 phases)
