pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,

    const Self = @This();

    pub fn new(kind: TokenType, lexeme: []const u8) Self {
        return Self{
            .kind = kind,
            .lexeme = lexeme,
        };
    }
};

pub const TokenType = enum {
    int,
    float,
    string,

    unknown,

    eof,
};

pub const SpanToken = struct {
    token: Token,
    start: Pos,
    end: Pos,

    const Self = @This();

    pub fn new(kind: TokenType, lexeme: []const u8, start: Pos, end: Pos) Self {
        return Self{
            .token = Token.new(kind, lexeme),
            .start = start,
            .end = end,
        };
    }
};

pub const Span = struct {
    start: Pos,
    end: Pos,
};

pub const Pos = struct {
    line: usize,
    col: usize,
};
