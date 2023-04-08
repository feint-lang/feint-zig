const std = @import("std");
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const tokenNS = @import("./token.zig");
const Token = tokenNS.Token;
const Loc = tokenNS.Loc;
const SpanToken = tokenNS.SpanToken;
const TokenErr = tokenNS.TokenErr;

pub const Lexer = struct {
    allocator: std.mem.Allocator,

    /// Source code
    source: []const u8,

    /// Number of characters/bytes in source
    len: usize,

    /// Index of current char in source
    pos: usize,

    /// Current line number (1-based)
    line: usize,

    /// Current column number (1-based)
    col: usize,

    /// Start of current token
    start: Loc,

    const Self = @This();

    pub fn new(allocator: std.mem.Allocator, source: []const u8) Self {
        return Self{
            .allocator = allocator,
            .source = source,
            .len = source.len,
            .pos = 0,
            .line = 1,
            .col = 0,
            .start = undefined,
        };
    }

    /// Get next token.
    pub fn next(self: *Self) SpanToken {
        if (self.next_char()) |c| {
            // std.debug.print("c = {c}\n", .{c});
            self.start = Loc{ .line = self.line, .col = self.col };
            return switch (c) {
                ' ' => {
                    self.skip_spaces();
                    return self.next();
                },
                '\n' => self.handle_newline(),
                '0'...'9' => self.scan_number(),
                '"' => self.scan_str('"'),
                '\'' => self.scan_str('\''),
                '*' => self.make_token(.star),
                '/' => self.make_token(.slash),
                '+' => self.make_token(.plus),
                '-' => self.make_token(.dash),
                '\t' => self.make_err(TokenErr.IllegalTab),
                else => self.make_err(TokenErr.UnexpectedChar),
            };
        }

        return self.make_token(.eof);
    }

    fn make_token(self: Self, token: Token) SpanToken {
        const end = Loc{ .line = self.line, .col = self.col };
        return SpanToken.new(token, self.start, end);
    }

    fn make_err(self: Self, err: TokenErr) SpanToken {
        return self.make_token(Token{ .err = err });
    }

    // Scanners --------------------------------------------------------

    fn handle_newline(self: *Self) SpanToken {
        return self.make_token(.nl);
    }

    fn scan_number(self: *Self) SpanToken {
        const start_pos = self.pos - 1;
        self.skip_while(std.ascii.isDigit);
        const digits = self.source[start_pos..self.pos];
        const n = parseInt(i128, digits, 10) catch {
            return self.make_err(TokenErr.ParseIntFailure);
        };
        return self.make_token(Token{ .int = n });
    }

    fn scan_str(self: *Self, quote: u8) SpanToken {
        const start_pos = self.pos;
        var v = std.ArrayList(u8).init(self.allocator);
        switch (quote) {
            '"' => self.skip_double_quoted_str(),
            '\'' => self.skip_single_quoted_str(),
            else => unreachable,
        }
        const end_pos = self.pos;
        if (self.next_char() == quote) {
            v.appendSlice(self.source[start_pos..end_pos]) catch {
                return self.make_err(TokenErr.AllocationErr);
            };
            return self.make_token(Token{ .str = v });
        }
        return self.make_err(TokenErr.UnterminatedString);
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

    fn skip_spaces(self: *Self) void {
        self.skip_while(is_space);
    }

    fn skip_double_quoted_str(self: *Self) void {
        self.skip_while(is_not_double_quote);
    }

    fn skip_single_quoted_str(self: *Self) void {
        self.skip_while(is_not_single_quote);
    }
};

fn is_space(c: u8) bool {
    return c == ' ';
}

fn is_not_double_quote(c: u8) bool {
    return c != '"';
}

fn is_not_single_quote(c: u8) bool {
    return c != '\'';
}

pub fn display_tokens(source: []const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var lexer = Lexer.new(arena.allocator(), source);

    while (true) {
        const token = lexer.next();
        switch (token.token) {
            Token.err => {
                token.print();
                break;
            },
            Token.eof => {
                token.print();
                break;
            },
            else => token.print(),
        }
    }
}
