/**
 * PLVM 词法分析器模块
 *
 * 本模块实现源代码的词法分析，将源代码字符串转换为词法单元（Token）序列。
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.lexer;

import plvm.token;
import std.exception : enforce;
import std.conv : text;

/**
 * 词法分析异常类
 *
 * 表示词法分析过程中的错误。
 */
class LexerException : Exception
{
    size_t line;    /// 错误行号
    size_t column;  /// 错误列号

    /**
     * 构造词法分析异常
     *
     * Params:
     *   msg = 错误消息
     *   l = 行号
     *   c = 列号
     */
    this(string msg, size_t l, size_t c)
    {
        super(text("词法错误 (", l, ":", c, "): ", msg));
        line = l;
        column = c;
    }
}

/**
 * 词法分析器类
 *
 * 将源代码字符串转换为词法单元序列。
 */
class Lexer
{
private:
    string source;      /// 源代码
    size_t pos;         /// 当前位置
    size_t line;        /// 当前行号
    size_t column;      /// 当前列号
    Token[] tokens;     /// 词法单元列表
    size_t fileIndex;   /// 文件索引

    /// 检查是否到达文件末尾
    bool isEOF() const pure nothrow @nogc @safe
    {
        return pos >= source.length;
    }

    /// 查看当前字符
    char peek() const pure nothrow @nogc @safe
    {
        if (isEOF()) return '\0';
        return source[pos];
    }

    /// 查看下一个字符
    char peekNext() const pure nothrow @nogc @safe
    {
        if (pos + 1 >= source.length) return '\0';
        return source[pos + 1];
    }

    /// 前进一个字符
    char advance() nothrow @safe
    {
        if (isEOF()) return '\0';
        char c = source[pos];
        pos++;
        column++;
        if (c == '\n')
        {
            line++;
            column = 1;
        }
        return c;
    }

    /// 匹配期望字符
    bool match_(char expected) nothrow @safe
    {
        if (isEOF() || peek() != expected) return false;
        advance();
        return true;
    }

    /// 跳过空白字符和注释
    void skipWhitespace() nothrow @safe
    {
        while (!isEOF())
        {
            char c = peek();
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n')
                advance();
            else if (c == '/' && peekNext() == '/')
            {
                while (!isEOF() && peek() != '\n')
                    advance();
            }
            else if (c == '/' && peekNext() == '*')
            {
                advance(); advance();
                while (!isEOF())
                {
                    if (peek() == '*' && peekNext() == '/')
                    {
                        advance(); advance();
                        break;
                    }
                    advance();
                }
            }
            else if (c == '/' && peekNext() == '+')
            {
                advance(); advance();
                int depth = 1;
                while (!isEOF() && depth > 0)
                {
                    if (peek() == '+' && peekNext() == '/')
                    {
                        advance(); advance();
                        depth--;
                    }
                    else if (peek() == '/' && peekNext() == '+')
                    {
                        advance(); advance();
                        depth++;
                    }
                    else
                        advance();
                }
            }
            else
                break;
        }
    }

    Token makeToken(TokenType t, string lex) nothrow @safe
    {
        Token tok;
        tok.type = t;
        tok.lexeme = lex;
        tok.line = line;
        tok.column = column - lex.length;
        tok.fileIndex = fileIndex;
        return tok;
    }

