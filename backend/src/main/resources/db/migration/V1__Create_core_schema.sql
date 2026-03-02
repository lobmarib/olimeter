-- V1: Core schema - Facility, User, MeasuringDevice
-- These are foundational entities referenced by all other tables.

-- Custom types
CREATE TYPE user_role AS ENUM ('user', 'supervisor', 'admin');
CREATE TYPE connectivity_status AS ENUM ('online_wifi', 'online_ble', 'offline', 'unknown');

-- Facility (multi-tenant grouping)
CREATE TABLE facilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_name VARCHAR(200) UNIQUE NOT NULL,
    location_address VARCHAR(500),
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    manager_user_id UUID, -- FK added after users table created
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- User
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(200),
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'user',
    facility_id UUID NOT NULL REFERENCES facilities(id),
    quota_config_json JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_facility ON users(facility_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_username ON users(username);

-- Add FK from facility manager back to users
ALTER TABLE facilities
    ADD CONSTRAINT fk_facilities_manager
    FOREIGN KEY (manager_user_id) REFERENCES users(id);

-- Measuring Device (ESP32)
CREATE TABLE measuring_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_name VARCHAR(100) NOT NULL,
    facility_id UUID NOT NULL REFERENCES facilities(id),
    device_model VARCHAR(50),
    firmware_version VARCHAR(20),
    mac_address VARCHAR(17) UNIQUE,
    ble_uuid VARCHAR(36) UNIQUE,
    tank_capacity_liters NUMERIC(10,2) NOT NULL,
    current_queue_depth INT NOT NULL DEFAULT 0,
    last_communication_at TIMESTAMP,
    last_wifi_connection_at TIMESTAMP,
    last_ble_contact_at TIMESTAMP,
    connectivity_status connectivity_status NOT NULL DEFAULT 'unknown',
    battery_percent INT CHECK (battery_percent BETWEEN 0 AND 100),
    signal_strength_dbm INT CHECK (signal_strength_dbm BETWEEN -120 AND -20),
    is_paused BOOLEAN NOT NULL DEFAULT FALSE,
    location_lat NUMERIC(10,8),
    location_lng NUMERIC(11,8),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (device_name, facility_id)
);

CREATE INDEX idx_devices_facility ON measuring_devices(facility_id);
CREATE INDEX idx_devices_connectivity ON measuring_devices(connectivity_status);
