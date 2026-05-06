/**
 * PLVM 虚拟机模块
 *
 * 本模块实现 PLVM 的字节码虚拟机，包括：
 * - 指令执行
 * - 函数调用
 * - 栈管理
 * - 宿主函数调用
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm.vm;

import plvm.value;
import plvm.bytecode;
import plvm.compiler;
import std.exception : enforce;
import std.conv : text, to;

/**
 * 虚拟机状态枚举
 */
enum VMStatus : ubyte
{
    ok,       /// 正常运行
    halted,   /// 已停止
    error_    /// 错误
}

/**
 * 虚拟机异常类
 *
 * 表示虚拟机执行过程中的错误。
 */
class VMException : Exception
{
    size_t line;  /// 错误行号

    /**
     * 构造虚拟机异常
     *
     * Params:
     *   msg = 错误消息
     *   ln = 行号
     */
    this(string msg, size_t ln = 0)
    {
        super(msg);
        line = ln;
    }
}

/**
 * 调用帧结构
 *
 * 存储函数调用的上下文信息。
 */
struct CallFrame
{
    size_t returnAddress;   /// 返回地址
    size_t bp;              /// 基址指针
    size_t spStart;         /// 栈指针起始位置
    size_t numLocals;       /// 局部变量数量
    string functionName;    /// 函数名
}

/// 宿主函数类型别名
alias HostFunction = Value delegate(Value[] args);

/**
 * 虚拟机类
 *
 * 执行字节码程序的核心引擎。
 */
class VirtualMachine
{
private:
    Value[] stack;               /// 数据栈
    size_t sp;                   /// 栈指针
    CallFrame[] callStack;       /// 调用栈
    BytecodeProgram program;     /// 字节码程序
    size_t ip;                   /// 指令指针
    bool halted;                 /// 是否已停止
    VMStatus status;             /// 虚拟机状态
    string lastError;            /// 最后的错误消息

    Value[string] globals;       /// 全局变量
    Value[] locals;              /// 局部变量

    HostFunction[size_t] hostFunctions;  /// 宿主函数映射
    size_t maxSteps = 10_000_000;        /// 最大步数限制
    size_t stepCount;                    /// 当前步数

    /// foreach 状态结构
    struct ForeachState
    {
        size_t arrayIndex;  /// 数组索引
        Value arrayVal;     /// 数组值
    }
    ForeachState[] foreachStack;  /// foreach 状态栈

    Value returnValue;  /// 返回值

public:
    /**
     * 构造虚拟机
     */
    this()
    {
        stack.length = 65536;
        sp = 0;
        ip = 0;
        halted = false;
        status = VMStatus.ok;
    }

    /**
     * 加载字节码程序
     *
     * Params:
     *   prog = 字节码程序
     */
    void loadProgram(BytecodeProgram prog)
    {
        program = prog;
        ip = 0;
        halted = false;
        status = VMStatus.ok;
        stack[] = Value.init;
        sp = 0;
        locals = [];
        callStack = [];
        foreachStack = [];
        stepCount = 0;
    }

    /**
     * 注册宿主函数
     *
     * Params:
     *   index = 函数索引
     *   func = 宿主函数委托
     */
    void registerHostFunction(size_t index, HostFunction func)
    {
        hostFunctions[index] = func;
    }

    /**
     * 设置最大执行步数
     *
     * Params:
     *   steps = 最大步数
     */
    void setMaxSteps(size_t steps)
    {
        maxSteps = steps;
    }

    /**
     * 执行字节码程序
     *
     * Returns: 程序返回值
     */
    Value execute()
    {
        return execute(0);
    }

    Value execute(size_t entryPoint)
    {
        ip = entryPoint;
        halted = false;
        status = VMStatus.ok;
        returnValue = Value.makeNull();

        if (callStack.length == 0)
        {
            size_t numLocals = 0;
            foreach (ref f; program.functions)
            {
                if (f.entryPoint == entryPoint)
                {
                    numLocals = f.numLocals;
                    break;
                }
            }

            locals.length = numLocals;

            CallFrame frame;
            frame.returnAddress = 0;
            frame.bp = 0;
            frame.spStart = sp;
            frame.numLocals = numLocals;
            frame.functionName = "<entry>";
            callStack ~= frame;
        }

        while (!halted && status == VMStatus.ok && ip < program.instructions.length)
        {
            stepCount++;
            if (stepCount > maxSteps)
            {
                errorOut("执行步数超过限制");
                break;
            }

            auto instr = program.instructions[ip];
            ip++;

            try
            {
                executeInstruction(instr);
            }
            catch (Exception e)
            {
                errorOut(text("运行时错误 (行 ", instr.line, "): ", e.msg));
            }
        }

        if (status == VMStatus.error_)
            throw new VMException(lastError);

        if (stack.length > 0 && sp > 0)
            returnValue = stack[sp - 1];

        return returnValue;
    }

