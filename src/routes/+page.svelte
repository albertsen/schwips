<script lang="ts">
	import { de, colorLabels } from '$lib/i18n/de';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	let filtersOpen = $state(false);

	const hasActiveFilters = $derived(Object.values(data.active).some((v) => v != null && v !== false));

	const year = new Date().getFullYear();
	function isReady(from: number | null, until: number | null) {
		return from != null && until != null && from <= year && year <= until;
	}
	function isNotYetReady(from: number | null) {
		return from != null && year < from;
	}

	function formatPrice(v: number) {
		return v.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
	}

	// Third row: Name · Region/Lage · Qualitätseinstufung (Typ · Rebsorte · Jahrgang share the row above,
	// Preis sits top-right in the head row).
	function subline(w: PageData['wines'][number]) {
		const parts: string[] = [];
		if (w.name) parts.push(w.name);
		if (w.appellation) parts.push(w.appellation);
		else if (w.region) parts.push(w.region);
		if (w.qualityLevel) parts.push(w.qualityLevel);
		return parts.join(' · ');
	}
</script>

<h1>
	{de.inventory}
	<span class="count-badge"
		>{data.counts.filtered}/{data.counts.total} {de.wines} - {data.counts
			.filteredBottles}/{data.counts.totalBottles} {de.bottles}</span
	>
</h1>

<button
	type="button"
	class="filter-toggle"
	aria-expanded={filtersOpen}
	onclick={() => (filtersOpen = !filtersOpen)}
>
	{de.filter}
</button>

