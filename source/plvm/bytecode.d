/**
 * PLVM 字节码模块
 *
 * 本模块定义了 PLVM 虚拟机的字节码格式，包括：
 * - $(LREF OpCode) 操作码枚举
 * - $(LREF Constant) 常量结构
 * - $(LREF Instruction) 指令结构
 * - $(LREF FunctionInfo) 函数信息
 * - $(LREF BytecodeProgram) 字节码程序
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.bytecode;

/**
 * 操作码枚举
 *
 * 定义了 PLVM 虚拟机支持的所有操作码。
 */
enum OpCode : ubyte
{
    NOP,                    /// 空操作
    PUSH,                   /// 压入常量
    POP,                    /// 弹出栈顶
    DUP,                    /// 复制栈顶

    CAST_TO_LONG,           /// 转换为 long
    CAST_TO_INT,            /// 转换为 int
    CAST_TO_SHORT,          /// 转换为 short
    CAST_TO_BYTE,           /// 转换为 byte
    CAST_TO_ULONG,          /// 转换为 ulong
    CAST_TO_UINT,           /// 转换为 uint
    CAST_TO_USHORT,         /// 转换为 ushort
    CAST_TO_UBYTE,          /// 转换为 ubyte
    CAST_TO_CHAR,           /// 转换为 char
    CAST_TO_WCHAR,          /// 转换为 wchar
    CAST_TO_DCHAR,          /// 转换为 dchar

    LOAD_LOCAL,             /// 加载局部变量
    STORE_LOCAL,            /// 存储局部变量
    LOAD_GLOBAL,            /// 加载全局变量
    STORE_GLOBAL,           /// 存储全局变量

    ADD,                    /// 加法
    SUB,                    /// 减法
    MUL,                    /// 乘法
    DIV,                    /// 除法
    MOD,                    /// 取模
    EQ,                     /// 等于
    NEQ,                    /// 不等于
    LT,                     /// 小于
    LTE,                    /// 小于等于
    GT,                     /// 大于
    GTE,                    /// 大于等于
    AND_OP,                 /// 逻辑与
    OR_OP,                  /// 逻辑或
    NOT,                    /// 逻辑非
    NEG,                    /// 取负
    BIT_NOT,                /// 按位取反
    BIT_AND,                /// 按位与
    BIT_OR,                 /// 按位或
    BIT_XOR,                /// 按位异或
    SHL,                    /// 左移
    SHR,                    /// 右移

    JMP,                    /// 无条件跳转
    JZ,                     /// 为零跳转
    JNZ,                    /// 非零跳转
    CALL,                   /// 调用函数
    CALL_HOST,              /// 调用宿主函数
    RET,                    /// 返回
    HALT,                   /// 停止

    ARRAY_NEW,              /// 创建数组
    ARRAY_GET,              /// 获取数组元素
    ARRAY_SET,              /// 设置数组元素
    ARRAY_APPEND,           /// 追加数组元素
    ARRAY_LEN,              /// 获取数组长度
    ARRAY_SLICE,            /// 数组切片

    STRUCT_NEW,             /// 创建结构体
    STRUCT_GET,             /// 获取结构体字段
    STRUCT_SET,             /// 设置结构体字段
    PROP_GET,               /// 获取属性

    FOREACH_BEGIN,          /// foreach 开始
    FOREACH_NEXT,           /// foreach 下一个
    FOREACH_END,            /// foreach 结束

    CAST_GENERIC,           /// 通用类型转换
}

/**
 * 常量类型枚举
 */
enum ConstantType : ubyte
{
    ctInteger,      /// 整数常量
    ctString,       /// 字符串常量
    ctIdentifier,   /// 标识符常量
}

/**
 * 常量结构
 *
 * 表示字节码程序中的一个常量值。
 */
struct Constant
{
    ConstantType type;  /// 常量类型
    union
    {
        long integerValue;      /// 整数值
        string stringValue;     /// 字符串值（用于字符串和标识符）
    }

    /**
     * 创建整数常量
     *
     * Params:
     *   val = 整数值
     *
     * Returns: 整数常量
     */
    static Constant makeInteger(long val)
    {
        Constant c;
        c.type = ConstantType.ctInteger;
        c.integerValue = val;
        return c;
    }

    /**
     * 创建字符串常量
     *
     * Params:
     *   val = 字符串值
     *
     * Returns: 字符串常量
     */
    static Constant makeString(string val)
    {
        Constant c;
        c.type = ConstantType.ctString;
        c.stringValue = val;
        return c;
    }

