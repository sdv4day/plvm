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
 * 支持基本类型、字符串、结构体、动态数组（字符串除外）。
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
    else static if (is(UT == struct))
    {
        Value[string] fields;
        static if (__traits(hasMember, UT, "tupleof"))
        {
            import std.traits : FieldNameTuple;
            static foreach (i, fieldName; FieldNameTuple!UT)
            {
                fields[fieldName] = valueFromD!(typeof(UT.tupleof[i]))(__traits(getMember, val, fieldName));
            }
        }
        return Value.makeStruct(UT.stringof, fields);
    }
    else static if (isDynamicArray!UT && !isSomeString!UT)
    {
        import std.range : ElementType;
        alias ElemType = ElementType!UT;
        Value[] arr;
        arr.reserve(val.length);
        foreach (ref elem; val)
        {
            arr ~= valueFromD!ElemType(elem);
        }
        return Value.makeArray(arr);
    }
    else
        return Value.make!UT(val);
}

/**
 * 将 PLVM 值转换为 D 值
 *
 * 支持基本类型、字符串、结构体和动态数组。
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
    else static if (isDynamicArray!UT && !isSomeString!UT)
    {
        import std.range : ElementType;
        alias ElemType = ElementType!UT;
        auto arr = val.asArray();
        UT result;
        result.length = arr.length;
        foreach (i; 0 .. arr.length)
        {
            result[i] = valueToD!ElemType(arr[i]);
        }
        return result;
    }
    else static if (is(UT == struct))
    {
        auto sv = val.asStruct();
        UT result;
        static if (__traits(hasMember, UT, "tupleof"))
        {
            import std.traits : FieldNameTuple;
            static foreach (i, fieldName; FieldNameTuple!UT)
            {
                if (auto p = fieldName in sv.fields)
                {
                    __traits(getMember, result, fieldName) = valueToD!(typeof(UT.tupleof[i]))(*p);
                }
            }
        }
        return result;
    }
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

/**
 * valueFromD / valueToD 结构体转换单元测试
 */
unittest
{
    struct Point { int x; int y; }

    auto pt = Point(3, 4);
    auto v = valueFromD(pt);
    assert(v.type == PValueType.vtStruct);
    assert(v.asStruct().typeName == "Point");
    assert(v.asStruct().fields["x"].asInteger() == 3);
    assert(v.asStruct().fields["y"].asInteger() == 4);

    auto pt2 = valueToD!Point(v);
    assert(pt2.x == 3);
    assert(pt2.y == 4);
}

/**
 * valueFromD / valueToD 数组转换单元测试
 */
unittest
{
    int[] arr = [1, 2, 3, 4, 5];
    auto v = valueFromD(arr);
    assert(v.type == PValueType.vtArray);
    assert(v.asArray().length == 5);
    assert(v.asArray()[0].asInteger() == 1);
    assert(v.asArray()[4].asInteger() == 5);

    auto arr2 = valueToD!(int[])(v);
    assert(arr2.length == 5);
    assert(arr2 == [1, 2, 3, 4, 5]);
}

/**
 * valueFromD / valueToD 字符串数组转换单元测试
 */
unittest
{
    string[] arr = ["a", "b", "c"];
    auto v = valueFromD(arr);
    assert(v.type == PValueType.vtArray);
    assert(v.asArray().length == 3);
    assert(v.asArray()[0].asString() == "a");
    assert(v.asArray()[1].asString() == "b");
    assert(v.asArray()[2].asString() == "c");

    auto arr2 = valueToD!(string[])(v);
    assert(arr2.length == 3);
    assert(arr2 == ["a", "b", "c"]);
}

/**
 * valueFromD / valueToD 嵌套结构体转换单元测试
 */
unittest
{
    struct Inner { int a; int b; }
    struct Outer { Inner inner; string label; }

    auto outerVal = Outer(Inner(10, 20), "test");
    auto v = valueFromD(outerVal);
    assert(v.type == PValueType.vtStruct);
    assert(v.asStruct().typeName == "Outer");
    assert(v.asStruct().fields["label"].asString() == "test");

    auto innerV = v.asStruct().fields["inner"];
    assert(innerV.type == PValueType.vtStruct);
    assert(innerV.asStruct().fields["a"].asInteger() == 10);
    assert(innerV.asStruct().fields["b"].asInteger() == 20);

    auto outerVal2 = valueToD!Outer(v);
    assert(outerVal2.inner.a == 10);
    assert(outerVal2.inner.b == 20);
    assert(outerVal2.label == "test");
}

/**
 * valueFromD / valueToD 结构体数组混合转换单元测试
 */
unittest
{
    struct Point { int x; int y; }

    Point[] pts = [Point(1, 2), Point(3, 4)];
    auto v = valueFromD(pts);
    assert(v.type == PValueType.vtArray);
    assert(v.asArray().length == 2);

    auto pts2 = valueToD!(Point[])(v);
    assert(pts2.length == 2);
    assert(pts2[0].x == 1);
    assert(pts2[0].y == 2);
    assert(pts2[1].x == 3);
    assert(pts2[1].y == 4);
}

/**
 * 宿主函数包装器结构体参数单元测试
 */
unittest
{
    struct Point { int x; int y; }

    static int sumPoint(Point p)
    {
        return p.x + p.y;
    }

    auto wrapper = createHostFunctionWrapper!(sumPoint)();
    Value[] args = [Value.makeStruct("Point", ["x": Value.makeInt(3), "y": Value.makeInt(4)])];
    auto result = wrapper(args);
    assert(result.asInteger() == 7);
}

/**
 * 宿主函数包装器数组参数单元测试
 */
unittest
{
    static int sumArray(int[] arr)
    {
        int sum;
        foreach (v; arr)
            sum += v;
        return sum;
    }

    auto wrapper = createHostFunctionWrapper!(sumArray)();
    Value[] args = [Value.makeArray([Value.makeInt(1), Value.makeInt(2), Value.makeInt(3), Value.makeInt(4), Value.makeInt(5)])];
    auto result = wrapper(args);
    assert(result.asInteger() == 15);
}

/**
 * 宿主函数包装器混合参数单元测试
 */
unittest
{
    struct Point { int x; int y; }

    static int mixedTest(int factor, Point p, string[] labels)
    {
        return factor * (p.x + p.y) + cast(int)labels.length;
    }

    auto wrapper = createHostFunctionWrapper!(mixedTest)();
    Value[] args = [
        Value.makeInt(10),
        Value.makeStruct("Point", ["x": Value.makeInt(3), "y": Value.makeInt(4)]),
        Value.makeArray([Value.makeString("a"), Value.makeString("b")])
    ];
    auto result = wrapper(args);
    assert(result.asInteger() == 72);
}
