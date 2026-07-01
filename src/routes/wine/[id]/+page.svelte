<script lang="ts">
	import {
		de,
		colorLabels,
		sweetnessLabels,
		closureLabels,
		statusLabels
	} from '$lib/i18n/de';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
	const w = $derived(data.wine);

	const inStock = $derived(data.bottles.filter((b) => b.status === 'in_stock').length);

	function grapeLabel(g: { canonical: string; labelName: string | null; percentage: number | null }) {
		const name = g.labelName ?? g.canonical;
		return g.percentage != null ? `${name} ${g.percentage}%` : name;
	}
</script>

<p class="back"><a href="/">&larr; {de.inventory}</a></p>

<h1>
	{w.producer}
	{#if w.name}<span class="cuvee">{w.name}</span>{/if}
	{#if w.vintage}<span class="vintage">{w.vintage}</span>{/if}
</h1>

<div class="layout">
	<section class="facts">
		<dl>
			{#if w.wineType}<dt>{de.wineType}</dt><dd>{w.wineType}</dd>{/if}
			{#if w.color}<dt>{de.color}</dt><dd>{colorLabels[w.color]}</dd>{/if}
			{#if w.sweetness}<dt>{de.sweetness}</dt><dd>{sweetnessLabels[w.sweetness]}</dd>{/if}
			{#if w.qualityLevel}<dt>{de.qualityLevel}</dt><dd>{w.qualityLevel}</dd>{/if}
			{#if data.grapes.length}<dt>{de.grapes}</dt><dd>{data.grapes.map(grapeLabel).join(', ')}</dd>{/if}
			{#if w.appellation}<dt>{de.appellation}</dt><dd>{w.appellation}</dd>{/if}
			{#if w.region}<dt>{de.region}</dt><dd>{w.region}{#if w.country}, {w.country}{/if}</dd>{/if}
			{#if w.vineyard}<dt>{de.vineyard}</dt><dd>{w.vineyard}</dd>{/if}
			{#if w.abv != null}<dt>{de.abv}</dt><dd>{w.abv} %</dd>{/if}
			{#if w.residualSugarGl != null}<dt>{de.residualSugar}</dt><dd>{w.residualSugarGl} g/l</dd>{/if}
			{#if w.acidityGl != null}<dt>{de.acidity}</dt><dd>{w.acidityGl} g/l</dd>{/if}
			{#if w.drinkFrom || w.drinkUntil}<dt>{de.drinkingWindow}</dt><dd>{w.drinkFrom ?? '?'}–{w.drinkUntil ?? '?'}</dd>{/if}
			{#if w.servingTempC}<dt>{de.servingTemp}</dt><dd>{w.servingTempC} °C</dd>{/if}
			{#if w.closure}<dt>{de.closure}</dt><dd>{closureLabels[w.closure]}</dd>{/if}
			{#if w.foodPairing}<dt>{de.foodPairing}</dt><dd>{w.foodPairing}</dd>{/if}
			{#if w.isOrganic}<dt>{de.organic}</dt><dd>✓</dd>{/if}
			{#if w.isVegan}<dt>{de.vegan}</dt><dd>✓</dd>{/if}
		</dl>

		{#if w.description}<p class="desc">{w.description}</p>{/if}

		{#if w.externalLinks && w.externalLinks.length}
			<ul class="links">
				{#each w.externalLinks as link (link)}<li><a href={link} rel="noreferrer">{link}</a></li>{/each}
			</ul>
		{/if}
	</section>

	{#if data.photos.length}
		<section class="gallery">
			{#each data.photos as photo (photo.id)}
				<img src="/photos/{photo.filePath}" alt="{w.producer} {w.name ?? ''}" loading="lazy" />
			{/each}
		</section>
	{/if}
</div>

<section>
	<h2>{de.bottles} · {inStock} {de.inStock}</h2>
	<table class="bottles">
		<thead>
			<tr>
				<th>{de.bottleSize}</th><th>{de.location}</th><th>{de.status}</th><th></th>
			</tr>
		</thead>
		<tbody>
			{#each data.bottles as bottle (bottle.id)}
				<tr>
					<td>{bottle.bottleSizeMl} ml</td>
					<td>{bottle.location ?? '—'}</td>
					<td>{statusLabels[bottle.status]}{#if bottle.consumedDate} ({bottle.consumedDate}){/if}</td>
					<td class="row-actions">
						{#if bottle.status === 'in_stock'}
							<form method="POST" action="?/markConsumed">
								<input type="hidden" name="bottle_id" value={bottle.id} />
								<button type="submit">{de.markConsumed}</button>
							</form>
							<form method="POST" action="?/removeBottle">
								<input type="hidden" name="bottle_id" value={bottle.id} />
								<button type="submit" class="danger">{de.removeBottle}</button>
							</form>
						{/if}
					</td>
				</tr>
			{/each}
		</tbody>
	</table>
	<form method="POST" action="?/addBottle">
		<button type="submit">{de.addBottle}</button>
	</form>
</section>

<section>
	<h2>{de.tastingNotes}</h2>
	{#if data.notes.length}
		<ul class="notes">
			{#each data.notes as note (note.id)}
				<li>
					<span class="note-meta">{note.tastedOn}{#if note.rating} · {note.rating}/5{/if}</span>
					<span>{note.note}</span>
				</li>
			{/each}
		</ul>
	{/if}
	{#if inStock > 0 || data.bottles.length > 0}
		<form method="POST" action="?/addTastingNote" class="note-form">
			<select name="bottle_id" required>
				{#each data.bottles as bottle (bottle.id)}
					<option value={bottle.id}>#{bottle.id} · {statusLabels[bottle.status]}</option>
				{/each}
			</select>
			<input type="date" name="tasted_on" />
			<input type="number" name="rating" min="1" max="5" placeholder={de.rating} />
			<input type="text" name="note" placeholder={de.addTastingNote} required />
			<button type="submit">{de.save}</button>
		</form>
	{/if}
</section>

<style>
	.back a {
		color: #78716c;
		text-decoration: none;
		font-size: 0.9rem;
	}
	h1 {
		color: #7c2d12;
	}
	.cuvee {
		font-weight: 500;
	}
	.vintage {
		color: #78716c;
	}
	.layout {
		display: grid;
		grid-template-columns: 1fr;
		gap: 1.5rem;
	}
	@media (min-width: 720px) {
		.layout {
			grid-template-columns: 3fr 2fr;
		}
	}
	dl {
		display: grid;
		grid-template-columns: max-content 1fr;
		gap: 0.35rem 1rem;
		margin: 0;
	}
	dt {
		color: #78716c;
		font-size: 0.85rem;
	}
	dd {
		margin: 0;
	}
	.desc {
		margin-top: 1rem;
		line-height: 1.5;
	}
	.links {
		font-size: 0.85rem;
		padding-left: 1rem;
	}
	.gallery {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
		gap: 0.5rem;
	}
	.gallery img {
		width: 100%;
		aspect-ratio: 1 / 1;
		border-radius: 8px;
		border: 1px solid #e7e2da;
		object-fit: cover;
		background: #f0ede8;
	}
	section {
		margin-top: 2rem;
	}
	h2 {
		font-size: 1.1rem;
		border-bottom: 1px solid #e7e2da;
		padding-bottom: 0.35rem;
	}
	table.bottles {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.9rem;
	}
	.bottles th {
		text-align: left;
		color: #78716c;
		font-weight: 500;
		padding: 0.35rem 0.5rem;
	}
	.bottles td {
		padding: 0.35rem 0.5rem;
		border-top: 1px solid #f0ede8;
	}
	.row-actions {
		display: flex;
		gap: 0.4rem;
	}
	button {
		padding: 0.3rem 0.7rem;
		border: 1px solid #d6d3d1;
		border-radius: 6px;
		background: #fff;
		cursor: pointer;
		font-size: 0.85rem;
	}
	button:hover {
		border-color: #c9a227;
	}
	button.danger:hover {
		border-color: #dc2626;
		color: #dc2626;
	}
	.notes {
		list-style: none;
		padding: 0;
		display: grid;
		gap: 0.5rem;
	}
	.notes li {
		display: grid;
		gap: 0.15rem;
		background: #fff;
		border: 1px solid #e7e2da;
		border-radius: 6px;
		padding: 0.5rem 0.75rem;
	}
	.note-meta {
		font-size: 0.8rem;
		color: #78716c;
	}
	.note-form {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-top: 0.75rem;
	}
	.note-form input[type='text'] {
		flex: 1;
		min-width: 200px;
	}
	.note-form input,
	.note-form select {
		padding: 0.3rem 0.5rem;
		border: 1px solid #d6d3d1;
		border-radius: 6px;
	}
</style>