    /**
     * 创建标识符常量
     *
     * Params:
     *   val = 标识符名称
     *
     * Returns: 标识符常量
     */
    static Constant makeIdentifier(string val)
    {
        Constant c;
        c.type = ConstantType.ctIdentifier;
        c.stringValue = val;
        return c;
    }
}

/**
 * 指令结构
 *
 * 表示字节码程序中的一条指令。
 */
struct Instruction
{
    OpCode opcode = OpCode.NOP; /// 操作码
    long arg1;                  /// 参数1
    long arg2;                  /// 参数2
    size_t line;                /// 源代码行号

    /**
     * 创建 NOP 指令
     */
    static Instruction nop(size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.NOP;
        i.line = ln;
        return i;
    }

    /**
     * 创建 PUSH 指令
     *
     * Params:
     *   constIdx = 常量索引
     *   ln = 行号
     */
    static Instruction push(long constIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.PUSH;
        i.arg1 = constIdx;
        i.line = ln;
        return i;
    }

    /**
     * 创建 POP 指令
     */
    static Instruction pop(size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.POP;
        i.line = ln;
        return i;
    }

    /**
     * 创建 DUP 指令
     */
    static Instruction dup_(size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.DUP;
        i.line = ln;
        return i;
    }

    /**
     * 创建 LOAD_LOCAL 指令
     *
     * Params:
     *   slot = 局部变量槽位
     *   ln = 行号
     */
    static Instruction loadLocal(long slot, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.LOAD_LOCAL;
        i.arg1 = slot;
        i.line = ln;
        return i;
    }

    /**
     * 创建 STORE_LOCAL 指令
     *
     * Params:
     *   slot = 局部变量槽位
     *   ln = 行号
     */
    static Instruction storeLocal(long slot, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.STORE_LOCAL;
        i.arg1 = slot;
        i.line = ln;
        return i;
    }

    /**
     * 创建 LOAD_GLOBAL 指令
     *
     * Params:
     *   nameIdx = 全局变量名索引
     *   ln = 行号
     */
    static Instruction loadGlobal(long nameIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.LOAD_GLOBAL;
        i.arg1 = nameIdx;
        i.line = ln;
        return i;
    }

    /**
     * 创建 STORE_GLOBAL 指令
     *
     * Params:
     *   nameIdx = 全局变量名索引
     *   ln = 行号
     */
    static Instruction storeGlobal(long nameIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.STORE_GLOBAL;
        i.arg1 = nameIdx;
        i.line = ln;
        return i;
    }

    /// 创建 ADD 指令
    static Instruction add_(size_t ln = 0) { Instruction i; i.opcode = OpCode.ADD; i.line = ln; return i; }
    /// 创建 SUB 指令
    static Instruction sub_(size_t ln = 0) { Instruction i; i.opcode = OpCode.SUB; i.line = ln; return i; }
    /// 创建 MUL 指令
    static Instruction mul_(size_t ln = 0) { Instruction i; i.opcode = OpCode.MUL; i.line = ln; return i; }
    /// 创建 DIV 指令
    static Instruction div_(size_t ln = 0) { Instruction i; i.opcode = OpCode.DIV; i.line = ln; return i; }
    /// 创建 MOD 指令
    static Instruction mod_(size_t ln = 0) { Instruction i; i.opcode = OpCode.MOD; i.line = ln; return i; }

    /// 创建 EQ 指令
    static Instruction eq_(size_t ln = 0) { Instruction i; i.opcode = OpCode.EQ; i.line = ln; return i; }
    /// 创建 NEQ 指令
    static Instruction neq_(size_t ln = 0) { Instruction i; i.opcode = OpCode.NEQ; i.line = ln; return i; }
    /// 创建 LT 指令
    static Instruction lt_(size_t ln = 0) { Instruction i; i.opcode = OpCode.LT; i.line = ln; return i; }
    /// 创建 LTE 指令
    static Instruction lte_(size_t ln = 0) { Instruction i; i.opcode = OpCode.LTE; i.line = ln; return i; }
    /// 创建 GT 指令
    static Instruction gt_(size_t ln = 0) { Instruction i; i.opcode = OpCode.GT; i.line = ln; return i; }
    /// 创建 GTE 指令
    static Instruction gte_(size_t ln = 0) { Instruction i; i.opcode = OpCode.GTE; i.line = ln; return i; }

