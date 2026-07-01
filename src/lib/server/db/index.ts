import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import { resolve } from 'node:path';
import * as schema from './schema';
import { ensureRuntimeDirs, RUNTIME_DATA_DIR } from '../runtime-dirs';

// runtime/ is gitignored — a fresh clone has neither the directory nor the
// SQLite file. Create the tree and apply any pending migrations before
// opening, so every entry point (dev server, import CLI, seed script) just
// works without a manual setup step.
ensureRuntimeDirs();

const dbPath = resolve(RUNTIME_DATA_DIR, 'schwips.db');

const sqlite = new Database(dbPath);
sqlite.pragma('foreign_keys = ON');

const drizzleDb = drizzle(sqlite, { schema });
migrate(drizzleDb, { migrationsFolder: resolve(process.cwd(), 'drizzle') });

export const db = drizzleDb;
export { schema };
