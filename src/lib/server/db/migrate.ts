import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import { resolve } from 'node:path';
import { ensureRuntimeDirs, RUNTIME_DATA_DIR } from '../runtime-dirs';

ensureRuntimeDirs();

const dbPath = resolve(RUNTIME_DATA_DIR, 'schwips.db');
const sqlite = new Database(dbPath);
const db = drizzle(sqlite);

migrate(db, { migrationsFolder: resolve(process.cwd(), 'drizzle') });
console.log('migrations applied');
sqlite.close();
process.exit(0);
