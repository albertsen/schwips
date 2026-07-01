import { sql } from 'drizzle-orm';
import {
	integer,
	primaryKey,
	real,
	sqliteTable,
	text,
	index
} from 'drizzle-orm/sqlite-core';

const now = sql`(unixepoch())`;

/**
 * A distinct wine (product / metadata). One row per wine, independent of how
 * many physical bottles are in stock. Inventory is a COUNT of `bottles`.
 */
export const wines = sqliteTable(
	'wines',
	{
		id: integer('id').primaryKey({ autoIncrement: true }),
		producer: text('producer').notNull(),
		// Proprietary / cuvée name printed by the winery (e.g. "GG", "Fumé"). May
		// be null; it is NOT the wine's identity on its own.
		name: text('name'),
		vintage: integer('vintage'), // null for NV sparkling
		wineType: text('wine_type'), // Art (Sekt, Kabinett, GG, …), free-ish
		color: text('color', { enum: ['white', 'red', 'rose', 'orange'] }),
		sweetness: text('sweetness', {
			enum: ['dry', 'off-dry', 'medium', 'sweet', 'noble-sweet']
		}),
		qualityLevel: text('quality_level'), // QbA, Prädikatswein, VDP.Große Lage, DOCG, …
		region: text('region'), // broad growing region (Toskana, Rheinhessen)
		country: text('country'),
		// Herkunftsbezeichnung / appellation (Chianti Classico, Bordeaux, Rioja).
		// May be the only origin/identity marker for Old-World wines without
		// printed grapes.
		appellation: text('appellation'),
		vineyard: text('vineyard'), // Einzellage / single vineyard
		abv: real('abv'), // alcohol % by volume
		residualSugarGl: real('residual_sugar_gl'),
		acidityGl: real('acidity_gl'),
		drinkFrom: integer('drink_from'), // year
		drinkUntil: integer('drink_until'), // year
		description: text('description'),
		foodPairing: text('food_pairing'),
		servingTempC: text('serving_temp_c'), // range, e.g. "10-12"
		closure: text('closure', { enum: ['cork', 'screwcap', 'glass', 'crown'] }),
		isOrganic: integer('is_organic', { mode: 'boolean' }),
		isVegan: integer('is_vegan', { mode: 'boolean' }),
		externalLinks: text('external_links', { mode: 'json' }).$type<string[]>(),
		// Structured catch-all for label facts with no dedicated column.
		extraData: text('extra_data', { mode: 'json' }).$type<Record<string, unknown>>(),
		// Per-field provenance: field name -> 'label' | 'research' | 'user'.
		dataSources: text('data_sources', { mode: 'json' }).$type<
			Record<string, 'label' | 'research' | 'user'>
		>(),
		importConfidence: real('import_confidence'), // 0..1
		// Normalized composite identity key, computed by src/lib/signature.ts.
		wineSignature: text('wine_signature').notNull(),
		createdAt: integer('created_at', { mode: 'timestamp' }).notNull().default(now),
		updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull().default(now)
	},
	(t) => [index('wines_signature_idx').on(t.wineSignature)]
);

/** Canonical grape variety (German-preferred name), separate from label spelling. */
export const grapes = sqliteTable('grapes', {
	id: integer('id').primaryKey({ autoIncrement: true }),
	name: text('name').notNull().unique(),
	color: text('color', { enum: ['white', 'red'] })
});

/** Maps every synonym / cross-language spelling to its canonical grape. */
export const grapeAliases = sqliteTable('grape_aliases', {
	id: integer('id').primaryKey({ autoIncrement: true }),
	grapeId: integer('grape_id')
		.notNull()
		.references(() => grapes.id),
	alias: text('alias').notNull().unique()
});

/** n:m link between a wine and its (canonical) grapes, with optional share. */
export const wineGrapes = sqliteTable(
	'wine_grapes',
	{
		wineId: integer('wine_id')
			.notNull()
			.references(() => wines.id),
		grapeId: integer('grape_id')
			.notNull()
			.references(() => grapes.id),
		percentage: real('percentage'),
		// The grape name exactly as printed on this bottle's label (e.g. "Pinot
		// Grigio"). Display uses `label_name ?? grapes.name`.
		labelName: text('label_name')
	},
	(t) => [primaryKey({ columns: [t.wineId, t.grapeId] })]
);

/** A physical bottle. Inventory = COUNT of bottles with status 'in_stock'. */
export const bottles = sqliteTable('bottles', {
	id: integer('id').primaryKey({ autoIncrement: true }),
	wineId: integer('wine_id')
		.notNull()
		.references(() => wines.id),
	bottleSizeMl: integer('bottle_size_ml').notNull().default(750),
	location: text('location'), // Lagerort, free text
	purchaseDate: text('purchase_date'), // ISO YYYY-MM-DD
	purchasePrice: real('purchase_price'), // EUR
	purchaseVendor: text('purchase_vendor'),
	currentValue: real('current_value'), // EUR
	status: text('status', { enum: ['in_stock', 'consumed', 'gifted'] })
		.notNull()
		.default('in_stock'),
	consumedDate: text('consumed_date'), // ISO YYYY-MM-DD
	personalRating: integer('personal_rating'), // 1..5
	createdAt: integer('created_at', { mode: 'timestamp' }).notNull().default(now),
	updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull().default(now)
});

/** Label photos linked to a wine, served from runtime/photos/<wine_id>/. */
export const photos = sqliteTable('photos', {
	id: integer('id').primaryKey({ autoIncrement: true }),
	wineId: integer('wine_id')
		.notNull()
		.references(() => wines.id),
	filePath: text('file_path').notNull(), // relative, e.g. "12/IMG_5106.jpeg"
	isPrimary: integer('is_primary', { mode: 'boolean' }).notNull().default(false),
	createdAt: integer('created_at', { mode: 'timestamp' }).notNull().default(now)
});

/** A tasting note for a specific bottle (so it records the bottle that was drunk). */
export const tastingNotes = sqliteTable('tasting_notes', {
	id: integer('id').primaryKey({ autoIncrement: true }),
	bottleId: integer('bottle_id')
		.notNull()
		.references(() => bottles.id),
	tastedOn: text('tasted_on'), // ISO YYYY-MM-DD
	rating: integer('rating'), // 1..5
	note: text('note'),
	createdAt: integer('created_at', { mode: 'timestamp' }).notNull().default(now)
});

export type Wine = typeof wines.$inferSelect;
export type NewWine = typeof wines.$inferInsert;
export type Grape = typeof grapes.$inferSelect;
export type NewGrape = typeof grapes.$inferInsert;
export type GrapeAlias = typeof grapeAliases.$inferSelect;
export type NewGrapeAlias = typeof grapeAliases.$inferInsert;
export type WineGrape = typeof wineGrapes.$inferSelect;
export type NewWineGrape = typeof wineGrapes.$inferInsert;
export type Bottle = typeof bottles.$inferSelect;
export type NewBottle = typeof bottles.$inferInsert;
export type Photo = typeof photos.$inferSelect;
export type NewPhoto = typeof photos.$inferInsert;
export type TastingNote = typeof tastingNotes.$inferSelect;
export type NewTastingNote = typeof tastingNotes.$inferInsert;