    /**
     * 带参数执行函数
     *
     * Params:
     *   entryPoint = 入口点
     *   args = 参数值数组
     *
     * Returns: 函数返回值
     */
    Value executeWithArgs(size_t entryPoint, Value[] args)
    {
        ip = entryPoint;
        halted = false;
        status = VMStatus.ok;
        returnValue = Value.makeNull();

        size_t numLocals = 0;
        size_t numParams = 0;
        foreach (ref f; program.functions)
        {
            if (f.entryPoint == entryPoint)
            {
                numLocals = f.numLocals;
                numParams = f.numParams;
                break;
            }
        }

        locals.length = numLocals;

        for (size_t i = 0; i < args.length && i < numParams; i++)
        {
            locals[i] = args[i];
        }

        CallFrame frame;
        frame.returnAddress = 0;
        frame.bp = 0;
        frame.spStart = sp;
        frame.numLocals = numLocals;
        frame.functionName = "<entry>";
        callStack ~= frame;

        while (!halted && status == VMStatus.ok && ip < program.instructions.length)
        {
            stepCount++;
            if (stepCount > maxSteps)
            {
                errorOut("执行步数超过限制");
                break;
            }

            auto instr = program.instructions[ip];
            ip++;

            try
            {
                executeInstruction(instr);
            }
            catch (Exception e)
            {
                errorOut(text("运行时错误 (行 ", instr.line, "): ", e.msg));
            }
        }

        if (status == VMStatus.error_)
            throw new VMException(lastError);

        if (stack.length > 0 && sp > 0)
            returnValue = stack[sp - 1];

        return returnValue;
    }

