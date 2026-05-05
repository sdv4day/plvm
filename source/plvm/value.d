/**
 * PLVM 值类型模块
 *
 * 本模块定义了 PLVM 虚拟机中使用的值类型系统，包括：
 * - $(LREF PValueType) 值类型枚举
 * - $(LREF Value) 值结构体
 * - $(LREF StructValue) 结构体值
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.value;

import std.conv : to;
import std.traits;

/**
 * PLVM 值类型枚举
 *
 * 定义了 PLVM 支持的所有值类型。
 */
enum PValueType : ubyte
{
    vtNull,      /// 空值类型
    vtBool,      /// 布尔类型
    vtByte,      /// 有符号 8 位整数
    vtUbyte,     /// 无符号 8 位整数
    vtShort,     /// 有符号 16 位整数
    vtUshort,    /// 无符号 16 位整数
    vtInt,       /// 有符号 32 位整数
    vtUint,      /// 无符号 32 位整数
    vtLong,      /// 有符号 64 位整数
    vtUlong,     /// 无符号 64 位整数
    vtChar,      /// UTF-8 字符
    vtWchar,     /// UTF-16 字符
    vtDchar,     /// UTF-32 字符
    vtString,    /// UTF-8 字符串
    vtWstring,   /// UTF-16 字符串
    vtDstring,   /// UTF-32 字符串
    vtArray,     /// 动态数组
    vtStruct,    /// 结构体
}

/**
 * 结构体值
 *
 * 用于存储结构体类型的值，包含类型名称和字段映射。
 */
struct StructValue
{
    string typeName;          /// 结构体类型名称
    Value[string] fields;     /// 字段名到值的映射
}

/**
 * PLVM 值结构体
 *
 * 表示 PLVM 虚拟机中的一个值。使用标签联合实现，
 * 支持多种基本类型、字符串、数组和结构体。
 *
 * Examples:
 * ---
 * // 创建整数值
 * auto intVal = Value.make!int(42);
 * assert(intVal.asInteger() == 42);
 *
 * // 创建字符串值
 * auto strVal = Value.make!string("hello");
 * assert(strVal.asString() == "hello");
 *
 * // 创建布尔值
 * auto boolVal = Value.make!bool(true);
 * assert(boolVal.isTruthy());
 * ---
 */
struct Value
{
    PValueType type = PValueType.vtNull;  /// 值类型标签

    union
    {
        long integerValue;      /// 整数值（用于所有整数类型和字符类型）
        string stringValue;     /// 字符串值
        Value[] arrayValue;     /// 数组值
        StructValue* structValue; /// 结构体指针
        bool boolValue;         /// 布尔值
    }

    /**
     * 创建空值
     *
     * Returns: 类型为 vtNull 的 Value 实例
     *
     * Examples:
     * ---
     * auto v = Value.makeNull();
     * assert(v.type == PValueType.vtNull);
     * assert(!v.isTruthy());
     * ---
     */
    static Value makeNull()
    {
        Value v;
        v.type = PValueType.vtNull;
        return v;
    }

