import log from "encore.dev/log";

export const withErrorLogging = async <T>(
  operation: string,
  action: () => Promise<T>
): Promise<T> => {
  try {
    return await action();
  } catch (error) {
    log.error(error, `operation_failed:${operation}`);
    throw error;
  }
};

export const ensureArray = <T>(value?: T | T[]): T[] => {
  if (!value) {
    return [];
  }
  return Array.isArray(value) ? value : [value];
};

export const nowISO = (): string => new Date().toISOString();

