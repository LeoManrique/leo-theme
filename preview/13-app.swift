//
//  13-app.swift — SwiftUI shaped, matching Mobile/GermanLock and
//  Desktop/macos-app-monitor.
//
//  Swift is the only sample with property wrappers (`@State`, `@Published`),
//  result builders (the `body` DSL), and `\()` string interpolation — three
//  things no other grammar in this corpus has.
//

import Foundation

// MARK: - Model

/// Quietest to loudest.
enum Severity: String, CaseIterable, Codable, Identifiable, Comparable {
    case debug, info, warn, fatal

    var id: String { rawValue }

    var weight: Int {
        switch self {
        case .debug: 0
        case .info:  1
        case .warn:  2
        case .fatal: 3
        }
    }

    var isLoud: Bool { self >= .warn }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.weight < rhs.weight
    }
}

/// All the enum payload shapes Swift allows.
enum Field {
    case empty
    case count(UInt64)
    case ratio(numerator: Double, denominator: Double)
    indirect case nested(Field)
}

struct Record: Identifiable, Codable, Hashable {
    let id: UUID
    var message: String
    var level: Severity
    var tags: [String]
    var meta: [String: String]?

    init(
        id: UUID = UUID(),
        message: String,
        level: Severity = .info,
        tags: [String] = ["preview", "leo-dark"],
        meta: [String: String]? = nil
    ) {
        self.id = id
        self.message = message
        self.level = level
        self.tags = tags
        self.meta = meta
    }

    /// Computed property with a `guard let`.
    var summary: String {
        guard let meta, !meta.isEmpty else {
            return "\(level.rawValue.uppercased()) · \(message)"
        }
        let pairs = meta.sorted { $0.key < $1.key }
                        .map { "\($0)=\($1)" }
                        .joined(separator: " ")
        return "\(level.rawValue.uppercased()) · \(message) · \(pairs)"
    }
}

// MARK: - Errors

enum CollectError: LocalizedError {
    case emptyBatch
    case closed(after: Int)
    case transport(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .emptyBatch:
            "Collector received an empty batch."
        case .closed(let after):
            "Collector closed after \(after) records."
        case .transport(let underlying):
            "Transport failed: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Protocol and generics

protocol Sink: Sendable {
    associatedtype Output

    func write(_ batch: [Record]) async throws -> Output
    var name: String { get }
}

extension Sink {
    /// Provided default — overriding is optional.
    nonisolated var name: String { String(describing: Self.self) }
}

actor MemorySink: Sink {
    typealias Output = Int

    private(set) var seen: [Record] = []
    private var closed = false

    func write(_ batch: [Record]) async throws -> Int {
        guard !batch.isEmpty else { throw CollectError.emptyBatch }
        guard !closed else { throw CollectError.closed(after: seen.count) }

        seen.append(contentsOf: batch)
        try await Task.sleep(for: .milliseconds(10))
        return seen.count
    }

    func close() { closed = true }
}

/// Generic with a `where` clause.
func render<S: Sequence>(_ items: S, separator: String = ", ") -> String
where S.Element: CustomStringConvertible {
    items.map(\.description).joined(separator: separator)
}

// MARK: - Extensions

extension Array where Element == Record {
    var loud: [Record] { filter(\.level.isLoud) }

    func grouped() -> [Severity: [Record]] {
        Dictionary(grouping: self, by: \.level)
    }

    subscript(safe index: Int) -> Record? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    static let bannerWidth = 74

    var banner: String { String(repeating: self, count: Self.bannerWidth) }
}

// MARK: - Entry point

// `@main` is deliberately omitted: this file is analysed standalone, and the
// attribute is only legal in a module with a single entry point.
@available(macOS 13.0, iOS 16.0, *)
struct Preview {
    static let maxRetries = 3
    static let goldenRatio = 1.618_033_988_749
    static let mask: UInt32 = 0xFF00_FF

    static func main() async {
        let records: [Record] = [
            Record(message: "boot sequence started", level: .debug),
            Record(message: "cache warmed", level: .info, meta: ["attempt": "1"]),
            Record(message: "retry budget low", level: .warn),
            Record(message: "unrecoverable", level: .fatal, tags: []),
        ]

        let sink = MemorySink()

        do {
            let written = try await sink.write(records)
            print("─".banner)
            print("sink:     \(sink.name)")
            print("written:  \(written) of \(records.count)")
            print("levels:   \(render(Severity.allCases.map(\.rawValue)))")
            print("loud:     \(records.loud.count)")
            print(String(format: "mask:     0x%06X · phi %.6f", mask, goldenRatio))
        } catch let error as CollectError {
            print("collect failed: \(error.errorDescription ?? "unknown")")
        } catch {
            print("unexpected: \(error)")
        }

        for (level, group) in records.grouped().sorted(by: { $0.key < $1.key }) {
            print("  \(level.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) × \(group.count)")
        }

        if let first = records[safe: 0] {
            print("  first: \(first.summary)")
        }

        // Trailing closure, optional chaining, nil coalescing, and a defer.
        defer { print("done") }

        let longest = records
            .max { $0.message.count < $1.message.count }?
            .message ?? "<none>"
        print("  longest: \"\(longest)\"")

        // Multi-line string literal with interpolation.
        let report = """
            Preview report
              records:  \(records.count)
              retries:  \(maxRetries)
              escaped:  \\(not interpolated)
            """
        print(report)
    }
}
