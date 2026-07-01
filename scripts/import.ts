/**
 * Deterministic wine import CLI — the ONLY DB writer during import.
 *
 * Reads a confirmed review JSON, validates it against the Zod schema, executes
 * the dedup decisions, writes wines/bottles/grapes in a single transaction, and
 * (only on success) moves the grouped photos into runtime/photos/<wine_id>/ and records
 * them. On any error the transaction rolls back and no files are moved.
 *
 * Usage: npm run import -- <review-json>
 */
import { eq } from 'drizzle-orm';
import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, unlinkSync } from 'node:fs';
import { resolve } from 'node:path';
import { db, schema } from '../src/lib/server/db/index';
import { reviewFileSchema, type WineFields } from '../src/lib/import/zod';
import { computeSignature } from '../src/lib/signature';
import { RUNTIME_INCOMING_DIR, RUNTIME_PHOTOS_DIR } from '../src/lib/server/runtime-dirs';

const cwd = process.cwd();

function fail(msg: string): never {
	console.error(msg);
	process.exit(1);
}

/** Insert a brand-new wine plus its grape links; returns the new wine id. */
function insertNewWine(tx: typeof db, w: WineFields, signature: string): number {
	const inserted = tx
		.insert(schema.wines)
		.values({
			producer: w.producer,
			name: w.name,
			vintage: w.vintage,
			wineType: w.wine_type,
			color: w.color,
			sweetness: w.sweetness,
			qualityLevel: w.quality_level,
			region: w.region,
			country: w.country,
			appellation: w.appellation,
			vineyard: w.vineyard,
			abv: w.abv,
			residualSugarGl: w.residual_sugar_gl,
			acidityGl: w.acidity_gl,
			drinkFrom: w.drink_from,
			drinkUntil: w.drink_until,
			description: w.description,
			foodPairing: w.food_pairing,
			servingTempC: w.serving_temp_c,
			closure: w.closure,
			isOrganic: w.is_organic,
			isVegan: w.is_vegan,
			externalLinks: w.external_links,
			extraData: w.extra_data,
			dataSources: w.data_sources,
			importConfidence: w.import_confidence,
			wineSignature: signature
		})
		.returning({ id: schema.wines.id })
		.get();
	const wineId = inserted.id;

	for (const g of w.grapes) {
		const grapeId = tx
			.select({ id: schema.grapes.id })
			.from(schema.grapes)
			.where(eq(schema.grapes.name, g.canonical))
			.get()!.id;
		tx.insert(schema.wineGrapes)
			.values({ wineId, grapeId, percentage: g.percentage ?? null, labelName: g.label_name ?? null })
			.onConflictDoNothing()
			.run();
	}
	return wineId;
}

const arg = process.argv[2];
if (!arg) fail('usage: npm run import -- <review-json>');

const filePath = resolve(cwd, arg);
if (!existsSync(filePath)) fail(`file not found: ${filePath}`);

let raw: unknown;
try {
	raw = JSON.parse(readFileSync(filePath, 'utf-8'));
} catch (e) {
	fail(`invalid JSON: ${(e as Error).message}`);
}

const parsed = reviewFileSchema.safeParse(raw);
if (!parsed.success) {
	fail('validation failed:\n' + JSON.stringify(parsed.error.format(), null, 2));
}
const review = parsed.data;

/** Photos to move once the transaction has committed. */
type PhotoMove = { wineId: number; files: string[]; isNewWine: boolean };
const photoMoves: PhotoMove[] = [];

let insertedWines = 0;
let insertedBottles = 0;

db.transaction((tx) => {
	for (const rb of review.bottles) {
		// Resolve each grape to a canonical row; learn new aliases.
		for (const g of rb.wine.grapes) {
			tx.insert(schema.grapes).values({ name: g.canonical, color: g.color }).onConflictDoNothing().run();
			if (g.label_name && g.label_name !== g.canonical) {
				const grapeId = tx
					.select({ id: schema.grapes.id })
					.from(schema.grapes)
					.where(eq(schema.grapes.name, g.canonical))
					.get()!.id;
				tx.insert(schema.grapeAliases)
					.values({ grapeId, alias: g.label_name })
					.onConflictDoNothing()
					.run();
			}
		}

		// Resolve the wine (reuse existing, or insert new — never mutate on reuse).
		let wineId: number;
		let isNewWine = false;
		if (rb.dedup.action === 'match_existing') {
			const existing = tx
				.select({ id: schema.wines.id })
				.from(schema.wines)
				.where(eq(schema.wines.id, rb.dedup.wine_id))
				.get();
			if (!existing) throw new Error(`match_existing wine_id ${rb.dedup.wine_id} not found`);
			wineId = existing.id;
		} else {
			const w = rb.wine;
			const signature = computeSignature({
				producer: w.producer,
				vintage: w.vintage,
				appellation: w.appellation,
				vineyard: w.vineyard,
				name: w.name,
				quality_level: w.quality_level,
				wine_type: w.wine_type,
				grapes: w.grapes.map((g) => g.canonical)
			});
			// Signature-based dedup: reuse a wine with this exact signature if it
			// already exists (from a prior run OR an earlier bottle in THIS batch),
			// so a second bottle of the same wine just increments stock.
			const bySignature = tx
				.select({ id: schema.wines.id })
				.from(schema.wines)
				.where(eq(schema.wines.wineSignature, signature))
				.get();
			if (bySignature) {
				wineId = bySignature.id;
			} else {
				isNewWine = true;
				wineId = insertNewWine(tx, w, signature);
				insertedWines++;
			}
		}

		// Insert the physical bottle against the resolved wine.
		const b = rb.bottle;
		tx.insert(schema.bottles)
			.values({
				wineId,
				bottleSizeMl: b.bottle_size_ml,
				location: b.location,
				purchaseDate: b.purchase_date,
				purchasePrice: b.purchase_price,
				purchaseVendor: b.purchase_vendor,
				currentValue: b.current_value,
				status: b.status,
				consumedDate: b.consumed_date,
				personalRating: b.personal_rating
			})
			.run();
		insertedBottles++;

		if (rb.photos.length > 0) photoMoves.push({ wineId, files: rb.photos, isNewWine });
	}
});

// Transaction committed — now move photos and record them. Files are moved out
// of the transaction so a filesystem error can't leave the DB half-written.
let movedPhotos = 0;
for (const move of photoMoves) {
	const destDir = resolve(RUNTIME_PHOTOS_DIR, String(move.wineId));
	mkdirSync(destDir, { recursive: true });
	move.files.forEach((file, i) => {
		const src = resolve(RUNTIME_INCOMING_DIR, file);
		const dest = resolve(destDir, file);
		try {
			renameSync(src, dest);
		} catch (e) {
			if ((e as NodeJS.ErrnoException).code === 'EXDEV') {
				copyFileSync(src, dest);
				unlinkSync(src);
			} else {
				throw e;
			}
		}
		db.insert(schema.photos)
			.values({
				wineId: move.wineId,
				filePath: `${move.wineId}/${file}`,
				isPrimary: move.isNewWine && i === 0
			})
			.run();
		movedPhotos++;
	});
}

console.log(`inserted ${insertedWines} wines, ${insertedBottles} bottles, ${movedPhotos} photos`);
process.exit(0);
