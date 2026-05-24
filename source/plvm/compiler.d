/**
 * PLVM 编译器模块
 *
 * 本模块实现从 AST 到字节码的编译过程，包括：
 * - 函数编译
 * - 表达式编译
 * - 语句编译
 * - 控制流处理
 * - 类型转换
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.compiler;

import plvm.token;
import plvm.ast;
import plvm.bytecode;
import plvm.parser;
import plvm.host_api : EnumValue;
import std.exception : enforce;
import std.conv : text, to;

/**
 * 编译异常类
 *
 * 表示编译过程中的错误。
 */
class CompileException : Exception
{
    size_t line;    /// 错误行号
    size_t column;  /// 错误列号

    /**
     * 构造编译异常
     *
     * Params:
     *   msg = 错误消息
     *   l = 行号
     *   c = 列号
     */
    this(string msg, size_t l, size_t c)
    {
        super(text("编译错误 (", l, ":", c, "): ", msg));
        line = l;
        column = c;
    }
}

/**
 * 可中断上下文结构
 *
 * 用于跟踪 break/continue 语句的跳转目标。
 */
struct BreakableContext
{
    size_t breakLabel;         /// break 跳转标签
    size_t continueLabel;      /// continue 跳转标签
    size_t[] breakJumps;       /// break 跳转指令位置列表
    size_t[] continueJumps;    /// continue 跳转指令位置列表
    bool isSwitch;             /// 是否为 switch 语句
}

/**
 * 编译器类
 *
 * 将 AST 编译为字节码程序。
 */
class Compiler
{
private:
    BytecodeProgram program;              /// 字节码程序
    BreakableContext[] breakStack;        /// 可中断上下文栈
    string currentFuncName;               /// 当前函数名
    FunctionInfo[] pendingFunctions;      /// 待处理函数列表
    FunctionDeclNode[] pendingFuncNodes;  /// 待处理函数节点列表
    bool isPassTwo;                       /// 是否为第二遍扫描
    size_t mainFuncEntry;                 /// main 函数入口点

    size_t[string] localVarSlots;         /// 局部变量槽位映射
    size_t localVarCount;                 /// 局部变量计数

    string[] registeredStructNames;       /// 已注册结构体名称
    string[string][string] enumMembers;   /// 枚举成员映射
    string[] registeredFuncNames;         /// 已注册函数名称
    string[long] registeredFuncIndices;   /// 函数索引映射
    string[] registeredHostNames;         /// 已注册宿主函数名称
    string[long] registeredHostIndices;   /// 宿主函数索引映射
    string[string] structFieldTypeMap;    /// 结构体字段类型映射

    string[string] localVarTypes;         /// 局部变量类型映射
    string[string][string] structTypeFields; /// 结构体类型字段映射

    EnumValue[] enumValues;               /// 枚举值列表

    /// 类型 ID 枚举
    enum TypeId : long
    {
        TYPE_VOID = 0,      /// void 类型
        TYPE_BOOL = 1,      /// bool 类型
        TYPE_BYTE = 2,      /// byte 类型
        TYPE_UBYTE = 3,     /// ubyte 类型
        TYPE_SHORT = 4,     /// short 类型
        TYPE_USHORT = 5,    /// ushort 类型
        TYPE_INT = 6,       /// int 类型
        TYPE_UINT = 7,      /// uint 类型
        TYPE_LONG = 8,      /// long 类型
        TYPE_ULONG = 9,     /// ulong 类型
        TYPE_CHAR = 10,     /// char 类型
        TYPE_WCHAR = 11,    /// wchar 类型
        TYPE_DCHAR = 12,    /// dchar 类型
        TYPE_STRING = 13,   /// string 类型
        TYPE_WSTRING = 14,  /// wstring 类型
        TYPE_DSTRING = 15   /// dstring 类型
    }

    /**
     * 将类型名转换为类型 ID
     *
     * Params:
     *   t = 类型名
     *
     * Returns: 类型 ID，未知类型返回 -1
     */
    long typeToTypeId(string t)
    {
        switch (t)
        {
            case "void": return TypeId.TYPE_VOID;
            case "bool": return TypeId.TYPE_BOOL;
            case "byte": return TypeId.TYPE_BYTE;
            case "ubyte": return TypeId.TYPE_UBYTE;
            case "short": return TypeId.TYPE_SHORT;
            case "ushort": return TypeId.TYPE_USHORT;
            case "int": return TypeId.TYPE_INT;
            case "uint": return TypeId.TYPE_UINT;
            case "long": return TypeId.TYPE_LONG;
            case "ulong": return TypeId.TYPE_ULONG;
            case "char": return TypeId.TYPE_CHAR;
            case "wchar": return TypeId.TYPE_WCHAR;
            case "dchar": return TypeId.TYPE_DCHAR;
            case "string": return TypeId.TYPE_STRING;
            case "wstring": return TypeId.TYPE_WSTRING;
            case "dstring": return TypeId.TYPE_DSTRING;
            default: return -1;
        }
    }

