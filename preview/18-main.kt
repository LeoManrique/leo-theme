/*
 * 18-main.kt — Kotlin comes from work rather than from your tree, so there is
 * no file count to quote.
 *
 * What to look at: annotations with a use-site target (`@file:`, `@get:`),
 * both template forms (`$name` and `${expr}`) and a string nested inside one,
 * labels (`scan@`, `break@scan`, `return@forEach`), and the null-safety
 * operators `?.` `?:` `!!` `as?`.
 *
 * Standard library only, so a bare `kotlinc 18-main.kt` compiles it.
 */

@file:JvmName("Preview")
@file:Suppress("unused", "MemberVisibilityCanBePrivate")

package preview

import kotlin.collections.ArrayDeque as Deque
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.properties.Delegates
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

// ── Constants ───────────────────────────────────────────────────────────────

const val MAX_RETRIES = 3
const val BANNER_WIDTH = 74
const val GOLDEN_RATIO = 1.618_033_988_749
const val COLOR_MASK = 0xFF00FF
const val FLAGS = 0b1010_1101
const val BIG = 9_007_199_254_740_991L
const val HALF = 0.5f
const val UNSIGNED = 42u
const val MARKER = '→'
const val TAB = '\t'
const val DEFAULT_TAG = "leo-dark"

val FLUSH_INTERVAL: Duration = 250.milliseconds

// ── Types ───────────────────────────────────────────────────────────────────

typealias Predicate<T> = (T) -> Boolean
typealias Fields = Map<String, Any?>

/** Quietest to loudest. */
enum class Severity(val weight: Int) {
    DEBUG(0), INFO(1), WARN(2), FATAL(3);

    val isLoud: Boolean
        get() = weight >= WARN.weight

    override fun toString(): String = name.lowercase()

    companion object {
        fun parse(code: String?): Severity = when (code?.trim()?.uppercase()) {
            "D", "DEBUG" -> DEBUG
            "I", "INFO" -> INFO
            "W", "WARN" -> WARN
            null -> INFO
            else -> FATAL
        }
    }
}

@JvmInline
value class RecordId(val raw: String) {
    init {
        require(ID_PATTERN.matches(raw)) { "malformed id: $raw" }
    }

    companion object {
        private val ID_PATTERN = Regex("""^rec_[0-9a-f]{8}$""")
    }
}

/**
 * One structured log line.
 *
 * @property id stable identifier, `rec_` plus eight hex digits
 * @property tags free-form labels, never empty
 */
data class Record(
    val id: RecordId,
    val message: String,
    val level: Severity = Severity.INFO,
    val tags: List<String> = listOf(DEFAULT_TAG),
    val meta: Fields = emptyMap(),
) {
    @get:JvmName("summary")
    val summary: String by lazy {
        val pairs = meta.entries.sortedBy { it.key }.joinToString(" ") { (key, value) -> "$key=$value" }
        "${level.name.padEnd(5)} · $message" + if (pairs.isEmpty()) "" else " · $pairs"
    }
}

/** Sealed hierarchy, matched exhaustively in [describe]. */
sealed interface Field {
    data object Empty : Field
    data class Count(val value: Long) : Field
    data class Ratio(val numerator: Double, val denominator: Double) : Field
}

fun interface Sink<in T> {
    @Throws(CollectException::class)
    fun write(batch: List<T>): Int
}

class CollectException(message: String, cause: Throwable? = null) : Exception(message, cause)

abstract class Formatter(protected val width: Int) {
    abstract fun format(record: Record): String

    open fun banner(): String = "─".repeat(width)
}

object Plain : Formatter(BANNER_WIDTH) {
    override fun format(record: Record): String = record.summary

    override fun banner(): String = super.banner().take(width / 2)
}

class MemorySink<T : Any>(private val capacity: Int = 16) : Sink<T>, Iterable<T> {
    private val seen = Deque<T>()
    private lateinit var label: String

    var closed: Boolean = false
        private set

    var written: Int by Delegates.observable(0) { _, old, new ->
        check(new >= old) { "written went backwards: $old -> $new" }
    }
        private set

    init {
        label = "memory[$capacity]"
    }

    val name: String
        get() = if (::label.isInitialized) label else "anonymous"

    override fun write(batch: List<T>): Int {
        if (batch.isEmpty()) throw CollectException("empty batch")
        if (closed) throw CollectException("closed")
        for (item in batch) {
            if (seen.size == capacity) seen.removeFirst()
            seen += item
        }
        written += batch.size
        return seen.size
    }

    override operator fun iterator(): Iterator<T> = seen.iterator()

    operator fun get(index: Int): T? = seen.getOrNull(index)

    fun close() {
        closed = true
    }
}

// ── Behaviour ───────────────────────────────────────────────────────────────

fun describe(field: Field): String = when (field) {
    Field.Empty -> "empty"
    is Field.Count -> if (field.value > 100) "count(many: ${field.value})" else "count(${field.value})"
    is Field.Ratio -> "ratio(%.3f)".format(field.numerator / field.denominator)
}

