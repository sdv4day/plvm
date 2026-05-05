module plvm.parser;

import plvm.token;
import plvm.ast;
import plvm.lexer;
import std.exception : enforce;
import std.conv : text, to;

class ParseException : Exception
{
    size_t line, column;
    this(string msg, size_t l, size_t c)
    {
        super(text("语法错误 (", l, ":", c, "): ", msg));
        line = l;
        column = c;
    }
}

class Parser
{
private:
    Token[] tokens;
    size_t current;
    string[] registeredStructNames;
    string[] registeredEnumNames;
    string[string][string] enumMembers;
    string[] registeredFuncNames;

    bool isEOF()
    {
        return tokens[current].type == TokenType.tokEOF;
    }

    Token peek()
    {
        return tokens[current];
    }

    Token peekNext()
    {
        if (current + 1 >= tokens.length)
            return tokens[$ - 1];
        return tokens[current + 1];
    }

    Token previous()
    {
        return tokens[current - 1];
    }

    Token advance()
    {
        if (!isEOF()) current++;
        return previous();
    }

    bool check(TokenType t)
    {
        if (isEOF()) return false;
        return peek().type == t;
    }

    bool match_(TokenType t)
    {
        if (check(t))
        {
            advance();
            return true;
        }
        return false;
    }

    Token consume(TokenType t, string msg)
    {
        if (check(t))
            return advance();
        throw new ParseException(msg, peek().line, peek().column);
    }

    AstNode parseProgram()
    {
        auto program = new ProgramNode();
        while (!isEOF())
        {
            auto decl = parseDeclaration();
            if (decl)
                program.declarations ~= decl;
        }
        return program;
    }

    AstNode parseDeclaration()
    {
        Token tok = peek();

        if (check(TokenType.tokKwStruct))
            return parseStructDecl();
        if (check(TokenType.tokKwEnum))
            return parseEnumDecl();

        return parseFunctionOrVarDecl();
    }

    AstNode parseStructDecl()
    {
        consume(TokenType.tokKwStruct, "期望 'struct'");
        auto node = new StructDeclNode();
        node.name = consume(TokenType.tokIdentifier, "期望结构体名称").lexeme;
        consume(TokenType.tokLBrace, "期望 '{'");

        while (!check(TokenType.tokRBrace) && !isEOF())
        {
            StructDeclNode.Field field;
            auto typeNode = parseType();
            field.typeNode = typeNode;
            field.typeName = typeNode.typeName;
            field.name = consume(TokenType.tokIdentifier, "期望字段名称").lexeme;
            consume(TokenType.tokSemicolon, "期望 ';'");
            node.fields ~= field;
        }

        consume(TokenType.tokRBrace, "期望 '}'");
        return node;
    }

    AstNode parseEnumDecl()
    {
        consume(TokenType.tokKwEnum, "期望 'enum'");
        auto node = new EnumDeclNode();
        node.name = consume(TokenType.tokIdentifier, "期望枚举名称").lexeme;

        if (match_(TokenType.tokColon))
        {
            node.baseTypeName = consume(TokenType.tokIdentifier, "期望枚举基础类型").lexeme;
        }

        consume(TokenType.tokLBrace, "期望 '{'");

        while (!check(TokenType.tokRBrace) && !isEOF())
        {
            EnumDeclNode.Member member;
            member.name = consume(TokenType.tokIdentifier, "期望枚举成员名称").lexeme;

            if (match_(TokenType.tokEq))
            {
                member.valueExpr = consume(TokenType.tokInteger, "期望枚举值").lexeme;
            }

            if (!check(TokenType.tokRBrace))
                consume(TokenType.tokComma, "期望 ',' 或 '}'");

            node.members ~= member;
        }

        consume(TokenType.tokRBrace, "期望 '}'");
        return node;
    }

