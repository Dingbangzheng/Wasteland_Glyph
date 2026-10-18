# Wasteland Glyph / 废土字符

纯终端、跨平台（Linux / Windows）、支持局域网联机的**实时制后末日生存 Roguelike**。
世界由种子唯一确定；无合作模式，所有玩家互为潜在威胁。

设计与数值的**唯一权威**是 [`GDD.md`](GDD.md)。本文件只说明如何构建与当前进度。

- 协议：GPL-3.0-or-later（整包；`data/` 全原创）
- 语言标准：C++17（禁用编译器扩展）
- 终端：PDCursesMod `PDC_WIDE`（Windows）/ ncursesw（Linux）
- 主机字节序：仅小端（配置期强制断言）

---

## 依赖

| 依赖 | 版本 | 获取方式 |
|---|---|---|
| PDCursesMod | **v4.5.4**（tag 锁版） | CMake `FetchContent` 自动拉取（Windows） |
| ncursesw | 系统包 | `libncursesw5-dev` / `ncurses-devel`（Linux） |
| CMake | ≥ 3.16 | 系统包 |
| 编译器 | MSVC 19.x / GCC 9+ / Clang 10+ | 系统包 |

后续里程碑按 GDD 2.1 追加：nlohmann/json（M3 前）、ENet（M3）、argon2 + libsodium/OpenSSL（M3）。

---

## 构建（Windows）

需要 Visual Studio 2022（含 C++ 桌面工作负载）。`FetchContent` 首次配置会拉取 PDCursesMod。

```powershell
pwsh -File scripts/build.ps1                       # 配置 + 构建 + 测试
pwsh -File scripts/build.ps1 -Config Debug -Clean  # 换配置并清空
```

脚本内部等价于：

```powershell
cmd /c '"D:\vs2022\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && cmake -S . -B build -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build build && ctest --test-dir build --output-on-failure'
```

产物：`build/bin/wasteland_glyph.exe`

> **为什么用 NMake 而不是 VS 生成器？**
> 本机 Visual Studio 2022 安装在 `D:\vs2022`，但**未注册到 Visual Studio Installer 的实例缓存**
> （注册表 `HKLM\SOFTWARE\Microsoft\VisualStudio\SxS\VS7` 不存在），所以 CMake 的
> `Visual Studio 17 2022` 生成器报 "could not find any instance of Visual Studio"，
> 而工具集本身可用。NMake 生成器只依赖 `vcvars64.bat`，因此走这条路径。
> 若你的 VS 是正常安装的，直接换回 VS 生成器即可：
> `cmake -S . -B build -G "Visual Studio 17 2022" -A x64`

> **离线构建：** 手动准备 PDCursesMod **v4.5.4** 源码后：
> `cmake -S . -B build -G "NMake Makefiles" -DWG_FETCH_DEPENDENCIES=OFF -Dpdcursesmod_SOURCE_DIR=<路径>`

## 构建（Linux）

```bash
sudo apt install build-essential cmake libncursesw5-dev
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j
```

产物：`build/bin/wasteland_glyph`

---

## 运行

```bash
wasteland_glyph                       # 用时钟生成随机世界种子
wasteland_glyph --seed 20261011       # 用原始 uint64 复现
wasteland_glyph --seed-str "00000000KAA4KT-1.0.1.1"   # 用显示形式复现（状态栏里就是它）
```

终端最小 **80×24**，低于则拒绝启动（GDD 6.1）。状态栏会打印显示形式的种子，可直接粘回
`--seed-str`。

| 键 | 功能 |
|---|---|
| 方向键 / `hjkl` / 数字键盘 / `yubn` | 移动（8 向） |
| `.` / `5` / 空格 | 等待一 tick |
| `;` | 查看（look）模式，Esc 退出 |
| `o` | 开关相邻门 |
| `q` | 退出 |

