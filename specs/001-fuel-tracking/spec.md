# Feature Specification: Fuel Dispensing Tracking

**Feature Branch**: `001-fuel-tracking`
**Created**: 2026-02-24
**Status**: Draft
**Input**: User description: Build an application that measures the amount of fuel/oil (by an IoT device) that a pre-validated and authorized user took and save that information into the database. Along with the amount of fuel/oil (in liters) some metadata needs to be included: measuring device ID, timestamp, authorized user, and destination of the fuel/oil (free text provided by the user when asking for permissions to take the fuel/oil).

## User Scenarios & Testing

### Clarifications - Session 2026-02-24

- Q1: Max liters determination → A: Flexible by user, role, monthly limit, daily limit, or custom rule
- Q2: Limit enforcement when quota exceeded → A: Request manager/admin override via separate workflow (not in dispensing request flow)
- Q3: Dispensing request response structure → A: Simple `{status, max_liters}`; override is separate feature
- Q4: Max liters representation → A: Show remaining balance from current quota, not full limit

---

### User Story 1 - Authorized User Requests Fuel Dispensing (Priority: P1)

An authorized user requests permission to dispense fuel from a measuring device. They provide the intended destination for the fuel. Upon approval, the system responds with approval/rejection status and the maximum liters available for dispensing based on the user's limits (role-based, monthly, daily, or custom rules). A manager/admin override workflow is available as a separate feature if the user has reached their limit.

**Why this priority**: This is the entry point for the entire feature. Without the ability to request and authorize dispensing, no fuel can be tracked. This is the foundation of the system.

**Independent Test**: Can be fully tested by having an authorized user submit a dispensing request with destination information and receiving confirmation that the request is recorded with approval status and max_liters available, independent of the actual measurement happening.

**Acceptance Scenarios**:

1. **Given** an authorized user is logged into the system, **When** they submit a fuel dispensing request with a destination, **Then** the request is recorded with timestamp, user ID, and returned with status and max_liters available
2. **Given** a dispensing request is received, **When** the backend validates the user authorization and checks applicable limits, **Then** the response includes: `{status: "approved", max_liters: <remaining_balance>}` or `{status: "rejected", reason: "<reason>"}`
3. **Given** a user has remaining quota available, **When** they receive approval, **Then** max_liters reflects the remaining balance (not the full limit) from current quota period (daily/monthly/custom)
4. **Given** a user has reached or exceeded their limit, **When** they request dispensing, **Then** the response is `{status: "rejected", reason: "limit_exceeded"}` and the system notes that an override workflow is available separately
5. **Given** an approved dispensing request, **When** the user initiates dispensing at the physical device, **Then** the IoT device begins measuring and tracking the fuel amount up to the max_liters limit

---

### User Story 2 - IoT Device Measures and Records Fuel Consumption (Priority: P1)

The ESP32 IoT device physically measures the fuel being dispensed in real-time using the connected meter sensor. The device records the volume in liters and captures the timestamp of each measurement event.

**Why this priority**: This is critical infrastructure. Without accurate measurement from the hardware, the entire system has no data to track. This must work reliably before data can be persisted.

**Independent Test**: Can be fully tested independently by having the ESP32 connected to a meter device, dispensing fuel, and verifying that measurements are recorded locally on the device with proper timestamps and volume data, even if backend communication fails.

**Acceptance Scenarios**:

1. **Given** an ESP32 device with an active dispensing session, **When** fuel flows through the connected meter sensor, **Then** the device captures the volume in liters with high accuracy
2. **Given** fuel is being dispensed, **When** the measurement event occurs, **Then** the device records the precise timestamp of the measurement
3. **Given** multiple fuel pulses are detected, **When** measurements accumulate, **Then** the total volume is calculated correctly
4. **Given** network connectivity is lost during dispensing, **When** fuel continues to be measured, **Then** measurements are queued locally with timestamp and volume data intact

---

### User Story 3 - System Records Fuel Dispensing to Database (Priority: P1)

The backend system receives measurement data from the ESP32 device and persists a complete dispensing record to the database. This includes matching the measurement to the original dispensing request and storing all associated metadata atomically.

**Why this priority**: Without persisting data reliably to the database, measurements are worthless. This is essential for the system to provide value and meet the constitution's data resilience requirements.

**Independent Test**: Can be fully tested by simulating ESP32 measurements and verifying that complete, valid dispensing records are stored in the database with all metadata intact, including validation of checksums and rejection of corrupted/duplicate data.

**Acceptance Scenarios**:

