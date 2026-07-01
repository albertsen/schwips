<script lang="ts">
	import { de } from '$lib/i18n/de';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	type Row = PageData['ready'][number];
</script>

<h1>{de.trinkfenster}</h1>

{#snippet list(rows: Row[])}
	{#if rows.length === 0}
		<p class="empty">—</p>
	{:else}
		<ul>
			{#each rows as w (w.id)}
				<li>
					<a href="/wine/{w.id}">
						<span>{w.producer}{#if w.name} {w.name}{/if}{#if w.vintage} · {w.vintage}{/if}</span>
						<span class="window">{w.drinkFrom ?? '?'}–{w.drinkUntil ?? '?'}</span>
						<span class="count">{w.inStock} × {de.bottles}</span>
					</a>
				</li>
			{/each}
		</ul>
	{/if}
{/snippet}

<h2>{de.readyNow} ({data.year})</h2>
{@render list(data.ready)}

<h2 class="past">{de.pastWindow}</h2>
{@render list(data.past)}

<style>
	h1 {
		color: #7c2d12;
	}
	h2 {
		font-size: 1.05rem;
		margin-top: 1.75rem;
		border-bottom: 1px solid #e7e2da;
		padding-bottom: 0.3rem;
	}
	h2.past {
		color: #b45309;
	}
	.empty {
		color: #a8a29e;
	}
	ul {
		list-style: none;
		padding: 0;
		display: grid;
		gap: 0.5rem;
	}
	a {
		display: flex;
		align-items: baseline;
		gap: 1rem;
		padding: 0.6rem 0.9rem;
		background: #fff;
		border: 1px solid #e7e2da;
		border-radius: 8px;
		text-decoration: none;
		color: inherit;
	}
	a:hover {
		border-color: #c9a227;
	}
	.window {
		color: #78716c;
		font-size: 0.9rem;
	}
	.count {
		margin-left: auto;
		font-size: 0.85rem;
	}
</style>
