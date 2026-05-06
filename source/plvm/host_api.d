/**
 * PLVM 宿主 API 模块
 *
 * 本模块提供宿主程序与 PLVM 交互的 API，包括：
 * - D 类型到 PLVM 类型的转换
 * - D 值与 PLVM 值的互转
 * - 结构体和枚举类型注册
 * - 宿主函数包装器生成
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.host_api;

import plvm.value;
import plvm.bytecode;
import plvm.compiler;
import plvm.vm;
import std.traits;
import std.conv : to;
import std.format : format;

/**
 * 将 D 类型转换为 PLVM 类型名称
 *
 * 使用 std.traits.Unqual 去除类型修饰符后返回类型名。
 *
 * Params:
 *   T = D 类型
 *
 * Returns: PLVM 类型名称字符串
 */
string typeToPlvmTypeName(T)()
{
    alias UT = Unqual!T;
    return UT.stringof;
}

/**
 * 将 D 值转换为 PLVM 值
 *
 * 支持基本类型、字符串和 void。
 *
 * Params:
 *   T = D 值类型
 *   val = D 值
 *
 * Returns: PLVM Value
 */
Value valueFromD(T)(T val)
{
    alias UT = Unqual!T;
    static if (is(UT == void))
        return Value.makeNull();
    else
        return Value.make!UT(val);
}

/**
 * 将 PLVM 值转换为 D 值
 *
 * 支持基本类型和字符串。
 *
 * Params:
 *   T = 目标 D 类型
 *   val = PLVM 值
 *
 * Returns: D 值
 */
T valueToD(T)(Value val)
{
    alias UT = Unqual!T;
    
    static if (is(UT == bool))
        return cast(T)val.asBool();
    else static if (isIntegral!UT || isSomeChar!UT)
        return cast(T)val.asInteger();
    else static if (is(UT == string))
        return cast(T)val.asString();
    else static if (is(UT == wstring))
        return cast(T)to!wstring(val.asString());
    else static if (is(UT == dstring))
        return cast(T)to!dstring(val.asString());
    else
    {
        T result;
        return result;
    }
}

/**
 * 结构体字段信息
 */
struct StructFieldInfo
{
    string name;        /// 字段名
    string typeName;    /// 字段类型名
}

/**
 * 获取结构体字段名列表
 *
 * Params:
 *   T = 结构体类型
 *
 * Returns: 字段名数组
 */
string[] getStructFieldNames(T)()
{
    string[] names;
    static if (is(T == struct))
    {
        foreach (i, member; __traits(allMembers, T))
        {
            static if (__traits(compiles, __traits(getMember, T, member)))
            {
                import std.traits : FieldTypeTuple;
            }
        }
    }
    return names;
}

/**
 * 枚举值信息
 */
struct EnumValue
{
    string enumName;    /// 枚举名
    string memberName;  /// 成员名
    long value;         /// 值
}

/**
 * 宿主 API 类
 *
 * 管理类型注册和函数注册信息。
 */
class HostApi
{
private:
    string[string][string] enumMembers;     /// 枚举成员映射
    EnumValue[] enumValues;                  /// 枚举值列表
    string[long] registeredFuncIndices;      /// 注册函数索引
    string[long] registeredHostIndices;      /// 注册宿主函数索引

public:
    /**
     * 类型注册信息
     */
    struct TypeRegistration
    {
        string typeName;                    /// 类型名
        string[string] fieldTypes;          /// 字段类型映射
    }

    TypeRegistration[] structRegistrations; /// 结构体注册列表

    /**
     * 注册结构体类型
     *
     * 将 D 结构体类型注册到 PLVM。
     *
     * Params:
     *   T = 结构体类型
     *   name = 自定义类型名（可选）
     */
    void registerStructType(T)(string name = null)
    {
        static if (is(T == struct))
        {
            string typeName = name.length > 0 ? name : T.stringof;

            TypeRegistration reg;
            reg.typeName = typeName;

            static if (__traits(hasMember, T, "tupleof"))
            {
                import std.traits : FieldNameTuple;
                alias FieldNames = FieldNameTuple!T;
                static foreach (i, _; FieldNames)
                {
                    reg.fieldTypes[FieldNames[i]] = typeToPlvmTypeName!(typeof(T.tupleof[i]))();
                }
            }
            structRegistrations ~= reg;
        }
    }

    /**
     * 注册枚举类型
     *
     * 将 D 枚举类型注册到 PLVM。
     *
     * Params:
     *   T = 枚举类型
     *   name = 自定义类型名（可选）
     */
    void registerEnumType(T)(string name = null)
    {
        static if (is(T == enum))
        {
            string typeName = name.length > 0 ? name : T.stringof;
            string[string] members;

            foreach (member; __traits(allMembers, T))
            {
                static if (member != "min" && member != "max" &&
                    __traits(compiles, cast(long)__traits(getMember, T, member)))
                {
                    auto val = __traits(getMember, T, member);
                    members[member] = format("%d", cast(long)val);

                    EnumValue ev;
                    ev.enumName = typeName;
                    ev.memberName = member;
                    ev.value = cast(long)val;
                    enumValues ~= ev;

                    enumMembers[typeName][member] = format("%d", cast(long)val);
                }
            }
        }
    }

