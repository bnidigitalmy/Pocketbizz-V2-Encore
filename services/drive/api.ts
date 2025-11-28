import { api, APIError, type Header } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import { OnDriveFileSynced } from "./events";
import type {
  CreateSyncLogRequest,
  CreateSyncLogResponse,
  DeleteSyncLogRequest,
  DeleteSyncLogResponse,
  ListSyncLogsRequest,
  ListSyncLogsResponse,
} from "./types";
import { DRIVE_LOGS_TABLE, fetchDriveLogById, mapDriveLog, sanitizeString } from "./utils";

export const listDriveSyncLogs = api<ListSyncLogsRequest, ListSyncLogsResponse>(
  { method: "GET", path: "/google-drive/sync-logs" },
  async ({ authorization, fileType }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    let query = client
      .from(DRIVE_LOGS_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("synced_at", { ascending: false });

    const trimmedType = sanitizeString(fileType);
    if (trimmedType) {
      query = query.ilike("file_type", `%${trimmedType}%`);
    }

    const { data, error } = await query;
    if (error) {
      throw APIError.internal(error.message);
    }

    return {
      success: true,
      data: { logs: (data ?? []).map((row) => mapDriveLog(row as any)) },
    };
  }
);

export const createDriveSyncLog = api<CreateSyncLogRequest, CreateSyncLogResponse>(
  { method: "POST", path: "/google-drive/sync-logs" },
  async ({ authorization, log }) => {
    const { client, ownerId } = resolveAuthContext(authorization);

    const fileName = sanitizeString(log.fileName);
    const fileType = sanitizeString(log.fileType);
    const driveFileId = sanitizeString(log.driveFileId);
    const driveLink = sanitizeString(log.driveWebViewLink);

    if (!fileName || !fileType || !driveFileId || !driveLink) {
      throw APIError.invalidArgument("fileName, fileType, driveFileId, and driveWebViewLink are required");
    }

    const payload = {
      business_owner_id: ownerId,
      file_name: fileName,
      file_type: fileType,
      drive_file_id: driveFileId,
      drive_web_view_link: driveLink,
      vendor_name: sanitizeString(log.vendorName) ?? null,
      metadata: log.metadata ?? null,
      synced_at: log.syncedAt ?? new Date().toISOString(),
    };

    const { data, error } = await client
      .from(DRIVE_LOGS_TABLE)
      .insert(payload)
      .select("*")
      .single();

    if (error) {
      throw APIError.internal(error.message);
    }

    await OnDriveFileSynced.publish({
      logId: data.id as string,
      businessOwnerId: ownerId,
      fileType: data.file_type,
    });

    return { success: true, data: { log: mapDriveLog(data as any) } };
  }
);

export const deleteDriveSyncLog = api<DeleteSyncLogRequest, DeleteSyncLogResponse>(
  { method: "DELETE", path: "/google-drive/sync-logs/:id" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const logId = sanitizeString(id);
    if (!logId) {
      throw APIError.invalidArgument("id is required");
    }

    await fetchDriveLogById(client, ownerId, logId);
    const { error } = await client
      .from(DRIVE_LOGS_TABLE)
      .delete()
      .eq("business_owner_id", ownerId)
      .eq("id", logId);

    if (error) {
      throw APIError.internal(error.message);
    }

    return { success: true };
  }
);

interface AuthorizedOnly {
  authorization: Header<"Authorization">;
}

