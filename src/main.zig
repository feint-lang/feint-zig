const std = @import("std");

const lexerNS = @import("./lexer.zig");
const tokenNS = @import("./token.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        1 => std.debug.print("TODO: Run REPL", .{}),
        2 => lexerNS.display_tokens(args[1]),
        else => std.debug.print("TODO", .{}),
    }
}
