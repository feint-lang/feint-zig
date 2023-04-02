const tokenNS = @import("./token.zig");
const Token = tokenNS.Token;
const TokenType = tokenNS.TokenType;
const SpanToken = tokenNS.SpanToken;

pub const Lexer = struct {
    source: []const u8,
    len: usize,
    i: usize,

    line: usize,
    col: usize,

    const Self = @This();

    pub fn new(source: []const u8) Self {
        return Self{
            .source = source,
            .len = source.len,
            .i = 0,
            .line = 0,
            .col = 0,
        };
    }

    pub fn next(self: *Self) SpanToken {
        if (self.next_char()) |c| {
            const token = switch (c) {
                '0'...'9' => self.scan_number(c),
                else => self.make_token(.unknown, &[_]u8{c}),
            };
            _ = token;
        }

        return self.make_token(.eof, "");
    }

    fn next_char(self: *Self) ?u8 {
        if (self.i == self.len) {
            return null;
        }

        defer self.i += 1;

        const c = self.source[self.i];

        if (c == '\r') {
            if (self.peek_char()) |d| {
                if (d == '\n') {
                    return self.next_char();
                }
            }
        }

        if (c == '\n') {
            self.line += 1;
            self.col = 0;
        }

        return c;
    }

    fn peek_char(self: *Self) ?u8 {
        const next_i = self.i + 1;
        if (next_i >= self.len) {
            return null;
        }
        return self.source[next_i];
    }

    fn make_token(self: Self, kind: TokenType, lexeme: []const u8) SpanToken {
        return SpanToken.new(
            kind,
            lexeme,
            .{
                .line = self.line,
                .col = self.col,
            },
            .{
                .line = self.line,
                .col = self.col,
            },
        );
    }

    fn scan_number(self: Self, first_digit: u8) SpanToken {
        var lexeme = [_]u8{first_digit};
        return self.make_token(.int, &lexeme);
    }
};
