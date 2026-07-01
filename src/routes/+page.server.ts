import { and, asc, eq, inArray, sql } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { bottles, grapes, wineGrapes, wines } from '$lib/server/db/schema';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ url }) => {
	const year = new Date().getFullYear();
	const q = url.searchParams;

	const producer = q.get('producer');
	const wineType = q.get('wine_type');
	const country = q.get('country');
	const region = q.get('region');
	const color = q.get('color');
	const vintage = q.get('vintage');
	const qualityLevel = q.get('quality_level');
	const trinkreif = q.get('trinkreif') === '1';

	const conditions = [];
	if (producer) conditions.push(eq(wines.producer, producer));
	if (wineType) conditions.push(eq(wines.wineType, wineType));
	if (country) conditions.push(eq(wines.country, country));
	if (region) conditions.push(eq(wines.region, region));
	if (qualityLevel) conditions.push(eq(wines.qualityLevel, qualityLevel));
	if (color) conditions.push(eq(wines.color, color as 'white' | 'red' | 'rose' | 'orange'));
	if (vintage) conditions.push(eq(wines.vintage, Number(vintage)));
	if (trinkreif) {
		conditions.push(sql`${wines.drinkFrom} <= ${year} and ${wines.drinkUntil} >= ${year}`);
	}

	const rows = db
		.select({
			id: wines.id,
			producer: wines.producer,
			name: wines.name,
			vintage: wines.vintage,
			wineType: wines.wineType,
			color: wines.color,
			country: wines.country,
			region: wines.region,
			appellation: wines.appellation,
			qualityLevel: wines.qualityLevel,
			drinkFrom: wines.drinkFrom,
			drinkUntil: wines.drinkUntil
		})
		.from(wines)
		.where(conditions.length ? and(...conditions) : undefined)
		.orderBy(asc(wines.producer), asc(wines.name))
		.all();

	// In-stock bottle count per wine (grouped, merged in JS — a correlated
	// subquery in a sql template renders unqualified columns and mis-binds).
	const countRows = db
		.select({ wineId: bottles.wineId, n: sql<number>`count(*)` })
		.from(bottles)
		.where(eq(bottles.status, 'in_stock'))
		.groupBy(bottles.wineId)
		.all();
	const countByWine = new Map(countRows.map((c) => [c.wineId, c.n]));
	const totalWines = db.select({ id: wines.id }).from(wines).all().length;

	// Grape display names per wine (label_name ?? canonical), grouped in JS.
	const wineIds = rows.map((r) => r.id);
	const grapeRows = wineIds.length
		? db
				.select({
					wineId: wineGrapes.wineId,
					canonical: grapes.name,
					labelName: wineGrapes.labelName
				})
				.from(wineGrapes)
				.innerJoin(grapes, eq(grapes.id, wineGrapes.grapeId))
				.where(inArray(wineGrapes.wineId, wineIds))
				.all()
		: [];

	const grapesByWine = new Map<number, string[]>();
	for (const g of grapeRows) {
		const list = grapesByWine.get(g.wineId) ?? [];
		list.push(g.labelName ?? g.canonical);
		grapesByWine.set(g.wineId, list);
	}

	// Distinct filter option values.
	const producers = db
		.selectDistinct({ v: wines.producer })
		.from(wines)
		.all()
		.map((r) => r.v)
		.filter((v): v is string => !!v)
		.sort();
	const types = db
		.selectDistinct({ v: wines.wineType })
		.from(wines)
		.all()
		.map((r) => r.v)
		.filter((v): v is string => !!v)
		.sort();
	const countries = db
		.selectDistinct({ v: wines.country })
		.from(wines)
		.all()
		.map((r) => r.v)
		.filter((v): v is string => !!v)
		.sort();
	const regions = db
		.selectDistinct({ v: wines.region })
		.from(wines)
		.all()
		.map((r) => r.v)
		.filter((v): v is string => !!v)
		.sort();
	const qualityLevels = db
		.selectDistinct({ v: wines.qualityLevel })
		.from(wines)
		.all()
		.map((r) => r.v)
		.filter((v): v is string => !!v)
		.sort();

	const winesWithStock = rows.map((r) => ({
		...r,
		grapes: grapesByWine.get(r.id) ?? [],
		inStock: countByWine.get(r.id) ?? 0
	}));
	const filteredBottles = winesWithStock.reduce((sum, w) => sum + w.inStock, 0);
	const totalBottles = countRows.reduce((sum, c) => sum + c.n, 0);
	return {
		wines: winesWithStock,
		filters: { producers, types, countries, regions, qualityLevels },
		active: { producer, wineType, country, region, color, vintage, qualityLevel, trinkreif },
		// Count of distinct wines (Bestand cards) matching the filter, out of
		// all distinct wines — each card is "ein Wein", bottle count lives on
		// the card itself. Bottle totals shown alongside in parentheses.
		counts: {
			filtered: winesWithStock.length,
			total: totalWines,
			filteredBottles,
			totalBottles
		}
	};
};
