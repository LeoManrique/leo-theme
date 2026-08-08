"""16-script.py — Python is thin in your tree (74 files) but it is the only
sample with f-string nesting, decorators stacked on classes, and the
structural `match` statement, so it stays in the corpus.

Module docstrings, class docstrings and inline comments are three separate
things in some grammars and one thing in others — worth comparing.
"""

from __future__ import annotations

import asyncio
import json
import re
from collections.abc import Callable, Iterable, Iterator, Sequence
from contextlib import suppress
from dataclasses import dataclass, field
from enum import IntEnum, auto
from functools import cached_property, lru_cache, wraps
from typing import Any, Final, Literal, Protocol, Self, TypeVar

T = TypeVar("T")

MAX_RETRIES: Final[int] = 3
GOLDEN_RATIO: Final = 1.618_033_988_749
COLOR_MASK: Final = 0xFF00FF
BINARY: Final = 0b1010_1101
OCTAL: Final = 0o755
COMPLEX: Final = 3 + 4j
ID_PATTERN: Final = re.compile(r"^rec_[0-9a-f]{8}$", re.IGNORECASE | re.VERBOSE)

Severity = Literal["debug", "info", "warn", "fatal"]


class Level(IntEnum):
    DEBUG = 0
    INFO = auto()
    WARN = auto()
    FATAL = auto()

    @property
    def is_loud(self) -> bool:
        return self >= Level.WARN


class Sink(Protocol):
    """Anything that can swallow a batch of records."""

    def write(self, batch: Sequence[Record]) -> int: ...

    @property
    def name(self) -> str: ...


@dataclass(slots=True, frozen=True, kw_only=True)
class Record:
    """One structured log line."""

    id: str
    message: str
    level: Level = Level.INFO
    tags: tuple[str, ...] = ("preview", "leo-dark")
    meta: dict[str, Any] = field(default_factory=dict, repr=False)

    def __post_init__(self) -> None:
        if not ID_PATTERN.match(self.id):
            raise ValueError(f"malformed id: {self.id!r}")

    @cached_property
    def summary(self) -> str:
        pairs = " ".join(f"{k}={v}" for k, v in sorted(self.meta.items()))
        return f"{self.level.name:<5} · {self.message}{f' · {pairs}' if pairs else ''}"

    @classmethod
    def parse(cls, raw: str) -> Self:
        payload = json.loads(raw)
        return cls(
            id=payload["id"],
            message=payload.get("message", ""),
            level=Level[payload.get("level", "INFO").upper()],
        )


def retry(times: int = MAX_RETRIES) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """Decorator factory — three levels of nesting, on purpose."""

    def decorator(fn: Callable[..., T]) -> Callable[..., T]:
        @wraps(fn)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            last: Exception | None = None
            for attempt in range(1, times + 1):
                try:
                    return fn(*args, **kwargs)
                except (ValueError, KeyError) as exc:
                    last = exc
                    print(f"attempt {attempt}/{times} failed: {exc}")
                finally:
                    pass
            raise RuntimeError("exhausted retries") from last

        return wrapper

    return decorator


@lru_cache(maxsize=128)
def level_name(code: str) -> str:
    match code.upper():
        case "D" | "DEBUG":
            return "debug"
        case "I" | "INFO":
            return "info"
        case "W" | "WARN" as matched:
            return matched.lower()
        case str() as other if len(other) == 1:
            return f"unknown({other})"
        case _:
            return "fatal"


def describe(value: object) -> str:
    match value:
        case None:
            return "<none>"
        case bool() as flag:
            return "yes" if flag else "no"
        case int() | float() as number:
            return f"{number:,.3f}"
        case [first, *rest]:
            return f"list[{first!r} + {len(rest)} more]"
        case {"id": str(rid), **extra}:
            return f"mapping({rid}, {len(extra)} extra)"
        case Record(message=msg, level=lvl):
            return f"record({lvl.name}: {msg})"
        case _:
            return repr(value)


class MemorySink:
    __slots__ = ("_seen", "_closed")

    def __init__(self) -> None:
        self._seen: list[Record] = []
        self._closed = False

    def __repr__(self) -> str:
        return f"<MemorySink seen={len(self._seen)} closed={self._closed}>"

    def __len__(self) -> int:
        return len(self._seen)

    def __iter__(self) -> Iterator[Record]:
        yield from self._seen

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_exc: object) -> Literal[False]:
        self._closed = True
        return False

    @property
    def name(self) -> str:
        return "memory"

    @retry(times=2)
    def write(self, batch: Sequence[Record]) -> int:
        if not batch:
            raise ValueError("empty batch")
        if self._closed:
            raise KeyError("closed")
        self._seen.extend(batch)
        return len(self._seen)


def partition(items: Iterable[T], predicate: Callable[[T], bool]) -> tuple[list[T], list[T]]:
    yes, no = [], []
    for item in items:
        (yes if predicate(item) else no).append(item)
    return yes, no


async def gather_records(count: int = 4) -> list[Record]:
    async def make(index: int) -> Record:
        await asyncio.sleep(0)
        return Record(
            id=f"rec_{index:08x}",
            message=f"event {index:02d} ready",
            level=Level(index % len(Level)),
            meta={"attempt": index, "ok": index % 2 == 0},
        )

    return await asyncio.gather(*(make(i) for i in range(count)))


def main() -> int:
    records = asyncio.run(gather_records())
    loud, quiet = partition(records, lambda r: r.level.is_loud)

    with MemorySink() as sink:
        written = sink.write(records)

    print("─" * 74)
    print(f"{'sink:':<12}{sink.name}")
    print(f"{'written:':<12}{written} of {len(records)}")
    print(f"{'loud/quiet:':<12}{len(loud)}/{len(quiet)}")
    print(f"{'mask:':<12}0x{COLOR_MASK:06X} · phi {GOLDEN_RATIO:.6f}")
    print(f"{'nested f:':<12}{f'inner {level_name("w")!r}'}")

    for record in sorted(records, key=lambda r: (r.level, r.message)):
        print(f"  {record.summary}")

    with suppress(ValueError):
        Record(id="not-an-id", message="rejected")

    comprehension = {
        level.name.lower(): [r.id for r in records if r.level is level]
        for level in Level
        if any(r.level is level for r in records)
    }
    print(json.dumps(comprehension, indent=2, sort_keys=True))

    return 0 if written else 1


if __name__ == "__main__":
    raise SystemExit(main())