    /**
     * 注册函数
     *
     * Params:
     *   Func = 函数别名
     *   name = 自定义函数名（可选）
     */
    void registerFunction(alias Func)(string name = null)
    {
        string funcName = name.length > 0 ? name : __traits(identifier, Func);
        registeredFuncIndices[registeredFuncIndices.length] = funcName;
    }

    /**
     * 注册宿主函数
     *
     * Params:
     *   Func = 函数别名
     *   name = 自定义函数名（可选）
     */
    void registerHostFunction(alias Func)(string name = null)
    {
        string funcName = name.length > 0 ? name : __traits(identifier, Func);
        registeredHostIndices[registeredHostIndices.length] = funcName;
    }

    /// 获取枚举成员映射
    string[string][string] getEnumMembers()
    {
        return enumMembers;
    }

    /// 获取枚举值列表
    EnumValue[] getEnumValues()
    {
        return enumValues;
    }

    /// 获取函数索引映射
    string[long] getFuncIndices()
    {
        return registeredFuncIndices;
    }

    /// 获取宿主函数索引映射
    string[long] getHostIndices()
    {
        return registeredHostIndices;
    }

    /// 获取已注册结构体名称列表
    string[] getStructNames()
    {
        string[] names;
        foreach (reg; structRegistrations)
            names ~= reg.typeName;
        return names;
    }
}

/**
 * 创建宿主函数包装器
 *
 * 将 D 函数包装为 PLVM 可调用的委托。
 * 支持任意数量参数的函数。
 *
 * Params:
 *   Func = 要包装的函数
 *
 * Returns: 包装后的委托
 */
template createHostFunctionWrapper(alias Func)
{
    auto createHostFunctionWrapper()
    {
        import std.functional : toDelegate;
        import std.conv : text;

        alias RT = ReturnType!Func;
        alias PT = Parameters!Func;

        static if (PT.length == 0)
        {
            return toDelegate((Value[] args) {
                auto result = Func();
                return valueFromD(result);
            });
        }
        else
        {
            static string buildArgDecls()
            {
                string result;
                static foreach (i, T; PT)
                {
                    result ~= text("auto a", i, " = valueToD!(PT[", i, "])(args[", i, "]); ");
                }
                return result;
            }

            static string buildCallArgs()
            {
                string result;
                static foreach (i; 0 .. PT.length)
                {
                    static if (i > 0) result ~= ", ";
                    result ~= text("a", i);
                }
                return result;
            }

            enum argDecls = buildArgDecls();
            enum callArgs = buildCallArgs();

            return toDelegate((Value[] args) {
                mixin(argDecls);
                auto result = mixin("Func(" ~ callArgs ~ ")");
                return valueFromD(result);
            });
        }
    }
}

/**
 * 宿主函数包装器单元测试
 */
unittest
{
    static int add(int a, int b) { return a + b; }
    auto wrapper = createHostFunctionWrapper!(add)();
    Value[] args = [Value.makeInt(3), Value.makeInt(4)];
    auto result = wrapper(args);
    assert(result.asInteger() == 7);
}

/**
 * 宿主函数包装器 delegate 类型单元测试
 */
unittest
{
    int captured = 100;

    int delegate(int, int) dg = delegate(int a, int b) {
        return captured + a + b;
    };

    auto wrapper = createHostFunctionWrapper!(dg)();
    Value[] args = [Value.makeInt(3), Value.makeInt(4)];
    auto result = wrapper(args);
    assert(result.asInteger() == 107);
}

/**
 * 宿主函数包装器匿名 delegate 单元测试
 */
unittest
{
    int captured = 50;

    auto wrapper = createHostFunctionWrapper!(delegate int(int a, int b) {
        return captured * a + b;
    })();
    Value[] args = [Value.makeInt(2), Value.makeInt(10)];
    auto result = wrapper(args);
    assert(result.asInteger() == 110);
}

/**
 * 宿主函数包装器函数指针单元测试
 */
unittest
{
    static int multiply(int a, int b) { return a * b; }
    int function(int, int) fp = &multiply;

    auto wrapper = createHostFunctionWrapper!(fp)();
    Value[] args = [Value.makeInt(3), Value.makeInt(4)];
    auto result = wrapper(args);
    assert(result.asInteger() == 12);
}

/**
 * 宿主函数包装器无参数 delegate 单元测试
 */
unittest
{
    int delegate() dg = delegate() {
        return 42;
    };

    auto wrapper = createHostFunctionWrapper!(dg)();
    Value[] args = [];
    auto result = wrapper(args);
    assert(result.asInteger() == 42);
}

/**
 * 宿主函数包装器嵌套 delegate 单元测试
 */
unittest
{
    int outerVar = 10;
    int middleVar = 5;

    int delegate(int) dg = delegate(int x) {
        int innerVar = 2;
        return outerVar + middleVar + innerVar + x;
    };

    auto wrapper = createHostFunctionWrapper!(dg)();
    Value[] args = [Value.makeInt(3)];
    auto result = wrapper(args);
    assert(result.asInteger() == 20);
}
