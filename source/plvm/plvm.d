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

class PlvmException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

class PlvmCompileException : PlvmException
{
    this(string msg)
    {
        super(msg);
    }
}

class PlvmRuntimeException : PlvmException
{
    this(string msg)
    {
        super(msg);
    }
}

class ModHandle
{
    string moduleName;
    BytecodeProgram program;
    size_t entryPoint;

    this(string name)
    {
        moduleName = name;
    }
}

class Plvm
{
private:
    VirtualMachine vm;
    HostApi hostApi;
    BytecodeProgram currentProgram;

    size_t maxSteps = 10_000_000;
    size_t maxMemory = 1024 * 1024;

    struct HostFuncEntry
    {
        string name;
        HostFunction func;
    }
    HostFuncEntry[] hostFuncEntries;

    bool compilePhase = true;

public:
    this()
    {
        vm = new VirtualMachine();
        vm.setMaxSteps(maxSteps);
        hostApi = new HostApi();
    }

    void registerFunction(alias Func)(string name = null)
    {
        hostApi.registerHostFunction!Func(name);

        string funcName = name.length > 0 ? name : __traits(identifier, Func);
        auto wrapper = createHostFunctionWrapper!(Func)();
        hostFuncEntries ~= HostFuncEntry(funcName, wrapper);
    }

    void registerStruct(T)(string name = null)
    {
        hostApi.registerStructType!T(name);
    }

    void registerEnum(T)(string name = null)
    {
        hostApi.registerEnumType!T(name);
    }

    void registerConstant(string name, long value)
    {
    }

    void setSandbox(size_t maxSteps_, size_t maxMem = 0)
    {
        maxSteps = maxSteps_;
        maxMemory = maxMem;
        vm.setMaxSteps(maxSteps_);
    }

    Value callOnce(string source, string funcName, Args...)(Args args)
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

            return executeModule(handle, args);
        }
        catch (Exception e)
        {
            throw new PlvmRuntimeException(e.msg);
        }
    }

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

            return executeModuleWithEntry(handle, entry, args);
        }
        catch (Exception e)
        {
            throw new PlvmRuntimeException(e.msg);
        }
    }

    void unloadScript(ModHandle handle)
    {
    }

    string disassembleLast() const
    {
        return currentProgram.disassemble();
    }

private:
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

    Value executeModule(ModHandle handle, types...)(types args)
    {
        vm.loadProgram(handle.program);

        foreach (i, entry; hostFuncEntries)
        {
            vm.registerHostFunction(i, entry.func);
        }

        return vm.execute(handle.entryPoint);
    }

    Value executeModuleWithEntry(ModHandle handle, size_t entry, types...)(types args)
    {
        vm.loadProgram(handle.program);

        foreach (i, entry_; hostFuncEntries)
        {
            vm.registerHostFunction(i, entry_.func);
        }

        return vm.execute(entry);
    }
}