    void emitCast(TypeNode targetType, size_t line)
    {
        string t = targetType.typeName;
        long typeId = typeToTypeId(t);
        if (typeId >= 0)
        {
            program.emit(Instruction.castGeneric(typeId, line));
            return;
        }
    }

    void compileExpr(AstNode node)
    {
        if (node is null) return;

        final switch (node.nodeType)
        {
            case AstNodeType.LiteralExpr:
                compileLiteral(cast(LiteralExprNode)node);
                break;
            case AstNodeType.IdentifierExpr:
                compileIdentifier(cast(IdentifierExprNode)node);
                break;
            case AstNodeType.BinaryExpr:
                compileBinary(cast(BinaryExprNode)node);
                break;
            case AstNodeType.UnaryExpr:
                compileUnary(cast(UnaryExprNode)node);
                break;
            case AstNodeType.CallExpr:
                compileCall(cast(CallExprNode)node);
                break;
            case AstNodeType.IndexExpr:
                compileIndex(cast(IndexExprNode)node);
                break;
            case AstNodeType.MemberAccessExpr:
                compileMemberAccess(cast(MemberAccessExprNode)node);
                break;
            case AstNodeType.TernaryExpr:
                compileTernary(cast(TernaryExprNode)node);
                break;
            case AstNodeType.PostfixExpr:
                compilePostfix(cast(PostfixExprNode)node);
                break;
            case AstNodeType.CastExpr:
                compileCastExpr(cast(CastExprNode)node);
                break;
            case AstNodeType.AssignStmt:
                compileAssignStmt(cast(AssignStmtNode)node);
                break;
            case AstNodeType.ArrayLiteralExpr:
                compileArrayLiteral(cast(ArrayLiteralExprNode)node);
                break;
            case AstNodeType.ArrayInitExpr:
                throw new CompileException("不支持数组初始化作为表达式", node.line, node.column);
            case AstNodeType.LambdaExpr:
                throw new CompileException("不支持 lambda 表达式作为值", node.line, node.column);
            case AstNodeType.FunctionType:
                throw new CompileException("不支持函数类型作为表达式", node.line, node.column);
            case AstNodeType.DelegateType:
                throw new CompileException("不支持委托类型作为表达式", node.line, node.column);
            case AstNodeType.VarDecl:
            case AstNodeType.ExprStmt:
            case AstNodeType.ReturnStmt:
            case AstNodeType.IfStmt:
            case AstNodeType.WhileStmt:
            case AstNodeType.DoWhileStmt:
            case AstNodeType.ForStmt:
            case AstNodeType.ForeachStmt:
            case AstNodeType.SwitchStmt:
            case AstNodeType.CaseStmt:
            case AstNodeType.DefaultStmt:
            case AstNodeType.BreakStmt:
            case AstNodeType.ContinueStmt:
            case AstNodeType.BlockStmt:
            case AstNodeType.FunctionDecl:
            case AstNodeType.StructDecl:
            case AstNodeType.EnumDecl:
            case AstNodeType.EnumMember:
            case AstNodeType.ImportDecl:
            case AstNodeType.Program:
                throw new CompileException(text("不支持编译表达式类型: ", cast(int)node.nodeType), node.line, node.column);
        }
    }

    void compileLiteral(LiteralExprNode node)
    {
        size_t idx;
        final switch (node.litType)
        {
            case LiteralExprNode.LiteralType.Integer:
                idx = program.addInteger(node.integerValue());
                break;
            case LiteralExprNode.LiteralType.String_:
            {
                string raw = node.value;
                if (raw.length >= 2 && raw[0] == '"' && raw[$ - 1] == '"')
                {
                    raw = raw[1 .. $ - 1];
                }
                idx = program.addString(raw);
                break;
            }
            case LiteralExprNode.LiteralType.Char_:
            {
                string raw = node.value;
                if (raw.length >= 2 && raw[0] == '\'' && raw[$ - 1] == '\'')
                    raw = raw[1 .. $ - 1];
                long charVal = 0;
                if (raw.length >= 2 && raw[0] == '\\')
                {
                    switch (raw[1])
                    {
                        case 'n': charVal = 10; break;
                        case 'r': charVal = 13; break;
                        case 't': charVal = 9; break;
                        case '\\': charVal = '\\'; break;
                        case '\'': charVal = '\''; break;
                        case '"': charVal = '"'; break;
                        case '0': charVal = 0; break;
                        default: charVal = raw[1]; break;
                    }
                }
                else if (raw.length > 0)
                {
                    charVal = raw[0];
                }
                idx = program.addInteger(charVal);
                break;
            }
            case LiteralExprNode.LiteralType.Boolean:
                idx = program.addInteger(node.value == "true" ? 1 : 0);
                break;
            case LiteralExprNode.LiteralType.Null_:
                idx = program.addInteger(0);
                break;
        }
        program.emit(Instruction.push(cast(long)idx, node.line));
    }