    AstNode parseFunctionOrVarDecl()
    {
        TypeNode returnType;
        bool hasReturnType = false;

        if (isTypeToken(peek().type))
        {
            returnType = parseType();
            hasReturnType = true;
        }
        else
        {
            returnType = new TypeNode("void");
        }

        if (isEOF()) return null;

        string name = peek().lexeme;

        if (peekNext().type == TokenType.tokLParen)
        {
            return parseFunctionDecl(returnType);
        }
        else
        {
            return parseVarDecl(returnType, hasReturnType);
        }
    }

    AstNode parseFunctionDecl(TypeNode returnType)
    {
        auto node = new FunctionDeclNode();
        node.line = peek().line;
        node.column = peek().column;
        node.returnType = returnType;
        node.returnTypeName = returnType.typeName;
        node.name = consume(TokenType.tokIdentifier, "期望函数名称").lexeme;

        consume(TokenType.tokLParen, "期望 '('");

        while (!check(TokenType.tokRParen) && !isEOF())
        {
            FunctionDeclNode.Param param;
            auto pType = parseType();
            param.typeNode = pType;
            param.typeName = pType.typeName;
            param.name = consume(TokenType.tokIdentifier, "期望参数名称").lexeme;
            node.params ~= param;

            if (!check(TokenType.tokRParen))
                consume(TokenType.tokComma, "期望 ',' 或 ')'");
        }

        consume(TokenType.tokRParen, "期望 ')'");

        if (match_(TokenType.tokSemicolon))
        {
            return node;
        }

        node.body = cast(BlockStmtNode)parseBlock();
        return node;
    }

    AstNode parseVarDecl(TypeNode typeNode, bool hasType = true)
    {
        auto node = new VarDeclNode();
        node.line = peek().line;
        node.column = peek().column;
        node.name = consume(TokenType.tokIdentifier, "期望变量名称").lexeme;
        node.typeNode = typeNode;

        if (match_(TokenType.tokEq))
        {
            node.initializer = parseExpression();
        }

        consume(TokenType.tokSemicolon, "期望 ';'");
        return node;
    }

    AstNode parseBlock()
    {
        consume(TokenType.tokLBrace, "期望 '{'");
        auto node = new BlockStmtNode();

        while (!check(TokenType.tokRBrace) && !isEOF())
        {
            node.statements ~= parseStatement();
        }

        consume(TokenType.tokRBrace, "期望 '}'");
        return node;
    }

    AstNode parseStatement()
    {
        Token tok = peek();

        if (check(TokenType.tokKwIf))
            return parseIfStmt();
        if (check(TokenType.tokKwWhile))
            return parseWhileStmt();
        if (check(TokenType.tokKwDo))
            return parseDoWhileStmt();
        if (check(TokenType.tokKwFor))
            return parseForOrForeachStmt();
        if (check(TokenType.tokKwForeach))
            return parseForeachStmt();
        if (check(TokenType.tokKwSwitch))
            return parseSwitchStmt();
        if (check(TokenType.tokKwReturn))
            return parseReturnStmt();
        if (check(TokenType.tokKwBreak))
        {
            advance();
            auto node = new BreakStmtNode();
            consume(TokenType.tokSemicolon, "期望 ';'");
            return node;
        }
        if (check(TokenType.tokKwContinue))
        {
            advance();
            auto node = new ContinueStmtNode();
            consume(TokenType.tokSemicolon, "期望 ';'");
            return node;
        }
        if (check(TokenType.tokLBrace))
            return parseBlock();
        if (check(TokenType.tokSemicolon))
        {
            advance();
            return null;
        }

        if (isTypeTokenInDeclContext())
        {
            return parseVarDecl(parseType());
        }

        return parseExpressionStatement();
    }

    AstNode parseIfStmt()
    {
        auto node = new IfStmtNode();
        node.line = peek().line;
        consume(TokenType.tokKwIf, "");
        consume(TokenType.tokLParen, "期望 '('");
        node.condition = parseExpression();
        consume(TokenType.tokRParen, "期望 ')'");
        node.thenBranch = parseStatement();

        if (match_(TokenType.tokKwElse))
            node.elseBranch = parseStatement();

        return node;
    }