1. **Given** measurement data is received from an ESP32 device, **When** the data includes valid volume, timestamp, and device ID, **Then** a dispensing record is created in the database
2. **Given** a dispensing record creation request, **When** the system validates the idempotency key, **Then** duplicate transmissions do not result in duplicate database entries
3. **Given** measurement data with corrupted checksum, **When** the system validates the transmission integrity, **Then** the record is rejected and error is logged
4. **Given** a dispensing record is being persisted, **When** the transaction executes, **Then** all fields (volume, timestamp, device ID, user ID, destination) are written atomically
5. **Given** network latency causes delayed delivery, **When** a measurement eventually arrives, **Then** it is persisted with its original timestamp (not system timestamp)

---

### User Story 4 - User Views Dispensing History (Priority: P2)

An authorized user can access their personal fuel dispensing history through the web or mobile application. They can view all their dispensing transactions, amounts dispensed, destinations, and timestamps.

**Why this priority**: Provides visibility to users on their fuel consumption and dispensing activities. Important for accountability and tracking but not critical for the initial system operation.

**Independent Test**: Can be tested independently by querying user dispensing records and verifying they can view filtered history with all metadata intact.

**Acceptance Scenarios**:

1. **Given** a user has completed dispensing transactions, **When** they access their history view, **Then** all records are displayed with date, amount (liters), destination, and device information
2. **Given** a user views their history, **When** they filter by date range, **Then** only records within that range are displayed
3. **Given** multiple dispensing records exist, **When** the user sorts by volume or date, **Then** records are sorted in the requested order

---

### User Story 5 - Administrator Views All Dispensing Activity (Priority: P3)

An administrator can access a comprehensive view of all fuel dispensing activity across all devices, users, and time periods. This enables monitoring and reporting of fuel usage patterns.

**Why this priority**: Useful for administrative oversight and reporting but not essential for the core dispensing functionality to work.

**Independent Test**: Can be tested independently by querying system-wide dispensing records and verifying administrators see all data while regular users see only their own.

**Acceptance Scenarios**:

1. **Given** an administrator accesses the system dashboard, **When** they view the dispensing summary, **Then** aggregated statistics are displayed (total liters dispensed, by user, by device, by time period)
2. **Given** administrator is viewing activity logs, **When** they filter by device ID or user, **Then** relevant records are displayed

---

### Edge Cases

- What happens if the ESP32 device loses WiFi connection mid-dispensing? (Should queue measurements locally)
- How does the system handle a user requesting fuel dispensing without proper authorization? (Should reject the request with clear error)
- What if multiple measurement events arrive out of order due to network delays? (Should use timestamps to order events, not arrival order)
- What happens if the meter sensor provides physically impossible values (negative volume)? (Should validate and reject)
- What if a dispensing request is approved but the user never actually dispenses fuel? (Request should eventually expire, define timeout period)
- What if two different devices try to send measurements for the same request simultaneously? (Idempotency key prevents duplicates)
- What if a user's quota limit changes during an active dispensing session? (Enforce at request time; in-flight dispensing continues with approved max_liters)
- What if a user tries to dispense more than max_liters after receiving approval? (Stop dispensing at max_liters limit, record actual amount dispensed)
- What if user has multiple overlapping quota rules (role-based AND user-specific)? (Apply most restrictive rule)

## Requirements

### Functional Requirements

- **FR-001**: System MUST authenticate users before allowing dispensing requests
- **FR-002**: System MUST authorize dispensing requests based on user permissions and account status
- **FR-003**: System MUST accept a free-text destination field from users when requesting fuel dispensing
- **FR-004**: System MUST communicate with ESP32 IoT devices via REST API or MQTT to receive measurements
- **FR-005**: System MUST validate all measurement data includes: device ID, volume (liters), timestamp, and idempotency key
- **FR-006**: System MUST detect and reject corrupted measurements using SHA-256 checksum validation
- **FR-007**: System MUST store dispensing records atomically with all metadata: volume, timestamp, device ID, authorized user, and destination
- **FR-008**: System MUST assign each measurement a unique idempotency key to prevent duplicate processing
- **FR-009**: System MUST persist dispensing records to PostgreSQL database with transactional guarantees
- **FR-010**: System MUST maintain complete audit trail of all dispensing activities (immutable ledger principle)
- **FR-011**: ESP32 device MUST queue failed transmissions locally with max 7-day retention
- **FR-012**: ESP32 device MUST retry failed transmissions with exponential backoff
- **FR-013**: System MUST timestamp all records with UTC timezone for consistency
- **FR-014**: System MUST allow users to view their own dispensing history with metadata
- **FR-015**: System MUST allow administrators to view all dispensing records across all users and devices
- **FR-016**: System MUST validate that dispensed volume is physically realistic (positive, within device capacity)
- **FR-017**: System MUST log all validation failures and rejection reasons for troubleshooting
- **FR-018**: System MUST support configurable quota limit rules by user, role, daily, monthly, or custom criteria
- **FR-019**: System MUST calculate remaining balance for each user based on applicable limit rules and current quota usage
- **FR-020**: System MUST return dispensing request response with simple structure: `{status: "approved"|"rejected", max_liters: <remaining_balance>}` or `{status: "rejected", reason: "<reason>"}`
- **FR-021**: System MUST ensure max_liters in response reflects remaining balance from current quota period, not the full limit
- **FR-022**: System MUST reject dispensing requests with `status: "rejected", reason: "limit_exceeded"` when user quota is exhausted, with note that override workflow is available separately
- **FR-023**: System MUST enforce dispensing volume does not exceed max_liters approved in the dispensing request
- **FR-024**: System MUST prevent dispensing beyond remaining quota; if user attempts to dispense more than max_liters, stop at max_liters limit