> M1 是**单进程回合制演示**：世界每个动作推进一 tick。GDD 2.2 的 20 TPS 实时制与
> GDD 4.4 的 server/client 分离都属于 M3，届时把「按输入推进」换成「按时间推进」即可，
> 世界逻辑不变。

## 种子字符串（GDD 3.4）

格式 `[WG-]<13 payload><1 check>[-<version>]`，例：`00000000KAA4KT-1.0.1.1`。

- 字符集：**Crockford Base32**（`0-9` + `A-Z` 去 `I L O U`），大小写不敏感，
  `O/o→0`、`I/i/L/l→1`；`U` 明确**拒绝**（不做 `U→V` 别名，否则一个种子有两种写法）。
- 13 字符 × 5 bit = 65 bit 装 64 bit 负载：**首字符只承载 4 bit，其最高位恒为 0**，
  因此**首字符一定是 `0`–`F`**，这条同时充当输入校验。
- 校验位取自**去掉 `0`** 的 31 字符表，算法为 13 个负载字符数值的**加权和 mod 31**
  （权重 1–13，能发现相邻字符换位）。
- 已知强度：1 个校验字符可检出约 96.8% 的单字符错误；实测 99.7%（含首字符范围规则）。
- `-version` 后缀**仅显示、不解析**（GDD 3.4 既定结论）。

完整规格见 [`docs/seed-format.md`](docs/seed-format.md)。

```bash
wasteland_glyph_digest --seed-str "00000000KAA4KT"   # 解析显示形式
wasteland_glyph_digest --seed-format-test            # 96 个种子往返 + 单字符损坏检出率
```

## M2 验收：同种子两次启动地图一致

GDD 18 的 M2 标准是「同种子两次启动地图一致」。`wasteland_glyph_digest` 把它变成一条
可复核的命令：

```bash
wasteland_glyph_digest --seed 20261011
# world_seed=20261011
# seed_string=00000000KAA4KT-1.0.1.1
# version_triple=1.0.1.1
# mod_hash=0
# effective_seed=20261011
# overmap=1081022071008857478
# spawn=5082,1914
# map=3217739401567804772
# towns=18
# dungeons=8
# road_links=17

wasteland_glyph_digest --seed 20261011 --data data   # 带 mod 的等价世界
wasteland_glyph_digest --selftest                     # 8 个种子各生成两遍并逐字比较
```

**`mod_hash` / `effective_seed`（GDD 20.5）：** 未装 mod 时 `mod_hash = 0` 且
`effective_seed = world_seed`（恒等，见 20.4 裁决二），所以摘要描述的就是服务器实际生成的世界。
`--data <root>` 让摘要工具走**与服务器完全相同**的种子路径，装了 mod 时报告偏移后的值。

**关于 `map=` 这一行：** 它是窗口内地形摘要，会随**世界生成算法的改动**变化。M3 的流式加载
（`c1c6ad3`，重写 `worldgen.cpp` 的窗口装配）改过它一次，当前值即上表所示；
`overmap` / `spawn` / `towns` / `dungeons` / `road_links` 自 M2 起未变。
**确定性本身由 `--selftest` 保证**（同种子生成两遍逐字相同），与具体数值无关。

两次运行输出必须逐字节相同；改了 `--seed` 则必须全部不同。`--selftest` 与
`--seed-format-test` 都已注册为 CTest 用例，每次 CI 都会跑。

---

## 测试

```bash
ctest --test-dir build --output-on-failure -C RelWithDebInfo   # Windows
ctest --test-dir build --output-on-failure                      # Linux
```

`tests/` 目前覆盖：