    void compileIdentifier(IdentifierExprNode node)
    {
        if (auto slot = node.name in localVarSlots)
        {
            program.emit(Instruction.loadLocal(cast(long)(*slot), node.line));
            return;
        }

        if (registeredFuncIndices.length > 0)
        {
            foreach (id, name; registeredFuncIndices)
            {
                if (name == node.name)
                {
                    program.emit(Instruction.push(program.addIdentifier(node.name), node.line));
                    return;
                }
            }
        }

        foreach (ev; enumValues)
        {
            if (ev.memberName == node.name || (ev.enumName ~ "." ~ ev.memberName) == node.name)
            {
                size_t idx = program.addInteger(ev.value);
                program.emit(Instruction.push(cast(long)idx, node.line));
                return;
            }
        }

        if (node.name in structTypeFields)
        {
            program.emit(Instruction.push(program.addIdentifier(node.name), node.line));
            return;
        }

        size_t nameIdx = program.addIdentifier(node.name);
        program.emit(Instruction.loadGlobal(cast(long)nameIdx, node.line));
    }

    void compileBinary(BinaryExprNode node)
    {
        string op = node.op;

        if (op == "&&")
        {
            compileExpr(node.left);
            size_t jzLeft = program.emit(Instruction.jz(0, node.line));
            compileExpr(node.right);
            size_t jzRight = program.emit(Instruction.jz(0, node.line));
            program.emit(Instruction.push(program.addInteger(1), node.line));
            size_t jmpEnd = program.emit(Instruction.jmp(0, node.line));
            program.patchJump(jzLeft, program.instructions.length);
            program.patchJump(jzRight, program.instructions.length);
            program.emit(Instruction.push(program.addInteger(0), node.line));
            program.patchJump(jmpEnd, program.instructions.length);
            return;
        }

        if (op == "||")
        {
            compileExpr(node.left);
            size_t jnzLeft = program.emit(Instruction.jnz(0, node.line));
            compileExpr(node.right);
            size_t jnzRight = program.emit(Instruction.jnz(0, node.line));
            program.emit(Instruction.push(program.addInteger(0), node.line));
            size_t jmpEnd = program.emit(Instruction.jmp(0, node.line));
            program.patchJump(jnzLeft, program.instructions.length);
            program.patchJump(jnzRight, program.instructions.length);
            program.emit(Instruction.push(program.addInteger(1), node.line));
            program.patchJump(jmpEnd, program.instructions.length);
            return;
        }

        compileExpr(node.left);
        compileExpr(node.right);

        OpCode oc;
        switch (op)
        {
            case "+": oc = OpCode.ADD; break;
            case "-": oc = OpCode.SUB; break;
            case "*": oc = OpCode.MUL; break;
            case "/": oc = OpCode.DIV; break;
            case "%": oc = OpCode.MOD; break;
            case "==": oc = OpCode.EQ; break;
            case "!=": oc = OpCode.NEQ; break;
            case "<": oc = OpCode.LT; break;
            case "<=": oc = OpCode.LTE; break;
            case ">": oc = OpCode.GT; break;
            case ">=": oc = OpCode.GTE; break;
            case "&": oc = OpCode.BIT_AND; break;
            case "|": oc = OpCode.BIT_OR; break;
            case "^": oc = OpCode.BIT_XOR; break;
            case "<<": oc = OpCode.SHL; break;
            case ">>": oc = OpCode.SHR; break;
            case "~": oc = OpCode.ADD; break;
            default:
                throw new CompileException(text("不支持的运算符: ", op), node.line, node.column);
        }

        Instruction i;
        i.opcode = oc;
        i.line = node.line;
        program.emit(i);
    }

    void compileUnary(UnaryExprNode node)
    {
        string op = node.op;

        if (op == "-")
        {
            compileExpr(node.operand);
            program.emit(Instruction.neg_(node.line));
        }
        else if (op == "!")
        {
            compileExpr(node.operand);
            program.emit(Instruction.not_(node.line));
        }
        else if (op == "~")
        {
            compileExpr(node.operand);
            program.emit(Instruction.bitNot(node.line));
        }
        else if (op == "++")
        {
            compileExpr(node.operand);
            program.emit(Instruction.push(program.addInteger(1), node.line));
            program.emit(Instruction.add_(node.line));
            storeTarget(node.operand, node.line);
        }
        else if (op == "--")
        {
            compileExpr(node.operand);
            program.emit(Instruction.push(program.addInteger(1), node.line));
            program.emit(Instruction.sub_(node.line));
            storeTarget(node.operand, node.line);
        }
        else if (op == "+")
        {
            compileExpr(node.operand);
        }
    }