### Key Entities

- **Dispensing Request**: Represents a user's request to dispense fuel, includes user ID, destination (free text), timestamp, authorization status, expiration time, max_liters (remaining balance from applicable quota), and applicable limit type (role, user, daily, monthly, or custom)
- **Dispensing Record**: Immutable ledger entry for completed fuel dispensing, includes volume (liters), device ID, measurement timestamp, authorized user ID, request destination, max_liters approved, and system receipt timestamp
- **Measuring Device**: Represents a physical ESP32-based meter device, includes device ID, location, calibration info, and last communication timestamp
- **User**: Represents an authorized system user with permission levels (regular user, administrator), assigned quota limits (daily/monthly/custom rules), and role-based limits
- **Quota Limit Rule**: Configurable rule defining maximum liters available, includes type (user-specific, role-based, daily, monthly, custom), limit value (liters), and period (if applicable)

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of valid dispensing requests from authorized users are recorded in database with complete metadata
- **SC-002**: Zero data loss: All measurements from ESP32 devices are either delivered to backend within 24 hours or queued locally for up to 7 days
- **SC-003**: Measurement accuracy: Volume measurements match physical meter readings within 0.1 liter accuracy (hardware-dependent)
- **SC-004**: Data integrity: Zero duplicate readings due to network retransmissions (idempotency key validation prevents >99% of duplicates; 100% across all layers)
- **SC-005**: Users can access their dispensing history within 2 seconds of request
- **SC-006**: Corrupted measurements are detected and rejected with 100% accuracy (SHA-256 checksum validation)
- **SC-007**: System maintains 99.9% availability for dispensing requests and record storage
- **SC-008**: Timestamp accuracy: ±2 second precision across ESP32 device and backend server
- **SC-009**: All dispensing records include complete audit trail enabling data recovery if corruption occurs
- **SC-010**: 95% of authorized users successfully complete dispensing request and dispense fuel on first attempt
- **SC-011**: Quota limit enforcement: 100% of dispensing requests respect configured limits; zero requests bypass established quotas
- **SC-012**: Max liters accuracy: Response includes correct remaining balance with 100% accuracy based on current usage and applicable rules
- **SC-013**: Limit rejection clarity: Users receive clear feedback when quota exceeded, with indication that override workflow exists

## Assumptions

- Users requesting fuel dispensing have already been registered and verified in the system (pre-validated)
- Authorization checks are performed at the application level (not delegated to external auth service for this MVP)
- ESP32 devices have WiFi connectivity (intermittently acceptable with local queueing)
- Meter devices connected to ESP32 output digital pulse signals proportional to volume dispensed
- Destinations are free-form text and do not require validation against predefined locations (for MVP)
- One ESP32 device manages one physical meter/fuel pump
- All timestamps use UTC for consistency across distributed devices
- Dispensing requests expire after 24 hours if no measurement is received
- PostgreSQL is available for persistent storage with transactional support
- Quota limit rules can be configured by administrators at multiple levels (user, role, daily, monthly, custom)
- Remaining balance calculation includes all current usage (today/this month/current period depending on rule type)
- Manager/admin override workflow is a separate feature to be defined later (outside scope of this MVP)
- Users who reach quota limits must submit a new dispensing request after obtaining override approval
- Most restrictive applicable rule is enforced when multiple overlapping quotas apply to a user

## Out of Scope

- Mobile push notifications for completed dispensing
- Real-time dashboard of active dispensing events
- Fuel price calculations or cost tracking
- Integration with fuel inventory management systems
- Email notifications (can be added in future iterations)
- Geographic location tracking of dispensing events beyond user-provided destination
- Manager/admin override workflow for quota limit exceptions (separate feature, defined later)
