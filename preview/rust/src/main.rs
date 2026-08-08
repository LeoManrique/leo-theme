//! Exercises the Rust token surface that Leo Dark colors.
//!
//! Rust is the largest language in this corpus, and it is the only sample that
//! reaches Zed's `variant` capture (enum variants), `attribute` (`#[derive]`),
//! and lifetime syntax. It builds and clippies clean on purpose — a file with
//! errors gets degraded rust-analyzer output, which reads as a theme bug.

use std::collections::{BTreeMap, HashMap};
use std::fmt::{self, Display};
use std::sync::Arc;

/// Quietest to loudest.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub enum Severity {
    Debug,
    #[default]
    Info,
    Warn,
    Fatal,
}

impl Display for Severity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            Severity::Debug => "debug",
            Severity::Info => "info",
            Severity::Warn => "warn",
            Severity::Fatal => "fatal",
        };
        write!(f, "{name}")
    }
}

/// All three variant shapes: unit, tuple, and struct.
#[derive(Debug, Clone)]
pub enum Field {
    Empty,
    Count(u64),
    Ratio(f64, f64),
    Span { start: usize, end: usize },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CollectError {
    EmptyBatch,
    Closed { at: usize },
}

impl Display for CollectError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyBatch => write!(f, "collector: empty batch"),
            Self::Closed { at } => write!(f, "collector: closed after {at} records"),
        }
    }
}

impl std::error::Error for CollectError {}

pub const MAX_RETRIES: usize = 3;
pub const BANNER_WIDTH: usize = 0x4A;
static DEFAULT_TAG: &str = "leo-dark";

#[derive(Debug, Clone)]
pub struct Record<'a> {
    pub message: &'a str,
    pub level: Severity,
    pub fields: BTreeMap<&'a str, Field>,
    pub tags: Vec<&'a str>,
}

impl<'a> Record<'a> {
    /// Builds a record with the default tag already attached.
    pub fn new(message: &'a str, level: Severity) -> Self {
        Self {
            message,
            level,
            fields: BTreeMap::new(),
            tags: vec![DEFAULT_TAG],
        }
    }

    #[must_use]
    pub fn with_field(mut self, key: &'a str, value: Field) -> Self {
        self.fields.insert(key, value);
        self
    }

    pub fn is_loud(&self) -> bool {
        matches!(self.level, Severity::Warn | Severity::Fatal)
    }
}

/// Anything that can swallow a batch of records.
pub trait Sink {
    fn write(&mut self, batch: &[Record<'_>]) -> Result<usize, CollectError>;

    /// Provided method — overriding is optional.
    fn name(&self) -> &'static str {
        "anonymous"
    }
}

#[derive(Default)]
struct MemorySink {
    seen: usize,
    closed: bool,
}

impl Sink for MemorySink {
    fn write(&mut self, batch: &[Record<'_>]) -> Result<usize, CollectError> {
        if batch.is_empty() {
            return Err(CollectError::EmptyBatch);
        }
        if self.closed {
            return Err(CollectError::Closed { at: self.seen });
        }
        self.seen += batch.len();
        Ok(self.seen)
    }

    fn name(&self) -> &'static str {
        "memory"
    }
}

/// Generic over anything displayable, with a `where` clause for contrast.
fn render<T>(items: &[T], sep: &str) -> String
where
    T: Display,
{
    items
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>()
        .join(sep)
}

fn tally(records: &[Record<'_>]) -> HashMap<Severity, usize> {
    let mut counts: HashMap<Severity, usize> = HashMap::new();
    for record in records {
        *counts.entry(record.level).or_insert(0) += 1;
    }
    counts
}

fn describe(field: &Field) -> String {
    match field {
        Field::Empty => "empty".to_owned(),
        Field::Count(n) if *n > 100 => format!("count(many: {n})"),
        Field::Count(n) => format!("count({n})"),
        Field::Ratio(num, den) => format!("ratio({:.3})", num / den),
        Field::Span { start, end } => format!("span[{start}..{end}]"),
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let shared: Arc<str> = Arc::from("shared payload");

    let records = vec![
        Record::new("boot sequence started", Severity::Debug)
            .with_field("attempt", Field::Count(1)),
        Record::new("cache warmed", Severity::Info)
            .with_field("ratio", Field::Ratio(1.618, 1.0)),
        Record::new("retry budget low", Severity::Warn)
            .with_field("span", Field::Span { start: 0, end: 42 }),
        Record::new(&shared, Severity::Fatal).with_field("empty", Field::Empty),
    ];

    let mut sink = MemorySink::default();
    let written = sink.write(&records)?;

    let loud: Vec<_> = records.iter().filter(|r| r.is_loud()).collect();
    let levels: Vec<Severity> = records.iter().map(|r| r.level).collect();
    let counts = tally(&records);

    let mut ordered: Vec<_> = counts.iter().collect();
    ordered.sort_by_key(|(level, _)| **level);

    println!("{}", "─".repeat(BANNER_WIDTH));
    println!("{:<12} {}", "sink:", sink.name());
    println!("{:<12} {written} of {}", "written:", records.len());
    println!("{:<12} {}", "levels:", render(&levels, ", "));
    println!("{:<12} {}", "loud:", loud.len());

    for (level, count) in ordered {
        println!("  {level:<8} × {count}");
    }

    for record in &records {
        for (key, field) in &record.fields {
            println!("  {key:>8} = {}", describe(field));
        }
    }

    // Closures, iterator chains, and the `?`-free fallible path.
    let longest = records
        .iter()
        .max_by_key(|r| r.message.len())
        .map(|r| r.message)
        .unwrap_or("<none>");
    println!("{:<12} {longest:?}", "longest:");

    let budget = MAX_RETRIES.checked_sub(loud.len()).unwrap_or_default();
    if budget == 0 {
        eprintln!("retry budget exhausted");
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_batch_is_rejected() {
        let mut sink = MemorySink::default();
        assert!(matches!(sink.write(&[]), Err(CollectError::EmptyBatch)));
    }

    #[test]
    fn loud_levels_are_detected() {
        assert!(Record::new("x", Severity::Fatal).is_loud());
        assert!(!Record::new("x", Severity::Debug).is_loud());
    }
}