fun render(value: Any?): String = when (value) {
    null -> "<null>"
    is Boolean -> if (value) "yes" else "no"
    is Int, is Long -> "%,d".format(value)
    is Double -> "%,.3f".format(value)
    is String -> if (value.isBlank()) "<blank>" else "\"$value\""
    is Collection<*> -> "list[${value.firstOrNull()} + ${maxOf(value.size - 1, 0)} more]"
    is Field -> describe(value)
    else -> value.toString()
}

@Deprecated("Use Severity.parse", ReplaceWith("Severity.parse(code)"), DeprecationLevel.WARNING)
fun levelOf(code: String): Severity = Severity.parse(code)

inline fun <reified T> Iterable<*>.only(): List<T> = filterIsInstance<T>()

infix fun Record.louderThan(other: Record): Boolean = level > other.level

operator fun Record.plus(tag: String): Record = copy(tags = tags + tag)

fun Record.isTagged(tag: String): Boolean = tag in this.tags

fun <T> Iterable<T>.split(predicate: Predicate<T>): Pair<List<T>, List<T>> = partition(predicate)

tailrec fun gcd(a: Long, b: Long): Long = if (b == 0L) a else gcd(b, a % b)

fun <T, R> longest(items: List<T>, vararg fallbacks: T, key: (T) -> R): T? where R : Comparable<R> =
    (items + fallbacks).maxByOrNull(key)

fun <T> retry(times: Int = MAX_RETRIES, block: (attempt: Int) -> T): T {
    var last: Exception? = null
    attempts@ for (attempt in 1..times) {
        try {
            return block(attempt)
        } catch (e: CollectException) {
            last = e
            println("attempt $attempt/$times failed: ${e.message}")
            if (attempt == times) break@attempts
            continue@attempts
        } catch (e: IllegalArgumentException) {
            last = e
        } finally {
            // Nothing to release, the branch is here for its keyword.
        }
    }
    throw CollectException("exhausted retries", last)
}

fun records(count: Int = 4): Sequence<Record> = sequence {
    for (index in 0 until count) {
        yield(
            Record(
                id = RecordId("rec_%08x".format(index)),
                message = "event ${index.toString().padStart(2, '0')} ready",
                level = Severity.entries[index % Severity.entries.size],
                meta = mapOf("attempt" to index, "ok" to (index % 2 == 0)),
            ),
        )
    }
}

suspend fun flush(sink: MemorySink<Record>): Int = sink.written

// ── Entry point ─────────────────────────────────────────────────────────────

suspend fun main(args: Array<String>) {
    val all = records().toList()
    val (loud, quiet) = all.split { it.level.isLoud }
    val sink = MemorySink<Record>(capacity = 8)

    val written = retry { attempt ->
        if (attempt == 1 && args.isNotEmpty()) {
            throw CollectException("unexpected arguments: ${args.joinToString()}")
        }
        sink.write(all)
    }

    println(Plain.banner())
    println("${"sink:".padEnd(12)}${sink.name}")
    println("${"written:".padEnd(12)}$written of ${all.size}")
    println("${"loud/quiet:".padEnd(12)}${loud.size}/${quiet.size}")
    println("${"mask:".padEnd(12)}0x${COLOR_MASK.toString(16).uppercase()} $MARKER phi ${"%.6f".format(GOLDEN_RATIO)}")
    println("${"price:".padEnd(12)}${'$'}9.99,\ttau ${(2 * PI * 100).roundToInt() / 100.0} · every $FLUSH_INTERVAL")

    val first: Record? = sink[0]
    val firstTag = first?.tags?.firstOrNull() ?: DEFAULT_TAG
    val tagged = first!! + "pinned"
    println("  ${Plain.format(tagged)} [$firstTag] louder=${tagged louderThan all.last()}")

    scan@ for (record in sink) {
        for (tag in record.tags) {
            if (tag == "skip") continue@scan
            if (record.level == Severity.FATAL) break@scan
        }
        println("  ${record.summary}")
    }

    all.forEach { record ->
        val attempt = record.meta["attempt"] as? Int ?: return@forEach
        when (attempt) {
            0 -> print("  first")
            in 1..2 -> print("  early")
            !in 0..MAX_RETRIES -> print("  late")
            else -> print("  last")
        }
        println(" ${record.id.raw}")
    }

    val fields = listOf(Field.Empty, Field.Count(42L), Field.Count(1_000L), Field.Ratio(1.618, 1.0))
    fields.map(::describe).forEach(::println)
    println(render(listOf<Any?>(null, true, BIG, "text").only<String>()))
    println(longest(all, tagged) { it.message.length }?.message ?: "<none>")

    // Raw string: no escapes, templates still apply.
    val report = """
        |Preview report
        |  records:  ${all.size}
        |  loud:     ${loud.size}
        |  escaped:  \n stays literal, ${'$'}HOME is not a template
    """.trimMargin()
    println(report)

    val closer = object : AutoCloseable {
        override fun close() = println("closed")
    }
    closer.use {
        check(flush(sink) == all.size) { "lost records" }
    }
    sink.close()
}