- **rng_determinism_test** — SplitMix64 参考值、地址化派生纯度、坐标不碰撞、`GEN_ALGO` 内部混入、坐标契约（0–8447）、块号 floor 除法。
- **seed_codec_test** — 编码形状（13+1）、首字符恒在 `0`–`F`、已知向量（由独立的 Python 实现交叉验证）、前缀可选与大小写不敏感、Crockford 别名、`U` 被拒、空白裁剪、单字符损坏检出率下界、**换位必被检出**、错误分类、版本后缀只携带不解析、错误码均有 i18n key、uint64 全域可表示。
- **world_determinism_test** — 同种子同世界（含 overmap 摘要与窗口原点）、异种子异世界、**点位地形纯函数性**、**流式块与纯函数一致**、**淘汰后重建透明**、**保留环与上限淘汰（含淘汰可复现）**、**窗口跟随与边界滞后**、**流式窗口等于全量生成**、**重填保留 explored 记忆**、**缓存命中不重复生成**、overmap 确定性与地形覆盖率、Poisson 盘城镇间距、地牢避开城镇与水面、道路 MST 成森林、街区接缝连续性、城镇街区含建筑/道路/门、各生物群系地形匹配、地图非退化、出生点可行走、值噪声连续性与确定性、FOV 半径/对称性/墙体点亮/无重复/性能预算、动作序列确定性、**长距离行走确定性**、时间推进、撞墙拒绝。
- **world_digest_selftest** — 8 个种子各生成两遍，报告逐字比较（GDD 18 M2 验收）。
- **seed_format_cli_test** — 96 个种子往返 + 单字符损坏检出率（经 CLI 而非库内调用）。

---

## 目录结构

```
GDD.md                 设计文档（唯一权威）
AGENTS.md              协作约定
docs/seed-format.md    种子字符串规格澄清稿（待回填 GDD 3.4）
CMakeLists.txt         顶层构建
cmake/                 配置期检查（小端断言、PDCursesMod 源列表）
scripts/build.ps1      Windows 构建脚本
src/
  core/rng.h           地址化随机数：splitmix64 / derive_seed / *_hash / PCG64
  core/seed.h|cpp      种子字符串编解码（Crockford base32 + mod 31 校验）
  core/version.h       PROTO_VER / SAVE_VER / GEN_ALGO 数值与显示串
  core/noise.h         地址化值噪声（octave / fbm），世界生成的唯一噪声源
  core/grid.h          全局 tile 坐标、块划分、8 向、`std::hash<Position>`
  core/time.h          GDD 7.1 时间常量（唯一来源：TICK_HZ / TICKS_PER_GAME_DAY / …）
  persist/save.h|cpp   存档：结构、原子写、世界增量、迁移、备份轮转（GDD 14.1-14.5）
  persist/log.h|cpp    分级日志、反作弊/管理员独立文件、崩溃处理（GDD 14.9-14.10）
  data/modman.h|cpp    mod 清单、加载排序、mod_hash、effective_seed（GDD 20.2-20.5）
  data/itemdb.h|cpp    条目合并、覆盖白名单、引用完整性、冻结（GDD 20.3）
  game/item.h|cpp      物品定义与堆叠、腐烂状态机、ToolTag（GDD 11.2-11.4）
  game/ground_items.h|cpp 逐格地面容器、50 件上限与溢出顺序、加载时累计腐烂（GDD 11.3-11.4）
  game/inventory.h|cpp 背包、重量/体积上限与超重惩罚（GDD 9.2）
  game/skill.h|cpp     6 技能与 `lvl²×50` 阈值（GDD 9.2 / 17）
  game/crafting.h|cpp  配方、工具/材料需求检查、制作锁（GDD 11.5）
  game/loot.h|cpp      加权掉落表与 `loot_hash` 地址化抽取（GDD 11.6）
  game/game_data.h|cpp 物品/配方/容器模板 + mod 集合的统一持有者（GDD 20.x）
  world/terrain.h      地形类型与 GDD 6.6 字符表
  world/map.h          局部地图 Tile / GameMap
  world/overmap.h|cpp  Overmap 层：生物群系、Poisson 盘城镇、地牢、MST+A* 道路
  world/localmap.h|cpp 单块内容：街区/建筑/自然散布/道路接缝
  world/chunk.h|cpp    地块流式加载：块缓存、按需生成、保留环 + 上限淘汰
  world/fov.h|cpp      递归阴影投射 FOV
  world/worldgen.h|cpp 世界装配（overmap → 流式窗口）
  game/player.h        玩家实体
  game/game.h|cpp      游戏状态与动作路径
  game/render.h|cpp    终端渲染与键位
  third_party/nlohmann/json.hpp   nlohmann/json v3.11.3 单头文件（MIT，内置）
  main.cpp             入口
tools/digest.cpp       世界摘要 / 确定性自检 / 种子格式自检
tests/                 确定性测试
data/                  原创数据（GDD 20.1：core/ 永远加载 + mods/）
  core/manifest.json   核心清单
  core/items/*.json    条目（武器 10.2 / 医疗 10.6 / 材料）
```

