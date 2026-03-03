-- =============================================================================
-- Mock data for dev profile (H2 in-memory database)
-- Loaded via spring.sql.init.data-locations on startup
-- =============================================================================

-- Passwords are bcrypt hashes of "password123"
-- Generated with: BCryptPasswordEncoder().encode("password123")

-- =============================================================================
-- Facilities
-- =============================================================================

INSERT INTO facilities (id, facility_name, location_address, timezone, is_active, created_at)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Central Storage Depot', '123 Main St, Lisbon, Portugal', 'Europe/Lisbon', true, TIMESTAMP '2026-01-01 00:00:00'),
    ('a0000000-0000-0000-0000-000000000002', 'North Warehouse', '456 Industrial Ave, Porto, Portugal', 'Europe/Lisbon', true, TIMESTAMP '2026-01-15 00:00:00');

-- =============================================================================
-- Users
-- =============================================================================

INSERT INTO users (id, username, email, full_name, password_hash, role, facility_id, quota_config_json, is_active, created_at, updated_at)
VALUES
    -- Admin
    ('b0000000-0000-0000-0000-000000000001', 'admin', 'admin@olimeeter.com', 'System Administrator',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'admin',
     'a0000000-0000-0000-0000-000000000001', NULL, true, TIMESTAMP '2026-01-01 08:00:00', TIMESTAMP '2026-01-01 08:00:00'),

    -- Supervisor at Central Storage
    ('b0000000-0000-0000-0000-000000000002', 'alice_supervisor', 'alice@olimeeter.com', 'Alice Johnson',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'supervisor',
     'a0000000-0000-0000-0000-000000000001', '{"monthly_limit_liters": 500, "daily_limit_liters": 50}', true, TIMESTAMP '2026-01-15 08:00:00', TIMESTAMP '2026-01-15 08:00:00'),

    -- Regular user at Central Storage
    ('b0000000-0000-0000-0000-000000000003', 'bob_driver', 'bob@olimeeter.com', 'Bob Smith',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'user',
     'a0000000-0000-0000-0000-000000000001', NULL, true, TIMESTAMP '2026-02-01 08:00:00', TIMESTAMP '2026-02-01 08:00:00'),

    -- Regular user at Central Storage
    ('b0000000-0000-0000-0000-000000000004', 'carol_operator', 'carol@olimeeter.com', 'Carol Davis',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'user',
     'a0000000-0000-0000-0000-000000000001', NULL, true, TIMESTAMP '2026-02-01 08:00:00', TIMESTAMP '2026-02-01 08:00:00'),

    -- User at North Warehouse
    ('b0000000-0000-0000-0000-000000000005', 'dave_north', 'dave@olimeeter.com', 'Dave Wilson',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'user',
     'a0000000-0000-0000-0000-000000000002', NULL, true, TIMESTAMP '2026-02-10 08:00:00', TIMESTAMP '2026-02-10 08:00:00');

-- Set facility managers
UPDATE facilities SET manager_user_id = 'b0000000-0000-0000-0000-000000000002' WHERE id = 'a0000000-0000-0000-0000-000000000001';
UPDATE facilities SET manager_user_id = 'b0000000-0000-0000-0000-000000000005' WHERE id = 'a0000000-0000-0000-0000-000000000002';

-- =============================================================================
-- Measuring Devices (ESP32)
-- =============================================================================