    Token readNumber() @safe
    {
        size_t start = pos;
        string numStr;
        bool hex = false, bin = false, oct_ = false;
        if (peek() == '0')
        {
            numStr ~= advance();
            char n = peek();
            if (n == 'x' || n == 'X')
            {
                hex = true;
                numStr ~= advance();
            }
            else if (n == 'b' || n == 'B')
            {
                bin = true;
                numStr ~= advance();
            }
            else if (n == 'o' || n == 'O')
            {
                oct_ = true;
                numStr ~= advance();
            }
        }
        while (!isEOF())
        {
            char c = peek();
            if (c == '_') { advance(); continue; }
            if (hex && ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))
                numStr ~= advance();
            else if (bin && (c == '0' || c == '1'))
                numStr ~= advance();
            else if (oct_ && (c >= '0' && c <= '7'))
                numStr ~= advance();
            else if (!hex && !bin && !oct_ && c >= '0' && c <= '9')
                numStr ~= advance();
            else
                break;
        }
        string lexeme = source[start .. pos];
        return makeToken(TokenType.tokInteger, lexeme);
    }

    Token readString_(char delim = '"') @safe
    {
        size_t start = pos;
        advance();
        while (!isEOF() && peek() != delim)
        {
            if (peek() == '\\')
            {
                advance();
                if (!isEOF()) advance();
            }
            else
                advance();
        }
        if (!isEOF()) advance();
        string lexeme = source[start .. pos];
        return makeToken(TokenType.tokString_, lexeme);
    }

    Token readChar_() @safe
    {
        size_t start = pos;
        advance();
        while (!isEOF() && peek() != '\'')
        {
            if (peek() == '\\')
            {
                advance();
                if (!isEOF()) advance();
            }
            else
                advance();
        }
        if (!isEOF()) advance();
        string lexeme = source[start .. pos];
        return makeToken(TokenType.tokChar_, lexeme);
    }

    Token readIdentifier() @safe
    {
        size_t start = pos;
        while (!isEOF())
        {
            char c = peek();
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                (c >= '0' && c <= '9') || c == '_')
                advance();
            else
                break;
        }
        string lexeme = source[start .. pos];
        return makeToken(checkKeyword(lexeme), lexeme);
    }

    TokenType checkKeyword(string lex) pure nothrow @nogc @safe
    {
        switch (lex)
        {
            case "void": return TokenType.tokKwVoid;
            case "bool": return TokenType.tokKwBool;
            case "byte": return TokenType.tokKwByte;
            case "ubyte": return TokenType.tokKwUbyte;
            case "short": return TokenType.tokKwShort;
            case "ushort": return TokenType.tokKwUshort;
            case "int": return TokenType.tokKwInt;
            case "uint": return TokenType.tokKwUint;
            case "long": return TokenType.tokKwLong;
            case "ulong": return TokenType.tokKwUlong;
            case "char": return TokenType.tokKwChar;
            case "wchar": return TokenType.tokKwWchar;
            case "dchar": return TokenType.tokKwDchar;
            case "string": return TokenType.tokKwString;
            case "wstring": return TokenType.tokKwWstring;
            case "dstring": return TokenType.tokKwDstring;
            case "if": return TokenType.tokKwIf;
            case "else": return TokenType.tokKwElse;
            case "while": return TokenType.tokKwWhile;
            case "do": return TokenType.tokKwDo;
            case "for": return TokenType.tokKwFor;
            case "foreach": return TokenType.tokKwForeach;
            case "switch": return TokenType.tokKwSwitch;
            case "case": return TokenType.tokKwCase;
            case "default": return TokenType.tokKwDefault;
            case "return": return TokenType.tokKwReturn;
            case "break": return TokenType.tokKwBreak;
            case "continue": return TokenType.tokKwContinue;
            case "true": return TokenType.tokKwTrue;
            case "false": return TokenType.tokKwFalse;
            case "null": return TokenType.tokKwNull;
            case "cast": return TokenType.tokKwCast;
            case "scope": return TokenType.tokKwScope;
            case "struct": return TokenType.tokKwStruct;
            case "enum": return TokenType.tokKwEnum;
            case "function": return TokenType.tokKwFunction;
            case "delegate": return TokenType.tokKwDelegate;
            case "is": return TokenType.tokKwIs;
            case "auto": return TokenType.tokKwAuto;
            case "in": return TokenType.tokKwIn;
            case "out": return TokenType.tokKwOut;
            case "ref": return TokenType.tokKwRef;
            case "static": return TokenType.tokKwStatic;
            case "const": return TokenType.tokKwConst;
            case "immutable": return TokenType.tokKwImmutable;
            case "this": return TokenType.tokKwThis;
            case "typeof": return TokenType.tokKwTypeof;
            case "sizeof": return TokenType.tokKwSizeof;
            default: return TokenType.tokIdentifier;
        }
    }

