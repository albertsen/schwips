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
	// Same estimated price on every bottle of a wine — show it once.
	const price = $derived(data.bottles.find((b) => b.currentValue != null)?.currentValue ?? null);

	function grapeLabel(g: { canonical: string; labelName: string | null; percentage: number | null }) {
		const name = g.labelName ?? g.canonical;
		return g.percentage != null ? `${name} ${g.percentage}%` : name;
	}

	function formatPrice(v: number) {
		return v.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
	}

	const stars = [1, 2, 3, 4, 5];
	const todayIso = new Date().toISOString().slice(0, 10);
</script>

<p class="back"><a href="/">&larr; {de.inventory}</a></p>

<h1>
	{w.producer}
	{#if w.name}<span class="cuvee">{w.name}</span>{/if}
	{#if w.vintage}<span class="vintage">{w.vintage}</span>{/if}
</h1>

<form method="POST" action="?/setRating" class="rating-form">
	{#each stars as n (n)}
		<button
			type="submit"
			name="rating"
			value={n}
			class="star"
			class:filled={w.rating != null && n <= w.rating}
			aria-label="{n} von 5 Sternen"
		>
			★
		</button>
	{/each}
	{#if w.rating != null}
		<button type="submit" name="rating" value="" class="clear-rating">{de.resetRating}</button>
	{/if}
</form>

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
			{#if price != null}<dt>{de.price}</dt><dd>{formatPrice(price)}</dd>{/if}
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
					<td>
						{statusLabels[bottle.status]}
						{#if bottle.status === 'consumed'}
							<form method="POST" action="?/editConsumedDate" class="consumed-date-form">
								<input type="hidden" name="bottle_id" value={bottle.id} />
								<input
									type="date"
									name="consumed_date"
									value={bottle.consumedDate ?? ''}
									onchange={(e) => e.currentTarget.form?.requestSubmit()}
								/>
							</form>
						{/if}
					</td>
					<td class="row-actions">
						{#if bottle.status === 'in_stock'}
							<form method="POST" action="?/markConsumed" class="consume-form">
								<input type="hidden" name="bottle_id" value={bottle.id} />
								<input type="date" name="consumed_date" value={todayIso} />
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
	.rating-form {
		display: flex;
		align-items: center;
		gap: 0.1rem;
		margin-top: 0.25rem;
	}
	.star {
		background: none;
		border: none;
		padding: 0.1rem;
		font-size: 1.4rem;
		line-height: 1;
		color: #d6d3d1;
		cursor: pointer;
	}
	.star:hover {
		color: #c9a227;
	}
	.star.filled {
		color: #c9a227;
	}
	.clear-rating {
		margin-left: 0.5rem;
		border: none;
		background: none;
		padding: 0;
		font-size: 0.75rem;
		color: #78716c;
		text-decoration: underline;
		cursor: pointer;
	}
	.consumed-date-form {
		display: inline-block;
		margin-left: 0.4rem;
	}
	.consumed-date-form input,
	.consume-form input {
		padding: 0.2rem 0.4rem;
		border: 1px solid #d6d3d1;
		border-radius: 6px;
		font-size: 0.85rem;
	}
	.consume-form {
		display: flex;
		align-items: center;
		gap: 0.4rem;
	}
</style>
