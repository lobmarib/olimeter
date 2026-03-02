/**
 * Frontend type definitions matching backend models.
 * Mirrors shared/types/models.ts for frontend-specific use.
 */

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
  created_at: string;
}

export interface MeasuringDevice {
  id: string;
  device_name: string;
  facility_id: string;
  device_model?: string;
  firmware_version?: string;
  tank_capacity_liters: number;
  connectivity_status: ConnectivityStatus;
  battery_percent?: number;
  signal_strength_dbm?: number;
  is_paused: boolean;
  last_communication_at?: string;
}

export interface User {
  id: string;
  username: string;
  email: string;
  full_name?: string;
  role: UserRole;
  facility_id: string;
  is_active: boolean;
}
