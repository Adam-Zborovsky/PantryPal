import type { ImportErrorCode } from './import-errors';

export class ImportSourceError extends Error {
  constructor(
    readonly code: ImportErrorCode,
    message: string,
  ) {
    super(message);
  }
}

export interface SourceAdapter {
  supports(url: URL): boolean;
}
