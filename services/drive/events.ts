import { topic } from "encore.dev/pubsub";

export interface DriveFileSyncedEvent {
  logId: string;
  businessOwnerId: string;
  fileType: string;
}

export const OnDriveFileSynced = topic<DriveFileSyncedEvent>("drive-file-synced");