INSERT INTO measuring_devices (id, device_name, facility_id, device_model, firmware_version, mac_address, ble_uuid, tank_capacity_liters, current_queue_depth, connectivity_status, battery_percent, signal_strength_dbm, is_paused, last_communication_at, last_wifi_connection_at, created_at, updated_at)
VALUES
    ('c0000000-0000-0000-0000-000000000001', 'Fuel Pump A', 'a0000000-0000-0000-0000-000000000001',
     'ESP32-S3 DevKit', '0.1.0', 'AA:BB:CC:DD:EE:01', '6E400000-B5A3-F393-E0A9-E50E24DCCA01',
     1000.00, 0, 'online_wifi', 85, -55, false,
     TIMESTAMP '2026-03-01 14:30:00', TIMESTAMP '2026-03-01 14:30:00',
     TIMESTAMP '2026-01-20 10:00:00', TIMESTAMP '2026-03-01 14:30:00'),

    ('c0000000-0000-0000-0000-000000000002', 'Fuel Pump B', 'a0000000-0000-0000-0000-000000000001',
     'ESP32-S3 DevKit', '0.1.0', 'AA:BB:CC:DD:EE:02', '6E400000-B5A3-F393-E0A9-E50E24DCCA02',
     500.00, 3, 'online_ble', 62, -72, false,
     TIMESTAMP '2026-03-01 14:25:00', NULL,
     TIMESTAMP '2026-02-01 10:00:00', TIMESTAMP '2026-03-01 14:25:00'),

    ('c0000000-0000-0000-0000-000000000003', 'Oil Pump North', 'a0000000-0000-0000-0000-000000000002',
     'ESP32-WROOM-32', '0.0.9', 'AA:BB:CC:DD:EE:03', '6E400000-B5A3-F393-E0A9-E50E24DCCA03',
     2000.00, 0, 'offline', 45, -90, false,
     TIMESTAMP '2026-02-28 09:00:00', TIMESTAMP '2026-02-28 09:00:00',
     TIMESTAMP '2026-02-10 10:00:00', TIMESTAMP '2026-02-28 09:00:00'),

    ('c0000000-0000-0000-0000-000000000004', 'Diesel Pump (Maintenance)', 'a0000000-0000-0000-0000-000000000001',
     'ESP32-S3 DevKit', '0.1.0', 'AA:BB:CC:DD:EE:04', NULL,
     750.00, 0, 'offline', NULL, NULL, true,
     NULL, NULL,
     TIMESTAMP '2026-02-15 10:00:00', TIMESTAMP '2026-03-01 08:00:00');

-- =============================================================================
-- Quota Limit Rules
-- =============================================================================

INSERT INTO quota_limit_rules (id, facility_id, rule_type, applies_to_user_id, applies_to_role, time_period, max_liters, enforcement_action, is_active, priority, created_at, updated_at)
VALUES
    -- Role-based daily limit: regular users get 50L/day
    ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
     'role_based', NULL, 'user', 'daily', 50.00, 'reject', true, 1,
     TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-01-01 00:00:00'),

    -- Role-based monthly limit: regular users get 500L/month
    ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001',
     'role_based', NULL, 'user', 'monthly', 500.00, 'reject', true, 2,
     TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-01-01 00:00:00'),

    -- Role-based daily limit: supervisors get 100L/day
    ('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001',
     'role_based', NULL, 'supervisor', 'daily', 100.00, 'reject', true, 1,
     TIMESTAMP '2026-01-01 00:00:00', TIMESTAMP '2026-01-01 00:00:00'),

    -- User-specific override: Bob gets extra 25L/day (75 total with role-based)
    ('d0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001',
     'user_specific', 'b0000000-0000-0000-0000-000000000003', NULL, 'daily', 75.00, 'reject', true, 10,
     TIMESTAMP '2026-02-15 00:00:00', TIMESTAMP '2026-02-15 00:00:00'),

    -- North Warehouse: all users get 200L/day
    ('d0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000002',
     'role_based', NULL, 'user', 'daily', 200.00, 'reject', true, 1,
     TIMESTAMP '2026-02-10 00:00:00', TIMESTAMP '2026-02-10 00:00:00');

-- =============================================================================
-- Dispensing Requests (mix of statuses)
-- =============================================================================

INSERT INTO dispensing_requests (id, user_id, device_id, requested_liters, approved_liters, status, rejection_reason, destination, created_at, approved_at, dispensing_started_at, dispensing_ended_at)
VALUES
    -- Completed request: Bob dispensed 25L yesterday
    ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003',
     'c0000000-0000-0000-0000-000000000001', 50.00, 50.00, 'completed', NULL, 'Storage Tank A',
     TIMESTAMP '2026-03-01 09:00:00', TIMESTAMP '2026-03-01 09:00:05',
     TIMESTAMP '2026-03-01 09:01:00', TIMESTAMP '2026-03-01 09:15:30'),

    -- Completed request: Alice dispensed 30L two days ago
    ('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002',
     'c0000000-0000-0000-0000-000000000001', 30.00, 30.00, 'completed', NULL, 'Generator Room',
     TIMESTAMP '2026-02-28 14:00:00', TIMESTAMP '2026-02-28 14:00:03',
     TIMESTAMP '2026-02-28 14:02:00', TIMESTAMP '2026-02-28 14:12:00'),

    -- Approved but not yet dispensed
    ('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004',
     'c0000000-0000-0000-0000-000000000002', 20.00, 20.00, 'approved', NULL, 'Vehicle Fleet - Truck 12',
     TIMESTAMP '2026-03-02 08:30:00', TIMESTAMP '2026-03-02 08:30:02',
     NULL, NULL),

    -- Rejected request: Carol exceeded quota
    ('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004',
     'c0000000-0000-0000-0000-000000000001', 100.00, 0.00, 'rejected', 'quota_exceeded', 'Emergency backup',
     TIMESTAMP '2026-03-02 10:00:00', NULL, NULL, NULL),

    -- Currently dispensing
    ('e0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000003',
     'c0000000-0000-0000-0000-000000000001', 40.00, 40.00, 'dispensing', NULL, 'Tractor Field B',
     TIMESTAMP '2026-03-02 11:00:00', TIMESTAMP '2026-03-02 11:00:04',
     TIMESTAMP '2026-03-02 11:01:00', NULL),

    -- Pending request
    ('e0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000005',
     'c0000000-0000-0000-0000-000000000003', 150.00, NULL, 'pending', NULL, 'North Silo Refill',
     TIMESTAMP '2026-03-02 11:30:00', NULL, NULL, NULL);

