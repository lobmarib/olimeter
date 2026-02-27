/** Shared type definitions matching backend data model (data-model.md) */

export type UserRole = "user" | "supervisor" | "admin";

export type DispensingRequestStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "dispensing"
  | "completed";

export type ConnectivityStatus =
  | "online_wifi"
  | "online_ble"
  | "offline"
  | "unknown";

export type CommunicationChannel = "wifi" | "ble-proxied";

export type QuotaRuleType =
  | "user_specific"
  | "role_based"
  | "daily"
  | "monthly"
  | "custom";

export type TimePeriod = "daily" | "monthly";

export type EnforcementAction = "reject" | "warn";

export type DeviceAuditEventType =
  | "relay_opened"
  | "relay_closed"
  | "hard_cutoff"
  | "timeout"
  | "manual_stop"
  | "error";

export type TriggerSource =
  | "backend_api"
  | "ble_command"
  | "local_timeout"
  | "hard_limit_reached"
  | "manual";

export type BLESessionStatus = "active" | "completed" | "failed" | "timeout";

export type ProxyPermissionType = "proxy" | "command";

export interface Facility {
  id: string;
  facility_name: string;
  location_address?: string;
  timezone: string;
  manager_user_id?: string;
  is_active: boolean;
  created_at: string;
}

export interface User {
  id: string;
  username: string;
  email: string;
  full_name?: string;
  role: UserRole;
  facility_id: string;
  quota_config_json?: Record<string, unknown>;
  is_active: boolean;
  last_login?: string;
  created_at: string;
  updated_at: string;
}

export interface QuotaLimitRule {
  id: string;
  facility_id: string;
  rule_type: QuotaRuleType;
  applies_to_user_id?: string;
  applies_to_role?: string;
  time_period?: TimePeriod;
  max_liters: number;
  enforcement_action: EnforcementAction;
  custom_condition_json?: Record<string, unknown>;
  is_active: boolean;
  priority: number;
  created_at: string;
  updated_at: string;
}

export interface DispensingRequest {
  id: string;
  user_id: string;
  device_id: string;
  requested_liters: number;
  approved_liters?: number;
  status: DispensingRequestStatus;
  rejection_reason?: string;
  destination?: string;
  created_at: string;
  approved_at?: string;
  dispensing_started_at?: string;
  dispensing_ended_at?: string;
}

export interface DispensingRecord {
  id: number;
  dispensing_request_id: string;
  device_id: string;
  user_id: string;
  volume_liters: number;
  measurement_timestamp: string;
  backend_received_at: string;
  communication_channel?: CommunicationChannel;
  checksum?: string;
  idempotency_key?: string;
  metadata_json?: Record<string, unknown>;
  created_at: string;
}

export interface MeasuringDevice {
  id: string;
  device_name: string;
  facility_id: string;
  device_model?: string;
  firmware_version?: string;
  mac_address?: string;
  ble_uuid?: string;
  tank_capacity_liters: number;
  current_queue_depth: number;
  last_communication_at?: string;
  last_wifi_connection_at?: string;
  last_ble_contact_at?: string;
  connectivity_status: ConnectivityStatus;
  battery_percent?: number;
  signal_strength_dbm?: number;
  is_paused: boolean;
  location_lat?: number;
  location_lng?: number;
  created_at: string;
  updated_at: string;
}

export interface DeviceAuditTrail {
  id: number;
  device_id: string;
  event_type: DeviceAuditEventType;
  dispensing_request_id?: string;
  max_liters_approved?: number;
  actual_volume_dispensed?: number;
  trigger_source: TriggerSource;
  timestamp: string;
  backend_received_at: string;
  metadata_json?: Record<string, unknown>;
  created_at: string;
}

export interface WiFiProfile {
  ssid: string;
  password?: string;
  priority: number;
  enabled: boolean;
  max_retries: number;
}

export interface WiFiConfiguration {
  id: string;
  device_id: string;
  ssid_profiles: WiFiProfile[];
  fallback_to_ble: boolean;
  ble_advertise_timeout_seconds: number;
  wifi_scan_interval_seconds: number;
  config_version: number;
  created_at: string;
  updated_at: string;
}

export interface BLESessionLog {
  id: string;
  mobile_user_id: string;
  device_id: string;
  session_start_at: string;
  session_end_at?: string;
  measurements_count: number;
  data_bytes_transferred?: number;
  status: BLESessionStatus;
  failure_reason?: string;
  signal_strength_dbm?: number;
  round_trip_latency_ms?: number;
  metadata_json?: Record<string, unknown>;
  created_at: string;
}

export interface MobileProxyPermission {
  id: string;
  user_id: string;
  device_id: string;
  permission_type: ProxyPermissionType;
  is_active: boolean;
  granted_by_user_id?: string;
  created_at: string;
}