    void compileCall(CallExprNode node)
    {
        string calleeName = null;

        if (auto idNode = cast(IdentifierExprNode)node.callee)
        {
            calleeName = idNode.name;
        }
        else if (auto maNode = cast(MemberAccessExprNode)node.callee)
        {
            calleeName = maNode.target ? null : maNode.member;
        }

        if (calleeName && (registeredFuncIndices.length > 0 || registeredHostIndices.length > 0))
        {
            foreach (id, name; registeredFuncIndices)
            {
                if (name == calleeName)
                {
                    compileHostCall(node, calleeName);
                    return;
                }
            }
            foreach (id, name; registeredHostIndices)
            {
                if (name == calleeName)
                {
                    compileHostCall(node, calleeName);
                    return;
                }
            }
        }

        foreach (i, arg; node.args)
            compileExpr(arg);

        if (calleeName)
        {
            size_t funcNameIdx = program.addIdentifier(calleeName);
            program.emit(Instruction.call_(cast(long)funcNameIdx, node.line));
        }
        else
        {
            compileExpr(node.callee);
            size_t funcNameIdx = program.addIdentifier("__anon_call__");
            program.emit(Instruction.call_(cast(long)funcNameIdx, node.line));
        }
    }

    void compileHostCall(CallExprNode node, string funcName)
    {
        foreach (i, arg; node.args)
            compileExpr(arg);

        long hostIdx = -1;
        foreach (id, name; registeredHostIndices)
        {
            if (name == funcName)
            {
                hostIdx = id;
                break;
            }
        }

        auto instr = Instruction.callHost(hostIdx, node.line);
        instr.arg2 = node.args.length;
        program.emit(instr);
    }

    void compileIndex(IndexExprNode node)
    {
        compileExpr(node.target);
        compileExpr(node.index);
        program.emit(Instruction.arrayGet(node.line));
    }

    void compileMemberAccess(MemberAccessExprNode node)
    {
        if (node.member == "length")
        {
            compileExpr(node.target);
            program.emit(Instruction.arrayLen(node.line));
            return;
        }

        if (auto idNode = cast(IdentifierExprNode)node.target)
        {
            string combined = idNode.name ~ "." ~ node.member;

            foreach (ev; enumValues)
            {
                string fullName = ev.enumName ~ "." ~ ev.memberName;
                if (fullName == combined)
                {
                    size_t idx = program.addInteger(ev.value);
                    program.emit(Instruction.push(cast(long)idx, node.line));
                    return;
                }
            }

            compileExpr(node.target);
            size_t fieldIdx = program.addStructFieldName(node.member);
            program.emit(Instruction.structGet(cast(long)fieldIdx, node.line));
        }
        else
        {
            compileExpr(node.target);
            size_t fieldIdx = program.addStructFieldName(node.member);
            program.emit(Instruction.structGet(cast(long)fieldIdx, node.line));
        }
    }

    void compileTernary(TernaryExprNode node)
    {
        compileExpr(node.condition);
        size_t jzPos = program.emit(Instruction.jz(0, node.line));
        compileExpr(node.thenExpr);
        size_t jmpPos = program.emit(Instruction.jmp(0, node.line));
        program.patchJump(jzPos, program.instructions.length);
        compileExpr(node.elseExpr);
        program.patchJump(jmpPos, program.instructions.length);
    }

    void compilePostfix(PostfixExprNode node)
    {
        string op = node.op;
        if (op == "++")
        {
            compileIdentifier(cast(IdentifierExprNode)node.target);
            program.emit(Instruction.dup_(node.line));
            program.emit(Instruction.push(program.addInteger(1), node.line));
            program.emit(Instruction.add_(node.line));
            storeTarget(node.target, node.line);
        }
        else if (op == "--")
        {
            compileIdentifier(cast(IdentifierExprNode)node.target);
            program.emit(Instruction.dup_(node.line));
            program.emit(Instruction.push(program.addInteger(1), node.line));
            program.emit(Instruction.sub_(node.line));
            storeTarget(node.target, node.line);
        }
    }

    void compileCastExpr(CastExprNode node)
    {
        compileExpr(node.expression);
        emitCast(node.targetType, node.line);
    }

    void compileAssignStmt(AssignStmtNode node)
    {
        string op = node.op;

        if (auto maNode = cast(MemberAccessExprNode)node.target)
        {
            compileExpr(maNode.target);
            if (op == "=")
            {
                compileExpr(node.value);
                size_t fieldIdx = program.addStructFieldName(maNode.member);
                program.emit(Instruction.structSet(cast(long)fieldIdx, node.line));
            }
            else
            {
                size_t fieldIdx = program.addStructFieldName(maNode.member);
                program.emit(Instruction.propGet(cast(long)fieldIdx, node.line));
                compileExpr(node.value);
                emitCompoundAssignOp(op, node.line);
                program.emit(Instruction.structSet(cast(long)fieldIdx, node.line));
            }
            return;
        }

        if (auto ixNode = cast(IndexExprNode)node.target)
        {
            if (op == "=")
            {
                compileExpr(ixNode.target);
                compileExpr(ixNode.index);
                compileExpr(node.value);
                program.emit(Instruction.arraySet(node.line));
            }
            else
            {
                compileExpr(ixNode.target);
                compileExpr(ixNode.index);
                program.emit(Instruction.dup_(node.line));
                program.emit(Instruction.arrayGet(node.line));
                compileExpr(node.value);
                emitCompoundAssignOp(op, node.line);
                program.emit(Instruction.arraySet(node.line));
            }
            return;
        }

        if (op == "=")
        {
            compileExpr(node.value);
            storeTarget(node.target, node.line);
        }
        else
        {
            compileExpr(node.target);
            compileExpr(node.value);
            emitCompoundAssignOp(op, node.line);
            storeTarget(node.target, node.line);
        }
    }

