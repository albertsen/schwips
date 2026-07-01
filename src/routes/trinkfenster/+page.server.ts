import { and, asc, eq, isNotNull, lt, sql } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { bottles, wines } from '$lib/server/db/schema';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
	const year = new Date().getFullYear();

	const base = {
		id: wines.id,
		producer: wines.producer,
		name: wines.name,
		vintage: wines.vintage,
		drinkFrom: wines.drinkFrom,
		drinkUntil: wines.drinkUntil
	};

	const ready = db
		.select(base)
		.from(wines)
		.where(sql`${wines.drinkFrom} <= ${year} and ${wines.drinkUntil} >= ${year}`)
		.orderBy(asc(wines.drinkUntil))
		.all();

	const past = db
		.select(base)
		.from(wines)
		.where(and(isNotNull(wines.drinkUntil), lt(wines.drinkUntil, year)))
		.orderBy(asc(wines.drinkUntil))
		.all();

	// In-stock bottle count per wine (grouped, merged in JS).
	const countRows = db
		.select({ wineId: bottles.wineId, n: sql<number>`count(*)` })
		.from(bottles)
		.where(eq(bottles.status, 'in_stock'))
		.groupBy(bottles.wineId)
		.all();
	const countByWine = new Map(countRows.map((c) => [c.wineId, c.n]));
	const withCount = (rows: typeof ready) => rows.map((r) => ({ ...r, inStock: countByWine.get(r.id) ?? 0 }));

	return { ready: withCount(ready), past: withCount(past), year };
};