    /// 创建 AND_OP 指令
    static Instruction andOp(size_t ln = 0) { Instruction i; i.opcode = OpCode.AND_OP; i.line = ln; return i; }
    /// 创建 OR_OP 指令
    static Instruction orOp(size_t ln = 0) { Instruction i; i.opcode = OpCode.OR_OP; i.line = ln; return i; }
    /// 创建 NOT 指令
    static Instruction not_(size_t ln = 0) { Instruction i; i.opcode = OpCode.NOT; i.line = ln; return i; }

    /// 创建 NEG 指令
    static Instruction neg_(size_t ln = 0) { Instruction i; i.opcode = OpCode.NEG; i.line = ln; return i; }
    /// 创建 BIT_NOT 指令
    static Instruction bitNot(size_t ln = 0) { Instruction i; i.opcode = OpCode.BIT_NOT; i.line = ln; return i; }
    /// 创建 BIT_AND 指令
    static Instruction bitAnd(size_t ln = 0) { Instruction i; i.opcode = OpCode.BIT_AND; i.line = ln; return i; }
    /// 创建 BIT_OR 指令
    static Instruction bitOr(size_t ln = 0) { Instruction i; i.opcode = OpCode.BIT_OR; i.line = ln; return i; }
    /// 创建 BIT_XOR 指令
    static Instruction bitXor(size_t ln = 0) { Instruction i; i.opcode = OpCode.BIT_XOR; i.line = ln; return i; }
    /// 创建 SHL 指令
    static Instruction shl_(size_t ln = 0) { Instruction i; i.opcode = OpCode.SHL; i.line = ln; return i; }
    /// 创建 SHR 指令
    static Instruction shr_(size_t ln = 0) { Instruction i; i.opcode = OpCode.SHR; i.line = ln; return i; }

    /**
     * 创建 JMP 指令
     *
     * Params:
     *   target = 跳转目标
     *   ln = 行号
     */
    static Instruction jmp(long target, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.JMP;
        i.arg1 = target;
        i.line = ln;
        return i;
    }

    /**
     * 创建 JZ 指令
     *
     * Params:
     *   target = 跳转目标
     *   ln = 行号
     */
    static Instruction jz(long target, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.JZ;
        i.arg1 = target;
        i.line = ln;
        return i;
    }

    /**
     * 创建 JNZ 指令
     *
     * Params:
     *   target = 跳转目标
     *   ln = 行号
     */
    static Instruction jnz(long target, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.JNZ;
        i.arg1 = target;
        i.line = ln;
        return i;
    }

    /**
     * 创建 CALL 指令
     *
     * Params:
     *   funcIdx = 函数索引
     *   ln = 行号
     */
    static Instruction call_(long funcIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.CALL;
        i.arg1 = funcIdx;
        i.line = ln;
        return i;
    }

    /**
     * 创建 CALL_HOST 指令
     *
     * Params:
     *   hostIdx = 宿主函数索引
     *   ln = 行号
     */
    static Instruction callHost(long hostIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.CALL_HOST;
        i.arg1 = hostIdx;
        i.line = ln;
        return i;
    }

    /// 创建 RET 指令
    static Instruction ret_(size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.RET;
        i.line = ln;
        return i;
    }

    /// 创建 HALT 指令
    static Instruction halt_(size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.HALT;
        i.line = ln;
        return i;
    }

    /**
     * 创建 ARRAY_NEW 指令
     *
     * Params:
     *   cap = 初始容量
     *   ln = 行号
     */
    static Instruction arrayNew(long cap, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.ARRAY_NEW;
        i.arg1 = cap;
        i.line = ln;
        return i;
    }

    /// 创建 ARRAY_GET 指令
    static Instruction arrayGet(size_t ln = 0) { Instruction i; i.opcode = OpCode.ARRAY_GET; i.line = ln; return i; }
    /// 创建 ARRAY_SET 指令
    static Instruction arraySet(size_t ln = 0) { Instruction i; i.opcode = OpCode.ARRAY_SET; i.line = ln; return i; }
    /// 创建 ARRAY_APPEND 指令
    static Instruction arrayAppend(size_t ln = 0) { Instruction i; i.opcode = OpCode.ARRAY_APPEND; i.line = ln; return i; }
    /// 创建 ARRAY_LEN 指令
    static Instruction arrayLen(size_t ln = 0) { Instruction i; i.opcode = OpCode.ARRAY_LEN; i.line = ln; return i; }
    /// 创建 ARRAY_SLICE 指令
    static Instruction arraySlice(size_t ln = 0) { Instruction i; i.opcode = OpCode.ARRAY_SLICE; i.line = ln; return i; }

