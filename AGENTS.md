# 开发约定（AGENTS）

本文件是**协作约定**，不是设计文档。设计与数值的唯一权威是 `GDD.md`。

## 铁律

1. **GDD 是唯一权威。** 任何与 `GDD.md` 冲突的实现都是 bug，改代码而不改 GDD 是禁止的。
2. **不得擅自做设计决策。** 遇到 GDD 未定义之处，一律按 `GDD.md` 第二十章 20.7 的待补清单处理：
   - 不自行拍定数值或规则；
   - 在代码中以 `// TODO(gdd-20.7 #<编号>): <缺口描述>` 标注；
   - 由项目所有者裁决后，先回填 GDD，再改代码。
3. **GDD 先行。** 实现某个系统前，该系统的 GDD 条目必须已经明确；否则先补 GDD。
4. **改动 GDD 需经所有者同意**，并在「修订说明」中登记条目。

## 当前里程碑状态

见 `GDD.md` 第十八章。已完成部分在 `README.md` 的「里程碑状态」中同步。

## 代码约定

- C++17，禁用编译器扩展（`CMAKE_CXX_EXTENSIONS OFF`）。
- 只支持小端主机，由 `cmake/endian_check.cmake` 在配置期强制。
- 源文件 UTF-8，**默认 ASCII**：UI 文案一律走 `data/i18n/`（GDD 15.1），禁止把中文硬编码进代码。
- 网络与存档相关代码在 M3 之后才出现；`packed POD + memcpy` 的合法性依赖小端断言。
- 随机数一律使用 `src/core/rng.h` 的地址化派生；**禁止**在世界逻辑中使用有状态随机流。
- 每个源文件带 SPDX 头：
  ```cpp
  // Copyright (C) 2026 Wasteland Glyph contributors
  // SPDX-License-Identifier: GPL-3.0-or-later
  ```

## 测试

- 新增世界逻辑必须补 `tests/` 下的确定性测试（同种子同结果）。
- 提交前本地必须通过：构建 + `ctest`。

## 提交信息

```
<scope>: <imperative summary>

Refs: GDD <章节号>
```

`scope` 取值示例：`core`、`world`、`game`、`net`、`data`、`build`、`docs`、`test`。
