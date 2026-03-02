-- V2: Dispensing schema - DispensingRequest, DispensingRecord (immutable), DeviceAuditTrail

-- Custom types
CREATE TYPE dispensing_request_status AS ENUM ('pending', 'approved', 'rejected', 'dispensing', 'completed');
CREATE TYPE audit_event_type AS ENUM ('relay_opened', 'relay_closed', 'hard_cutoff', 'timeout', 'manual_stop', 'error');
CREATE TYPE trigger_source AS ENUM ('backend_api', 'ble_command', 'local_timeout', 'hard_limit_reached', 'manual');

-- Dispensing Request
CREATE TABLE dispensing_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    device_id UUID NOT NULL REFERENCES measuring_devices(id),
    requested_liters NUMERIC(10,2) NOT NULL CHECK (requested_liters > 0),
    approved_liters NUMERIC(10,2) CHECK (approved_liters >= 0),
    status dispensing_request_status NOT NULL DEFAULT 'pending',
    rejection_reason VARCHAR(255),
    destination VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMP,
    dispensing_started_at TIMESTAMP,
    dispensing_ended_at TIMESTAMP
);

CREATE INDEX idx_dispensing_requests_user ON dispensing_requests(user_id, created_at DESC);
CREATE INDEX idx_dispensing_requests_device ON dispensing_requests(device_id);
CREATE INDEX idx_dispensing_requests_status ON dispensing_requests(status);

-- Dispensing Record (IMMUTABLE LEDGER - append only)
CREATE TABLE dispensing_records (
    id BIGSERIAL PRIMARY KEY,
    dispensing_request_id UUID NOT NULL REFERENCES dispensing_requests(id),
    device_id UUID NOT NULL REFERENCES measuring_devices(id),
    user_id UUID NOT NULL REFERENCES users(id),
    volume_liters NUMERIC(10,2) NOT NULL CHECK (volume_liters >= 0),
    measurement_timestamp TIMESTAMP NOT NULL,
    backend_received_at TIMESTAMP NOT NULL DEFAULT NOW(),
    communication_channel VARCHAR(20),
    checksum VARCHAR(64),
    idempotency_key UUID UNIQUE,
    metadata_json JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dispensing_records_user ON dispensing_records(user_id, created_at DESC);
CREATE INDEX idx_dispensing_records_device ON dispensing_records(device_id, created_at DESC);
CREATE INDEX idx_dispensing_records_request ON dispensing_records(dispensing_request_id);
CREATE INDEX idx_dispensing_records_timestamp ON dispensing_records(measurement_timestamp);

-- Device Audit Trail (IMMUTABLE - append only)
CREATE TABLE device_audit_trail (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES measuring_devices(id),
    event_type audit_event_type NOT NULL,
    dispensing_request_id UUID REFERENCES dispensing_requests(id),
    max_liters_approved NUMERIC(10,2),
    actual_volume_dispensed NUMERIC(10,2),
    trigger_source trigger_source,
    timestamp TIMESTAMP NOT NULL,
    backend_received_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata_json JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_trail_device ON device_audit_trail(device_id, timestamp DESC);
CREATE INDEX idx_audit_trail_request ON device_audit_trail(dispensing_request_id);