    void emitCompoundAssignOp(string op, size_t line)
    {
        string opChar = op[0 .. $ - 1];
        if (opChar == "+") program.emit(Instruction.add_(line));
        else if (opChar == "-") program.emit(Instruction.sub_(line));
        else if (opChar == "*") program.emit(Instruction.mul_(line));
        else if (opChar == "/") program.emit(Instruction.div_(line));
        else if (opChar == "%") program.emit(Instruction.mod_(line));
        else if (opChar == "~") program.emit(Instruction.add_(line));
        else if (opChar == "&") program.emit(Instruction.bitAnd(line));
        else if (opChar == "|") program.emit(Instruction.bitOr(line));
        else if (opChar == "^") program.emit(Instruction.bitXor(line));
        else if (opChar == "<<") program.emit(Instruction.shl_(line));
        else if (opChar == ">>") program.emit(Instruction.shr_(line));
    }

    void compileArrayLiteral(ArrayLiteralExprNode node)
    {
        program.emit(Instruction.arrayNew(node.elements.length, node.line));
        foreach (elem; node.elements)
        {
            compileExpr(elem);
            program.emit(Instruction.arrayAppend(node.line));
        }
    }

    void storeTarget(AstNode target, size_t line)
    {
        if (auto idNode = cast(IdentifierExprNode)target)
        {
            if (auto slot = idNode.name in localVarSlots)
            {
                program.emit(Instruction.storeLocal(cast(long)(*slot), line));
            }
            else
            {
                size_t nameIdx = program.addIdentifier(idNode.name);
                program.emit(Instruction.storeGlobal(cast(long)nameIdx, line));
            }
        }
        else if (auto maNode = cast(MemberAccessExprNode)target)
        {
            compileExpr(maNode.target);
            size_t fieldIdx = program.addStructFieldName(maNode.member);
            program.emit(Instruction.structSet(cast(long)fieldIdx, line));
        }
        else if (auto ixNode = cast(IndexExprNode)target)
        {
            compileExpr(ixNode.target);
            compileExpr(ixNode.index);
            program.emit(Instruction.arraySet(line));
        }
    }

    void compileStmt(AstNode node)
    {
        if (node is null) return;

        final switch (node.nodeType)
        {
            case AstNodeType.VarDecl:
                compileVarDecl(cast(VarDeclNode)node);
                break;
            case AstNodeType.ExprStmt:
                compileExprStmt(cast(ExprStmtNode)node);
                break;
            case AstNodeType.AssignStmt:
                compileAssignStmt(cast(AssignStmtNode)node);
                break;
            case AstNodeType.ReturnStmt:
                compileReturn(cast(ReturnStmtNode)node);
                break;
            case AstNodeType.IfStmt:
                compileIf(cast(IfStmtNode)node);
                break;
            case AstNodeType.WhileStmt:
                compileWhile(cast(WhileStmtNode)node);
                break;
            case AstNodeType.DoWhileStmt:
                compileDoWhile(cast(DoWhileStmtNode)node);
                break;
            case AstNodeType.ForStmt:
                compileFor(cast(ForStmtNode)node);
                break;
            case AstNodeType.ForeachStmt:
                compileForeach(cast(ForeachStmtNode)node);
                break;
            case AstNodeType.SwitchStmt:
                compileSwitch(cast(SwitchStmtNode)node);
                break;
            case AstNodeType.BreakStmt:
                compileBreak(cast(BreakStmtNode)node);
                break;
            case AstNodeType.ContinueStmt:
                compileContinue(cast(ContinueStmtNode)node);
                break;
            case AstNodeType.BlockStmt:
                compileBlock(cast(BlockStmtNode)node);
                break;
            case AstNodeType.FunctionDecl:
                throw new CompileException("不支持函数嵌套声明", node.line, node.column);
            case AstNodeType.CaseStmt:
                throw new CompileException("case 语句不在 switch 中", node.line, node.column);
            case AstNodeType.DefaultStmt:
                throw new CompileException("default 语句不在 switch 中", node.line, node.column);
            case AstNodeType.StructDecl:
                throw new CompileException("不支持结构体声明作为语句", node.line, node.column);
            case AstNodeType.EnumDecl:
                throw new CompileException("不支持枚举声明作为语句", node.line, node.column);
            case AstNodeType.EnumMember:
                throw new CompileException("不支持枚举成员作为语句", node.line, node.column);
            case AstNodeType.ImportDecl:
                throw new CompileException("不支持导入声明作为语句", node.line, node.column);
            case AstNodeType.LiteralExpr:
            case AstNodeType.IdentifierExpr:
            case AstNodeType.BinaryExpr:
            case AstNodeType.UnaryExpr:
            case AstNodeType.CallExpr:
            case AstNodeType.IndexExpr:
            case AstNodeType.MemberAccessExpr:
            case AstNodeType.TernaryExpr:
            case AstNodeType.PostfixExpr:
            case AstNodeType.CastExpr:
            case AstNodeType.ArrayLiteralExpr:
            case AstNodeType.ArrayInitExpr:
            case AstNodeType.LambdaExpr:
            case AstNodeType.FunctionType:
            case AstNodeType.DelegateType:
            case AstNodeType.Program:
                throw new CompileException(text("不支持的语句类型: ", cast(int)node.nodeType), node.line, node.column);
        }
    }

