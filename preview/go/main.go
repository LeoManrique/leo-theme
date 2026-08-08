// Package main exercises the Go token surface that Leo Dark colors.
//
// Every construct below targets a distinct highlight group: doc comments,
// iota constants, struct tags, interfaces, generics, channels, and errors.
// It compiles and vets clean, so gopls emits full semantic tokens — the
// file is useless as a comparison if half the identifiers fall back to
// TextMate scopes.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

// Severity ranks how loudly a Record should be reported.
type Severity int

// Severity levels, ordered from quietest to loudest.
const (
	Debug Severity = iota
	Info
	Warn
	Fatal
)

// String implements [fmt.Stringer].
func (s Severity) String() string {
	switch s {
	case Debug:
		return "debug"
	case Info:
		return "info"
	case Warn:
		return "warn"
	case Fatal:
		return "fatal"
	default:
		return fmt.Sprintf("severity(%d)", int(s))
	}
}

const (
	maxRetries    = 3
	flushInterval = 250 * time.Millisecond
	bannerWidth   = 0x4A
	ratio         = 1.618
	marker        = '→'
)

// ErrEmptyBatch is returned when a sink is handed nothing to write.
var ErrEmptyBatch = errors.New("collector: empty batch")

// Record is one structured log line.
type Record struct {
	Message string         `json:"message"`
	Level   Severity       `json:"level"`
	Fields  map[string]any `json:"fields,omitempty"`
	Tags    []string       `json:"tags,omitempty"`
	At      time.Time      `json:"at"`
}

// Sink accepts batches of records and is safe for concurrent use.
type Sink interface {
	Write(ctx context.Context, batch []Record) error
	Close() error
}

// Number constrains the numeric types Reduce can fold over.
type Number interface {
	~int | ~int64 | ~float64
}

type memorySink struct {
	mu      sync.Mutex
	records []Record
	closed  bool
}

func (m *memorySink) Write(ctx context.Context, batch []Record) error {
	if len(batch) == 0 {
		return fmt.Errorf("memory sink: %w", ErrEmptyBatch)
	}

	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	if m.closed {
		return errors.New("memory sink: already closed")
	}
	m.records = append(m.records, batch...)
	return nil
}

func (m *memorySink) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.closed = true
	return nil
}

// Map applies fn to every element of in, preserving order.
func Map[T, U any](in []T, fn func(T) U) []U {
	out := make([]U, 0, len(in))
	for _, v := range in {
		out = append(out, fn(v))
	}
	return out
}

// Reduce folds in down to a single value, starting from seed.
func Reduce[T any, N Number](in []T, seed N, fn func(N, T) N) N {
	acc := seed
	for _, v := range in {
		acc = fn(acc, v)
	}
	return acc
}

// describe demonstrates a type switch over an empty interface.
func describe(v any) string {
	switch t := v.(type) {
	case nil:
		return "<nil>"
	case string:
		return quote(t)
	case error:
		return "error: " + t.Error()
	case []Record:
		return fmt.Sprintf("%d records", len(t))
	default:
		return fmt.Sprintf("%T(%v)", t, t)
	}
}

func quote(s string) string { return `"` + s + `"` }

// collect fans a producer goroutine into a batch, stopping on ctx or close.
func collect(ctx context.Context, in <-chan Record, size int) []Record {
	batch := make([]Record, 0, size)
	timeout := time.NewTimer(flushInterval)
	defer timeout.Stop()

	for len(batch) < size {
		select {
		case rec, ok := <-in:
			if !ok {
				return batch
			}
			batch = append(batch, rec)
		case <-timeout.C:
			return batch
		case <-ctx.Done():
			return batch
		}
	}
	return batch
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	stream := make(chan Record, maxRetries)
	var wg sync.WaitGroup

	wg.Go(func() {
		defer close(stream)

		for i, level := range []Severity{Debug, Info, Warn, Fatal} {
			stream <- Record{
				Message: fmt.Sprintf("event %02d %c ready", i, marker),
				Level:   level,
				Fields:  map[string]any{"attempt": i, "ok": i%2 == 0, "ratio": ratio},
				Tags:    []string{"preview", "leo-dark"},
				At:      time.Now(),
			}
		}
	})

	batch := collect(ctx, stream, maxRetries+1)
	wg.Wait()

	sink := &memorySink{}
	if err := sink.Write(ctx, batch); err != nil {
		switch {
		case errors.Is(err, ErrEmptyBatch):
			fmt.Fprintln(os.Stderr, "nothing to flush")
		case errors.Is(err, context.DeadlineExceeded):
			fmt.Fprintln(os.Stderr, "timed out")
		default:
			fmt.Fprintf(os.Stderr, "write failed: %v\n", err)
			os.Exit(1)
		}
	}
	defer func() {
		if err := sink.Close(); err != nil {
			panic(err)
		}
	}()

	labels := Map(batch, func(r Record) string {
		return strings.ToUpper(r.Level.String())
	})
	sort.Strings(labels)

	total := Reduce(batch, 0, func(acc int, r Record) int {
		return acc + len(r.Message)
	})

	fmt.Println(strings.Repeat("─", bannerWidth))
	fmt.Printf("%-12s %s\n", "levels:", strings.Join(labels, ", "))
	fmt.Printf("%-12s %d bytes\n", "payload:", total)
	fmt.Printf("%-12s %s\n", "describe:", describe(batch))
}