    AstNode parseWhileStmt()
    {
        auto node = new WhileStmtNode();
        node.line = peek().line;
        consume(TokenType.tokKwWhile, "");
        consume(TokenType.tokLParen, "期望 '('");
        node.condition = parseExpression();
        consume(TokenType.tokRParen, "期望 ')'");
        node.body = parseStatement();
        return node;
    }

    AstNode parseDoWhileStmt()
    {
        auto node = new DoWhileStmtNode();
        node.line = peek().line;
        advance();
        node.body = parseStatement();
        consume(TokenType.tokKwWhile, "期望 'while'");
        consume(TokenType.tokLParen, "期望 '('");
        node.condition = parseExpression();
        consume(TokenType.tokRParen, "期望 ')'");
        consume(TokenType.tokSemicolon, "期望 ';'");
        return node;
    }

    AstNode parseForOrForeachStmt()
    {
        advance();
        consume(TokenType.tokLParen, "期望 '('");

        AstNode init = null;

        if (isTypeToken(peek().type) && peekNext().type == TokenType.tokIdentifier)
        {
            TypeNode initType = parseType();
            string varName = consume(TokenType.tokIdentifier, "期望变量名").lexeme;
            if (match_(TokenType.tokSemicolon))
            {
                auto node = new ForStmtNode();
                node.line = peek().line;
                auto vd = new VarDeclNode();
                vd.name = varName;
                vd.typeNode = initType;
                node.init = vd;
                node.condition = parseExpression();
                consume(TokenType.tokSemicolon, "期望 ';'");
                if (!check(TokenType.tokRParen))
                    node.increment = parseExpression();
                consume(TokenType.tokRParen, "期望 ')'");
                node.body = parseStatement();
                return node;
            }
            else if (match_(TokenType.tokComma))
            {
                auto forNode = new ForStmtNode();
                forNode.line = peek().line;
                auto vd = new VarDeclNode();
                vd.name = varName;
                vd.typeNode = initType;
                forNode.init = vd;
                forNode.condition = parseExpression();
                consume(TokenType.tokSemicolon, "期望 ';'");
                if (!check(TokenType.tokRParen))
                    forNode.increment = parseExpression();
                consume(TokenType.tokRParen, "期望 ')'");
                forNode.body = parseStatement();
                return forNode;
            }
            else
            {
                auto forNode = new ForStmtNode();
                forNode.line = peek().line;
                auto assign = new AssignStmtNode();
                auto idNode = new IdentifierExprNode();
                idNode.name = varName;
                assign.target = idNode;
                consume(TokenType.tokEq, "期望 '='");
                assign.value = parseExpression();
                assign.op = "=";
                forNode.init = assign;
                consume(TokenType.tokSemicolon, "期望 ';'");
                forNode.condition = parseExpression();
                consume(TokenType.tokSemicolon, "期望 ';'");
                if (!check(TokenType.tokRParen))
                    forNode.increment = parseExpression();
                consume(TokenType.tokRParen, "期望 ')'");
                forNode.body = parseStatement();
                return forNode;
            }
        }
        else if (match_(TokenType.tokSemicolon))
        {
            auto node = new ForStmtNode();
            node.line = peek().line;
            node.init = null;
            node.condition = parseExpression();
            consume(TokenType.tokSemicolon, "期望 ';'");
            if (!check(TokenType.tokRParen))
                node.increment = parseExpression();
            consume(TokenType.tokRParen, "期望 ')'");
            node.body = parseStatement();
            return node;
        }
        else
        {
            init = parseExpression();
            consume(TokenType.tokSemicolon, "期望 ';'");
            auto node = new ForStmtNode();
            node.line = peek().line;
            node.init = init;
            node.condition = parseExpression();
            consume(TokenType.tokSemicolon, "期望 ';'");
            if (!check(TokenType.tokRParen))
                node.increment = parseExpression();
            consume(TokenType.tokRParen, "期望 ')'");
            node.body = parseStatement();
            return node;
        }
    }

