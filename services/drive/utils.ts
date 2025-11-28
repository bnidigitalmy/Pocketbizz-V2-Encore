import type { SupabaseClient } from "@supabase/supabase-js";
import { APIError } from "encore.dev/api";

import type { DriveSyncLog } from "./types";

export const DRIVE_LOGS_TABLE = "google_drive_sync_logs";

export const sanitizeString = (value?: string | null): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length ? trimmed : undefined;
};

export interface DriveLogRow {
  id: string;
  business_owner_id: string;
  file_name: string;
  file_type: string;
  drive_file_id: string;
  drive_web_view_link: string;
  vendor_name: string | null;
  metadata: Record<string, unknown> | null;
  synced_at: string;
  created_at: string;
}

export const mapDriveLog = (row: DriveLogRow): DriveSyncLog => ({
  id: row.id,
  fileName: row.file_name,
  fileType: row.file_type,
  driveFileId: row.drive_file_id,
  driveWebViewLink: row.drive_web_view_link,
  vendorName: row.vendor_name ?? undefined,
  metadata: row.metadata ?? undefined,
  syncedAt: row.synced_at,
  createdAt: row.created_at,
});

export const fetchDriveLogById = async (
  client: SupabaseClient,
  ownerId: string,
  id: string
): Promise<DriveLogRow> => {
  const { data, error } = await client
    .from(DRIVE_LOGS_TABLE)
    .select("*")
    .eq("business_owner_id", ownerId)
    .eq("id", id)
    .maybeSingle();

  if (error) {
    throw APIError.internal(error.message);
  }
  if (!data) {
    throw APIError.notFound("Drive sync log not found");
  }

  return data as DriveLogRow;
};

