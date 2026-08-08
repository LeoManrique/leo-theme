/**
 * Exercises the TSX token surface — 529 .tsx files across lms-github-desktop,
 * todoist-lms and trivia-fullstack make this the busiest UI language here.
 *
 * JSX is the only sample besides 07-page.html that reaches Zed's `tag` capture,
 * and the only place where tag names, attribute names and expression containers
 * have to stay visually separable from each other.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, ReactNode } from "react";

// ── Types ────────────────────────────────────────────────────────────────────

export type Severity = "debug" | "info" | "warn" | "fatal";

export interface Record {
  readonly id: string;
  message: string;
  level: Severity;
  tags?: string[];
  meta?: Readonly<{ attempt: number; ok: boolean }>;
}

type Filter<T> = (item: T, index: number) => boolean;

export enum Panel {
  Sidebar = "sidebar",
  Editor = "editor",
  Terminal = "terminal",
}

const LEVEL_WEIGHT = {
  debug: 0,
  info: 1,
  warn: 2,
  fatal: 3,
} as const satisfies globalThis.Record<Severity, number>;

const ID_PATTERN = /^rec_[0-9a-f]{8}$/iu;
const MAX_VISIBLE = 50;

// ── Helpers ──────────────────────────────────────────────────────────────────

function isLoud({ level }: Record): boolean {
  return LEVEL_WEIGHT[level] >= LEVEL_WEIGHT.warn;
}

async function fetchRecords(panel: Panel, signal?: AbortSignal): Promise<Record[]> {
  const response = await fetch(`/api/records?panel=${encodeURIComponent(panel)}`, {
    headers: { Accept: "application/json" },
    signal,
  });

  if (!response.ok) {
    throw new Error(`records: ${response.status} ${response.statusText}`);
  }

  const body = (await response.json()) as { records?: Record[] };
  return body.records ?? [];
}

function partition<T>(items: readonly T[], predicate: Filter<T>): [T[], T[]] {
  const yes: T[] = [];
  const no: T[] = [];
  items.forEach((item, i) => (predicate(item, i) ? yes : no).push(item));
  return [yes, no];
}

// ── Presentational ───────────────────────────────────────────────────────────

interface BadgeProps {
  level: Severity;
  children?: ReactNode;
  compact?: boolean;
}

const badgeStyle: CSSProperties = {
  fontVariantNumeric: "tabular-nums",
  letterSpacing: "0.02em",
};

function Badge({ level, children, compact = false }: BadgeProps) {
  return (
    <span
      className={`badge badge--${level}${compact ? " badge--compact" : ""}`}
      style={badgeStyle}
      data-level={level}
      aria-label={`severity ${level}`}
      title={level.toUpperCase()}
    >
      {children ?? level}
    </span>
  );
}

// ── Container ────────────────────────────────────────────────────────────────

export interface LogPanelProps {
  panel?: Panel;
  initial?: Record[];
  onSelect?: (record: Record) => void;
}

export default function LogPanel({
  panel = Panel.Editor,
  initial = [],
  onSelect,
}: LogPanelProps) {
  const [records, setRecords] = useState<Record[]>(initial);
  const [query, setQuery] = useState("");
  const [error, setError] = useState<Error | null>(null);
  const [pending, setPending] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const controller = new AbortController();
    setPending(true);

    fetchRecords(panel, controller.signal)
      .then((next) => setRecords(next.slice(0, MAX_VISIBLE)))
      .catch((cause: unknown) => {
        if (cause instanceof Error && cause.name !== "AbortError") {
          setError(cause);
        }
      })
      .finally(() => setPending(false));

    return () => controller.abort();
  }, [panel]);

  const [loud, quiet] = useMemo(() => partition(records, isLoud), [records]);

  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) return records;
    return records.filter(({ message, tags }) =>
      message.toLowerCase().includes(needle) ||
      tags?.some((tag) => tag.startsWith(needle)),
    );
  }, [records, query]);

  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent<HTMLInputElement>) => {
      if (event.key === "Escape") {
        setQuery("");
        inputRef.current?.blur();
      }
    },
    [],
  );

  if (error) {
    return (
      <div className="log-panel log-panel--error" role="alert">
        <p>Could not load records: {error.message}</p>
        <button type="button" onClick={() => setError(null)}>
          Dismiss
        </button>
      </div>
    );
  }

  return (
    <>
      <header className="log-panel__header">
        <h2>
          {panel} <small>({visible.length})</small>
        </h2>
        <input
          ref={inputRef}
          type="search"
          value={query}
          placeholder="Filter…"
          disabled={pending}
          spellCheck={false}
          onChange={(e) => setQuery(e.currentTarget.value)}
          onKeyDown={handleKeyDown}
        />
      </header>

      {pending && <progress className="log-panel__spinner" />}

      <ul className="log-panel__list">
        {visible.map((record, index) => {
          const valid = ID_PATTERN.test(record.id);
          return (
            <li
              key={record.id}
              className="log-panel__row"
              data-index={index}
              data-valid={valid || undefined}
              onClick={() => onSelect?.(record)}
            >
              <Badge level={record.level} compact={index > 10} />
              <span className="log-panel__message">{record.message}</span>
              {record.meta ? (
                <code>
                  attempt {record.meta.attempt} · {record.meta.ok ? "ok" : "failed"}
                </code>
              ) : (
                <code>no metadata</code>
              )}
            </li>
          );
        })}
      </ul>

      <footer>
        {loud.length} loud / {quiet.length} quiet
        {visible.length === 0 && <em> — nothing matches “{query}”</em>}
      </footer>
    </>
  );
}