    AstNode parseForeachStmt()
    {
        auto node = new ForeachStmtNode();
        node.line = peek().line;
        consume(TokenType.tokKwForeach, "");
        consume(TokenType.tokLParen, "期望 '('");

        if (isTypeToken(peek().type) && peekNext().type == TokenType.tokIdentifier)
        {
            node.loopVarType = parseType();
            node.loopVarName = consume(TokenType.tokIdentifier, "期望变量名").lexeme;
        }
        else
        {
            node.loopVarName = consume(TokenType.tokIdentifier, "期望变量名").lexeme;
        }

        consume(TokenType.tokSemicolon, "期望 ';'");
        node.iterable = parseExpression();
        consume(TokenType.tokRParen, "期望 ')'");
        node.body = parseStatement();
        return node;
    }

    AstNode parseSwitchStmt()
    {
        auto node = new SwitchStmtNode();
        node.line = peek().line;
        consume(TokenType.tokKwSwitch, "");
        consume(TokenType.tokLParen, "期望 '('");
        node.expression = parseExpression();
        consume(TokenType.tokRParen, "期望 ')'");
        consume(TokenType.tokLBrace, "期望 '{'");

        while (!check(TokenType.tokRBrace) && !isEOF())
        {
            if (match_(TokenType.tokKwCase))
            {
                auto caseNode = new CaseStmtNode();
                caseNode.line = peek().line;
                caseNode.value = parseExpression();
                consume(TokenType.tokColon, "期望 ':'");

                while (!check(TokenType.tokKwCase) && !check(TokenType.tokKwDefault)
                    && !check(TokenType.tokRBrace) && !isEOF())
                {
                    caseNode.body ~= parseStatement();
                }
                node.cases ~= caseNode;
            }
            else if (match_(TokenType.tokKwDefault))
            {
                auto defaultNode = new DefaultStmtNode();
                defaultNode.line = peek().line;
                consume(TokenType.tokColon, "期望 ':'");

                while (!check(TokenType.tokKwCase) && !check(TokenType.tokKwDefault)
                    && !check(TokenType.tokRBrace) && !isEOF())
                {
                    defaultNode.body ~= parseStatement();
                }
                node.cases ~= defaultNode;
            }
            else
            {
                throw new ParseException("期望 'case' 或 'default'", peek().line, peek().column);
            }
        }

        consume(TokenType.tokRBrace, "期望 '}'");
        return node;
    }

    AstNode parseReturnStmt()
    {
        auto node = new ReturnStmtNode();
        node.line = peek().line;
        advance();

        if (!check(TokenType.tokSemicolon))
            node.value = parseExpression();

        consume(TokenType.tokSemicolon, "期望 ';'");
        return node;
    }

    AstNode parseExpressionStatement()
    {
        auto node = new ExprStmtNode();
        node.line = peek().line;

        if (isTypeTokenInDeclContext())
        {
            return parseVarDecl(parseType());
        }

        AstNode expr = parseExpression();
        consume(TokenType.tokSemicolon, "期望 ';'");
        node.expression = expr;
        return node;
    }

    AstNode parseExpression()
    {
        return parseAssignment();
    }

    AstNode parseAssignment()
    {
        AstNode expr = parseTernary();

        if (match_(TokenType.tokEq) || match_(TokenType.tokPlusEq) ||
            match_(TokenType.tokMinusEq) || match_(TokenType.tokStarEq) ||
            match_(TokenType.tokSlashEq) || match_(TokenType.tokPercentEq) ||
            match_(TokenType.tokAmpEq) || match_(TokenType.tokPipeEq) ||
            match_(TokenType.tokCaretEq) || match_(TokenType.tokShlEq) ||
            match_(TokenType.tokShrEq) || match_(TokenType.tokTildeEq))
        {
            auto assign = new AssignStmtNode();
            assign.target = expr;
            assign.op = previous().lexeme;
            assign.value = parseExpression();
            return assign;
        }

        return expr;
    }

