/**
 * PLVM 抽象语法树模块
 *
 * 本模块定义了 PLVM 的抽象语法树（AST）节点类型，包括：
 * - 程序节点
 * - 声明节点（变量、函数、结构体、枚举）
 * - 语句节点（if、while、for、switch 等）
 * - 表达式节点（字面量、二元、一元、调用等）
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.ast;

/**
 * AST 节点类型枚举
 *
 * 定义了所有可能的 AST 节点类型。
 */
enum AstNodeType : ubyte
{
    Program,        /// 程序

    VarDecl,        /// 变量声明
    AssignStmt,     /// 赋值语句
    ExprStmt,       /// 表达式语句
    ReturnStmt,     /// 返回语句
    IfStmt,         /// if 语句
    WhileStmt,      /// while 语句
    DoWhileStmt,    /// do-while 语句
    ForStmt,        /// for 语句
    ForeachStmt,    /// foreach 语句
    SwitchStmt,     /// switch 语句
    CaseStmt,       /// case 语句
    DefaultStmt,    /// default 语句
    BreakStmt,      /// break 语句
    ContinueStmt,   /// continue 语句
    BlockStmt,      /// 块语句
    FunctionDecl,   /// 函数声明

    LiteralExpr,    /// 字面量表达式
    IdentifierExpr, /// 标识符表达式
    BinaryExpr,     /// 二元表达式
    UnaryExpr,      /// 一元表达式
    CallExpr,       /// 调用表达式
    IndexExpr,      /// 索引表达式
    MemberAccessExpr, /// 成员访问表达式
    TernaryExpr,    /// 三元表达式
    PostfixExpr,    /// 后缀表达式
    CastExpr,       /// 类型转换表达式
    ArrayLiteralExpr, /// 数组字面量表达式
    ArrayInitExpr,  /// 数组初始化表达式
    LambdaExpr,     /// lambda 表达式
    FunctionType,   /// 函数类型
    DelegateType,   /// 委托类型

    StructDecl,     /// 结构体声明
    EnumDecl,       /// 枚举声明
    EnumMember,     /// 枚举成员
    ImportDecl      /// 导入声明
}

/**
 * 值类别枚举
 */
enum ValueCategory
{
    LValue,  /// 左值
    RValue   /// 右值
}

/**
 * AST 节点基类
 *
 * 所有 AST 节点的基类。
 */
class AstNode
{
    AstNodeType nodeType;  /// 节点类型
    size_t line;           /// 行号
    size_t column;         /// 列号
    string filePath;       /// 文件路径

    /**
     * 构造 AST 节点
     *
     * Params:
     *   t = 节点类型
     */
    this(AstNodeType t)
    {
        nodeType = t;
    }
}

/**
 * 程序节点
 *
 * 表示整个程序，包含一系列声明。
 */
class ProgramNode : AstNode
{
    AstNode[] declarations;  /// 声明列表

    this()
    {
        super(AstNodeType.Program);
    }
}

/**
 * 类型节点
 *
 * 表示类型信息。
 */
class TypeNode : AstNode
{
    string typeName;      /// 类型名
    bool isSlice = false; /// 是否为切片
    TypeNode elementType; /// 元素类型

    this(string name)
    {
        super(AstNodeType.LiteralExpr);
        typeName = name;
    }
}

/**
 * 变量声明节点
 */
class VarDeclNode : AstNode
{
    string name;          /// 变量名
    TypeNode typeNode;    /// 类型节点
    AstNode initializer;  /// 初始化表达式

    this()
    {
        super(AstNodeType.VarDecl);
    }
}

/**
 * 表达式语句节点
 */
class ExprStmtNode : AstNode
{
    AstNode expression;

    this()
    {
        super(AstNodeType.ExprStmt);
    }
}

class AssignStmtNode : AstNode
{
    AstNode target;
    AstNode value;
    string op; // "=", "+=", "-=", "*=", etc.

    this()
    {
        super(AstNodeType.AssignStmt);
    }
}

class ReturnStmtNode : AstNode
{
    AstNode value;

    this()
    {
        super(AstNodeType.ReturnStmt);
    }
}

class IfStmtNode : AstNode
{
    AstNode condition;
    AstNode thenBranch;
    AstNode elseBranch;

    this()
    {
        super(AstNodeType.IfStmt);
    }
}

class WhileStmtNode : AstNode
{
    AstNode condition;
    AstNode body;

    this()
    {
        super(AstNodeType.WhileStmt);
    }
}