public:
    this(string src, size_t fileIdx = 0)
    {
        source = src;
        pos = 0;
        line = 1;
        column = 1;
        fileIndex = fileIdx;
    }

    Token[] lex()
    {
        tokens = [];

        while (!isEOF())
        {
            size_t oldPos = pos;
            skipWhitespace();
            if (isEOF()) break;

            size_t tokLine = line;
            size_t tokCol = column;

            char c = peek();

            if (c == '"')
            {
                Token tok = readString_('"');
                tok.line = tokLine;
                tok.column = tokCol;
                tokens ~= tok;
            }
            else if (c == '`')
            {
                Token tok = readString_('`');
                tok.line = tokLine;
                tok.column = tokCol;
                tokens ~= tok;
            }
            else if (c == '\'')
            {
                Token tok = readChar_();
                tok.line = tokLine;
                tok.column = tokCol;
                tokens ~= tok;
            }
            else if (c == '.' && (peekNext() >= '0' && peekNext() <= '9'))
            {
                Token tok = readNumber();
                tok.line = tokLine;
                tok.column = tokCol;
                tokens ~= tok;
            }
            else if ((c >= '0' && c <= '9'))
            {
                Token tok = readNumber();
                tok.line = tokLine;
                tok.column = tokCol;
                tokens ~= tok;
            }
            else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')
            {
                Token tok = readIdentifier();
                tok.line = tokLine;
                tok.column = tokCol;
                tokens ~= tok;
            }
            else
            {
                switch (c)
                {
                    case '(': tokens ~= makeToken(TokenType.tokLParen, "("); advance(); break;
                    case ')': tokens ~= makeToken(TokenType.tokRParen, ")"); advance(); break;
                    case '{': tokens ~= makeToken(TokenType.tokLBrace, "{"); advance(); break;
                    case '}': tokens ~= makeToken(TokenType.tokRBrace, "}"); advance(); break;
                    case '[': tokens ~= makeToken(TokenType.tokLBracket, "["); advance(); break;
                    case ']': tokens ~= makeToken(TokenType.tokRBracket, "]"); advance(); break;
                    case ',': tokens ~= makeToken(TokenType.tokComma, ","); advance(); break;
                    case ';': tokens ~= makeToken(TokenType.tokSemicolon, ";"); advance(); break;
                    case '.': tokens ~= makeToken(TokenType.tokDot, "."); advance(); break;
                    case ':': tokens ~= makeToken(TokenType.tokColon, ":"); advance(); break;
                    case '?': tokens ~= makeToken(TokenType.tokQuestion, "?"); advance(); break;
                    case '~':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokTildeEq, "~=");
                        else
                            tokens ~= makeToken(TokenType.tokTilde, "~");
                        break;
                    case '+':
                        advance();
                        if (match_('+'))
                            tokens ~= makeToken(TokenType.tokPlusPlus, "++");
                        else if (match_('='))
                            tokens ~= makeToken(TokenType.tokPlusEq, "+=");
                        else
                            tokens ~= makeToken(TokenType.tokPlus, "+");
                        break;
                    case '-':
                        advance();
                        if (match_('-'))
                            tokens ~= makeToken(TokenType.tokMinusMinus, "--");
                        else if (match_('='))
                            tokens ~= makeToken(TokenType.tokMinusEq, "-=");
                        else if (match_('>'))
                            tokens ~= makeToken(TokenType.tokArrow, "->");
                        else
                            tokens ~= makeToken(TokenType.tokMinus, "-");
                        break;
                    case '*':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokStarEq, "*=");
                        else
                            tokens ~= makeToken(TokenType.tokStar, "*");
                        break;
                    case '/':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokSlashEq, "/=");
                        else
                            tokens ~= makeToken(TokenType.tokSlash, "/");
                        break;
                    case '%':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokPercentEq, "%=");
                        else
                            tokens ~= makeToken(TokenType.tokPercent, "%");
                        break;
                    case '=':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokEqEq, "==");
                        else
                            tokens ~= makeToken(TokenType.tokEq, "=");
                        break;
                    case '!':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokNotEq, "!=");
                        else
                            tokens ~= makeToken(TokenType.tokNot, "!");
                        break;
                    case '<':
                        advance();
                        if (match_('<'))
                        {
                            if (match_('='))
                                tokens ~= makeToken(TokenType.tokShlEq, "<<=");
                            else
                                tokens ~= makeToken(TokenType.tokShl, "<<");
                        }
                        else if (match_('='))
                            tokens ~= makeToken(TokenType.tokLte, "<=");
                        else
                            tokens ~= makeToken(TokenType.tokLt, "<");
                        break;
                    case '>':
                        advance();
                        if (match_('>'))
                        {
                            if (match_('='))
                                tokens ~= makeToken(TokenType.tokShrEq, ">>=");
                            else
                                tokens ~= makeToken(TokenType.tokShr, ">>");
                        }
                        else if (match_('='))
                            tokens ~= makeToken(TokenType.tokGte, ">=");
                        else
                            tokens ~= makeToken(TokenType.tokGt, ">");
                        break;
                    case '&':
                        advance();
                        if (match_('&'))
                            tokens ~= makeToken(TokenType.tokAmpAmp, "&&");
                        else if (match_('='))
                            tokens ~= makeToken(TokenType.tokAmpEq, "&=");
                        else
                            tokens ~= makeToken(TokenType.tokAmp, "&");
                        break;
                    case '|':
                        advance();
                        if (match_('|'))
                            tokens ~= makeToken(TokenType.tokPipePipe, "||");
                        else if (match_('='))
                            tokens ~= makeToken(TokenType.tokPipeEq, "|=");
                        else
                            tokens ~= makeToken(TokenType.tokPipe, "|");
                        break;
                    case '^':
                        advance();
                        if (match_('='))
                            tokens ~= makeToken(TokenType.tokCaretEq, "^=");
                        else
                            tokens ~= makeToken(TokenType.tokCaret, "^");
                        break;
                    default:
                        throw new LexerException(text("未识别的字符: '", c, "'"), line, column);
                }
            }
        }
        tokens ~= makeToken(TokenType.tokEOF, "");
        return tokens;
    }
}

