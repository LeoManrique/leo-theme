/*
 * Main.java — 129 .java files in Desktop/learn-offline.
 *
 * No numeric prefix on this one: the public class name has to match the file
 * name, and `18-Main` is not a legal Java identifier. Same reason Makefile and
 * Dockerfile keep their bare names — see CHECKLIST.md.
 *
 * Java is the only sample with annotations on declarations, a sealed
 * hierarchy, and text blocks.
 */

package preview;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

public final class Main {

    // ── Constants ───────────────────────────────────────────────────────────

    private static final int MAX_RETRIES = 3;
    private static final int BANNER_WIDTH = 74;
    private static final double GOLDEN_RATIO = 1.618_033_988_749;
    private static final int COLOR_MASK = 0xFF00FF;
    private static final long BIG = 9_007_199_254_740_991L;
    private static final char MARKER = '→';
    private static final String DEFAULT_TAG = "leo-dark";

    // ── Types ───────────────────────────────────────────────────────────────

    /** Quietest to loudest. */
    public enum Severity {
        DEBUG(0), INFO(1), WARN(2), FATAL(3);

        private final int weight;

        Severity(int weight) {
            this.weight = weight;
        }

        public boolean isLoud() {
            return weight >= WARN.weight;
        }

        @Override
        public String toString() {
            return name().toLowerCase();
        }
    }

    /** Record class — the compact constructor form. */
    public record LogRecord(String id, String message, Severity level, List<String> tags) {
        public LogRecord {
            Objects.requireNonNull(id, "id");
            Objects.requireNonNull(message, "message");
            level = level == null ? Severity.INFO : level;
            tags = tags == null ? List.of(DEFAULT_TAG) : List.copyOf(tags);
        }

        public LogRecord(String id, String message) {
            this(id, message, Severity.INFO, null);
        }

        public String summary() {
            return "%-5s · %s".formatted(level, message);
        }
    }

    /** Sealed hierarchy, matched exhaustively below. */
    public sealed interface Field permits Field.Empty, Field.Count, Field.Ratio {
        record Empty() implements Field {}
        record Count(long value) implements Field {}
        record Ratio(double numerator, double denominator) implements Field {}
    }

    @FunctionalInterface
    interface Sink<T> {
        int write(List<T> batch) throws CollectException;

        default String name() {
            return "anonymous";
        }
    }

    static class CollectException extends Exception {
        private static final long serialVersionUID = 1L;

        CollectException(String message) {
            super(message);
        }
    }

    // ── Behaviour ───────────────────────────────────────────────────────────

    static String describe(Field field) {
        return switch (field) {
            case Field.Empty ignored -> "empty";
            case Field.Count(long value) when value > 100 -> "count(many: %d)".formatted(value);
            case Field.Count(long value) -> "count(%d)".formatted(value);
            case Field.Ratio(double num, double den) -> "ratio(%.3f)".formatted(num / den);
        };
    }

    @SafeVarargs
    static <T> List<T> filter(Predicate<? super T> predicate, T... items) {
        List<T> out = new ArrayList<>(items.length);
        for (T item : items) {
            if (predicate.test(item)) {
                out.add(item);
            }
        }
        return out;
    }

    @SuppressWarnings("unused")
    static Optional<LogRecord> longest(List<LogRecord> records) {
        return records.stream().max(Comparator.comparingInt(r -> r.message().length()));
    }

    // ── Entry point ─────────────────────────────────────────────────────────

    public static void main(String... args) {
        var records = List.of(
                new LogRecord("rec_0a1b2c3d", "boot sequence started", Severity.DEBUG, null),
                new LogRecord("rec_1e2f3a4b", "cache warmed", Severity.INFO, List.of("cache")),
                new LogRecord("rec_5c6d7e8f", "retry budget low", Severity.WARN, null),
                new LogRecord("rec_9a0b1c2d", "unrecoverable"));

        Map<Severity, Long> counts = records.stream()
                .collect(Collectors.groupingBy(LogRecord::level, () -> new EnumMap<>(Severity.class),
                        Collectors.counting()));

        long loud = records.stream().filter(r -> r.level().isLoud()).count();

        System.out.println("-".repeat(BANNER_WIDTH));
        System.out.printf("%-12s%d of %d%n", "records:", records.size(), records.size());
        System.out.printf("%-12s%d%n", "loud:", loud);
        System.out.printf("%-12s0x%06X %c phi %.6f%n", "mask:", COLOR_MASK, MARKER, GOLDEN_RATIO);
        System.out.printf("%-12s%d%n", "big:", BIG);

        counts.forEach((level, count) -> System.out.printf("  %-6s x %d%n", level, count));

        records.stream()
                .sorted(Comparator.comparing(LogRecord::level).thenComparing(LogRecord::message))
                .map(LogRecord::summary)
                .forEach(line -> System.out.println("  " + line));

        List<Field> fields = List.of(
                new Field.Empty(),
                new Field.Count(42L),
                new Field.Count(1_000L),
                new Field.Ratio(1.618, 1.0));

        fields.forEach(f -> System.out.println("  " + describe(f)));

        IntStream.rangeClosed(1, MAX_RETRIES)
                .mapToObj(i -> "attempt %d/%d".formatted(i, MAX_RETRIES))
                .forEach(System.out::println);

        // Text block — the only multi-line string form in Java.
        String report = """
                Preview report
                  records:  %d
                  loud:     %d
                  escaped:  \\n stays literal, \s trailing space kept
                """.formatted(records.size(), loud);
        System.out.print(report);

        try (var scope = new AutoCloseable() {
            @Override
            public void close() {
                System.out.println("closed");
            }
        }) {
            Objects.requireNonNull(scope);
            if (args.length > 0) {
                throw new CollectException("unexpected arguments: " + String.join(", ", args));
            }
        } catch (CollectException e) {
            System.err.println("collect failed: " + e.getMessage());
        } catch (Exception e) {
            throw new IllegalStateException(e);
        } finally {
            System.out.println("done");
        }
    }
}
