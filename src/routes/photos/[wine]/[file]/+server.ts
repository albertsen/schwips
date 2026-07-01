import { error } from '@sveltejs/kit';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { RUNTIME_PHOTOS_DIR } from '$lib/server/runtime-dirs';
import type { RequestHandler } from './$types';

const TYPES: Record<string, string> = {
	jpeg: 'image/jpeg',
	jpg: 'image/jpeg',
	png: 'image/png',
	webp: 'image/webp',
	heic: 'image/heic'
};

export const GET: RequestHandler = ({ params }) => {
	// Guard against path traversal: wine must be numeric, file a bare filename.
	if (!/^\d+$/.test(params.wine)) throw error(400, 'invalid wine id');
	if (!/^[\w.-]+$/.test(params.file) || params.file.includes('..')) {
		throw error(400, 'invalid file name');
	}

	const ext = params.file.split('.').pop()?.toLowerCase() ?? '';
	const contentType = TYPES[ext];
	if (!contentType) throw error(400, 'unsupported file type');

	const path = resolve(RUNTIME_PHOTOS_DIR, params.wine, params.file);
	if (!existsSync(path)) throw error(404, 'not found');

	const bytes = readFileSync(path);
	return new Response(new Uint8Array(bytes), {
		headers: {
			'Content-Type': contentType,
			'Cache-Control': 'private, max-age=3600'
		}
	});
};