unittest
{
    auto lexer = new Lexer("int x = 42;");
    auto tokens = lexer.lex();
    assert(tokens.length >= 5);
    assert(tokens[0].type == TokenType.tokKwInt);
    assert(tokens[1].type == TokenType.tokIdentifier);
    assert(tokens[1].lexeme == "x");
    assert(tokens[2].type == TokenType.tokEq);
    assert(tokens[3].type == TokenType.tokInteger);
    assert(tokens[3].lexeme == "42");
    assert(tokens[4].type == TokenType.tokSemicolon);
}

unittest
{
    auto lexer = new Lexer("if (x < 10) return true;");
    auto tokens = lexer.lex();
    assert(tokens[0].type == TokenType.tokKwIf);
    assert(tokens[1].type == TokenType.tokLParen);
    assert(tokens[2].type == TokenType.tokIdentifier);
    assert(tokens[3].type == TokenType.tokLt);
    assert(tokens[4].type == TokenType.tokInteger);
    assert(tokens[5].type == TokenType.tokRParen);
    assert(tokens[6].type == TokenType.tokKwReturn);
    assert(tokens[7].type == TokenType.tokKwTrue);
}

unittest
{
    auto lexer = new Lexer("\"hello world\"");
    auto tokens = lexer.lex();
    assert(tokens[0].type == TokenType.tokString_);
    assert(tokens[0].lexeme == "\"hello world\"");
}

unittest
{
    auto lexer = new Lexer("// 这是注释\nint x;");
    auto tokens = lexer.lex();
    assert(tokens[0].type == TokenType.tokKwInt);
    assert(tokens[1].type == TokenType.tokIdentifier);
}
