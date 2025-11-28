import type { Header } from "encore.dev/api";

interface AuthorizedRequest {
  authorization: Header<"Authorization">;
}

export interface DriveSyncLog {
  id: string;
  fileName: string;
  fileType: string;
  driveFileId: string;
  driveWebViewLink: string;
  vendorName?: string;
  metadata?: Record<string, unknown>;
  syncedAt: string;
  createdAt: string;
}

export interface ListSyncLogsRequest extends AuthorizedRequest {
  fileType?: string;
}

export interface ListSyncLogsResponse {
  success: boolean;
  data?: {
    logs: DriveSyncLog[];
  };
  error?: string;
}

export interface CreateSyncLogRequest extends AuthorizedRequest {
  log: {
    fileName: string;
    fileType: string;
    driveFileId: string;
    driveWebViewLink: string;
    vendorName?: string;
    metadata?: Record<string, unknown>;
    syncedAt?: string;
  };
}

export interface CreateSyncLogResponse {
  success: boolean;
  data?: {
    log: DriveSyncLog;
  };
  error?: string;
}

export interface DeleteSyncLogRequest extends AuthorizedRequest {
  id: string;
}

export interface DeleteSyncLogResponse {
  success: boolean;
  error?: string;
}

