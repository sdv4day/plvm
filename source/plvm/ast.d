module plvm.ast;

enum AstNodeType : ubyte
{
    Program,

    VarDecl, AssignStmt, ExprStmt,
    ReturnStmt, IfStmt, WhileStmt, DoWhileStmt,
    ForStmt, ForeachStmt, SwitchStmt, CaseStmt, DefaultStmt,
    BreakStmt, ContinueStmt,
    BlockStmt,
    FunctionDecl,

    LiteralExpr, IdentifierExpr, BinaryExpr,
    UnaryExpr, CallExpr, IndexExpr,
    MemberAccessExpr, TernaryExpr,
    PostfixExpr, CastExpr,
    ArrayLiteralExpr, ArrayInitExpr,
    LambdaExpr,
    FunctionType, DelegateType,

    StructDecl, EnumDecl,
    EnumMember,
    ImportDecl
}

enum ValueCategory
{
    LValue, RValue
}

class AstNode
{
    AstNodeType nodeType;
    size_t line, column;
    string filePath;

    this(AstNodeType t)
    {
        nodeType = t;
    }
}

class ProgramNode : AstNode
{
    AstNode[] declarations;

    this()
    {
        super(AstNodeType.Program);
    }
}

class TypeNode : AstNode
{
    string typeName;
    bool isSlice = false;
    TypeNode elementType;

    this(string name)
    {
        super(AstNodeType.LiteralExpr);
        typeName = name;
    }
}

class VarDeclNode : AstNode
{
    string name;
    TypeNode typeNode;
    AstNode initializer;

    this()
    {
        super(AstNodeType.VarDecl);
    }
}

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