class DoWhileStmtNode : AstNode
{
    AstNode body;
    AstNode condition;

    this()
    {
        super(AstNodeType.DoWhileStmt);
    }
}

class ForStmtNode : AstNode
{
    AstNode init;
    AstNode condition;
    AstNode increment;
    AstNode body;

    this()
    {
        super(AstNodeType.ForStmt);
    }
}

class ForeachStmtNode : AstNode
{
    string loopVarName;
    TypeNode loopVarType;
    bool hasIndexVar;
    string indexVarName;
    AstNode iterable;
    AstNode body;

    this()
    {
        super(AstNodeType.ForeachStmt);
    }
}

class SwitchStmtNode : AstNode
{
    AstNode expression;
    AstNode[] cases;

    this()
    {
        super(AstNodeType.SwitchStmt);
    }
}

class CaseStmtNode : AstNode
{
    AstNode value;
    AstNode[] body;

    this()
    {
        super(AstNodeType.CaseStmt);
    }
}

class DefaultStmtNode : AstNode
{
    AstNode[] body;

    this()
    {
        super(AstNodeType.DefaultStmt);
    }
}

class BreakStmtNode : AstNode
{
    this()
    {
        super(AstNodeType.BreakStmt);
    }
}

class ContinueStmtNode : AstNode
{
    this()
    {
        super(AstNodeType.ContinueStmt);
    }
}

class BlockStmtNode : AstNode
{
    AstNode[] statements;

    this()
    {
        super(AstNodeType.BlockStmt);
    }
}

class FunctionDeclNode : AstNode
{
    string name;
    TypeNode returnType;
    string returnTypeName;
    struct Param
    {
        string name;
        TypeNode typeNode;
        string typeName;
    }
    Param[] params;
    BlockStmtNode body;
    bool isNested;

    this()
    {
        super(AstNodeType.FunctionDecl);
    }
}

class LiteralExprNode : AstNode
{
    enum LiteralType { Integer, String_, Char_, Boolean, Null_ }
    LiteralType litType;
    string value;

    this()
    {
        super(AstNodeType.LiteralExpr);
    }

    long integerValue() const
    {
        import std.conv : to;
        return to!long(value);
    }
}

class IdentifierExprNode : AstNode
{
    string name;

    this()
    {
        super(AstNodeType.IdentifierExpr);
    }
}

class BinaryExprNode : AstNode
{
    AstNode left;
    AstNode right;
    string op;

    this()
    {
        super(AstNodeType.BinaryExpr);
    }
}

class UnaryExprNode : AstNode
{
    AstNode operand;
    string op;
    bool isPrefix = true;

    this()
    {
        super(AstNodeType.UnaryExpr);
    }
}

class CallExprNode : AstNode
{
    AstNode callee;
    AstNode[] args;
    bool isHostCall;
    string hostFuncName;

    this()
    {
        super(AstNodeType.CallExpr);
    }
}

class IndexExprNode : AstNode
{
    AstNode target;
    AstNode index;

    this()
    {
        super(AstNodeType.IndexExpr);
    }
}

class MemberAccessExprNode : AstNode
{
    AstNode target;
    string member;

    this()
    {
        super(AstNodeType.MemberAccessExpr);
    }
}

class TernaryExprNode : AstNode
{
    AstNode condition;
    AstNode thenExpr;
    AstNode elseExpr;

    this()
    {
        super(AstNodeType.TernaryExpr);
    }
}

class PostfixExprNode : AstNode
{
    AstNode target;
    string op;

    this()
    {
        super(AstNodeType.PostfixExpr);
    }
}

class CastExprNode : AstNode
{
    TypeNode targetType;
    AstNode expression;

    this()
    {
        super(AstNodeType.CastExpr);
    }
}

class ArrayLiteralExprNode : AstNode
{
    AstNode[] elements;

    this()
    {
        super(AstNodeType.ArrayLiteralExpr);
    }
}

class LambdaExprNode : AstNode
{
    FunctionDeclNode func;

    this()
    {
        super(AstNodeType.LambdaExpr);
    }
}

class StructDeclNode : AstNode
{
    string name;
    struct Field
    {
        string name;
        TypeNode typeNode;
        string typeName;
    }
    Field[] fields;

    this()
    {
        super(AstNodeType.StructDecl);
    }
}

class EnumDeclNode : AstNode
{
    string name;
    struct Member
    {
        string name;
        string valueExpr;
    }
    Member[] members;
    string baseTypeName;

    this()
    {
        super(AstNodeType.EnumDecl);
    }
}
