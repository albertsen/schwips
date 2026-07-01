/**
 * Zod schemas mirroring the Drizzle model. The import CLI validates confirmed
 * review JSON against these before any DB write.
 */
import { z } from 'zod';

const provenance = z.enum(['label', 'research', 'user']);

export const grapeEntrySchema = z.object({
	canonical: z.string(), // resolved canonical variety name
	label_name: z.string().nullable().optional(), // spelling printed on the label
	color: z.enum(['white', 'red']),
	percentage: z.number().nullable().optional()
});

export const wineFieldsSchema = z.object({
	producer: z.string(),
	name: z.string().nullable(),
	vintage: z.number().int().nullable(),
	wine_type: z.string().nullable(),
	color: z.enum(['white', 'red', 'rose', 'orange']).nullable(),
	sweetness: z.enum(['dry', 'off-dry', 'medium', 'sweet', 'noble-sweet']).nullable(),
	quality_level: z.string().nullable(),
	region: z.string().nullable(),
	country: z.string().nullable(),
	appellation: z.string().nullable(),
	vineyard: z.string().nullable(),
	abv: z.number().nullable(),
	residual_sugar_gl: z.number().nullable(),
	acidity_gl: z.number().nullable(),
	drink_from: z.number().int().nullable(),
	drink_until: z.number().int().nullable(),
	description: z.string().nullable(),
	food_pairing: z.string().nullable(),
	serving_temp_c: z.string().nullable(),
	closure: z.enum(['cork', 'screwcap', 'glass', 'crown']).nullable(),
	is_organic: z.boolean().nullable(),
	is_vegan: z.boolean().nullable(),
	external_links: z.array(z.string()).default([]),
	extra_data: z.record(z.string(), z.unknown()).default({}),
	data_sources: z.record(z.string(), provenance).default({}),
	import_confidence: z.number().min(0).max(1),
	grapes: z.array(grapeEntrySchema).default([])
});

export const bottleSchema = z.object({
	bottle_size_ml: z.number().int().default(750),
	location: z.string().nullable(),
	purchase_date: z.string().nullable(),
	purchase_price: z.number().nullable(),
	purchase_vendor: z.string().nullable(),
	current_value: z.number().nullable(),
	status: z.enum(['in_stock', 'consumed', 'gifted']).default('in_stock'),
	consumed_date: z.string().nullable(),
	personal_rating: z.number().int().min(1).max(5).nullable()
});

export const dedupSchema = z.discriminatedUnion('action', [
	z.object({ action: z.literal('new_wine') }),
	z.object({ action: z.literal('match_existing'), wine_id: z.number().int() })
]);

export const reviewBottleSchema = z.object({
	photos: z.array(z.string()), // any number of filenames in incoming/
	dedup: dedupSchema,
	wine: wineFieldsSchema,
	bottle: bottleSchema,
	confidence: z.number().min(0).max(1),
	open_questions: z.array(z.string()).optional() // German notes for the reviewer
});

export const reviewFileSchema = z.object({
	generated_at: z.string(),
	bottles: z.array(reviewBottleSchema)
});

export type GrapeEntry = z.infer<typeof grapeEntrySchema>;
export type WineFields = z.infer<typeof wineFieldsSchema>;
export type BottleInput = z.infer<typeof bottleSchema>;
export type Dedup = z.infer<typeof dedupSchema>;
export type ReviewBottle = z.infer<typeof reviewBottleSchema>;
export type ReviewFile = z.infer<typeof reviewFileSchema>;