---

## 里程碑状态

以 `GDD.md` 第十八章为准，此处仅记录进度。

| 阶段 | 状态 | 说明 |
|---|---|---|
| M1 单机终端 Demo | **已完成** | `@` 移动、FOV、种子驱动生成、确定性测试、CI 工作流 |
| M2 种子驱动单机世界 | **已完成** | overmap 64×64、生物群系、Poisson 盘城镇、**地牢入口与内部**、MST+A* 道路、街区模板；摘要工具与自检已接 CTest |
| M2.5 地块流式加载 | **已完成** | `ChunkCache` 按需生成 + 保留环/上限淘汰；`StreamingMap` 边界滞后重填；explored 记忆跨重填保留 |
| M3 客户端/服务器分离 | **已完成** | 协议/序列化、ENet 双进程、握手与版本硬拒、多客户端、每玩家 FOV 与 tile delta、MTU 分帧、输入队列、会话 token 重连、X25519+ChaCha20-Poly1305 加密、argon2id 账号与注册模式、反作弊基础 |
| M4a 战斗数值 | **已完成** | 6 部位 HP、两层命中判定（自然命中 → 部位抽样）、5 件武器表、护甲固定减伤、部位功能联动（手臂/腿部/爬行）、僵尸实体与击杀 |
| M4b 疼痛 + 出血 + 骨折 | **已完成** | 痛值（伤害×2，上限 50，影响命中与速度，每游戏分钟 −1）、出血（速率=伤害/游戏分钟，留血迹，无自然止血）、骨折（累计伤害 ≥ 上限 25%，部位锁定，需夹板）、僵尸三通道感知（视觉/听觉/嗅觉沿血迹链式追踪）、八向 A* 寻路、**僵尸联机下发** |
| M4c 感染 + 医疗流程 | **已完成** | 伤口感染 30%（与 11.4 腐烂食物共用同一数字）、发病延迟 2 游戏日、每游戏分钟 −1 HP；**四个独立医疗动作**（包扎/固定/消毒/抗生素）；拒绝时**不消耗回合与物品** |
| M4d PvP + 尸体容器 + WieldedItem | 未开始 | 击杀生效，尸体生成 |
| M5 UID 颜色标识 | **已完成** | 12 色池（六暗六亮六色相），`player_id % 12` 纯模映射，重连不变色 |
| M6 颜色上限与拒绝 | **已完成** | 12 账号注册拒绝、12 在线拒绝（`ERR_SERVER_FULL`）、ENet peer 上限 16 |
| 第二十章 数据文件与 mod 系统 | **已完成** | `data/core` + `data/mods/`、清单校验、`(load_order,id)` 排序、覆盖白名单、引用完整性、`mod_hash`、`effective_seed`、握手 `ERR_MOD_MISMATCH` |
| 第十一章物品层 | **已完成** | 11.2 物品与堆叠、11.3 地面容器（50 件上限 + 溢出顺序）、11.4 腐烂（3 日 / 1 日、冰箱 ×0.5、冰库永久）、11.5 配方与需求检查、11.6 地址化掉落；**9.2 背包与拾取/丢弃**（`g` / `d`，200ms 冷却）。**11.5 的制作 UI 与 15.2 的 `i` 背包界面待做** |
| 第十四章存档 | **已完成** | 目录结构、.tmp+fsync+rename 原子写、锁、世界逐格增量（含窗口重填后重放）、SAVE_VER 迁移（迁移前备份）、备份轮转（7 代 + premigrate 豁免）、mod_hash 拒绝、**定时存档**（默认 300s）、**优雅关闭**（广播 + 宽限 + 存档）、**分级日志**（server/anticheat/admin 三流）、**崩溃处理**（SIGSEGV/SIGABRT + 堆栈）。14.6 体积实测属 M9 |
| M4d PvP + 尸体容器 | **已完成** | 击杀生效（部位归零 → 背包整体转入尸体）、尸体容器（g 搜刮、3 游戏日腐烂散落、离线不消失）、PvP 结算复用僵尸路径、12.8 C 视野校验。**WieldedItem 的「物品实例化 + 武器数值改为 JSON 单一来源」待 M10** |
| M7 死亡与重生 | **已完成** | 技能÷2（死亡瞬间一次、向下取整）、物品全掉（M4d 已就绪）、**SpawnRule 六级降级重生**（100/50/30/20/10/1，attempt 跨级累加保证确定性）、10 秒倒计时、重生后状态重置、**公告不含坐标**且走可靠通道、12.8 I 复活期间丢包。**首登出生走同一阶梯** |
| M8–M11 | 未开始 | |

