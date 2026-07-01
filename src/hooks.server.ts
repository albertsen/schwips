import { redirect, type Handle } from '@sveltejs/kit';
import { SESSION_COOKIE, isAuthEnabled, verifySession } from '$lib/server/auth';
import { ensureRuntimeDirs } from '$lib/server/runtime-dirs';

// Runs once when the server process starts, before the first request —
// `runtime/` is gitignored so a fresh clone has none of it on disk yet.
// (Importing `$lib/server/db` elsewhere also triggers this + migrations, but
// this guarantees it even for a request that never touches the DB module.)
ensureRuntimeDirs();

const LOGIN_PATH = '/login'; // route/UI out of scope for v1

export const handle: Handle = async ({ event, resolve }) => {
	// Local default: auth disabled -> no-op passthrough.
	if (!isAuthEnabled()) return resolve(event);

	const isLogin = event.url.pathname === LOGIN_PATH;
	if (!isLogin && !verifySession(event.cookies.get(SESSION_COOKIE))) {
		throw redirect(303, LOGIN_PATH);
	}
	return resolve(event);
};