    void compileVarDecl(VarDeclNode node)
    {
        localVarTypes[node.name] = node.typeNode ? node.typeNode.typeName : "auto";
        localVarCount++;
        localVarSlots[node.name] = localVarCount - 1;

        if (node.initializer)
        {
            compileExpr(node.initializer);
            program.emit(Instruction.storeLocal(cast(long)(localVarCount - 1), node.line));
        }
        else if (node.typeNode)
        {
            string typeName = node.typeNode.typeName;
            foreach (name; registeredStructNames)
            {
                if (name == typeName)
                {
                    program.emit(Instruction.structNew(node.line));
                    program.emit(Instruction.storeLocal(cast(long)(localVarCount - 1), node.line));
                    break;
                }
            }
        }
    }

    void compileExprStmt(ExprStmtNode node)
    {
        compileExpr(node.expression);
        program.emit(Instruction.pop(node.line));
    }

    void compileReturn(ReturnStmtNode node)
    {
        if (node.value)
        {
            compileExpr(node.value);
            program.emit(Instruction.ret_(node.line));
        }
        else
        {
            program.emit(Instruction.push(program.addInteger(0), node.line));
            program.emit(Instruction.ret_(node.line));
        }
    }

    void compileIf(IfStmtNode node)
    {
        compileExpr(node.condition);
        size_t jzPos = program.emit(Instruction.jz(0, node.line));
        compileStmt(node.thenBranch);

        if (node.elseBranch)
        {
            size_t jmpPos = program.emit(Instruction.jmp(0, node.line));
            program.patchJump(jzPos, program.instructions.length);
            compileStmt(node.elseBranch);
            program.patchJump(jmpPos, program.instructions.length);
        }
        else
        {
            program.patchJump(jzPos, program.instructions.length);
        }
    }

    void compileWhile(WhileStmtNode node)
    {
        size_t loopStart = program.instructions.length;
        compileExpr(node.condition);
        size_t jzPos = program.emit(Instruction.jz(0, node.line));

        BreakableContext ctx;
        ctx.breakLabel = 0;
        ctx.continueLabel = loopStart;
        ctx.isSwitch = false;
        breakStack ~= ctx;

        compileStmt(node.body);
        program.emit(Instruction.jmp(cast(long)loopStart, node.line));

        auto breakJumpsCopy = breakStack[$ - 1].breakJumps;
        auto continueJumpsCopy = breakStack[$ - 1].continueJumps;
        breakStack = breakStack[0 .. $ - 1];
        program.patchJump(jzPos, program.instructions.length);

        foreach (ref jumpPos; breakJumpsCopy)
            program.patchJump(jumpPos, program.instructions.length);
        foreach (ref jumpPos; continueJumpsCopy)
            program.patchJump(jumpPos, loopStart);
    }

    void compileDoWhile(DoWhileStmtNode node)
    {
        size_t bodyStart = program.instructions.length;

        BreakableContext ctx;
        ctx.breakLabel = 0;
        ctx.continueLabel = 0;
        ctx.isSwitch = false;
        breakStack ~= ctx;

        compileStmt(node.body);
        size_t condStart = program.instructions.length;
        compileExpr(node.condition);
        program.emit(Instruction.jnz(cast(long)bodyStart, node.line));

        auto breakJumpsCopy = breakStack[$ - 1].breakJumps;
        auto continueJumpsCopy = breakStack[$ - 1].continueJumps;
        breakStack = breakStack[0 .. $ - 1];
        ctx.continueLabel = condStart;

        foreach (ref jumpPos; breakJumpsCopy)
            program.patchJump(jumpPos, program.instructions.length);
        foreach (ref jumpPos; continueJumpsCopy)
            program.patchJump(jumpPos, condStart);
    }

