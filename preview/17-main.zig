//! 17-main.zig — 115 .zig files in Desktop/learn-offline, all recent, so this
//! is the language you are actively picking up.
//!
//! Zig is the only sample with builtins (`@import`, `@intCast`), error unions
//! (`!T`), `comptime`, and `defer`/`errdefer`. Your Zed already has the zig
//! extension installed; VS Code needs one for anything past TextMate.

const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ── Constants ───────────────────────────────────────────────────────────────

const max_retries: usize = 3;
const banner_width: usize = 74;
const golden_ratio: f64 = 1.618033988749;
const color_mask: u32 = 0xFF00FF;
const binary: u8 = 0b1010_1101;
const octal: u16 = 0o755;
const escaped = "tab \t quote \" backslash \\ newline \n unicode \u{2192}";
const raw_string =
    \\Multi-line string literal.
    \\Each line starts with a backslash pair.
    \\No escape processing happens here: \n stays literal.
;

// ── Types ───────────────────────────────────────────────────────────────────

const Severity = enum(u2) {
    debug,
    info,
    warn,
    fatal,

    pub fn isLoud(self: Severity) bool {
        return @intFromEnum(self) >= @intFromEnum(Severity.warn);
    }

    pub fn name(self: Severity) []const u8 {
        return switch (self) {
            .debug => "debug",
            .info => "info",
            .warn => "warn",
            .fatal => "fatal",
        };
    }
};

/// Tagged union — Zig's version of a sum type with payloads.
const Field = union(enum) {
    empty: void,
    count: u64,
    ratio: struct { num: f64, den: f64 },
    text: []const u8,

    pub fn format(
        self: Field,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .empty => try writer.writeAll("empty"),
            .count => |n| try writer.print("count({d})", .{n}),
            .ratio => |r| try writer.print("ratio({d:.3})", .{r.num / r.den}),
            .text => |t| try writer.print("text(\"{s}\")", .{t}),
        }
    }
};

const CollectError = error{
    EmptyBatch,
    Closed,
    OutOfMemory,
};

const Record = struct {
    id: u32,
    message: []const u8,
    level: Severity = .info,
    field: Field = .empty,

    const Self = @This();

    pub fn init(id: u32, message: []const u8, level: Severity) Self {
        return .{ .id = id, .message = message, .level = level };
    }

    pub fn withField(self: Self, f: Field) Self {
        var copy = self;
        copy.field = f;
        return copy;
    }
};

// ── Generic function, comptime ──────────────────────────────────────────────

fn Ring(comptime T: type, comptime capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn push(self: *Self, value: T) !void {
            if (self.len >= capacity) return error.OutOfMemory;
            self.items[self.len] = value;
            self.len += 1;
        }

        pub fn slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }
    };
}

fn countLoud(records: []const Record) usize {
    var total: usize = 0;
    for (records) |record| {
        if (record.level.isLoud()) total += 1;
    }
    return total;
}

// ── Sink ────────────────────────────────────────────────────────────────────

const MemorySink = struct {
    seen: ArrayList(Record),
    closed: bool = false,

    pub fn init(allocator: Allocator) MemorySink {
        return .{ .seen = ArrayList(Record).init(allocator) };
    }

    pub fn deinit(self: *MemorySink) void {
        self.seen.deinit();
    }

    pub fn write(self: *MemorySink, batch: []const Record) CollectError!usize {
        if (batch.len == 0) return CollectError.EmptyBatch;
        if (self.closed) return CollectError.Closed;

        try self.seen.appendSlice(batch);
        return self.seen.items.len;
    }
};

// ── Entry point ─────────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sink = MemorySink.init(allocator);
    defer sink.deinit();

    const records = [_]Record{
        Record.init(1, "boot sequence started", .debug).withField(.{ .count = 1 }),
        Record.init(2, "cache warmed", .info).withField(.{ .ratio = .{ .num = 1.618, .den = 1.0 } }),
        Record.init(3, "retry budget low", .warn).withField(.{ .text = "budget" }),
        Record.init(4, "unrecoverable", .fatal),
    };

    const written = sink.write(&records) catch |err| switch (err) {
        CollectError.EmptyBatch => {
            std.debug.print("nothing to flush\n", .{});
            return;
        },
        else => return err,
    };

    var ring = Ring(u32, max_retries){};
    for (records) |record| {
        ring.push(record.id) catch break;
    }

    const stdout = std.io.getStdOut().writer();

    try stdout.writeByteNTimes('-', banner_width);
    try stdout.writeByte('\n');
    try stdout.print("{s:<12}{s}\n", .{ "target:", @tagName(builtin.cpu.arch) });
    try stdout.print("{s:<12}{d} of {d}\n", .{ "written:", written, records.len });
    try stdout.print("{s:<12}{d}\n", .{ "loud:", countLoud(&records) });
    try stdout.print("{s:<12}0x{X:0>6} phi {d:.6}\n", .{ "mask:", color_mask, golden_ratio });
    try stdout.print("{s:<12}{d} queued\n", .{ "ring:", ring.slice().len });

    for (records, 0..) |record, index| {
        try stdout.print("  {d:>2} {s:<6} {s} [{}]\n", .{
            index,
            record.level.name(),
            record.message,
            record.field,
        });
    }

    // comptime block, optionals, orelse, and a labelled break.
    const label = comptime blk: {
        var total: usize = 0;
        var i: usize = 0;
        while (i < 4) : (i += 1) total += i;
        break :blk total;
    };

    const maybe: ?[]const u8 = if (records.len > 0) records[0].message else null;
    const resolved = maybe orelse "<none>";

    try stdout.print("{s:<12}{d} · {s}\n", .{ "comptime:", label, resolved });
    try stdout.print("{s:<12}{d} {d} {s}\n", .{ "literals:", binary, octal, escaped[0..3] });
    try stdout.writeAll(raw_string);
    try stdout.writeByte('\n');
}

test "loud levels are detected" {
    try std.testing.expect(Severity.fatal.isLoud());
    try std.testing.expect(!Severity.debug.isLoud());
}

test "empty batch is rejected" {
    var sink = MemorySink.init(std.testing.allocator);
    defer sink.deinit();
    try std.testing.expectError(CollectError.EmptyBatch, sink.write(&.{}));
}