-- =============================================================================
-- Dispensing Records (immutable ledger)
-- =============================================================================

INSERT INTO dispensing_records (dispensing_request_id, device_id, user_id, volume_liters, measurement_timestamp, backend_received_at, communication_channel, checksum, idempotency_key, metadata_json, created_at)
VALUES
    -- Bob's completed dispensing (3 measurement batches)
    ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003',
     15.50, TIMESTAMP '2026-03-01 09:05:00', TIMESTAMP '2026-03-01 09:05:02', 'wifi',
     'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
     'f0000000-0000-0000-0000-000000000001', '{"battery_percent": 85, "signal_strength_dbm": -55, "queue_depth": 0}',
     TIMESTAMP '2026-03-01 09:05:02'),

    ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003',
     20.30, TIMESTAMP '2026-03-01 09:10:00', TIMESTAMP '2026-03-01 09:10:03', 'wifi',
     'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3',
     'f0000000-0000-0000-0000-000000000002', '{"battery_percent": 84, "signal_strength_dbm": -56, "queue_depth": 0}',
     TIMESTAMP '2026-03-01 09:10:03'),

    ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003',
     25.05, TIMESTAMP '2026-03-01 09:15:00', TIMESTAMP '2026-03-01 09:15:01', 'wifi',
     'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
     'f0000000-0000-0000-0000-000000000003', '{"battery_percent": 84, "signal_strength_dbm": -57, "queue_depth": 0}',
     TIMESTAMP '2026-03-01 09:15:01'),

    -- Alice's completed dispensing (via BLE proxy)
    ('e0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002',
     30.00, TIMESTAMP '2026-02-28 14:10:00', TIMESTAMP '2026-02-28 14:10:05', 'ble-proxied',
     'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5',
     'f0000000-0000-0000-0000-000000000004', '{"battery_percent": 78, "signal_strength_dbm": -65, "queue_depth": 0, "ble_latency_ms": 145}',
     TIMESTAMP '2026-02-28 14:10:05'),

    -- Bob's in-progress dispensing (partial measurement so far)
    ('e0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003',
     12.75, TIMESTAMP '2026-03-02 11:05:00', TIMESTAMP '2026-03-02 11:05:01', 'wifi',
     'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6',
     'f0000000-0000-0000-0000-000000000005', '{"battery_percent": 83, "signal_strength_dbm": -54, "queue_depth": 0}',
     TIMESTAMP '2026-03-02 11:05:01');

-- =============================================================================
-- Device Audit Trail
-- =============================================================================