    void compileFor(ForStmtNode node)
    {
        if (node.init)
            compileStmt(node.init);

        size_t condStart = program.instructions.length;
        size_t jzPos = 0;

        if (node.condition)
        {
            compileExpr(node.condition);
            jzPos = program.emit(Instruction.jz(0, node.line));
        }

        size_t bodyStart = program.instructions.length;

        BreakableContext ctx;
        ctx.breakLabel = 0;
        ctx.continueLabel = 0;
        ctx.isSwitch = false;
        breakStack ~= ctx;

        compileStmt(node.body);

        size_t incStart = program.instructions.length;
        if (node.increment)
        {
            compileExpr(node.increment);
            program.emit(Instruction.pop(node.line));
        }

        program.emit(Instruction.jmp(cast(long)condStart, node.line));

        auto breakJumpsCopy = breakStack[$ - 1].breakJumps;
        auto continueJumpsCopy = breakStack[$ - 1].continueJumps;
        breakStack = breakStack[0 .. $ - 1];

        if (node.condition)
            program.patchJump(jzPos, program.instructions.length);

        ctx.continueLabel = incStart;

        foreach (ref jumpPos; breakJumpsCopy)
            program.patchJump(jumpPos, program.instructions.length);
        foreach (ref jumpPos; continueJumpsCopy)
            program.patchJump(jumpPos, incStart);
    }

    void compileForeach(ForeachStmtNode node)
    {
        compileExpr(node.iterable);

        long varSlot = cast(long)localVarCount;
        if (node.loopVarName.length > 0)
        {
            localVarSlots[node.loopVarName] = varSlot;
            localVarCount++;
        }

        program.emit(Instruction.foreachBegin(varSlot, node.line));

        size_t bodyStart = program.instructions.length;

        BreakableContext ctx;
        ctx.breakLabel = 0;
        ctx.continueLabel = 0;
        ctx.isSwitch = false;
        breakStack ~= ctx;

        compileStmt(node.body);

        program.emit(Instruction.foreachNext(cast(long)bodyStart, node.line));

        auto breakJumpsCopy = breakStack[$ - 1].breakJumps;
        breakStack = breakStack[0 .. $ - 1];

        program.emit(Instruction.foreachEnd(node.line));

        foreach (ref jumpPos; breakJumpsCopy)
            program.patchJump(jumpPos, program.instructions.length);
    }

    void compileSwitch(SwitchStmtNode node)
    {
        compileExpr(node.expression);

        BreakableContext ctx;
        ctx.breakLabel = 0;
        ctx.continueLabel = 0;
        ctx.isSwitch = true;
        breakStack ~= ctx;

        foreach (c; node.cases)
        {
            if (auto caseNode = cast(CaseStmtNode)c)
            {
                program.emit(Instruction.dup_(caseNode.line));
                compileExpr(caseNode.value);
                program.emit(Instruction.eq_(caseNode.line));
                size_t jzPos = program.emit(Instruction.jz(0, caseNode.line));
                program.emit(Instruction.pop(caseNode.line));

                foreach (stmt; caseNode.body)
                    compileStmt(stmt);

                program.patchJump(jzPos, program.instructions.length);
            }
            else if (auto defaultNode = cast(DefaultStmtNode)c)
            {
                program.emit(Instruction.pop(defaultNode.line));
                foreach (stmt; defaultNode.body)
                    compileStmt(stmt);
            }
        }

        program.emit(Instruction.pop(node.line));
        auto breakJumpsCopy = breakStack[$ - 1].breakJumps;
        breakStack = breakStack[0 .. $ - 1];

        foreach (ref jumpPos; breakJumpsCopy)
            program.patchJump(jumpPos, program.instructions.length);
    }

    void compileBreak(BreakStmtNode)
    {
        if (breakStack.length == 0)
            throw new CompileException("break 不在循环或 switch 中", 0, 0);

        auto ctx = &breakStack[$ - 1];
        size_t jmpPos = program.emit(Instruction.jmp(0, 0));
        ctx.breakJumps ~= jmpPos;
    }

    void compileContinue(ContinueStmtNode)
    {
        if (breakStack.length == 0 || breakStack[$ - 1].isSwitch)
            throw new CompileException("continue 不在循环中", 0, 0);

        auto ctx = &breakStack[$ - 1];
        size_t jmpPos = program.emit(Instruction.jmp(0, 0));
        ctx.continueJumps ~= jmpPos;
    }

    void compileBlock(BlockStmtNode node)
    {
        foreach (stmt; node.statements)
            compileStmt(stmt);
    }

