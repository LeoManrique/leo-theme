<!--
  14-component.svelte — Svelte 5 runes, matching Desktop/leogit,
  Fullstack/leosync-src and Fullstack/mini-jnj.

  This is the densest `embedded` case in the corpus: TypeScript, markup and
  SCSS in one file, each needing its own grammar injection. If any of the three
  blocks renders flat, the Svelte grammar is missing on that editor — check
  CHECKLIST.md before blaming the theme.
-->

<script lang="ts">
  import { onMount, tick } from "svelte";
  import type { Snippet } from "svelte";

  type Severity = "debug" | "info" | "warn" | "fatal";

  interface Record {
    id: string;
    message: string;
    level: Severity;
    tags?: string[];
  }

  interface Props {
    records?: Record[];
    title?: string;
    compact?: boolean;
    children?: Snippet;
    onselect?: (record: Record) => void;
  }

  const LEVEL_WEIGHT: Record<string, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    fatal: 3,
  };

  let {
    records = [],
    title = "Log panel",
    compact = false,
    children,
    onselect,
  }: Props = $props();

  let query = $state("");
  let selectedId = $state<string | null>(null);
  let inputEl = $state<HTMLInputElement | null>(null);

  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) return records;
    return records.filter(
      ({ message, tags }) =>
        message.toLowerCase().includes(needle) ||
        tags?.some((tag) => tag.startsWith(needle)),
    );
  });

  const loudCount = $derived(
    visible.filter((r) => LEVEL_WEIGHT[r.level] >= LEVEL_WEIGHT.warn).length,
  );

  $effect(() => {
    if (selectedId === null) return;
    const found = records.find((r) => r.id === selectedId);
    if (found) onselect?.(found);
  });

  onMount(async () => {
    await tick();
    inputEl?.focus();
  });

  function select(record: Record) {
    selectedId = selectedId === record.id ? null : record.id;
  }

  function onKeyDown(event: KeyboardEvent) {
    if (event.key === "Escape") {
      query = "";
      selectedId = null;
    }
  }
</script>

<svelte:window onkeydown={onKeyDown} />

<svelte:head>
  <title>{title} — {visible.length} records</title>
</svelte:head>

<section class="log-panel" class:compact data-loud={loudCount > 0}>
  <header>
    <h2>
      {title}
      <small>({visible.length}{#if loudCount > 0}, {loudCount} loud{/if})</small>
    </h2>

    <input
      bind:this={inputEl}
      bind:value={query}
      type="search"
      placeholder="Filter…"
      spellcheck="false"
      aria-label="Filter records"
    />
  </header>

  {#if visible.length === 0}
    <p class="empty">
      Nothing matches <strong>“{query}”</strong>.
      <button type="button" onclick={() => (query = "")}>Clear</button>
    </p>
  {:else}
    <ul>
      {#each visible as record, index (record.id)}
        <li
          class="row"
          class:selected={record.id === selectedId}
          data-index={index}
          onclick={() => select(record)}
          onkeydown={(e) => e.key === "Enter" && select(record)}
          role="button"
          tabindex="0"
        >
          <span class="badge badge--{record.level}">{record.level}</span>
          <span class="message">{record.message}</span>

          {#if record.tags?.length}
            <span class="tags">
              {#each record.tags as tag}<code>{tag}</code>{/each}
            </span>
          {:else}
            <span class="tags muted">untagged</span>
          {/if}
        </li>
      {:else}
        <li class="row muted">unreachable — :else on #each</li>
      {/each}
    </ul>
  {/if}

  {#await Promise.resolve(visible.length)}
    <p>counting…</p>
  {:then total}
    <footer>{total} shown of {records.length}</footer>
  {:catch error}
    <footer class="error">{error.message}</footer>
  {/await}

  {#key selectedId}
    <p class="hint" transition:fade>
      {#if selectedId}Selected <code>{selectedId}</code>{:else}Nothing selected{/if}
    </p>
  {/key}

  {@render children?.()}

  {@html "<!-- raw html expression -->"}
</section>

<style lang="scss">
  $accent: #5996db;
  $muted: rgba(255, 255, 255, 0.38);

  .log-panel {
    display: grid;
    gap: 0.5rem;
    background: #1a1a1a;
    border-radius: 4px;

    &.compact {
      gap: 0.25rem;
      font-size: 0.9em;
    }

    header {
      display: flex;
      align-items: center;
      justify-content: space-between;

      h2 small {
        color: $muted;
        font-weight: 400;
      }
    }
  }

  .row {
    display: flex;
    gap: 0.5rem;
    cursor: pointer;

    &:hover {
      background: rgba(255, 255, 255, 0.04);
    }

    &.selected {
      background: rgba(89, 150, 219, 0.18);
      border-inline-start: 2px solid $accent;
    }
  }

  .muted {
    color: $muted;
  }

  :global(body) {
    margin: 0;
  }
</style>
