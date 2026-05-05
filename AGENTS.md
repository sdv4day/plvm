# AGENTS.md

## Build and test commands

- Run `dub build --compiler=ldc2` after any code change.
- Run `dub test --compiler=ldc2` before finishing.
- Run `dub run -c test_app` to run the test application.
- If `dub` is not found, the environment setup is broken and must be fixed.

## Standard library usage

- **优先使用标准库**：编程过程中充分使用 D 语言标准库中的内置功能。
- **避免自行包装**：优先使用标准库中的内置模板或函数，避免不必要的自行包装。
- **常用标准库模块**：
  - `std.traits`：类型特征和元编程（如 `isNumeric!T`、`FieldTypeTuple!T` 等）
  - `std.sumtype`：和类型实现，用于类型安全的联合类型
  - `std.typecons`：类型构造器（如 `Nullable!T`、`RefCounted!T` 等）
  - `std.variant`：变体类型，用于动态类型值存储
  - `std.algorithm`：算法和范围操作
  - `std.container`：容器类型
  - `std.range`：范围和迭代器
  - `std.conv`：类型转换
  - `std.format`：格式化输出

## Implementation guidelines

- 使用 `std.traits` 提供的类型特征模板，而不是自己实现类型检查
- 使用 `std.sumtype` 实现类型安全的联合类型，而不是自定义枚举或标签联合
- 使用 `std.variant` 存储动态类型值，而不是自己实现变体类型
- 使用 `std.typecons` 提供的类型构造器，如 `Nullable!T` 表示可选值
- 使用标准库的算法和容器，而不是自己实现数据结构和算法
- 在实现前，先检查标准库是否已经提供了所需功能