> **待实现任务的完整清单见 [`任务.md`](任务.md)。** 它是从 `GDD.md` 抽出的工作分册，
> 只含未实现部分，并按里程碑排序；设计权威仍是 `GDD.md`。

### M4b 运行方式

单人跑，开局 2–4 格外一小群**休眠**僵尸。走一步（脚步 4 格噪音）、开门（6 格）、挥空一刀
（8 格）都会把它们吵醒。**流血会留下血迹，僵尸嗅觉沿血迹链在 30 格内追踪**——所以受伤后
别乱跑。

状态栏第 3 行显示 `pain=` / `bleeding=N/min` / `fx:<部位>`；受伤后 HP 会**持续下降**，
直到包扎（M4c 接入物品）。

联机时僵尸**已下发**（快照实体列表新增 `kind` 与 `awake`），所以两位玩家能看到并攻击同一批
僵尸；各自只看到自己视野内的。**僵尸移动与受击在两台客户端上完全一致**（服务端权威）。

### M4a 运行方式

单人直接跑：

```bash
wasteland_glyph --seed-str 00000000KAA4KT-1.0.1.1
```

开局 2–4 格外会有一小群**休眠**僵尸（`Z` 暗红）。方向键撞上去即攻击：GDD 15.2 把方向键
同时当作移动与攻击，所以世界自己决定这一下是走过去还是挥出去。状态栏第 2 行显示
`HP` 总条、`hit=`（当前命中率）、`cd=`（攻击冷却剩余），以及 `crawling` / `arms: no weapon`
这两个会改变按键行为的部位状态。

联机时僵尸**尚未下发**（见下方「已完成里程碑的后续项」）。

### M3 运行方式（GDD 4.4）

单机、联机、开服走同一条路径：**先起 server，再起 client**。主机开服后只当服务器，不自动入局。

```bash
# 终端 1：开服
wasteland_glyph_server --headless --port 7777 --seed 20261011

# 终端 2 / 3：入局（各一个进程）
wasteland_glyph --connect 127.0.0.1 --port 7777
```

实测（双客户端连同一服）：

```
[server] listening on port 17778, world_seed=20261011 seed_string=00000000KAA4KT-1.0.1.1
[server] client 1 joined as player_id 0
[server] client 2 joined as player_id 1
[client] joined: world_seed=20261011 ... player_id=0 tick=44
[client] joined: world_seed=20261011 ... player_id=1 tick=86
```