INSERT INTO device_audit_trail (device_id, event_type, dispensing_request_id, max_liters_approved, actual_volume_dispensed, trigger_source, timestamp, backend_received_at, created_at)
VALUES
    -- Bob's completed dispensing lifecycle
    ('c0000000-0000-0000-0000-000000000001', 'relay_closed', 'e0000000-0000-0000-0000-000000000001',
     50.00, NULL, 'backend_api', TIMESTAMP '2026-03-01 09:01:00', TIMESTAMP '2026-03-01 09:01:01', TIMESTAMP '2026-03-01 09:01:01'),
    ('c0000000-0000-0000-0000-000000000001', 'relay_opened', 'e0000000-0000-0000-0000-000000000001',
     50.00, 25.05, 'manual', TIMESTAMP '2026-03-01 09:15:30', TIMESTAMP '2026-03-01 09:15:31', TIMESTAMP '2026-03-01 09:15:31'),

    -- Alice's completed dispensing lifecycle
    ('c0000000-0000-0000-0000-000000000001', 'relay_closed', 'e0000000-0000-0000-0000-000000000002',
     30.00, NULL, 'backend_api', TIMESTAMP '2026-02-28 14:02:00', TIMESTAMP '2026-02-28 14:02:01', TIMESTAMP '2026-02-28 14:02:01'),
    ('c0000000-0000-0000-0000-000000000001', 'relay_opened', 'e0000000-0000-0000-0000-000000000002',
     30.00, 30.00, 'hard_limit_reached', TIMESTAMP '2026-02-28 14:12:00', TIMESTAMP '2026-02-28 14:12:01', TIMESTAMP '2026-02-28 14:12:01'),

    -- Bob's in-progress dispensing (relay still closed)
    ('c0000000-0000-0000-0000-000000000001', 'relay_closed', 'e0000000-0000-0000-0000-000000000005',
     40.00, NULL, 'backend_api', TIMESTAMP '2026-03-02 11:01:00', TIMESTAMP '2026-03-02 11:01:01', TIMESTAMP '2026-03-02 11:01:01');

-- =============================================================================
-- WiFi Configurations
-- =============================================================================

INSERT INTO wifi_configurations (id, device_id, ssid_profiles, fallback_to_ble, ble_advertise_timeout_seconds, wifi_scan_interval_seconds, config_version, created_at, updated_at)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
     '[{"ssid": "FacilityNet", "priority": 1, "enabled": true, "max_retries": 5}, {"ssid": "BackupWiFi", "priority": 2, "enabled": true, "max_retries": 3}]',
     true, 300, 60, 2, TIMESTAMP '2026-01-20 10:00:00', TIMESTAMP '2026-02-15 10:00:00'),

    ('10000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002',
     '[{"ssid": "FacilityNet", "priority": 1, "enabled": true, "max_retries": 5}]',
     true, 300, 60, 1, TIMESTAMP '2026-02-01 10:00:00', TIMESTAMP '2026-02-01 10:00:00'),

    ('10000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003',
     '[{"ssid": "NorthWarehouseWiFi", "priority": 1, "enabled": true, "max_retries": 10}]',
     true, 600, 120, 1, TIMESTAMP '2026-02-10 10:00:00', TIMESTAMP '2026-02-10 10:00:00');

-- =============================================================================
-- BLE Session Logs
-- =============================================================================

INSERT INTO ble_session_logs (id, mobile_user_id, device_id, session_start_at, session_end_at, measurements_count, data_bytes_transferred, status, signal_strength_dbm, round_trip_latency_ms, metadata_json, created_at)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001',
     TIMESTAMP '2026-02-28 14:08:00', TIMESTAMP '2026-02-28 14:12:30', 1, 2048, 'completed',
     -65, 145, '{"mobile_device": "iPhone 15 Pro", "ble_mtu": 244, "retries": 0}',
     TIMESTAMP '2026-02-28 14:08:00');

-- =============================================================================
-- Mobile Proxy Permissions
-- =============================================================================

INSERT INTO mobile_proxy_permissions (id, user_id, device_id, permission_type, is_active, granted_by_user_id, created_at)
VALUES
    ('30000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001',
     'proxy', true, 'b0000000-0000-0000-0000-000000000001', TIMESTAMP '2026-02-01 00:00:00'),

    ('30000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002',
     'proxy', true, 'b0000000-0000-0000-0000-000000000001', TIMESTAMP '2026-02-01 00:00:00'),

    ('30000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001',
     'proxy', true, 'b0000000-0000-0000-0000-000000000002', TIMESTAMP '2026-02-15 00:00:00');

-- =============================================================================
-- Summary of mock data:
--   2 Facilities (Central Storage, North Warehouse)
--   5 Users (1 admin, 1 supervisor, 3 regular)
--   4 Devices (2 online, 1 offline, 1 in maintenance)
--   5 Quota rules (role-based + user-specific)
--   6 Dispensing requests (completed, approved, rejected, dispensing, pending)
--   5 Dispensing records (3 for first request, 1 BLE-proxied, 1 in-progress)
--   5 Audit trail entries (relay open/close events)
--   3 WiFi configurations
--   1 BLE session log
--   3 Mobile proxy permissions
--
-- All user passwords: password123
-- =============================================================================
