/**
 * THIS FILE IS SUPPOSED TO HAVE ERRORS. Do not fix them.
 *
 * It is the only sample that renders the diagnostic surfaces: red and yellow
 * squiggles, the faded `editor.showUnused` treatment, strikethrough on
 * deprecated symbols, the hover card, and the inline text errorLens paints
 * at the end of each offending line.
 *
 * Everything is self-contained — no imports — so the diagnostics you see are
 * exactly the ones listed below and never a missing-module artifact.
 *
 *   1. type mismatch on assignment          → error squiggle
 *   2. wrong argument type                  → error squiggle
 *   3. too few arguments                    → error squiggle
 *   4. missing property in object literal   → error squiggle
 *   5. possibly-undefined access            → error squiggle
 *   6. unused local + unused parameter      → faded (unnecessary)
 *   7. call to a @deprecated function       → strikethrough
 *   8. unreachable statement                → faded (unnecessary)
 */

export interface Config {
  name: string;
  retries: number;
  verbose: boolean;
}

// 1 — string is not assignable to number.
const retries: number = "three";

// 6 — declared and never read, so it renders faded.
const unusedLocal = { scratch: true };
let neverRead: string[];

function build(config: Config, unusedParam: number): string {
  return `${config.name} ×${config.retries}`;
}

// 4 — `verbose` is missing from the object literal.
const partial: Config = {
  name: "preview",
  retries: 3,
};

// 3 — build expects two arguments.
const label = build(partial);

// 2 — a boolean where a Config was expected.
const wrong = build(true, 1);

/**
 * Formats a record the old way.
 *
 * @deprecated Use {@link format} instead — this exists to render strikethrough.
 */
export function legacyFormat(value: string): string {
  return value.trim().toUpperCase();
}

export function format(value: string): string {
  return value.trim();
}

// 7 — the call site should be struck through.
const legacy = legacyFormat("still called");

interface Maybe {
  inner?: { depth: number };
}

// 5 — `inner` is possibly undefined.
export function depthOf(m: Maybe): number {
  return m.inner.depth;
}

export function unreachable(): number {
  return 42;
  // 8 — everything past the return is dead, so it renders faded.
  console.log("never runs", retries, label, wrong, legacy);
}
