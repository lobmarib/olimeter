/** Shared API request/response types matching OpenAPI contracts */

import type { DispensingRequestStatus, CommunicationChannel } from "./models";

// --- Dispensing Request API (contracts/dispensing-request.openapi.yaml) ---

export interface CreateDispensingRequestBody {
  device_id: string;
  requested_liters: number;
  destination?: string;
}

export interface DispensingRequestApprovedResponse {
  id: string;
  status: "approved" | "pending";
  approved_liters: number;
  created_at: string;
}

export interface DispensingRequestRejectedResponse {
  status: "rejected";
  reason: "quota_exceeded" | "device_offline" | "invalid_request";
  approved_liters: 0;
  message?: string;
}

export type CreateDispensingRequestResponse =
  | DispensingRequestApprovedResponse
  | DispensingRequestRejectedResponse;

export interface DispensingRequestListItem {
  id: string;
  user_id: string;
  device_id: string;
  requested_liters: number;
  approved_liters?: number;
  status: DispensingRequestStatus;
  rejection_reason?: string;
  created_at: string;
  approved_at?: string;
}

// --- Measurement API (contracts/measurements.openapi.yaml) ---

export interface RecordMeasurementHeaders {
  "Device-ID": string;
  "Idempotency-Key": string;
  "X-Checksum": string;
  "Communication-Channel"?: CommunicationChannel;
}

export interface RecordMeasurementBody {
  volume_liters: number;
  timestamp: string;
  dispensing_request_id: string;
  battery_percent?: number;
  signal_strength_dbm?: number;
}

export interface MeasurementRecordedResponse {
  id: string;
  status: "recorded";
  created_at: string;
}

export interface MeasurementDuplicateResponse {
  status: "already_processed";
  original_record_id: string;
}

// --- Device Relay Control API ---

export interface RelayActivateBody {
  dispensing_request_id: string;
  max_liters: number;
}

export interface RelayControlResponse {
  status: "success" | "offline_queued";
  timestamp: string;
}

// --- History API ---

export interface HistoryQueryParams {
  start_date?: string;
  end_date?: string;
  limit?: number;
  offset?: number;
  sort_by?: "date" | "volume";
  sort_order?: "asc" | "desc";
}

// --- Admin API ---

export interface AdminDispensingSummary {
  total_liters_dispensed: number;
  total_requests: number;
  active_devices: number;
  period_start: string;
  period_end: string;
  by_user: Array<{
    user_id: string;
    username: string;
    total_liters: number;
    request_count: number;
  }>;
  by_device: Array<{
    device_id: string;
    device_name: string;
    total_liters: number;
    connectivity_status: string;
  }>;
}

// --- Paginated response wrapper ---

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  limit: number;
  offset: number;
}

// --- Error response ---

export interface ApiError {
  error: string;
  message: string;
  status: number;
  timestamp: string;
}