未给 `--connect` 时客户端进入**单机模式**（本进程内跑世界），用于 M1/M2 的既有行为与离线测试。

### 已完成里程碑的后续项

- **JSON 模板**：GDD 8.3 要求每块加载 JSON 模板。解析器尚未引入，且尚无模板内容，
  故使用「(块子种子, 块内偏移) → 地形」的过程化模板顶上，调用契约不变。
- **道路交叉口**：`ROAD_*` 位掩码已记录出口方向，渲染层尚未据此描绘岔口形状。
- **钓鱼 / 建造 / 陷阱 / 电力 / 动物 / 远程 / 裁缝**：规格已回填 `GDD.md`，实现未开工
- **已消掉的既有偏离**：21.9 **地牢内部**（生成 + 进出）、21.2 **烹饪**、21.6 **游泳**、21.7 **天气**、21.8 **温度**、15.1 **i18n** 均已实现
  第二十一章，**实现**待对应里程碑。
- **僵尸联机下发**：**已实现**（见 M4b）。快照实体列表新增 `kind` 与 `awake`，僵尸按可见性
  过滤后随玩家同表下发。
- **僵尸感知与寻路**：**已实现**（GDD 6.6 / 21.1）：视觉 10 格受光照与遮挡、听觉按 21.1 噪音表
  （不穿墙）、嗅觉 30 格沿血迹链式追踪；八向 A* 复用统一地形代价表；每 2 tick 判定；连续 5 真实
  秒无命中回休眠。
- **地形代价表**：GDD 6.6 说寻路「复用 8.3 的地形代价表」，但 **8.3 与 10.9 都没有该表**
  （20.7 #27）。已实现部分为浅水 ×2（6.6 原文），草地 ×1.5 是占位值。
- **光照等级**：6.6 与 8.4 要求按白天/夜·室内/火把缩放，但**昼夜状态与室内判定本身未定义**
  （20.7 #32），故当前恒按白天口径。
- **闪避**：10.5 说疼痛影响闪避，但全文档没有闪避机制（20.7 #31），故「痛值 → 闪避」未接线。
- **技能成长**：GDD 10.2 定义了「技能 → 命中率」，但没定义技能怎么涨（20.7 #25），当前全员技能 0。
- **医疗物品**：感染与四个医疗动作的**机制已实现**（`apply_medical()` / `InjuryState::roll_infection()`），
  但**物品与键位未接**：医疗物品表的 id 与材料是占位（GDD 20.7 #34），15.2 键位表没有
  包扎/固定/消毒/抗生素的按键（#35）。所以游戏内暂时没有按键能包扎——机制可被测试直接调用。
  感染的**推进曲线**（发病延迟 2 游戏日 / 每游戏分钟 −1 HP）同样是占位（#39），所有者只裁决了
  30% 概率与「四个步骤独立」。
- **光照等级**：8.4 的昼夜与「室内」判定**已实现**（`ambient_light_level()` / `is_indoors_at()`）。
  白天 20 格、夜与室内 3 格。8.4 的火把（8 格）与 21.7 的天气修正是 M11 项。
- **快照通道**：快照走 **ch1 且为 unreliable-sequenced**（12.2 的「M3 后」列）。帧预算按数据报
  计算，`max_frame_bytes = 1300`。
- **加密与账号**：已实现（GDD 12.4 / 12.5）。明文传输路径只在 `--no-encryption` 下可达，
  启动时会打警告。
- GitHub Actions CI 尚未在远端验证（需要远端仓库）。

---

## 贡献

改代码前先读 [`AGENTS.md`](AGENTS.md)。核心一条：**GDD 未定义的东西不要自己拍板**，
按 `GDD.md` 20.7 待补清单以 `TODO(gdd-20.7 #N)` 标注。