    AstNode parseTernary()
    {
        AstNode expr = parseLogicalOr();

        if (match_(TokenType.tokQuestion))
        {
            auto node = new TernaryExprNode();
            node.condition = expr;
            node.thenExpr = parseExpression();
            consume(TokenType.tokColon, "期望 ':'");
            node.elseExpr = parseTernary();
            return node;
        }

        return expr;
    }

    AstNode parseLogicalOr()
    {
        AstNode expr = parseLogicalAnd();

        while (match_(TokenType.tokPipePipe))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = "||";
            node.right = parseLogicalAnd();
            expr = node;
        }

        return expr;
    }

    AstNode parseLogicalAnd()
    {
        AstNode expr = parseEquality();

        while (match_(TokenType.tokAmpAmp))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = "&&";
            node.right = parseEquality();
            expr = node;
        }

        return expr;
    }

    AstNode parseEquality()
    {
        AstNode expr = parseComparison();

        while (match_(TokenType.tokEqEq) || match_(TokenType.tokNotEq))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = previous().lexeme;
            node.right = parseComparison();
            expr = node;
        }

        return expr;
    }

    AstNode parseComparison()
    {
        AstNode expr = parseShift();

        while (match_(TokenType.tokLt) || match_(TokenType.tokLte) ||
               match_(TokenType.tokGt) || match_(TokenType.tokGte))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = previous().lexeme;
            node.right = parseShift();
            expr = node;
        }

        return expr;
    }

    AstNode parseShift()
    {
        AstNode expr = parseAdditive();

        while (match_(TokenType.tokShl) || match_(TokenType.tokShr))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = previous().lexeme;
            node.right = parseAdditive();
            expr = node;
        }

        return expr;
    }

    AstNode parseAdditive()
    {
        AstNode expr = parseMultiplicative();

        while (match_(TokenType.tokPlus) || match_(TokenType.tokMinus))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = previous().lexeme;
            node.right = parseMultiplicative();
            expr = node;
        }

        return expr;
    }

    AstNode parseMultiplicative()
    {
        AstNode expr = parseBitwise();

        while (match_(TokenType.tokStar) || match_(TokenType.tokSlash) || match_(TokenType.tokPercent))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = previous().lexeme;
            node.right = parseBitwise();
            expr = node;
        }

        return expr;
    }

    AstNode parseBitwise()
    {
        AstNode expr = parseUnary();

        while (match_(TokenType.tokAmp) || match_(TokenType.tokPipe) || match_(TokenType.tokCaret))
        {
            auto node = new BinaryExprNode();
            node.left = expr;
            node.op = previous().lexeme;
            node.right = parseUnary();
            expr = node;
        }

        return expr;
    }

    AstNode parseUnary()
    {
        if (match_(TokenType.tokMinus) || match_(TokenType.tokPlus) ||
            match_(TokenType.tokNot) || match_(TokenType.tokTilde) ||
            match_(TokenType.tokPlusPlus) || match_(TokenType.tokMinusMinus))
        {
            auto node = new UnaryExprNode();
            node.op = previous().lexeme;
            node.isPrefix = true;
            node.operand = parseUnary();
            return node;
        }

        if (match_(TokenType.tokKwCast))
            return parseCastExpr();

        return parsePostfix();
    }

    AstNode parseCastExpr()
    {
        auto node = new CastExprNode();
        consume(TokenType.tokLParen, "期望 '('");
        node.targetType = parseType();
        consume(TokenType.tokRParen, "期望 ')'");
        node.expression = parseUnary();
        return node;
    }

    AstNode parsePostfix()
    {
        AstNode expr = parsePrimary();

        while (true)
        {
            if (match_(TokenType.tokDot))
            {
                if (check(TokenType.tokIdentifier))
                {
                    auto node = new MemberAccessExprNode();
                    node.target = expr;
                    node.member = advance().lexeme;
                    expr = node;
                }
                else
                {
                    throw new ParseException("期望成员名称", peek().line, peek().column);
                }
            }
            else if (match_(TokenType.tokLBracket))
            {
                auto node = new IndexExprNode();
                node.target = expr;
                node.index = parseExpression();
                consume(TokenType.tokRBracket, "期望 ']'");
                expr = node;
            }
            else if (match_(TokenType.tokLParen))
            {
                auto node = new CallExprNode();
                node.callee = expr;
                node.line = peek().line;

                if (!check(TokenType.tokRParen))
                {
                    node.args ~= parseExpression();
                    while (match_(TokenType.tokComma))
                        node.args ~= parseExpression();
                }

                consume(TokenType.tokRParen, "期望 ')'");
                expr = node;
            }
            else if (match_(TokenType.tokPlusPlus) || match_(TokenType.tokMinusMinus))
            {
                auto node = new PostfixExprNode();
                node.target = expr;
                node.op = previous().lexeme;
                expr = node;
            }
            else
            {
                break;
            }
        }

        return expr;
    }

    AstNode parsePrimary()
    {
        Token tok = peek();

        if (match_(TokenType.tokInteger))
        {
            auto node = new LiteralExprNode();
            node.litType = LiteralExprNode.LiteralType.Integer;
            node.value = previous().lexeme;
            return node;
        }

        if (match_(TokenType.tokString_))
        {
            auto node = new LiteralExprNode();
            node.litType = LiteralExprNode.LiteralType.String_;
            node.value = previous().lexeme;
            return node;
        }

        if (match_(TokenType.tokChar_))
        {
            auto node = new LiteralExprNode();
            node.litType = LiteralExprNode.LiteralType.Char_;
            node.value = previous().lexeme;
            return node;
        }

        if (match_(TokenType.tokKwTrue))
        {
            auto node = new LiteralExprNode();
            node.litType = LiteralExprNode.LiteralType.Boolean;
            node.value = "true";
            return node;
        }

        if (match_(TokenType.tokKwFalse))
        {
            auto node = new LiteralExprNode();
            node.litType = LiteralExprNode.LiteralType.Boolean;
            node.value = "false";
            return node;
        }

        if (match_(TokenType.tokKwNull))
        {
            auto node = new LiteralExprNode();
            node.litType = LiteralExprNode.LiteralType.Null_;
            node.value = "null";
            return node;
        }

        if (check(TokenType.tokIdentifier))
        {
            auto node = new IdentifierExprNode();
            node.line = peek().line;
            node.column = peek().column;
            node.name = advance().lexeme;
            return node;
        }

        if (match_(TokenType.tokLParen))
        {
            AstNode expr = parseExpression();
            consume(TokenType.tokRParen, "期望 ')'");
            return expr;
        }

        if (match_(TokenType.tokLBracket))
        {
            auto node = new ArrayLiteralExprNode();
            if (!check(TokenType.tokRBracket))
            {
                node.elements ~= parseExpression();
                while (match_(TokenType.tokComma))
                    node.elements ~= parseExpression();
            }
            consume(TokenType.tokRBracket, "期望 ']'");
            return node;
        }

        throw new ParseException(text("意外的 Token: ", peek().lexeme), peek().line, peek().column);
    }

    TypeNode parseType()
    {
        string typeName;
        Token tok = peek();

        TypeNode node = new TypeNode("");

        if (check(TokenType.tokIdentifier))
        {
            typeName = advance().lexeme;
            node.typeName = typeName;
        }
        else if (isBaseTypeToken(tok.type))
        {
            typeName = typeKeywordToString(tok.type);
            advance();
            node.typeName = typeName;
        }
        else
        {
            typeName = typeKeywordToString(tok.type);
            advance();
            node.typeName = typeName;
        }

        if (match_(TokenType.tokLBracket))
        {
            consume(TokenType.tokRBracket, "期望 ']'");
            node.isSlice = true;
        }

        return node;
    }

    bool isTypeTokenInDeclContext()
    {
        TokenType t = peek().type;
        if (isBaseTypeToken(t) || t == TokenType.tokKwAuto || t == TokenType.tokKwScope)
            return true;
        if (t == TokenType.tokIdentifier)
            return peekNext().type == TokenType.tokIdentifier;
        return false;
    }

    bool isTypeToken(TokenType t)
    {
        return isBaseTypeToken(t) || t == TokenType.tokIdentifier
            || t == TokenType.tokKwAuto || t == TokenType.tokKwScope;
    }

    bool isBaseTypeToken(TokenType t)
    {
        switch (t)
        {
            case TokenType.tokKwVoid, TokenType.tokKwBool,
                 TokenType.tokKwByte, TokenType.tokKwUbyte,
                 TokenType.tokKwShort, TokenType.tokKwUshort,
                 TokenType.tokKwInt, TokenType.tokKwUint,
                 TokenType.tokKwLong, TokenType.tokKwUlong,
                 TokenType.tokKwChar, TokenType.tokKwWchar, TokenType.tokKwDchar,
                 TokenType.tokKwString, TokenType.tokKwWstring, TokenType.tokKwDstring:
                return true;
            default:
                return false;
        }
    }

    string typeKeywordToString(TokenType t)
    {
        switch (t)
        {
            case TokenType.tokKwVoid: return "void";
            case TokenType.tokKwBool: return "bool";
            case TokenType.tokKwByte: return "byte";
            case TokenType.tokKwUbyte: return "ubyte";
            case TokenType.tokKwShort: return "short";
            case TokenType.tokKwUshort: return "ushort";
            case TokenType.tokKwInt: return "int";
            case TokenType.tokKwUint: return "uint";
            case TokenType.tokKwLong: return "long";
            case TokenType.tokKwUlong: return "ulong";
            case TokenType.tokKwChar: return "char";
            case TokenType.tokKwWchar: return "wchar";
            case TokenType.tokKwDchar: return "dchar";
            case TokenType.tokKwString: return "string";
            case TokenType.tokKwWstring: return "wstring";
            case TokenType.tokKwDstring: return "dstring";
            case TokenType.tokKwAuto: return "auto";
            default: return "";
        }
    }

    void setRegisteredNames(string[] structs, string[] enums, string[string][string] enumMems, string[] funcs)
    {
        registeredStructNames = structs;
        registeredEnumNames = enums;
        enumMembers = enumMems;
        registeredFuncNames = funcs;
    }