    /**
     * 创建 STRUCT_NEW 指令
     *
     * Params:
     *   fieldCount = 字段数量
     *   ln = 行号
     */
    static Instruction structNew(long fieldCount, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.STRUCT_NEW;
        i.arg1 = fieldCount;
        i.line = ln;
        return i;
    }

    /**
     * 创建 STRUCT_GET 指令
     *
     * Params:
     *   fieldIdx = 字段索引
     *   ln = 行号
     */
    static Instruction structGet(long fieldIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.STRUCT_GET;
        i.arg1 = fieldIdx;
        i.line = ln;
        return i;
    }

    /**
     * 创建 STRUCT_SET 指令
     *
     * Params:
     *   fieldIdx = 字段索引
     *   ln = 行号
     */
    static Instruction structSet(long fieldIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.STRUCT_SET;
        i.arg1 = fieldIdx;
        i.line = ln;
        return i;
    }

    /**
     * 创建 PROP_GET 指令
     *
     * Params:
     *   propIdx = 属性索引
     *   ln = 行号
     */
    static Instruction propGet(long propIdx, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.PROP_GET;
        i.arg1 = propIdx;
        i.line = ln;
        return i;
    }

    /**
     * 创建 FOREACH_BEGIN 指令
     *
     * Params:
     *   varSlot = 循环变量槽位
     *   ln = 行号
     */
    static Instruction foreachBegin(long varSlot, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.FOREACH_BEGIN;
        i.arg1 = varSlot;
        i.line = ln;
        return i;
    }

    /**
     * 创建 FOREACH_NEXT 指令
     *
     * Params:
     *   target = 跳转目标
     *   ln = 行号
     */
    static Instruction foreachNext(long target, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.FOREACH_NEXT;
        i.arg1 = target;
        i.line = ln;
        return i;
    }

    /// 创建 FOREACH_END 指令
    static Instruction foreachEnd(size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.FOREACH_END;
        i.line = ln;
        return i;
    }

    /**
     * 创建 CAST_GENERIC 指令
     *
     * Params:
     *   targetTypeId = 目标类型ID
     *   ln = 行号
     */
    static Instruction castGeneric(long targetTypeId, size_t ln = 0)
    {
        Instruction i;
        i.opcode = OpCode.CAST_GENERIC;
        i.arg1 = targetTypeId;
        i.line = ln;
        return i;
    }

    /// 创建 CAST_TO_LONG 指令
    static Instruction castToLong(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_LONG; i.line = ln; return i; }
    /// 创建 CAST_TO_INT 指令
    static Instruction castToInt(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_INT; i.line = ln; return i; }
    /// 创建 CAST_TO_SHORT 指令
    static Instruction castToShort(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_SHORT; i.line = ln; return i; }
    /// 创建 CAST_TO_BYTE 指令
    static Instruction castToByte(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_BYTE; i.line = ln; return i; }
    /// 创建 CAST_TO_ULONG 指令
    static Instruction castToUlong(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_ULONG; i.line = ln; return i; }
    /// 创建 CAST_TO_UINT 指令
    static Instruction castToUint(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_UINT; i.line = ln; return i; }
    /// 创建 CAST_TO_USHORT 指令
    static Instruction castToUshort(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_USHORT; i.line = ln; return i; }
    /// 创建 CAST_TO_UBYTE 指令
    static Instruction castToUbyte(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_UBYTE; i.line = ln; return i; }
    /// 创建 CAST_TO_CHAR 指令
    static Instruction castToChar(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_CHAR; i.line = ln; return i; }
    /// 创建 CAST_TO_WCHAR 指令
    static Instruction castToWchar(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_WCHAR; i.line = ln; return i; }
    /// 创建 CAST_TO_DCHAR 指令
    static Instruction castToDchar(size_t ln = 0) { Instruction i; i.opcode = OpCode.CAST_TO_DCHAR; i.line = ln; return i; }
}

/**
 * 函数信息结构
 *
 * 存储函数的元数据信息。
 */
struct FunctionInfo
{
    string name;            /// 函数名
    size_t entryPoint;      /// 入口点指令索引
    size_t numLocals;       /// 局部变量数量
    size_t numParams;       /// 参数数量
    string[] paramNames;    /// 参数名列表
    string[] capturedVars;  /// 捕获的变量列表
}

