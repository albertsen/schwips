<script lang="ts">
	import { page } from '$app/state';
	import favicon from '$lib/assets/favicon.svg';
	import { de } from '$lib/i18n/de';

	let { children } = $props();

	// Filters set on the inventory list are carried in the URL's query string.
	// When navigating to a wine and back, that string rides along (see the
	// wine-card link in +page.svelte), so re-deriving the "Bestand" link from
	// it here restores the same filters instead of resetting to "/".
	const inventoryHref = $derived('/' + page.url.search);
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>{de.appName}</title>
</svelte:head>

<header>
	<nav>
		<a href="/" class="brand">{de.appName}</a>
		<a href={inventoryHref}>{de.inventory}</a>
	</nav>
</header>

<main>
	{@render children()}
</main>

<style>
	:global(body) {
		margin: 0;
		font-family:
			system-ui,
			-apple-system,
			'Segoe UI',
			sans-serif;
		color: #1c1917;
		background: #faf9f7;
	}
	header {
		border-bottom: 1px solid #e7e2da;
		background: #fff;
	}
	nav {
		display: flex;
		gap: 1.5rem;
		align-items: baseline;
		max-width: 960px;
		margin: 0 auto;
		padding: 1rem 1.25rem;
	}
	nav a {
		color: #57534e;
		text-decoration: none;
		font-size: 0.95rem;
	}
	nav a:hover {
		color: #1c1917;
	}
	.brand {
		font-weight: 700;
		font-size: 1.15rem;
		color: #7c2d12;
		margin-right: auto;
	}
	main {
		max-width: 960px;
		margin: 0 auto;
		padding: 1.5rem 1.25rem 4rem;
	}
</style>
