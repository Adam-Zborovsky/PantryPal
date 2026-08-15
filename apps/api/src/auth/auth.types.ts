export interface AccessClaims {
  sub: string;
  email: string;
  sessionId: string;
}

export interface AuthenticatedRequest extends Request {
  user: AccessClaims;
}
import type { Request } from 'express';
