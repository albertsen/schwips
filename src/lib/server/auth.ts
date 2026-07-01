/**
 * Single-password auth SEAM for a future hosted deployment. No user management,
 * no users table, no login UI in v1 — only the switch and the check.
 *
 * Local default: `SCHWIPS_AUTH_PASSWORD` is unset -> auth disabled -> the
 * `handle` hook is a passthrough. When the env var is set (hosting), the hook
 * enforces a valid session cookie.
 */
import { createHmac } from 'node:crypto';

export const SESSION_COOKIE = 'schwips_session';

export function isAuthEnabled(): boolean {
	return !!process.env.SCHWIPS_AUTH_PASSWORD;
}

/** Deterministic session token derived from the shared password. */
export function sessionToken(): string {
	const password = process.env.SCHWIPS_AUTH_PASSWORD ?? '';
	return createHmac('sha256', password).update('schwips-session-v1').digest('hex');
}

export function verifySession(cookie: string | undefined): boolean {
	if (!isAuthEnabled()) return true;
	return !!cookie && cookie === sessionToken();
}