    void compileFunction(FunctionDeclNode node)
    {
        if (!isPassTwo)
        {
            FunctionInfo info;
            info.name = node.name;
            info.numParams = node.params.length;
            info.numLocals = 0;

            foreach (ref p; node.params)
                info.paramNames ~= p.name;

            pendingFunctions ~= info;
            pendingFuncNodes ~= node;
            return;
        }

        FunctionInfo* info = null;
        foreach (ref f; pendingFunctions)
        {
            if (f.name == node.name)
            {
                info = &f;
                break;
            }
        }

        if (info is null)
            return;

        localVarSlots = null;
        localVarCount = 0;
        currentFuncName = node.name;

        size_t entry = program.instructions.length;
        info.entryPoint = entry;
        info.numLocals = node.params.length;

        foreach (i, ref p; node.params)
        {
            localVarSlots[p.name] = i;
            localVarCount++;
        }

        compileBlock(node.body);

        info.numLocals = localVarCount;

        if (program.instructions.length == entry || (program.instructions[$ - 1].opcode != OpCode.HALT && program.instructions[$ - 1].opcode != OpCode.RET))
        {
            program.emit(Instruction.push(program.addInteger(0), node.line));
            program.emit(Instruction.halt_(node.line));
        }
    }

public:
    this(string[] structNames = null, string[string][string] enumMems = null,
         string[] funcNames = null, string[] hostNames = null)
    {
        registeredStructNames = structNames ? structNames : [];
        enumMembers = enumMems ? enumMems : (string[string][string]).init;
        registeredFuncNames = funcNames ? funcNames : [];
        registeredHostNames = hostNames ? hostNames : [];
    }

    void setEnumValues(EnumValue[] values)
    {
        enumValues = values;
    }

    void setRegisteredFuncIndices(string[long] indices)
    {
        registeredFuncIndices = indices;
    }

    void setRegisteredHostIndices(string[long] indices)
    {
        registeredHostIndices = indices;
    }

    BytecodeProgram compile(AstNode root)
    {
        auto progNode = cast(ProgramNode)root;
        if (progNode is null)
            throw new CompileException("根节点不是 ProgramNode", 0, 0);

        isPassTwo = false;
        pendingFunctions = [];
        pendingFuncNodes = [];

        foreach (decl; progNode.declarations)
        {
            if (auto funcDecl = cast(FunctionDeclNode)decl)
            {
                if (funcDecl.body !is null)
                    compileFunction(funcDecl);
                else
                {
                    FunctionInfo info;
                    info.name = funcDecl.name;
                    info.numParams = funcDecl.params.length;
                    info.numLocals = 0;
                    pendingFunctions ~= info;
                    pendingFuncNodes ~= funcDecl;
                }
            }
        }

        isPassTwo = true;
        foreach (i, decl; progNode.declarations)
        {
            if (auto funcDecl = cast(FunctionDeclNode)decl)
            {
                if (funcDecl.body !is null)
                    compileFunction(funcDecl);
            }
        }

        program.functions = pendingFunctions;

        bool hasMain = false;
        foreach (ref fn; program.functions)
        {
            if (fn.name == "main")
            {
                hasMain = true;
                mainFuncEntry = fn.entryPoint;
                break;
            }
        }

        if (!hasMain)
        {
            FunctionInfo anonInfo;
            anonInfo.name = "__anon_main__";
            anonInfo.entryPoint = program.instructions.length;
            anonInfo.numLocals = 0;

            localVarSlots = null;
            localVarCount = 0;
            currentFuncName = "__anon_main__";

            foreach (decl; progNode.declarations)
            {
                if (auto vd = cast(VarDeclNode)decl)
                {
                    compileVarDecl(vd);
                }
                else if (auto es = cast(ExprStmtNode)decl)
                {
                    compileStmt(es);
                }
                else if (auto assign = cast(AssignStmtNode)decl)
                {
                    compileAssignStmt(assign);
                }
            }

            anonInfo.numLocals = localVarCount;
            if (program.instructions.length == anonInfo.entryPoint ||
                program.instructions[$ - 1].opcode != OpCode.HALT)
            {
                program.emit(Instruction.push(program.addInteger(0), 0));
                program.emit(Instruction.halt_(0));
            }
            program.functions ~= anonInfo;
            mainFuncEntry = anonInfo.entryPoint;
        }

        return program;
    }

    static BytecodeProgram compileSource(string source,
        string[] structNames = null, string[string][string] enumMems = null,
        string[] funcNames = null, string[] hostNames = null,
        EnumValue[] evs = null,
        string[long] funcIndices = null, string[long] hostIndices = null)
    {
        auto root = Parser.parseSource(source, "<script>", structNames,
            enumMems ? enumMems.keys : null,
            enumMems, funcNames);

        auto compiler = new Compiler(structNames, enumMems, funcNames, hostNames);
        if (evs) compiler.setEnumValues(evs);
        if (funcIndices) compiler.setRegisteredFuncIndices(funcIndices);
        if (hostIndices) compiler.setRegisteredHostIndices(hostIndices);
        return compiler.compile(root);
    }

    size_t mainEntry() const
    {
        return mainFuncEntry;
    }
}

unittest
{
    auto program = Compiler.compileSource("int main() { return 42; }");
    assert(program.instructions.length > 0);
    assert(program.functions.length > 0);
}

unittest
{
    auto program = Compiler.compileSource("int add(int a, int b) { return a + b; }");
    assert(program.instructions.length > 0);
}

unittest
{
    auto program = Compiler.compileSource("int main() { int x = 10; return x; }");
    assert(program.instructions.length > 0);
}
