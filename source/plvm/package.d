/**
 * PLVM - Portable Lightweight Virtual Machine
 *
 * PLVM 是一个轻量级、可嵌入的 D 语言语法脚本引擎。
 *
 * 本模块是 PLVM 库的主入口点，公开导入所有公共模块。
 *
 * ## 主要组件
 *
 * - $(LREF value) - 值类型系统
 * - $(LREF bytecode) - 字节码定义
 * - $(LREF token) - 词法单元定义
 * - $(LREF lexer) - 词法分析器
 * - $(LREF ast) - 抽象语法树
 * - $(LREF parser) - 语法分析器
 * - $(LREF compiler) - 字节码编译器
 * - $(LREF vm) - 虚拟机
 * - $(LREF host_api) - 宿主 API
 * - $(LREF plvm) - 主接口类
 *
 * ## 快速开始
 *
 * ```d
 * import plvm;
 *
 * void main()
 * {
 *     // 创建 PLVM 实例
 *     Plvm vm = new Plvm();
 *
 *     // 注册宿主函数
 *     vm.registerFunction("hostAdd", &myAddFunction);
 *
 *     // 执行脚本
 *     string script = `
 *         int main()
 *         {
 *             return hostAdd(10, 20);
 *         }
 *     `;
 *
 *     Value result = vm.callOnce(script);
 *     writeln("Result: ", result.asInteger());
 * }
 * ```
 *
 * Copyright: Copyright (c) 2024, PLVM Authors
 * License: MIT
 * Authors: PLVM Team
 */
module plvm;

public import plvm.value;       /// 值类型系统
public import plvm.bytecode;    /// 字节码定义
public import plvm.token;       /// 词法单元定义
public import plvm.lexer;       /// 词法分析器
public import plvm.ast;         /// 抽象语法树
public import plvm.parser;      /// 语法分析器
public import plvm.compiler;    /// 字节码编译器
public import plvm.vm;          /// 虚拟机
public import plvm.host_api;    /// 宿主 API
public import plvm.plvm;        /// 主接口类
