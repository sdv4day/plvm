/**
 * PLVM 主接口模块
 *
 * 本模块提供 PLVM 的主要公共 API，包括：
 * - 脚本加载和编译
 * - 函数调用
 * - 类型注册
 * - 宿主函数注册
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.plvm;

import plvm.value;
import plvm.bytecode;
import plvm.compiler;
import plvm.vm;
import plvm.host_api;
import plvm.lexer;
import plvm.parser;
import std.traits;
import std.conv : to;
import std.format : format;
import std.exception : enforce;

/**
 * PLVM 基础异常类
 */
class PlvmException : Exception
{
    /**
     * 构造 PLVM 异常
     *
     * Params:
     *   msg = 错误消息
     */
    this(string msg)
    {
        super(msg);
    }
}

/// PLVM 编译异常
class PlvmCompileException : PlvmException
{
    this(string msg) { super(msg); }
}

/// PLVM 运行时异常
class PlvmRuntimeException : PlvmException
{
    this(string msg) { super(msg); }
}

/**
 * 模块句柄类
 *
 * 表示一个已编译的脚本模块。
 */
class ModHandle
{
    string moduleName;          /// 模块名
    BytecodeProgram program;    /// 字节码程序
    size_t entryPoint;          /// 入口点

    /**
     * 构造模块句柄
     *
     * Params:
     *   name = 模块名
     */
    this(string name)
    {
        moduleName = name;
    }
}

/**
 * PLVM 主类
 *
 * 提供脚本引擎的主要功能接口。
 *
 * Examples:
 * ---
 * import plvm;
 *
 * void main()
 * {
 *     Plvm vm = new Plvm();
 *     vm.registerFunction("hostAdd", &myAdd);
 *     Value result = vm.callOnce("int main() { return hostAdd(1, 2); }");
 *     writeln(result.asInteger()); // 输出: 3
 * }
 * ---
 */
class Plvm
{
private:
    VirtualMachine vm;              /// 虚拟机实例
    HostApi hostApi;                /// 宿主 API
    BytecodeProgram currentProgram; /// 当前程序

    size_t maxSteps = 10_000_000;   /// 最大步数
    size_t maxMemory = 1024 * 1024; /// 最大内存

    /// 宿主函数条目
    struct HostFuncEntry
    {
        string name;        /// 函数名
        HostFunction func;  /// 函数委托
    }
    HostFuncEntry[] hostFuncEntries;  /// 宿主函数条目列表

    bool compilePhase = true;  /// 是否在编译阶段

    BytecodeProgram compileModule(string source)
    {
        string[] structNames = hostApi.getStructNames();
        auto enumMems = hostApi.getEnumMembers();
        string[] enumNameList;
        foreach (k, v; enumMems)
            enumNameList ~= k;

        auto funcIndices = hostApi.getFuncIndices();
        auto hostIndices = hostApi.getHostIndices();
        auto enumVals = hostApi.getEnumValues();

        currentProgram = Compiler.compileSource(source,
            structNames, enumMems,
            hostApi.getFuncIndices().values,
            hostApi.getHostIndices().values,
            enumVals, funcIndices, hostIndices);

        return currentProgram;
    }

public:
    /**
     * 构造 PLVM 实例
     */
    this()
    {
        vm = new VirtualMachine();
        vm.setMaxSteps(maxSteps);
        hostApi = new HostApi();
    }

    /**
     * 注册宿主函数
     *
     * 将 D 函数注册为脚本可调用的宿主函数。
     *
     * Params:
     *   Func = 函数别名
     *   name = 函数名（可选，默认为函数原名）
     */
    void registerFunction(alias Func)(string name = null)
    {
        hostApi.registerHostFunction!Func(name);

        string funcName = name.length > 0 ? name : __traits(identifier, Func);
        auto wrapper = createHostFunctionWrapper!(Func)();
        hostFuncEntries ~= HostFuncEntry(funcName, wrapper);
    }

    /**
     * 注册结构体类型
     *
     * 将 D 结构体类型注册到脚本引擎。
     *
     * Params:
     *   T = 结构体类型
     *   name = 类型名（可选）
     */
    void registerStruct(T)(string name = null)
    {
        hostApi.registerStructType!T(name);
    }

    /**
     * 注册枚举类型
     *
     * 将 D 枚举类型注册到脚本引擎。
     *
     * Params:
     *   T = 枚举类型
     *   name = 类型名（可选）
     */
    void registerEnum(T)(string name = null)
    {
        hostApi.registerEnumType!T(name);
    }

    /**
     * 注册常量
     *
     * Params:
     *   name = 常量名
     *   value = 常量值
     */
    void registerConstant(string name, long value)
    {
    }

    void setSandbox(size_t maxSteps_, size_t maxMem = 0)
    {
        maxSteps = maxSteps_;
        maxMemory = maxMem;
        vm.setMaxSteps(maxSteps_);
    }