    void executeInstruction(ref Instruction instr)
    {
        final switch (instr.opcode)
        {
            case OpCode.NOP: break;

            case OpCode.PUSH:
            {
                auto c = program.constants[cast(size_t)instr.arg1];
                final switch (c.type)
                {
                    case ConstantType.ctInteger:
                        push(Value.makeLong(c.integerValue));
                        break;
                    case ConstantType.ctString:
                        push(Value.makeString(c.stringValue));
                        break;
                    case ConstantType.ctIdentifier:
                        push(Value.makeString(c.stringValue));
                        break;
                }
                break;
            }

            case OpCode.POP:
                if (sp > 0) sp--;
                break;

            case OpCode.DUP:
                if (sp > 0)
                {
                    push(stack[sp - 1]);
                }
                break;

            case OpCode.LOAD_LOCAL:
            {
                size_t slot = cast(size_t)instr.arg1;
                auto frame = &callStack[$ - 1];
                push(locals[frame.bp + slot]);
                break;
            }

            case OpCode.STORE_LOCAL:
            {
                size_t slot = cast(size_t)instr.arg1;
                auto frame = &callStack[$ - 1];
                auto val = pop_();
                locals[frame.bp + slot] = val;
                break;
            }

            case OpCode.LOAD_GLOBAL:
            {
                auto c = program.constants[cast(size_t)instr.arg1];
                auto ptr = c.stringValue in globals;
                if (ptr)
                    push(*ptr);
                else
                    push(Value.makeNull());
                break;
            }

            case OpCode.STORE_GLOBAL:
            {
                auto c = program.constants[cast(size_t)instr.arg1];
                auto val = pop_();
                globals[c.stringValue] = val;
                break;
            }

            case OpCode.ADD:
            {
                auto b = pop_();
                auto a = pop_();
                push(binaryArith(a, b, "+"));
                break;
            }
            case OpCode.SUB:
            {
                auto b = pop_();
                auto a = pop_();
                push(binaryArith(a, b, "-"));
                break;
            }
            case OpCode.MUL:
            {
                auto b = pop_();
                auto a = pop_();
                push(binaryArith(a, b, "*"));
                break;
            }
            case OpCode.DIV:
            {
                auto b = pop_();
                auto a = pop_();
                push(binaryArith(a, b, "/"));
                break;
            }
            case OpCode.MOD:
            {
                auto b = pop_();
                auto a = pop_();
                push(binaryArith(a, b, "%"));
                break;
            }

            case OpCode.EQ:
            {
                auto b = pop_();
                auto a = pop_();
                push(compare(a, b, "=="));
                break;
            }
            case OpCode.NEQ:
            {
                auto b = pop_();
                auto a = pop_();
                push(compare(a, b, "!="));
                break;
            }
            case OpCode.LT:
            {
                auto b = pop_();
                auto a = pop_();
                push(compare(a, b, "<"));
                break;
            }
            case OpCode.LTE:
            {
                auto b = pop_();
                auto a = pop_();
                push(compare(a, b, "<="));
                break;
            }
            case OpCode.GT:
            {
                auto b = pop_();
                auto a = pop_();
                push(compare(a, b, ">"));
                break;
            }
            case OpCode.GTE:
            {
                auto b = pop_();
                auto a = pop_();
                push(compare(a, b, ">="));
                break;
            }

            case OpCode.AND_OP:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeBool(a.isTruthy() && b.isTruthy()));
                break;
            }
            case OpCode.OR_OP:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeBool(a.isTruthy() || b.isTruthy()));
                break;
            }
            case OpCode.NOT:
            {
                auto a = pop_();
                push(Value.makeBool(!a.isTruthy()));
                break;
            }

            case OpCode.NEG:
            {
                auto a = pop_();
                push(Value.makeLong(-a.asInteger()));
                break;
            }
            case OpCode.BIT_NOT:
            {
                auto a = pop_();
                push(Value.makeLong(~a.asInteger()));
                break;
            }
            case OpCode.BIT_AND:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeLong(a.asInteger() & b.asInteger()));
                break;
            }
            case OpCode.BIT_OR:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeLong(a.asInteger() | b.asInteger()));
                break;
            }
            case OpCode.BIT_XOR:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeLong(a.asInteger() ^ b.asInteger()));
                break;
            }
            case OpCode.SHL:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeLong(a.asInteger() << b.asInteger()));
                break;
            }
            case OpCode.SHR:
            {
                auto b = pop_();
                auto a = pop_();
                push(Value.makeLong(a.asInteger() >> b.asInteger()));
                break;
            }

            case OpCode.JMP:
                ip = cast(size_t)instr.arg1;
                break;
            case OpCode.JZ:
            {
                auto val = pop_();
                if (!val.isTruthy())
                    ip = cast(size_t)instr.arg1;
                break;
            }
            case OpCode.JNZ:
            {
                auto val = pop_();
                if (val.isTruthy())
                    ip = cast(size_t)instr.arg1;
                break;
            }

            case OpCode.CALL:
            {
                callUserFunction(cast(size_t)instr.arg1);
                break;
            }
            case OpCode.CALL_HOST:
            {
                callHostFunction(cast(size_t)instr.arg1, cast(size_t)instr.arg2);
                break;
            }
            case OpCode.RET:
            {
                if (callStack.length <= 1)
                {
                    halted = true;
                }
                else
                {
                    auto frame = callStack[$ - 1];
                    size_t retAddr = frame.returnAddress;
                    callStack = callStack[0 .. $ - 1];
                    ip = retAddr;
                }
                break;
            }
            case OpCode.HALT:
                if (callStack.length <= 1)
                {
                    halted = true;
                }
                else
                {
                    auto frame = callStack[$ - 1];
                    size_t retAddr = frame.returnAddress;
                    callStack = callStack[0 .. $ - 1];
                    ip = retAddr;
                }
                break;

            case OpCode.ARRAY_NEW:
            {
                push(Value.makeArray(new Value[0]));
                break;
            }
            case OpCode.ARRAY_GET:
            {
                auto idx = pop_();
                auto arr = pop_();
                auto arrVal = arr.arrayValue;
                size_t index = cast(size_t)idx.asInteger();
                if (index < arrVal.length)
                    push(arrVal[index]);
                else
                {
                    errorOut("数组索引越界");
                }
                break;
            }
            case OpCode.ARRAY_SET:
            {
                auto val = pop_();
                auto idx = pop_();
                auto arr = pop_();
                size_t index = cast(size_t)idx.asInteger();
                auto arrVal = arr.arrayValue;
                if (index < arrVal.length)
                {
                    arrVal[index] = val;
                    arr.arrayValue = arrVal;
                }
                else
                {
                    errorOut("数组索引越界");
                }
                break;
            }
            case OpCode.ARRAY_APPEND:
            {
                auto val = pop_();
                auto arr = pop_();
                auto arrVal = arr.arrayValue;
                arrVal ~= val;
                arr.arrayValue = arrVal;
                push(arr);
                break;
            }
            case OpCode.ARRAY_LEN:
            {
                auto arr = pop_();
                push(Value.makeLong(arr.arrayValue.length));
                break;
            }
            case OpCode.ARRAY_SLICE:
            {
                auto endVal = pop_();
                auto startVal = pop_();
                auto arr = pop_();
                size_t start = cast(size_t)startVal.asInteger();
                size_t end = cast(size_t)endVal.asInteger();
                auto arrVal = arr.arrayValue;
                if (start <= end && end <= arrVal.length)
                    push(Value.makeArray(arrVal[start .. end]));
                else
                    errorOut("切片索引越界");
                break;
            }

            case OpCode.STRUCT_NEW:
            {
                push(Value.makeStruct("anon", (Value[string]).init));
                break;
            }
            case OpCode.STRUCT_GET:
            {
                string fieldName = program.structFieldNames[cast(size_t)instr.arg1];
                auto sv = pop_();
                auto s = sv.asStruct();
                if (s && fieldName in s.fields)
                {
                    push(s.fields[fieldName]);
                }
                else
                {
                    errorOut(text("结构体字段不存在: ", fieldName));
                }
                break;
            }
            case OpCode.STRUCT_SET:
            {
                string fieldName = program.structFieldNames[cast(size_t)instr.arg1];
                auto val = pop_();
                auto sv = pop_();
                auto s = sv.asStruct();
                if (s)
                {
                    s.fields[fieldName] = val;
                }
                else
                {
                    errorOut(text("无法设置字段: ", fieldName));
                }
                break;
            }
            case OpCode.PROP_GET:
            {
                auto sv = stack[sp - 1];
                break;
            }

            case OpCode.FOREACH_BEGIN:
            {
                auto arr = pop_();
                ForeachState fs;
                fs.arrayIndex = 0;
                fs.arrayVal = arr;
                foreachStack ~= fs;
                break;
            }
            case OpCode.FOREACH_NEXT:
            {
                auto fs = &foreachStack[$ - 1];
                if (fs.arrayIndex < fs.arrayVal.arrayValue.length)
                {
                    push(fs.arrayVal.arrayValue[fs.arrayIndex]);
                    size_t slot = cast(size_t)instr.arg1;
                    auto frame = &callStack[$ - 1];
                    locals[frame.bp + slot] = fs.arrayVal.arrayValue[fs.arrayIndex];
                    fs.arrayIndex++;
                }
                else
                {
                    ip = program.instructions.length;
                }
                break;
            }
            case OpCode.FOREACH_END:
            {
                if (foreachStack.length > 0)
                    foreachStack = foreachStack[0 .. $ - 1];
                break;
            }

            case OpCode.CAST_TO_LONG:
            {
                auto val = pop_();
                push(Value.makeLong(val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_INT:
            {
                auto val = pop_();
                push(Value.makeInt(cast(int)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_SHORT:
            {
                auto val = pop_();
                push(Value.makeShort(cast(short)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_BYTE:
            {
                auto val = pop_();
                push(Value.makeByte(cast(byte)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_ULONG:
            {
                auto val = pop_();
                push(Value.makeUlong(cast(ulong)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_UINT:
            {
                auto val = pop_();
                push(Value.makeUint(cast(uint)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_USHORT:
            {
                auto val = pop_();
                push(Value.makeUshort(cast(ushort)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_UBYTE:
            {
                auto val = pop_();
                push(Value.makeUbyte(cast(ubyte)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_CHAR:
            {
                auto val = pop_();
                push(Value.makeChar(cast(char)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_WCHAR:
            {
                auto val = pop_();
                push(Value.makeWchar(cast(wchar)val.asInteger()));
                break;
            }
            case OpCode.CAST_TO_DCHAR:
            {
                auto val = pop_();
                push(Value.makeDchar(cast(dchar)val.asInteger()));
                break;
            }
            case OpCode.CAST_GENERIC:
            {
                handleGenericCast(cast(long)instr.arg1);
                break;
            }
        }
    }

    void callUserFunction(size_t funcNameIdx)
    {
        auto c = program.constants[funcNameIdx];
        string funcName = c.stringValue;

        FunctionInfo* funcInfo = null;
        foreach (ref f; program.functions)
        {
            if (f.name == funcName)
            {
                funcInfo = &f;
                break;
            }
        }

        if (funcInfo is null)
        {
            errorOut(text("未找到函数: ", funcName));
            return;
        }

        size_t bp = locals.length;
        locals.length = bp + funcInfo.numLocals;

        for (ptrdiff_t i = funcInfo.numParams - 1; i >= 0; i--)
        {
            auto arg = pop_();
            locals[bp + i] = arg;
        }

        CallFrame frame;
        frame.returnAddress = ip;
        frame.bp = bp;
        frame.spStart = sp;
        frame.numLocals = funcInfo.numLocals;
        frame.functionName = funcInfo.name;
        callStack ~= frame;

        ip = funcInfo.entryPoint;
    }

    void callHostFunction(size_t hostIdx, size_t numArgs)
    {
        if (auto pfunc = hostIdx in hostFunctions)
        {
            Value[] args;
            for (size_t i = 0; i < numArgs; i++)
            {
                args = pop_() ~ args;
            }

            auto result = (*pfunc)(args);
            push(result);
        }
        else
        {
            errorOut(text("未注册的主机函数: ", hostIdx));
        }
    }

    void handleGenericCast(long targetTypeId)
    {
        auto val = pop_();

        switch (targetTypeId)
        {
            case 0: push(Value.makeNull()); break;
            case 1: push(Value.makeBool(val.asInteger() != 0)); break;
            case 2: push(Value.makeByte(cast(byte)val.asInteger())); break;
            case 3: push(Value.makeUbyte(cast(ubyte)val.asInteger())); break;
            case 4: push(Value.makeShort(cast(short)val.asInteger())); break;
            case 5: push(Value.makeUshort(cast(ushort)val.asInteger())); break;
            case 6: push(Value.makeInt(cast(int)val.asInteger())); break;
            case 7: push(Value.makeUint(cast(uint)val.asInteger())); break;
            case 8: push(Value.makeLong(val.asInteger())); break;
            case 9: push(Value.makeUlong(cast(ulong)val.asInteger())); break;
            case 10: push(Value.makeChar(cast(char)val.asInteger())); break;
            case 11: push(Value.makeWchar(cast(wchar)val.asInteger())); break;
            case 12: push(Value.makeDchar(cast(dchar)val.asInteger())); break;
            case 13: push(Value.makeString(val.toString())); break;
            default: push(val); break;
        }
    }

    void push(Value v)
    {
        if (sp >= stack.length)
        {
            errorOut("栈溢出");
            return;
        }
        stack[sp] = v;
        sp++;
    }

    Value pop_()
    {
        if (sp == 0)
        {
            errorOut("栈下溢");
            return Value.makeNull();
        }
        sp--;
        return stack[sp];
    }

    Value binaryArith(Value a, Value b, string op)
    {
        if (a.type == PValueType.vtString || b.type == PValueType.vtString)
        {
            if (op == "+")
                return Value.makeString(a.toString() ~ b.toString());
            throw new VMException(text("不支持字符串的 '", op, "' 操作"));
        }

        long ai = a.asInteger();
        long bi = b.asInteger();

        switch (op)
        {
            case "+": return Value.makeLong(ai + bi);
            case "-": return Value.makeLong(ai - bi);
            case "*": return Value.makeLong(ai * bi);
            case "/":
                if (bi == 0) throw new VMException("除零错误");
                return Value.makeLong(ai / bi);
            case "%":
                if (bi == 0) throw new VMException("除零错误");
                return Value.makeLong(ai % bi);
            default: return Value.makeLong(0);
        }
    }

    Value compare(Value a, Value b, string op)
    {
        long ai = a.asInteger();
        long bi = b.asInteger();

        bool result;
        switch (op)
        {
            case "==": result = (ai == bi); break;
            case "!=": result = (ai != bi); break;
            case "<": result = (ai < bi); break;
            case "<=": result = (ai <= bi); break;
            case ">": result = (ai > bi); break;
            case ">=": result = (ai >= bi); break;
            default: result = false; break;
        }

        return Value.makeBool(result);
    }

    void errorOut(string msg)
    {
        status = VMStatus.error_;
        lastError = msg;
    }

    VMStatus getStatus() const
    {
        return status;
    }

    string getLastError() const
    {
        return lastError;
    }
}