    /**
     * 创建指定类型的值（模板函数）
     *
     * 支持的类型：bool, byte, ubyte, short, ushort, int, uint, long, ulong,
     * char, wchar, dchar, string, wstring, dstring, Value[]
     *
     * Params:
     *   T = 值的类型
     *   val = 要包装的值
     *
     * Returns: 包装后的 Value 实例
     *
     * Examples:
     * ---
     * auto intVal = Value.make!int(42);
     * auto strVal = Value.make!string("hello");
     * auto arrVal = Value.make!(Value[])([Value.make!int(1), Value.make!int(2)]);
     * ---
     */
    static Value make(T)(T val)
    {
        Value v;
        static if (is(T == bool))
        {
            v.type = PValueType.vtBool;
            v.boolValue = val;
            v.integerValue = val ? 1 : 0;
        }
        else static if (is(T == byte))
        {
            v.type = PValueType.vtByte;
            v.integerValue = val;
        }
        else static if (is(T == ubyte))
        {
            v.type = PValueType.vtUbyte;
            v.integerValue = val;
        }
        else static if (is(T == short))
        {
            v.type = PValueType.vtShort;
            v.integerValue = val;
        }
        else static if (is(T == ushort))
        {
            v.type = PValueType.vtUshort;
            v.integerValue = val;
        }
        else static if (is(T == int))
        {
            v.type = PValueType.vtInt;
            v.integerValue = val;
        }
        else static if (is(T == uint))
        {
            v.type = PValueType.vtUint;
            v.integerValue = val;
        }
        else static if (is(T == long))
        {
            v.type = PValueType.vtLong;
            v.integerValue = val;
        }
        else static if (is(T == ulong))
        {
            v.type = PValueType.vtUlong;
            v.integerValue = cast(long)val;
        }
        else static if (is(T == char))
        {
            v.type = PValueType.vtChar;
            v.integerValue = val;
        }
        else static if (is(T == wchar))
        {
            v.type = PValueType.vtWchar;
            v.integerValue = val;
        }
        else static if (is(T == dchar))
        {
            v.type = PValueType.vtDchar;
            v.integerValue = val;
        }
        else static if (is(T == string))
        {
            v.type = PValueType.vtString;
            v.stringValue = val;
        }
        else static if (is(T == wstring))
        {
            v.type = PValueType.vtWstring;
            v.stringValue = to!string(val);
        }
        else static if (is(T == dstring))
        {
            v.type = PValueType.vtDstring;
            v.stringValue = to!string(val);
        }
        else static if (is(T == Value[]))
        {
            v.type = PValueType.vtArray;
            v.arrayValue = val;
        }
        else
            static assert(false, "Unsupported type for Value.make: " ~ T.stringof);
        return v;
    }

    /**
     * 创建结构体值
     *
     * Params:
     *   typeName = 结构体类型名称
     *   fields = 字段名到值的映射
     *
     * Returns: 结构体类型的 Value 实例
     *
     * Examples:
     * ---
     * Value[string] fields;
     * fields["x"] = Value.make!int(10);
     * fields["y"] = Value.make!int(20);
     * auto pt = Value.makeStruct("Point", fields);
     * assert(pt.type == PValueType.vtStruct);
     * ---
     */
    static Value makeStruct(string typeName, Value[string] fields)
    {
        Value v;
        v.type = PValueType.vtStruct;
        v.structValue = new StructValue;
        v.structValue.typeName = typeName;
        v.structValue.fields = fields;
        return v;
    }

    alias makeBool = make!bool;        /// 创建布尔值的别名
    alias makeByte = make!byte;        /// 创建 byte 值的别名
    alias makeUbyte = make!ubyte;      /// 创建 ubyte 值的别名
    alias makeShort = make!short;      /// 创建 short 值的别名
    alias makeUshort = make!ushort;    /// 创建 ushort 值的别名
    alias makeInt = make!int;          /// 创建 int 值的别名
    alias makeUint = make!uint;        /// 创建 uint 值的别名
    alias makeLong = make!long;        /// 创建 long 值的别名
    alias makeUlong = make!ulong;      /// 创建 ulong 值的别名
    alias makeChar = make!char;        /// 创建 char 值的别名
    alias makeWchar = make!wchar;      /// 创建 wchar 值的别名
    alias makeDchar = make!dchar;      /// 创建 dchar 值的别名
    alias makeString = make!string;    /// 创建 string 值的别名
    alias makeWstring = make!wstring;  /// 创建 wstring 值的别名
    alias makeDstring = make!dstring;  /// 创建 dstring 值的别名
    alias makeArray = make!(Value[]);  /// 创建数组值的别名

    /**
     * 获取整数值
     *
     * Returns: 整数值
     *
     * Note: 调用前应确保类型为整数类型
     */
    long asInteger() const
    {
        return integerValue;
    }

    /**
     * 获取布尔值
     *
     * Returns: 布尔值
     *
     * Note: 调用前应确保类型为布尔类型
     */
    bool asBool() const
    {
        return boolValue;
    }