    /**
     * 一次性执行脚本（带参数）
     *
     * 编译并执行脚本，返回结果。
     *
     * Params:
     *   source = 脚本源码
     *   funcName = 要调用的函数名
     *   args = 函数参数
     *
     * Returns: 函数返回值
     */
    Value callOnce(Args...)(string source, string funcName, Args args)
    {
        try
        {
            auto program = compileModule(source);
            auto handle = new ModHandle("<script>");
            handle.program = program;
            handle.entryPoint = 0;

            foreach (ref f; program.functions)
            {
                if (f.name == funcName)
                {
                    handle.entryPoint = f.entryPoint;
                    break;
                }
            }

            if (handle.entryPoint == 0 && program.functions.length > 0)
            {
                handle.entryPoint = program.functions[0].entryPoint;
            }

            Value[] valueArgs;
            static if (Args.length > 0)
            {
                valueArgs.reserve(Args.length);
                foreach (i, arg; args)
                {
                    valueArgs ~= valueFromD(arg);
                }
            }

            return executeModuleWithArgs(handle, handle.entryPoint, valueArgs);
        }
        catch (Exception e)
        {
            throw new PlvmRuntimeException(e.msg);
        }
    }

    /**
     * 一次性执行脚本
     *
     * 编译并执行脚本，返回结果。
     *
     * Params:
     *   source = 脚本源码
     *   funcName = 要调用的函数名
     *
     * Returns: 函数返回值
     */
    Value callOnce(string source, string funcName)
    {
        try
        {
            auto program = compileModule(source);
            auto handle = new ModHandle("<script>");
            handle.program = program;
            handle.entryPoint = 0;

            foreach (ref f; program.functions)
            {
                if (f.name == funcName)
                {
                    handle.entryPoint = f.entryPoint;
                    break;
                }
            }

            if (handle.entryPoint == 0 && program.functions.length > 0)
            {
                handle.entryPoint = program.functions[0].entryPoint;
            }

            vm.loadProgram(handle.program);
            foreach (i, entry; hostFuncEntries)
                vm.registerHostFunction(i, entry.func);
            return vm.execute(handle.entryPoint);
        }
        catch (Exception e)
        {
            throw new PlvmRuntimeException(e.msg);
        }
    }

    /**
     * 加载脚本
     *
     * 编译脚本并返回模块句柄。
     *
     * Params:
     *   source = 脚本源码
     *   moduleName = 模块名（可选）
     *
     * Returns: 模块句柄
     */
    ModHandle loadScript(string source, string moduleName = "<script>")
    {
        try
        {
            auto program = compileModule(source);
            auto handle = new ModHandle(moduleName);
            handle.program = program;

            foreach (ref f; program.functions)
            {
                if (f.name == "main" || f.name == "__anon_main__")
                {
                    handle.entryPoint = f.entryPoint;
                    break;
                }
            }
            if (handle.entryPoint == 0 && program.functions.length > 0)
                handle.entryPoint = program.functions[0].entryPoint;

            return handle;
        }
        catch (Exception e)
        {
            throw new PlvmCompileException(e.msg);
        }
    }

    /**
     * 调用模块中的函数
     *
     * Params:
     *   handle = 模块句柄
     *   funcName = 函数名
     *   args = 函数参数
     *
     * Returns: 函数返回值
     */
    Value callFunction(Args...)(ModHandle handle, string funcName, Args args)
    {
        try
        {
            size_t entry = 0;
            foreach (ref f; handle.program.functions)
            {
                if (f.name == funcName)
                {
                    entry = f.entryPoint;
                    break;
                }
            }

            Value[] valueArgs;
            static if (Args.length > 0)
            {
                valueArgs.reserve(Args.length);
                foreach (i, arg; args)
                {
                    valueArgs ~= valueFromD(arg);
                }
            }

            return executeModuleWithArgs(handle, entry, valueArgs);
        }
        catch (Exception e)
        {
            throw new PlvmRuntimeException(e.msg);
        }
    }

    /**
     * 卸载脚本
     *
     * Params:
     *   handle = 模块句柄
     */
    void unloadScript(ModHandle handle)
    {
    }

    /**
     * 反汇编最后一个程序
     *
     * Returns: 反汇编字符串
     */
    string disassembleLast() const
    {
        return currentProgram.disassemble();
    }

    /**
     * 执行模块
     *
     * 使用模块的入口点执行程序。
     *
     * Params:
     *   handle = 模块句柄
     *
     * Returns: 执行结果
     */
    Value executeModule(ModHandle handle)
    {
        vm.loadProgram(handle.program);

        foreach (i, entry; hostFuncEntries)
        {
            vm.registerHostFunction(i, entry.func);
        }

        return vm.execute(handle.entryPoint);
    }

    /**
     * 执行模块指定入口点
     *
     * 使用指定的入口点执行程序。
     *
     * Params:
     *   handle = 模块句柄
     *   entry = 入口点
     *
     * Returns: 执行结果
     */
    Value executeModuleWithEntry(ModHandle handle, size_t entry)
    {
        vm.loadProgram(handle.program);

        foreach (i, entry_; hostFuncEntries)
        {
            vm.registerHostFunction(i, entry_.func);
        }

        return vm.execute(entry);
    }

    /**
     * 带参数执行模块指定入口点
     *
     * 使用指定的入口点和参数执行程序。
     *
     * Params:
     *   handle = 模块句柄
     *   entry = 入口点
     *   args = 参数值数组
     *
     * Returns: 执行结果
     */
    Value executeModuleWithArgs(ModHandle handle, size_t entry, Value[] args)
    {
        vm.loadProgram(handle.program);

        foreach (i, entry_; hostFuncEntries)
        {
            vm.registerHostFunction(i, entry_.func);
        }

        return vm.executeWithArgs(entry, args);
    }
}
