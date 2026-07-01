/**
 * Seed common canonical grapes and their German<->international aliases so the
 * importer resolves e.g. "Pinot Grigio" to `Grauburgunder` out of the box.
 * Idempotent: safe to run repeatedly (onConflictDoNothing on unique columns).
 */
import { eq } from 'drizzle-orm';
import { db, schema } from '../src/lib/server/db/index';

type Color = 'white' | 'red';
type Seed = { name: string; color: Color; aliases?: string[] };

const SEEDS: Seed[] = [
	{ name: 'Grauburgunder', color: 'white', aliases: ['Pinot Gris', 'Pinot Grigio', 'Ruländer'] },
	{ name: 'Weißburgunder', color: 'white', aliases: ['Pinot Blanc', 'Pinot Bianco', 'Klevner'] },
	{ name: 'Spätburgunder', color: 'red', aliases: ['Pinot Noir', 'Pinot Nero', 'Blauburgunder'] },
	{ name: 'Müller-Thurgau', color: 'white', aliases: ['Rivaner'] },
	{ name: 'Zweigelt', color: 'red', aliases: ['Blauer Zweigelt'] },
	// Common no-alias varieties (canonical only).
	{ name: 'Riesling', color: 'white' },
	{ name: 'Silvaner', color: 'white' },
	{ name: 'Chardonnay', color: 'white' },
	{ name: 'Sauvignon Blanc', color: 'white' },
	{ name: 'Nebbiolo', color: 'red' },
	{ name: 'Sangiovese', color: 'red' },
	{ name: 'Merlot', color: 'red' },
	{ name: 'Cabernet Sauvignon', color: 'red' }
];

for (const seed of SEEDS) {
	db.insert(schema.grapes).values({ name: seed.name, color: seed.color }).onConflictDoNothing().run();

	const [grape] = db
		.select({ id: schema.grapes.id })
		.from(schema.grapes)
		.where(eq(schema.grapes.name, seed.name))
		.all();

	for (const alias of seed.aliases ?? []) {
		db.insert(schema.grapeAliases)
			.values({ grapeId: grape.id, alias })
			.onConflictDoNothing()
			.run();
	}
}

const grapeCount = db.select().from(schema.grapes).all().length;
const aliasCount = db.select().from(schema.grapeAliases).all().length;
console.log(`seeded grapes: ${grapeCount} canonical, ${aliasCount} aliases`);
process.exit(0);