<div class="layout">
	<aside class="filters-panel" class:open={filtersOpen}>
		<form method="GET" class="filters">
			<label>
				{de.color}
				<select name="color" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each Object.entries(colorLabels) as [value, label] (value)}
						<option {value} selected={data.active.color === value}>{label}</option>
					{/each}
				</select>
			</label>
			<label>
				{de.wineType}
				<select name="wine_type" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.types as type (type)}
						<option value={type} selected={data.active.wineType === type}>{type}</option>
					{/each}
				</select>
			</label>
			<label>
				{de.grape}
				<select name="grape" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.grapeOptions as g (g)}
						<option value={g} selected={data.active.grape === g}>{g}</option>
					{/each}
				</select>
			</label>
			<label>
				{de.country}
				<select name="country" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.countries as country (country)}
						<option value={country} selected={data.active.country === country}>{country}</option>
					{/each}
				</select>
			</label>
			<label>
				{de.region}
				<select name="region" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.regions as region (region)}
						<option value={region} selected={data.active.region === region}>{region}</option>
					{/each}
				</select>
			</label>
			<label>
				{de.winery}
				<select name="producer" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.producers as producer (producer)}
						<option value={producer} selected={data.active.producer === producer}
							>{producer}</option
						>
					{/each}
				</select>
			</label>
			<label>
				{de.qualityLevel}
				<select name="quality_level" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.qualityLevels as ql (ql)}
						<option value={ql} selected={data.active.qualityLevel === ql}>{ql}</option>
					{/each}
				</select>
			</label>
			<label>
				{de.price}
				<select name="price_range" onchange={(e) => e.currentTarget.form?.requestSubmit()}>
					<option value="">{de.all}</option>
					{#each data.filters.priceBuckets as bucket (bucket)}
						<option value={bucket} selected={data.active.priceRange === bucket}
							>{bucket}–{bucket + 10} €</option
						>
					{/each}
				</select>
			</label>
			<label class="check">
				<input
					type="checkbox"
					name="trinkreif"
					value="1"
					checked={data.active.trinkreif}
					onchange={(e) => e.currentTarget.form?.requestSubmit()}
				/>
				{de.readyNow}
			</label>
		</form>
		{#if hasActiveFilters}
			<a href="/" class="reset-filters">{de.resetFilters}</a>
		{/if}
	</aside>

	<div class="content">
		{#if data.wines.length === 0}
			<p class="empty">{de.noWines}</p>
		{:else}
			<ul class="wine-list">
				{#each data.wines as wine (wine.id)}
					<li>
						<a href="/wine/{wine.id}">
							<span class="head">
								<span class="producer">{wine.producer}</span>
								{#if wine.price != null}<span class="price">{formatPrice(wine.price)}</span>{/if}
							</span>
							<span class="type-row">
								{#if wine.wineType}<span class="type">{wine.wineType}</span>{/if}
								{#if wine.grapes.length}<span class="grape">{wine.grapes.join(', ')}</span>{/if}
								{#if wine.vintage}<span class="vintage">{wine.vintage}</span>{/if}
							</span>
							{#if subline(wine)}<span class="sub">{subline(wine)}</span>{/if}
							<span class="meta">
								{#if wine.color}<span class="tag color-{wine.color}"
										>{colorLabels[wine.color]}</span
									>{/if}
								{#if isReady(wine.drinkFrom, wine.drinkUntil)}<span class="tag ready"
										>{de.readyNow}</span
									>{:else if isNotYetReady(wine.drinkFrom)}<span class="tag not-ready"
										>{de.notYetReady}</span
									>{/if}
								<span class="count">{wine.inStock} {de.bottles}</span>
							</span>
						</a>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
</div>

<style>
	h1 {
		color: #7c2d12;
	}
	.count-badge {
		font-size: 0.9rem;
		font-weight: 400;
		color: #78716c;
		vertical-align: middle;
	}
	.filter-toggle {
		display: none;
	}
	.layout {
		display: block;
	}
	.filters-panel {
		margin-bottom: 1.5rem;
	}
	.filters {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
		align-items: end;
	}
	.filters label {
		display: flex;
		flex-direction: column;
		font-size: 0.8rem;
		color: #57534e;
		gap: 0.25rem;
	}
	.filters label.check {
		flex-direction: row;
		align-items: center;
		gap: 0.4rem;
	}
	select {
		padding: 0.35rem 0.5rem;
		border: 1px solid #d6d3d1;
		border-radius: 6px;
		background: #fff;
	}
	.empty {
		color: #78716c;
	}
	.reset-filters {
		display: inline-block;
		margin-top: 0.75rem;
		font-size: 0.8rem;
		color: #78716c;
		text-decoration: underline;
	}
	.reset-filters:hover {
		color: #c9a227;
	}

	/* Narrow: filters collapse behind a toggle button instead of a sidebar. */
	@media (max-width: 719px) {
		.filter-toggle {
			display: inline-flex;
			align-items: center;
			gap: 0.4rem;
			margin-bottom: 1rem;
			padding: 0.5rem 0.9rem;
			border: 1px solid #d6d3d1;
			border-radius: 6px;
			background: #fff;
			color: #57534e;
			font-size: 0.9rem;
			cursor: pointer;
		}
		.filter-toggle:hover {
			border-color: #c9a227;
		}
		.filters-panel {
			display: none;
		}
		.filters-panel.open {
			display: block;
		}
	}

	/* Wide: sidebar layout, filters always visible, toggle button hidden. */
	@media (min-width: 720px) {
		/* Lines up with the wine list (the grid's content column), not the sidebar. */
		h1 {
			margin-left: calc(200px + 2rem);
		}
		.layout {
			display: grid;
			grid-template-columns: 200px 1fr;
			gap: 2rem;
			align-items: start;
		}
		.filters-panel {
			margin-bottom: 0;
			position: sticky;
			top: 1rem;
		}
		.filters {
			flex-direction: column;
			align-items: stretch;
			flex-wrap: nowrap;
			gap: 1rem;
		}
		.filters select {
			width: 100%;
		}
		.filters label.check {
			flex-direction: row;
		}
	}
	.wine-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: grid;
		gap: 0.6rem;
	}
	.wine-list a {
		display: grid;
		gap: 0.25rem;
		padding: 0.85rem 1rem;
		background: #fff;
		border: 1px solid #e7e2da;
		border-radius: 8px;
		text-decoration: none;
		color: inherit;
	}
	.wine-list a:hover {
		border-color: #c9a227;
	}
	.head {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		font-weight: 600;
	}
	.price {
		font-weight: 400;
		font-size: 0.9rem;
		color: #78716c;
		white-space: nowrap;
	}
	.vintage {
		color: #78716c;
	}
	.type-row {
		display: flex;
		align-items: baseline;
		flex-wrap: wrap;
		gap: 0.5rem;
		font-size: 0.85rem;
	}
	.type {
		font-size: 0.78rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: #a16207;
		font-weight: 600;
	}
	.grape {
		color: #57534e;
	}
	.type-row .vintage {
		color: #1c1917;
	}
	/* Small middot separators between Typ · Rebsorte · Jahrgang. */
	.type-row .grape::before,
	.type-row .vintage::before {
		content: '·';
		margin-right: 0.5rem;
		color: #a8a29e;
		font-weight: 400;
	}
	.sub {
		font-size: 0.9rem;
		color: #57534e;
	}
	.meta {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		margin-top: 0.2rem;
	}
	.tag {
		font-size: 0.75rem;
		padding: 0.1rem 0.5rem;
		border-radius: 999px;
		background: #f0ede8;
		color: #57534e;
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
	}
	.tag.ready {
		background: #dcfce7;
		color: #166534;
	}
	.tag.not-ready {
		background: #fee2e2;
		color: #b91c1c;
	}
	/* Colour tags tinted by wine colour, with a leading dot. */
	.tag[class*='color-']::before {
		content: '';
		width: 0.55rem;
		height: 0.55rem;
		border-radius: 50%;
		background: currentColor;
	}
	.tag.color-white {
		background: #ecece9;
		color: #57534e;
	}
	.tag.color-red {
		background: #fecaca;
		color: #991b1b;
	}
	.tag.color-rose {
		background: #fbcfe8;
		color: #9d174d;
	}
	.tag.color-orange {
		background: #ffedd5;
		color: #c2410c;
	}
	.count {
		margin-left: auto;
		font-size: 0.85rem;
		color: #1c1917;
	}
</style>