public:
    this(Token[] toks)
    {
        tokens = toks;
        current = 0;
    }

    static ProgramNode parseSource(string source, string filePath = "<script>",
        string[] structNames = null, string[] enumNames = null,
        string[string][string] enumMems = null, string[] funcNames = null)
    {
        auto lexer = new Lexer(source);
        auto tokens = lexer.lex();
        return parseTokens(tokens, filePath, structNames, enumNames, enumMems, funcNames);
    }

    static ProgramNode parseTokens(Token[] tokens, string filePath = "<script>",
        string[] structNames = null, string[] enumNames = null,
        string[string][string] enumMems = null, string[] funcNames = null)
    {
        auto parser = new Parser(tokens);
        parser.setRegisteredNames(
            structNames ? structNames : [],
            enumNames ? enumNames : [],
            enumMems ? enumMems : (string[string][string]).init,
            funcNames ? funcNames : []
        );
        return cast(ProgramNode)parser.parseProgram();
    }
}

unittest
{
    auto program = Parser.parseSource("int add(int a, int b) { return a + b; }");
    assert(program !is null);
    assert(program.declarations.length >= 1);
    auto func = cast(FunctionDeclNode)program.declarations[0];
    assert(func !is null);
    assert(func.name == "add");
    assert(func.params.length == 2);
    assert(func.params[0].name == "a");
    assert(func.params[1].name == "b");
}

unittest
{
    auto program = Parser.parseSource("int x = 5 + 3 * 2;");
    assert(program.declarations.length >= 1);
    auto vd = cast(VarDeclNode)program.declarations[0];
    assert(vd !is null);
    assert(vd.name == "x");
}

unittest
{
    auto program = Parser.parseSource("auto main() { if (a < b) return a; else return b; }");
    assert(program.declarations.length >= 1);
}
