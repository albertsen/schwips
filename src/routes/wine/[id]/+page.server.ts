import { error, fail } from '@sveltejs/kit';
import { and, asc, desc, eq } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { bottles, grapes, tastingNotes, photos, wineGrapes, wines } from '$lib/server/db/schema';
import { computeSignature } from '$lib/signature';
import type { Actions, PageServerLoad } from './$types';

/** Editable wines fields: input name -> Drizzle model property (camelCase). */
const EDITABLE: Record<string, string> = {
	producer: 'producer',
	name: 'name',
	vintage: 'vintage',
	wine_type: 'wineType',
	quality_level: 'qualityLevel',
	region: 'region',
	country: 'country',
	appellation: 'appellation',
	vineyard: 'vineyard',
	abv: 'abv',
	drink_from: 'drinkFrom',
	drink_until: 'drinkUntil',
	description: 'description',
	food_pairing: 'foodPairing',
	serving_temp_c: 'servingTempC'
};

const NUMERIC = new Set(['vintage', 'abv', 'drink_from', 'drink_until']);
const IDENTITY = new Set([
	'producer',
	'name',
	'vintage',
	'wine_type',
	'quality_level',
	'appellation',
	'vineyard'
]);

function today() {
	return new Date().toISOString().slice(0, 10);
}

function loadWine(id: number) {
	const wine = db.select().from(wines).where(eq(wines.id, id)).get();
	if (!wine) throw error(404, 'Wein nicht gefunden');

	const grapeRows = db
		.select({
			canonical: grapes.name,
			labelName: wineGrapes.labelName,
			percentage: wineGrapes.percentage
		})
		.from(wineGrapes)
		.innerJoin(grapes, eq(grapes.id, wineGrapes.grapeId))
		.where(eq(wineGrapes.wineId, id))
		.all();

	const bottleRows = db
		.select()
		.from(bottles)
		.where(eq(bottles.wineId, id))
		.orderBy(asc(bottles.status), asc(bottles.id))
		.all();

	const photoRows = db
		.select()
		.from(photos)
		.where(eq(photos.wineId, id))
		.orderBy(desc(photos.isPrimary), asc(photos.id))
		.all();

	const notes = db
		.select({
			id: tastingNotes.id,
			bottleId: tastingNotes.bottleId,
			tastedOn: tastingNotes.tastedOn,
			rating: tastingNotes.rating,
			note: tastingNotes.note
		})
		.from(tastingNotes)
		.innerJoin(bottles, eq(bottles.id, tastingNotes.bottleId))
		.where(eq(bottles.wineId, id))
		.orderBy(desc(tastingNotes.tastedOn))
		.all();

	return { wine, grapes: grapeRows, bottles: bottleRows, photos: photoRows, notes };
}

export const load: PageServerLoad = async ({ params }) => {
	return loadWine(Number(params.id));
};

export const actions: Actions = {
	markConsumed: async ({ request, params }) => {
		const form = await request.formData();
		const bottleId = Number(form.get('bottle_id'));
		if (!bottleId) return fail(400, { message: 'bottle_id fehlt' });
		db.update(bottles)
			.set({ status: 'consumed', consumedDate: today(), updatedAt: new Date() })
			.where(and(eq(bottles.id, bottleId), eq(bottles.wineId, Number(params.id))))
			.run();
		return { ok: true };
	},

	addBottle: async ({ params }) => {
		db.insert(bottles).values({ wineId: Number(params.id), status: 'in_stock' }).run();
		return { ok: true };
	},

	removeBottle: async ({ request, params }) => {
		const form = await request.formData();
		const bottleId = Number(form.get('bottle_id'));
		if (!bottleId) return fail(400, { message: 'bottle_id fehlt' });
		// Only delete an in-stock bottle; consumed bottles keep history.
		db.delete(bottles)
			.where(
				and(
					eq(bottles.id, bottleId),
					eq(bottles.wineId, Number(params.id)),
					eq(bottles.status, 'in_stock')
				)
			)
			.run();
		return { ok: true };
	},

	addTastingNote: async ({ request }) => {
		const form = await request.formData();
		const bottleId = Number(form.get('bottle_id'));
		const note = String(form.get('note') ?? '').trim();
		const ratingRaw = form.get('rating');
		if (!bottleId || !note) return fail(400, { message: 'Flasche und Notiz erforderlich' });
		db.insert(tastingNotes)
			.values({
				bottleId,
				tastedOn: String(form.get('tasted_on') || today()),
				rating: ratingRaw ? Number(ratingRaw) : null,
				note
			})
			.run();
		return { ok: true };
	},

	editField: async ({ request, params }) => {
		const id = Number(params.id);
		const form = await request.formData();
		const field = String(form.get('field') ?? '');
		if (!(field in EDITABLE)) {
			return fail(400, { message: `Feld nicht editierbar: ${field}` });
		}
		const rawValue = String(form.get('value') ?? '').trim();
		const value = rawValue === '' ? null : NUMERIC.has(field) ? Number(rawValue) : rawValue;

		const wine = db.select().from(wines).where(eq(wines.id, id)).get();
		if (!wine) throw error(404, 'Wein nicht gefunden');

		const dataSources = { ...(wine.dataSources ?? {}), [field]: 'user' as const };
		const set: Record<string, unknown> = {
			[EDITABLE[field]]: value,
			dataSources,
			updatedAt: new Date()
		};

		db.update(wines)
			.set(set as never)
			.where(eq(wines.id, id))
			.run();

		// Recompute the signature if an identity field changed.
		if (IDENTITY.has(field)) {
			const canonical = db
				.select({ name: grapes.name })
				.from(wineGrapes)
				.innerJoin(grapes, eq(grapes.id, wineGrapes.grapeId))
				.where(eq(wineGrapes.wineId, id))
				.all()
				.map((r) => r.name);
			const updated = db.select().from(wines).where(eq(wines.id, id)).get()!;
			const signature = computeSignature({
				producer: updated.producer,
				vintage: updated.vintage,
				appellation: updated.appellation,
				vineyard: updated.vineyard,
				name: updated.name,
				quality_level: updated.qualityLevel,
				wine_type: updated.wineType,
				grapes: canonical
			});
			db.update(wines).set({ wineSignature: signature }).where(eq(wines.id, id)).run();
		}

		return { ok: true };
	}
};
