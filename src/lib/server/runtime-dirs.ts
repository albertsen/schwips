/**
 * `runtime/` holds everything that isn't source code (SQLite file, imported
 * photos, the import inbox) and is entirely gitignored, so a fresh clone has
 * none of it on disk. Call `ensureRuntimeDirs()` before touching any path
 * below it — it's idempotent, safe to call on every process start.
 */
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const cwd = process.cwd();

export const RUNTIME_DIR = resolve(cwd, 'runtime');
export const RUNTIME_DATA_DIR = resolve(RUNTIME_DIR, 'data');
export const RUNTIME_PHOTOS_DIR = resolve(RUNTIME_DIR, 'photos');
export const RUNTIME_INCOMING_DIR = resolve(RUNTIME_DIR, 'incoming');
export const RUNTIME_INCOMING_REVIEW_DIR = resolve(RUNTIME_INCOMING_DIR, 'review');

export function ensureRuntimeDirs(): void {
	for (const dir of [RUNTIME_DATA_DIR, RUNTIME_PHOTOS_DIR, RUNTIME_INCOMING_REVIEW_DIR]) {
		mkdirSync(dir, { recursive: true });
	}
}
