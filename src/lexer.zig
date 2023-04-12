const std = @import("std");
const ArrayList = std.ArrayList;

const token_ns = @import("./token.zig");
const Token = token_ns.Token;
const TokenErr = token_ns.TokenErr;
const TokenResult = token_ns.TokenResult;

pub const Lexer = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    /// Source code
    source: []const u8,

    /// Number of characters/bytes in source
    len: u32,

    /// Index of current char in source
    pos: u32,

    /// Line of current char in source
    line: u32,

    /// Column of current char in source
    col: u32,

    /// Start index of current token
    start: u32,

    /// Start line of current token
    start_line: u32,

    /// Start column of current token
    start_col: u32,

    indent_level: u8,
    bracket_stack: ArrayList(Token),

    pub fn init(allocator: *std.mem.Allocator, source: []const u8) Self {
        return Self{
            .allocator = allocator,
            .source = source,
            .len = @intCast(u32, source.len),
            .pos = 0,
            .line = 1,
            .col = 0,
            .start = 0,
            .start_line = 1,
            .start_col = 0,
            .indent_level = 0,
            .bracket_stack = ArrayList(Token).init(allocator.*),
        };
    }

    /// Get next token or error.
    pub fn next(self: *Self) ?TokenResult {
        self.start = self.pos;

        if (self.next_char()) |c| {
            self.start_line = self.line;
            self.start_col = self.col;

            return switch (c) {
                ' ' => {
                    self.skip_while(is_space);
                    return self.next();
                },
                '\n' => {
                    if (self.handle_newline()) |result| {
                        return result;
                    }
                    return self.next();
                },
                // Groupings -------------------------------------------
                '(' => self.push_bracket(.lparen),
                ')' => self.make_token(.rparen),
                '[' => self.push_bracket(.lbrace),
                ']' => self.make_token(.rbrace),
                '{' => self.push_bracket(.lbracket),
                '}' => self.make_token(.rbracket),
                // Keyword Types ---------------------------------------
                'a'...'z' => self.scan_keyword_or_ident(),
                '@' => self.make_token(.always),
                // Types -----------------------------------------------
                '0' => if (self.peek_char()) |d| switch (d) {
                    'b', 'B' => self.scan_number_base_2(),
                    'o', 'O' => self.scan_number_base_8(),
                    'x', 'X' => self.scan_number_base_16(),
                    else => self.scan_number_base_10(),
                } else self.make_token(.int),
                '1'...'9' => self.scan_number_base_10(),
                '"' => self.scan_str(c),
                '\'' => self.scan_str(c),
                // Binary Operators ------------------------------------
                '*' => self.make_token(.star),
                '/' => self.make_token(.slash),
                '+' => self.make_token(.plus),
                '-' => self.make_token(.dash),
                // Errors ----------------------------------------------
                '\t' => self.make_err(error.IllegalTab),
                else => self.make_err(error.UnexpectedChar),
            };
        }

        return null;
    }

    /// Info about the current token
    const TokenInfo = struct {
        start: u32,
        end: u32,
        start_line: u32,
        start_col: u32,
        end_line: u32,
        end_col: u32,
        lexeme: []const u8,
    };

    /// XXX: This should only be called after next() is called
    pub fn token_info(self: Self) TokenInfo {
        return .{
            .start = self.start,
            .end = self.pos - 1,
            .start_line = self.start_line,
            .start_col = self.start_col,
            .end_line = self.line,
            .end_col = self.col,
            .lexeme = self.source[self.start..self.pos],
        };
    }

    fn make_token(self: Self, kind: Token.Kind) TokenResult {
        return .{
            .Ok = .{
                .kind = kind,
                .start = self.start,
                .end = self.pos - 1,
            },
        };
    }

    fn make_err(self: Self, err: TokenErr.Kind) TokenResult {
        return .{
            .Err = .{
                .kind = err,
                .start = self.start,
                .end = self.pos - 1,
            },
        };
    }

    /// TODO: Indent, dedent, etc
    fn handle_newline(self: *Self) ?TokenResult {
        _ = self;
        return null;
    }

    fn push_bracket(self: *Self, kind: Token.Kind) TokenResult {
        const token = .{
            .kind = kind,
            .start = self.start,
            .end = self.start,
        };
        self.bracket_stack.append(token) catch |err| {
            return self.make_err(err);
        };
        return .{ .Ok = token };
    }

    // Scanners --------------------------------------------------------

    fn scan_keyword_or_ident(self: *Self) ?TokenResult {
        self.skip_until_boundary();
        const info = self.token_info();
        if (Token.keywords.get(info.lexeme)) |kind| {
            return self.make_token(kind);
        }
        return self.make_token(.ident);
    }

    fn scan_number_base_10(self: *Self) ?TokenResult {
        self.skip_until_boundary();

        const info = self.token_info();
        const lexeme = info.lexeme;

        if (lexeme[0] == '0' and lexeme.len > 1 and is_digit(lexeme[1])) {
            return self.make_err(error.LeadingZero);
        }

        if (self.peek_char()) |d| {
            if (d == '.') {
                _ = self.next_char();
                self.skip_until_boundary();
                return self.make_token(.float);
            }
        }

        return self.make_token(.int);
    }

    fn scan_number_base_2(self: *Self) ?TokenResult {
        self.skip_until_boundary();
        return self.make_token(.int2);
    }

    fn scan_number_base_8(self: *Self) ?TokenResult {
        self.skip_until_boundary();
        return self.make_token(.int8);
    }

    fn scan_number_base_16(self: *Self) ?TokenResult {
        self.skip_until_boundary();
        return self.make_token(.int16);
    }

    fn scan_str(self: *Self, quote: u8) ?TokenResult {
        switch (quote) {
            '"' => self.skip_until(is_double_quote),
            '\'' => self.skip_until(is_single_quote),
            else => unreachable,
        }
        if (self.next_char() == quote) {
            return self.make_token(.str);
        }
        return self.make_err(error.UnterminatedString);
    }

    // Character handling ----------------------------------------------

    /// Consume and return next character. Normalizes \r\n style
    /// newlines to \n.
    fn next_char(self: *Self) ?u8 {
        if (self.pos == self.len) {
            return null;
        }

        var c = self.source[self.pos];

        if (c == '\r') {
            if (self.peek_char()) |d| {
                if (d == '\n') {
                    self.pos += 1;
                    c = '\n';
                }
            }
        }

        self.pos += 1;

        if (c == '\n') {
            self.line += 1;
            self.col = 0;
        } else {
            self.col += 1;
        }

        return c;
    }

    /// Peek at next character without consuming it.
    fn peek_char(self: *Self) ?u8 {
        if (self.pos == self.len) {
            return null;
        }
        return self.source[self.pos];
    }

    fn skip_while(self: *Self, comptime test_fn: fn (c: u8) bool) void {
        while (self.peek_char()) |c| {
            if (test_fn(c)) {
                _ = self.next_char();
            } else {
                break;
            }
        }
    }

    fn skip_until(self: *Self, comptime test_fn: fn (c: u8) bool) void {
        while (self.peek_char()) |c| {
            if (!test_fn(c)) {
                _ = self.next_char();
            } else {
                break;
            }
        }
    }

    fn skip_until_boundary(self: *Self) void {
        self.skip_until(is_boundary);
    }
};

fn is_space(c: u8) bool {
    return c == ' ';
}

fn is_whitespace(c: u8) bool {
    return std.ascii.isWhitespace(c);
}

fn is_bracket(c: u8) bool {
    return switch (c) {
        '(', ')', '[', ']', '{', '}' => true,
        else => false,
    };
}

fn is_digit(c: u8) bool {
    return std.ascii.isDigit(c);
}

fn is_binary_digit(c: u8) bool {
    return switch (c) {
        '0'...'1' => true,
        else => false,
    };
}

fn is_octal_digit(c: u8) bool {
    return switch (c) {
        '0'...'7' => true,
        else => false,
    };
}

fn is_hex_digit(c: u8) bool {
    return std.ascii.isHex(c);
}

fn is_operator(c: u8) bool {
    return switch (c) {
        '*', '/', '+', '-' => true,
        else => false,
    };
}

fn is_boundary(c: u8) bool {
    if (is_whitespace(c) or is_bracket(c) or is_operator(c)) {
        return true;
    }
    return switch (c) {
        '.' => true,
        else => false,
    };
}

fn is_double_quote(c: u8) bool {
    return c != '"';
}

fn is_single_quote(c: u8) bool {
    return c != '\'';
}