/**
 * 字节码程序结构
 *
 * 表示一个完整的字节码程序，包含指令、常量、函数信息等。
 */
struct BytecodeProgram
{
    Instruction[] instructions;     /// 指令数组
    Constant[] constants;           /// 常量数组
    FunctionInfo[] functions;       /// 函数信息数组
    string[] structFieldNames;      /// 结构体字段名数组

    /**
     * 添加常量（去重）
     *
     * Params:
     *   c = 常量值
     *
     * Returns: 常量索引
     */
    size_t addConstant(Constant c)
    {
        foreach (i, existing; constants)
        {
            if (existing.type == c.type)
            {
                if (existing.type == ConstantType.ctInteger && existing.integerValue == c.integerValue)
                    return i;
                if (existing.type == ConstantType.ctString && existing.stringValue == c.stringValue)
                    return i;
                if (existing.type == ConstantType.ctIdentifier && existing.stringValue == c.stringValue)
                    return i;
            }
        }
        size_t idx = constants.length;
        constants ~= c;
        return idx;
    }

    /**
     * 添加整数常量
     *
     * Params:
     *   val = 整数值
     *
     * Returns: 常量索引
     */
    size_t addInteger(long val)
    {
        return addConstant(Constant.makeInteger(val));
    }

    /**
     * 添加字符串常量
     *
     * Params:
     *   val = 字符串值
     *
     * Returns: 常量索引
     */
    size_t addString(string val)
    {
        return addConstant(Constant.makeString(val));
    }

    /**
     * 添加标识符常量
     *
     * Params:
     *   val = 标识符名称
     *
     * Returns: 常量索引
     */
    size_t addIdentifier(string val)
    {
        return addConstant(Constant.makeIdentifier(val));
    }

    /**
     * 添加结构体字段名
     *
     * Params:
     *   name = 字段名
     *
     * Returns: 字段名索引
     */
    size_t addStructFieldName(string name)
    {
        foreach (i, existing; structFieldNames)
        {
            if (existing == name)
                return i;
        }
        size_t idx = structFieldNames.length;
        structFieldNames ~= name;
        return idx;
    }

    /**
     * 发射指令
     *
     * Params:
     *   instr = 指令
     *
     * Returns: 指令索引
     */
    size_t emit(Instruction instr)
    {
        size_t pos = instructions.length;
        instructions ~= instr;
        return pos;
    }

    /**
     * 修补跳转指令目标
     *
     * Params:
     *   jumpPos = 跳转指令位置
     *   target = 目标位置
     */
    void patchJump(size_t jumpPos, size_t target)
    {
        instructions[jumpPos].arg1 = cast(long)target;
    }

    /**
     * 反汇编程序
     *
     * Returns: 反汇编文本
     */
    string disassemble() const
    {
        import std.format : format;
        string result = "=== Constants ===\n";
        foreach (i, c; constants)
        {
            final switch (c.type)
            {
                case ConstantType.ctInteger:
                    result ~= format("  [%d] int: %d\n", i, c.integerValue);
                    break;
                case ConstantType.ctString:
                    result ~= format("  [%d] str: \"%s\"\n", i, c.stringValue);
                    break;
                case ConstantType.ctIdentifier:
                    result ~= format("  [%d] id: %s\n", i, c.stringValue);
                    break;
            }
        }

        result ~= "\n=== Functions ===\n";
        foreach (f; functions)
        {
            result ~= format("  %s: entry=%d locals=%d params=%d\n",
                f.name, f.entryPoint, f.numLocals, f.numParams);
        }

        result ~= "\n=== Instructions ===\n";
        foreach (i, instr; instructions)
        {
            result ~= format("  %04d: %s", i, instr.opcode);
            if (instr.arg1 != 0)
                result ~= format(" %d", instr.arg1);
            if (instr.arg2 != 0)
                result ~= format(" %d", instr.arg2);
            if (instr.line > 0)
                result ~= format("  ; line %d", instr.line);
            result ~= "\n";
        }
        return result;
    }
}

/**
 * 获取操作码名称
 *
 * Params:
 *   op = 操作码
 *
 * Returns: 操作码名称字符串
 */
string opcodeName(OpCode op) pure nothrow @nogc
{
    import std.traits : EnumMembers;
    foreach (member; __traits(allMembers, OpCode))
    {
        if (__traits(getMember, OpCode, member) == op)
            return member;
    }
    return "UNKNOWN";
}