    /**
     * 获取字符串值
     *
     * Returns: 字符串值
     *
     * Note: 调用前应确保类型为字符串类型
     */
    string asString() const
    {
        return stringValue;
    }

    /**
     * 获取数组值
     *
     * Returns: Value 数组
     *
     * Note: 调用前应确保类型为数组类型
     */
    Value[] asArray()
    {
        return arrayValue;
    }

    /**
     * 获取结构体指针
     *
     * Returns: StructValue 指针
     *
     * Note: 调用前应确保类型为结构体类型
     */
    StructValue* asStruct()
    {
        return structValue;
    }

    /**
     * 判断值是否为真
     *
     * 不同类型的真值判断规则：
     * - vtNull: 始终为 false
     * - vtBool: 布尔值本身
     * - 整数类型: 非零为真
     * - 字符串类型: 非空为真
     * - 数组类型: 非空为真
     * - 结构体类型: 非空指针为真
     *
     * Returns: 值是否为真
     *
     * Examples:
     * ---
     * assert(Value.make!bool(true).isTruthy());
     * assert(!Value.make!bool(false).isTruthy());
     * assert(Value.make!int(42).isTruthy());
     * assert(!Value.make!int(0).isTruthy());
     * assert(Value.make!string("hello").isTruthy());
     * assert(!Value.make!string("").isTruthy());
     * ---
     */
    bool isTruthy() const
    {
        final switch (type)
        {
            case PValueType.vtNull:
                return false;
            case PValueType.vtBool:
                return boolValue;
            case PValueType.vtByte, PValueType.vtUbyte,
                 PValueType.vtShort, PValueType.vtUshort,
                 PValueType.vtInt, PValueType.vtUint,
                 PValueType.vtLong, PValueType.vtUlong,
                 PValueType.vtChar, PValueType.vtWchar, PValueType.vtDchar:
                return integerValue != 0;
            case PValueType.vtString, PValueType.vtWstring, PValueType.vtDstring:
                return stringValue.length > 0;
            case PValueType.vtArray:
                return arrayValue.length > 0;
            case PValueType.vtStruct:
                return structValue !is null;
        }
    }

    /**
     * 将值转换为字符串表示
     *
     * Returns: 值的字符串表示
     *
     * Examples:
     * ---
     * assert(Value.make!int(42).toString() == "42");
     * assert(Value.make!bool(true).toString() == "true");
     * assert(Value.make!string("hello").toString() == "hello");
     * assert(Value.makeNull().toString() == "null");
     * ---
     */
    string toString() const
    {
        import std.format : format;
        final switch (type)
        {
            case PValueType.vtNull:
                return "null";
            case PValueType.vtBool:
                return boolValue ? "true" : "false";
            case PValueType.vtByte, PValueType.vtShort, PValueType.vtInt, PValueType.vtLong,
                 PValueType.vtChar, PValueType.vtWchar, PValueType.vtDchar:
                return format("%d", integerValue);
            case PValueType.vtUbyte, PValueType.vtUshort, PValueType.vtUint, PValueType.vtUlong:
                return format("%d", cast(ulong)integerValue);
            case PValueType.vtString:
                return stringValue;
            case PValueType.vtWstring, PValueType.vtDstring:
                return stringValue;
            case PValueType.vtArray:
                return format("array[%d]", arrayValue.length);
            case PValueType.vtStruct:
                return structValue ? format("struct(%s)", structValue.typeName) : "struct(null)";
        }
    }
}

/**
 * Value 结构体单元测试
 */
unittest
{
    auto v = Value.make!int(42);
    assert(v.type == PValueType.vtInt);
    assert(v.asInteger() == 42);

    auto b = Value.make!bool(true);
    assert(b.isTruthy());

    auto n = Value.makeNull();
    assert(!n.isTruthy());

    auto s = Value.make!string("hello");
    assert(s.asString() == "hello");

    auto v2 = Value.makeInt(100);
    assert(v2.asInteger() == 100);

    auto v3 = Value.make!long(999L);
    assert(v3.asInteger() == 999);
}
