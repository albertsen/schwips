/**
 * German UI dictionary. Components reference keys, never German literals.
 * DB enum values stay English and are mapped to German only at the
 * presentation layer via the *Labels maps below.
 */
export const de = {
	appName: 'Schwips',
	inventory: 'Bestand',
	wines: 'Weine',
	trinkfenster: 'Trinkfenster',
	wineDetail: 'Weindetails',

	producer: 'Erzeuger',
	winery: 'Weingut',
	name: 'Name',
	vintage: 'Jahrgang',
	wineType: 'Weintyp',
	color: 'Farbe',
	sweetness: 'Geschmack',
	qualityLevel: 'Qualitätsstufe',
	region: 'Region',
	country: 'Land',
	appellation: 'Herkunftsbezeichnung',
	vineyard: 'Lage',
	grape: 'Rebsorte',
	grapes: 'Rebsorten',
	abv: 'Alkohol',
	residualSugar: 'Restzucker',
	acidity: 'Säure',
	drinkingWindow: 'Trinkreife',
	drinkFrom: 'Trinken ab',
	drinkUntil: 'Trinken bis',
	description: 'Beschreibung',
	foodPairing: 'Speiseempfehlung',
	servingTemp: 'Trinktemperatur',
	closure: 'Verschluss',
	organic: 'Bio',
	vegan: 'Vegan',

	bottles: 'Flaschen',
	bottleSize: 'Flaschengröße',
	location: 'Lagerort',
	status: 'Status',
	purchaseDate: 'Kaufdatum',
	purchasePrice: 'Kaufpreis',
	purchaseVendor: 'Händler',
	currentValue: 'Aktueller Wert',
	inStock: 'vorrätig',

	tastingNotes: 'Verkostungsnotizen',
	rating: 'Bewertung',
	tastedOn: 'Verkostet am',

	addBottle: 'Flasche hinzufügen',
	removeBottle: 'Flasche entfernen',
	markConsumed: 'Als getrunken markieren',
	addTastingNote: 'Notiz hinzufügen',
	save: 'Speichern',

	readyNow: 'Trinkreif jetzt',
	notYetReady: 'Noch nicht trinkreif',
	pastWindow: 'Trinkfenster überschritten',

	all: 'Alle',
	filter: 'Filter',
	sort: 'Sortierung',
	noWines: 'Noch keine Weine im Bestand.'
} as const;

export type MessageKey = keyof typeof de;

export function t(key: MessageKey): string {
	return de[key];
}

export const colorLabels: Record<string, string> = {
	white: 'Weiß',
	red: 'Rot',
	rose: 'Rosé',
	orange: 'Orange'
};

export const sweetnessLabels: Record<string, string> = {
	dry: 'trocken',
	'off-dry': 'halbtrocken',
	medium: 'lieblich',
	sweet: 'süß',
	'noble-sweet': 'edelsüß'
};

export const closureLabels: Record<string, string> = {
	cork: 'Kork',
	screwcap: 'Schraubverschluss',
	glass: 'Glasstopfen',
	crown: 'Kronkorken'
};

export const statusLabels: Record<string, string> = {
	in_stock: 'vorrätig',
	consumed: 'getrunken',
	gifted: 'verschenkt'
};
