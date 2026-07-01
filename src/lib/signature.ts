/**
 * Composite natural identity for a wine, used for dedup. Shared by the web app
 * (on write) and the import CLI so signatures are always consistent.
 *
 * Grapes must be passed as CANONICAL names (aliases resolved by the caller), so
 * a "Grauburgunder" and a "Pinot Grigio" of the same wine yield the same
 * signature. Including `appellation` gives Old-World wines without printed
 * grapes (e.g. a Chianti) a stable, distinguishing key.
 */

export interface SignatureInput {
	producer?: string | null;
	vintage?: number | string | null;
	appellation?: string | null;
	vineyard?: string | null;
	name?: string | null;
	quality_level?: string | null;
	wine_type?: string | null;
	grapes?: string[] | null;
}

const GERMAN_FOLDS: Array<[RegExp, string]> = [
	[/ä/g, 'a'],
	[/ö/g, 'o'],
	[/ü/g, 'u'],
	[/ß/g, 'ss']
];

function normalize(part: string | number | null | undefined): string {
	if (part === null || part === undefined) return '';
	let s = String(part).toLowerCase();
	for (const [re, to] of GERMAN_FOLDS) s = s.replace(re, to);
	// Strip remaining diacritics (é, à, ñ, …).
	s = s.normalize('NFKD').replace(/[̀-ͯ]/g, '');
	// Collapse whitespace runs to a single space, trim.
	return s.replace(/\s+/g, ' ').trim();
}

export function computeSignature(w: SignatureInput): string {
	const grapes = (w.grapes ?? [])
		.map(normalize)
		.filter((g) => g.length > 0)
		.sort()
		.join(',');

	return [
		normalize(w.producer),
		normalize(w.vintage),
		normalize(w.appellation),
		normalize(w.vineyard),
		normalize(w.name),
		normalize(w.quality_level),
		normalize(w.wine_type),
		grapes
	].join('|');
}
