const std = @import("std");

pub const Token = struct {
    const Self = @This();

    kind: Kind,
    start: u32,
    end: u32,

    pub fn init(kind: Kind, start: u32, end: u32) Self {
        return .{
            .kind = kind,
            .start = start,
            .end = end,
        };
    }

    pub fn format(self: Self) []const u8 {
        return self.kind.format();
    }

    pub const keywords = std.ComptimeStringMap(
        Kind,
        .{
            .{ "nil", .nil },
            .{ "true", .true_ },
            .{ "false", .false_ },
            .{ "import", .import },
            .{ "as", .as },
            .{ "block", .block },
            .{ "if", .if_ },
            .{ "else", .else_ },
            .{ "match", .match },
            .{ "loop", .loop },
            .{ "break", .break_ },
            .{ "continue", .continue_ },
            .{ "jump", .jump },
            .{ "return", .return_ },
            .{ "$halt", .halt },
            .{ "$print", .print },
        },
    );

    pub const Kind = enum {
        scope,

        // Groupings ---------------------------------------------------
        lparen,
        rparen,
        lbracket,
        rbracket,
        lbrace,
        rbrace,

        // Keyword Types -----------------------------------------------
        nil,
        true_,
        false_,

        // Types -------------------------------------------------------
        always,
        int,
        int2,
        int8,
        int16,
        float,
        str,

        // Keywords ----------------------------------------------------
        import,
        as,
        block,
        if_,
        else_,
        match,
        loop,
        break_,
        continue_,
        jump,
        return_,
        halt,
        print,

        // Identifiers -------------------------------------------------
        ident,

        // Binary Operators --------------------------------------------
        star,
        slash,
        plus,
        dash,

        end_of_statement,

        // XXX: NL isn't a token and should be removed
        nl,

        pub fn format(self: Kind) []const u8 {
            return switch (self) {
                .scope => "->",

                // Groupings -------------------------------------------
                .lparen => "(",
                .rparen => ")",
                .lbracket => "[",
                .rbracket => "]",
                .lbrace => "{",
                .rbrace => "}",

                // Keyword Types ---------------------------------------
                .nil => "nil",
                .true_ => "true",
                .false_ => "false",
                .always => "@",

                // Types -----------------------------------------------
                .int => "Int",
                .int2 => "Int2",
                .int8 => "Int8",
                .int16 => "Int16",
                .float => "Float",
                .str => "Str",

                // Keywords --------------------------------------------
                .import => "import",
                .as => "as",
                .block => "block",
                .if_ => "if",
                .else_ => "else",
                .match => "match",
                .loop => "loop",
                .break_ => "break",
                .continue_ => "continue",
                .jump => "jump",
                .return_ => "return",
                .halt => "$halt",
                .print => "$print",

                // Identifiers -----------------------------------------
                .ident => "ident",

                // Binary Operators ------------------------------------
                .star => "*",
                .slash => "/",
                .plus => "+",
                .dash => "-",

                .end_of_statement => ";",
                .nl => "\\n",
            };
        }
    };
};

pub const TokenErr = struct {
    const Self = @This();

    pub const Kind = error{
        OutOfMemory,
        UnexpectedChar,
        IllegalTab,
        LeadingZero,
        UnterminatedString,
    };

    kind: Kind,
    start: u32,
    end: u32,

    pub fn format(self: Self) []const u8 {
        return switch (self.kind) {
            error.OutOfMemory => "Out of memory",
            error.UnexpectedChar => "Unexpected character",
            error.IllegalTab => "Tabs may not be used for indentation or whitespace",
            error.LeadingZero => "Decimal numbers may not start with a leading zero",
            error.UnterminatedString => "Unterminated string literal",
        };
    }
};

pub const TokenResult = union(enum) {
    const Self = @This();

    Ok: Token,
    Err: TokenErr,

    pub fn start(self: Self) u32 {
        return switch (self) {
            .Ok => |token| token.start,
            .Err => |err| err.start,
        };
    }

    pub fn end(self: Self) u32 {
        return switch (self) {
            .Ok => |token| token.end,
            .Err => |err| err.end,
        };
    }

    pub fn format(self: Self) []const u8 {
        return switch (self) {
            .Ok => |token| token.format(),
            .Err => |err| err.format(),
        };
    }
};
