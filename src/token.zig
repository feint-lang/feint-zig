const std = @import("std");

pub const TokenErr = error{
    AllocationErr,
    UnexpectedChar,
    IllegalTab,
    ParseIntFailure,
    UnterminatedString,
};

pub const Token = union(enum) {
    // Types
    int: i128,
    float: f64,
    str: std.ArrayList(u8),

    // Binary operators
    star,
    slash,
    plus,
    dash,

    nl,
    eof,

    err: TokenErr,

    const Self = @This();

    pub fn to_str(self: Self) []const u8 {
        return switch (self) {
            // Types
            .int => "Int",
            .float => "Float",
            .str => |v| {
                std.debug.print("Str({s})", .{v.items});
                return "Str";
            },

            // Binary operators
            .star => "*",
            .slash => "/",
            .plus => "+",
            .dash => "-",

            .nl => "\\n",
            .eof => "EOF",

            .err => |err| {
                const E = TokenErr;
                switch (err) {
                    E.AllocationErr => return "Could not allocate memory for token",
                    E.UnexpectedChar => return "Unexpected character",
                    E.IllegalTab => return "Tabs may not be used for indentation or whitespace",
                    E.ParseIntFailure => return "Failed to parse Int from characters",
                    E.UnterminatedString => return "Unterminated string literal",
                }
            },
        };
    }
};

/// Source code location.
pub const Loc = struct {
    line: usize,
    col: usize,
};

pub const SpanToken = struct {
    token: Token,
    start: Loc,
    end: Loc,

    const Self = @This();

    pub fn new(token: Token, start: Loc, end: Loc) Self {
        return Self{
            .token = token,
            .start = start,
            .end = end,
        };
    }

    pub fn print(self: Self) void {
        return std.debug.print("{s} at {d}:{d} -> {d}:{d}\n", .{
            self.token.to_str(),
            self.start.line,
            self.start.col,
            self.end.line,
            self.end.col,
        });
    }
};
