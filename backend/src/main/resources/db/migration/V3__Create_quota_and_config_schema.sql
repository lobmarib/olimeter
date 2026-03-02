-- V3: Quota & configuration - QuotaLimitRule, WiFiConfiguration, BLESessionLog, MobileProxyPermission

-- Custom types
CREATE TYPE quota_rule_type AS ENUM ('user_specific', 'role_based', 'daily', 'monthly', 'custom');
CREATE TYPE time_period AS ENUM ('daily', 'monthly');
CREATE TYPE enforcement_action AS ENUM ('reject', 'warn');
CREATE TYPE ble_session_status AS ENUM ('active', 'completed', 'failed', 'timeout');
CREATE TYPE proxy_permission_type AS ENUM ('proxy', 'command');

-- Quota Limit Rule
CREATE TABLE quota_limit_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES facilities(id),
    rule_type quota_rule_type NOT NULL,
    applies_to_user_id UUID REFERENCES users(id),
    applies_to_role VARCHAR(50),
    time_period time_period,
    max_liters NUMERIC(10,2) NOT NULL CHECK (max_liters > 0),
    enforcement_action enforcement_action NOT NULL DEFAULT 'reject',
    custom_condition_json JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    priority INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quota_rules_facility ON quota_limit_rules(facility_id);
CREATE INDEX idx_quota_rules_user ON quota_limit_rules(applies_to_user_id);
CREATE INDEX idx_quota_rules_role ON quota_limit_rules(applies_to_role);

-- WiFi Configuration (per device)
CREATE TABLE wifi_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES measuring_devices(id),
    ssid_profiles JSONB NOT NULL,
    fallback_to_ble BOOLEAN NOT NULL DEFAULT TRUE,
    ble_advertise_timeout_seconds INT NOT NULL DEFAULT 300 CHECK (ble_advertise_timeout_seconds BETWEEN 30 AND 3600),
    wifi_scan_interval_seconds INT NOT NULL DEFAULT 60,
    config_version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wifi_config_device ON wifi_configurations(device_id);

-- BLE Session Log (audit trail for BLE-proxied communications)
CREATE TABLE ble_session_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mobile_user_id UUID NOT NULL REFERENCES users(id),
    device_id UUID NOT NULL REFERENCES measuring_devices(id),
    session_start_at TIMESTAMP NOT NULL,
    session_end_at TIMESTAMP,
    measurements_count INT NOT NULL DEFAULT 0,
    data_bytes_transferred INT,
    status ble_session_status NOT NULL DEFAULT 'active',
    failure_reason VARCHAR(255),
    signal_strength_dbm INT,
    round_trip_latency_ms INT,
    metadata_json JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ble_sessions_user ON ble_session_logs(mobile_user_id);
CREATE INDEX idx_ble_sessions_device ON ble_session_logs(device_id);

-- Mobile Proxy Permission
CREATE TABLE mobile_proxy_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    device_id UUID NOT NULL REFERENCES measuring_devices(id),
    permission_type proxy_permission_type NOT NULL DEFAULT 'proxy',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    granted_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, device_id)
);

CREATE INDEX idx_proxy_permissions_user ON mobile_proxy_permissions(user_id);
CREATE INDEX idx_proxy_permissions_device ON mobile_proxy_permissions(device_id);
