/**
 * PLVM 词法单元模块
 *
 * 本模块定义了 PLVM 词法分析器使用的词法单元（Token）类型。
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.token;

/**
 * 词法单元类型枚举
 *
 * 定义了 PLVM 支持的所有词法单元类型。
 */
enum TokenType : ubyte
{
    tokEOF,         /// 文件结束
    tokIdentifier,  /// 标识符
    tokInteger,     /// 整数常量
    tokString_,     /// 字符串常量
    tokChar_,       /// 字符常量

    tokLParen,      /// 左括号 (
    tokRParen,      /// 右括号 )
    tokLBrace,      /// 左花括号 {
    tokRBrace,      /// 右花括号 }
    tokLBracket,    /// 左方括号 [
    tokRBracket,    /// 右方括号 ]
    tokComma,       /// 逗号 ,
    tokSemicolon,   /// 分号 ;
    tokDot,         /// 点 .
    tokColon,       /// 冒号 :
    tokQuestion,    /// 问号 ?

    tokPlus,        /// 加号 +
    tokMinus,       /// 减号 -
    tokStar,        /// 乘号 *
    tokSlash,       /// 除号 /
    tokPercent,     /// 取模 %
    tokPlusPlus,    /// 自增 ++
    tokMinusMinus,  /// 自减 --
    tokEq,          /// 赋值 =
    tokPlusEq,      /// 加赋值 +=
    tokMinusEq,     /// 减赋值 -=
    tokStarEq,      /// 乘赋值 *=
    tokSlashEq,     /// 除赋值 /=
    tokPercentEq,   /// 模赋值 %=
    tokAmpEq,       /// 与赋值 &=
    tokPipeEq,      /// 或赋值 |=
    tokCaretEq,     /// 异或赋值 ^=
    tokShlEq,       /// 左移赋值 <<=
    tokShrEq,       /// 右移赋值 >>=

    tokEqEq,        /// 等于 ==
    tokNotEq,       /// 不等于 !=
    tokLt,          /// 小于 <
    tokLte,         /// 小于等于 <=
    tokGt,          /// 大于 >
    tokGte,         /// 大于等于 >=
    tokShl,         /// 左移 <<
    tokShr,         /// 右移 >>

    tokAmp,         /// 按位与 &
    tokPipe,        /// 按位或 |
    tokCaret,       /// 按位异或 ^
    tokTilde,       /// 按位取反 ~
    tokAmpAmp,      /// 逻辑与 &&
    tokPipePipe,    /// 逻辑或 ||
    tokNot,         /// 逻辑非 !
    tokTildeEq,     /// 按位取反赋值 ~=

    tokArrow,       /// 箭头 =>

    tokKwVoid,      /// 关键字 void
    tokKwBool,      /// 关键字 bool
    tokKwByte,      /// 关键字 byte
    tokKwUbyte,     /// 关键字 ubyte
    tokKwShort,     /// 关键字 short
    tokKwUshort,    /// 关键字 ushort
    tokKwInt,       /// 关键字 int
    tokKwUint,      /// 关键字 uint
    tokKwLong,      /// 关键字 long
    tokKwUlong,     /// 关键字 ulong
    tokKwChar,      /// 关键字 char
    tokKwWchar,     /// 关键字 wchar
    tokKwDchar,     /// 关键字 dchar
    tokKwString,    /// 关键字 string
    tokKwWstring,   /// 关键字 wstring
    tokKwDstring,   /// 关键字 dstring

    tokKwIf,        /// 关键字 if
    tokKwElse,      /// 关键字 else
    tokKwWhile,     /// 关键字 while
    tokKwDo,        /// 关键字 do
    tokKwFor,       /// 关键字 for
    tokKwForeach,   /// 关键字 foreach
    tokKwSwitch,    /// 关键字 switch
    tokKwCase,      /// 关键字 case
    tokKwDefault,   /// 关键字 default
    tokKwReturn,    /// 关键字 return
    tokKwBreak,     /// 关键字 break
    tokKwContinue,  /// 关键字 continue
    tokKwTrue,      /// 关键字 true
    tokKwFalse,     /// 关键字 false
    tokKwNull,      /// 关键字 null
    tokKwCast,      /// 关键字 cast
    tokKwScope,     /// 关键字 scope
    tokKwStruct,    /// 关键字 struct
    tokKwEnum,      /// 关键字 enum
    tokKwFunction,  /// 关键字 function
    tokKwDelegate,  /// 关键字 delegate
    tokKwIs,        /// 关键字 is
    tokKwAuto,      /// 关键字 auto
    tokKwIn,        /// 关键字 in
    tokKwOut,       /// 关键字 out
    tokKwRef,       /// 关键字 ref
    tokKwStatic,    /// 关键字 static
    tokKwConst,     /// 关键字 const
    tokKwImmutable, /// 关键字 immutable
    tokKwClass,     /// 关键字 class
    tokKwInterface, /// 关键字 interface
    tokKwThis,      /// 关键字 this
    tokKwTypeof,    /// 关键字 typeof
    tokKwSizeof,    /// 关键字 sizeof
}

/**
 * 词法单元结构
 *
 * 表示源代码中的一个词法单元。
 */
struct Token
{
    TokenType type = TokenType.tokEOF;  /// 词法单元类型
    string lexeme;                      /// 原始文本
    size_t line;                        /// 行号
    size_t column;                      /// 列号
    size_t fileIndex;                   /// 文件索引
}

/**
 * 源文件结构
 *
 * 表示一个源文件。
 */
struct SourceFile
{
    string name;        /// 文件名
    string content;     /// 文件内容
}

/// 词法单元名称映射表
static string[TokenType] tokenNames;

/**
 * 初始化词法单元名称映射表
 */
shared static this()
{
    import std.traits : EnumMembers;
    foreach (member; __traits(allMembers, TokenType))
    {
        static if (__traits(compiles, __traits(getMember, TokenType, member)))
        {
            tokenNames[__traits(getMember, TokenType, member)] = member;
        }
    }
}

/**
 * 获取词法单元类型名称
 *
 * Params:
 *   t = 词法单元类型
 *
 * Returns: 词法单元类型名称字符串
 */
string tokenName(TokenType t)
{
    auto p = t in tokenNames;
    return p ? *p : "unknown";
}
