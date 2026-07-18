import { and, asc, eq, inArray, sql, type SQL } from 'drizzle-orm';
import { db } from '$lib/server/db';
import { bottles, grapes, wineGrapes, wines } from '$lib/server/db/schema';
import type { PageServerLoad } from './$types';

type OwnColumn = 'producer' | 'wineType' | 'country' | 'region' | 'qualityLevel' | 'color';

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
	const grape = q.get('grape');
	const priceRangeParam = q.get('price_range');
	const priceRange = priceRangeParam !== null && priceRangeParam !== '' ? Number(priceRangeParam) : null;
	const trinkreif = q.get('trinkreif') === '1';

	// Named (not positional) so each facet's option list can be computed with
	// every OTHER condition applied — a selection never leaves a sibling
	// dropdown offering a value that would produce zero results.
	const condMap: Record<string, SQL> = {};
	if (producer) condMap.producer = eq(wines.producer, producer);
	if (wineType) condMap.wineType = eq(wines.wineType, wineType);
	if (country) condMap.country = eq(wines.country, country);
	if (region) condMap.region = eq(wines.region, region);
	if (qualityLevel) condMap.qualityLevel = eq(wines.qualityLevel, qualityLevel);
	if (color) condMap.color = eq(wines.color, color as 'white' | 'red' | 'rose' | 'orange');
	if (vintage) condMap.vintage = eq(wines.vintage, Number(vintage));
	if (grape) {
		// Grapes live on the many-to-many wine_grapes table, not a wines column —
		// resolve matching wine ids first, then filter wines by inArray.
		const wineIdsForGrape = db
			.select({ wineId: wineGrapes.wineId })
			.from(wineGrapes)
			.innerJoin(grapes, eq(grapes.id, wineGrapes.grapeId))
			.where(eq(grapes.name, grape))
			.all()
			.map((r) => r.wineId);
		condMap.grape = inArray(wines.id, wineIdsForGrape);
	}
	if (trinkreif) {
		condMap.trinkreif = sql`${wines.drinkFrom} <= ${year} and ${wines.drinkUntil} >= ${year}`;
	}

	// Estimated price per wine (same value on every bottle of that wine — see
	// `min` rather than `avg` to sidestep float rounding). Computed across ALL
	// bottles up front since faceting needs it before the final wine set exists.
	const priceRows = db
		.select({ wineId: bottles.wineId, price: sql<number | null>`min(${bottles.currentValue})` })
		.from(bottles)
		.groupBy(bottles.wineId)
		.all();
	const priceByWine = new Map(priceRows.map((p) => [p.wineId, p.price]));

	// Ids of wines matching every active filter except those in `excludeKeys`.
	// Price lives on `bottles`, not `wines`, so it's applied here in JS rather
	// than through condMap.
	function facetIds(excludeKeys: string[] = []): number[] {
		const conds = Object.entries(condMap)
			.filter(([k]) => !excludeKeys.includes(k))
			.map(([, c]) => c);
		let ids = db
			.select({ id: wines.id })
			.from(wines)
			.where(conds.length ? and(...conds) : undefined)
			.all()
			.map((r) => r.id);
		if (priceRange != null && !excludeKeys.includes('price')) {
			ids = ids.filter((id) => {
				const p = priceByWine.get(id);
				return p != null && Math.floor(p / 10) * 10 === priceRange;
			});
		}
		return ids;
	}

	function distinctForOwnColumn(excludeKey: string, column: OwnColumn): string[] {
		const ids = facetIds([excludeKey]);
		if (!ids.length) return [];
		return db
			.selectDistinct({ v: wines[column] })
			.from(wines)
			.where(inArray(wines.id, ids))
			.all()
			.map((r) => r.v)
			.filter((v): v is string => !!v)
			.sort();
	}

	const matchingIds = facetIds();
	const rows = matchingIds.length
		? db
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
				.where(inArray(wines.id, matchingIds))
				.orderBy(asc(wines.producer), asc(wines.name))
				.all()
		: [];

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

	const priceBuckets = (() => {
		const ids = facetIds(['price']);
		return [
			...new Set(
				ids
					.map((id) => priceByWine.get(id))
					.filter((p): p is number => p != null)
					.map((p) => Math.floor(p / 10) * 10)
			)
		].sort((a, b) => a - b);
	})();

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

	// Distinct filter option values, each faceted against every OTHER active filter.
	const producers = distinctForOwnColumn('producer', 'producer');
	const types = distinctForOwnColumn('wineType', 'wineType');
	const countries = distinctForOwnColumn('country', 'country');
	const regions = distinctForOwnColumn('region', 'region');
	const qualityLevels = distinctForOwnColumn('qualityLevel', 'qualityLevel');
	const colors = distinctForOwnColumn('color', 'color');
	const grapeOptions = (() => {
		const ids = facetIds(['grape']);
		if (!ids.length) return [];
		return db
			.selectDistinct({ v: grapes.name })
			.from(grapes)
			.innerJoin(wineGrapes, eq(wineGrapes.grapeId, grapes.id))
			.where(inArray(wineGrapes.wineId, ids))
			.all()
			.map((r) => r.v)
			.filter((v): v is string => !!v)
			.sort();
	})();

	const winesWithStock = rows.map((r) => ({
		...r,
		grapes: grapesByWine.get(r.id) ?? [],
		inStock: countByWine.get(r.id) ?? 0,
		price: priceByWine.get(r.id) ?? null
	}));
	const filteredBottles = winesWithStock.reduce((sum, w) => sum + w.inStock, 0);
	const totalBottles = countRows.reduce((sum, c) => sum + c.n, 0);
	return {
		wines: winesWithStock,
		filters: { producers, types, countries, regions, qualityLevels, colors, priceBuckets, grapeOptions },
		active: {
			producer,
			wineType,
			country,
			region,
			color,
			vintage,
			qualityLevel,
			grape,
			priceRange,
			trinkreif
		},
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
