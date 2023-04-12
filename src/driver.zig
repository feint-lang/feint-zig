//! The driver coordinates parsing source and running it.
const std = @import("std");
const Lexer = @import("./lexer.zig").Lexer;

pub const Driver = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn display_tokens(_: Self, source: []const u8) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var allocator = arena.allocator();
        defer arena.deinit();
        var lexer = Lexer.init(&allocator, source);
        while (lexer.next()) |result| {
            const info = lexer.token_info();
            std.debug.print("({d} -> {d}) {d}:{d} -> {d}:{d} : {s} \"{s}\"\n", .{
                info.start,
                info.end,
                info.start_line,
                info.start_col,
                info.end_line,
                info.end_col,
                result.format(),
                info.lexeme,
            });
        } else {
            std.debug.print("EOF\n", .{});
        }
    }
};
