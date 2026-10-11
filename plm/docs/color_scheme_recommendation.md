# plm 前端色彩方案（2026-10-09 实施）

已实施统一冷灰色板、浅蓝选中态、语义色配对和 QSS 色彩 token。Artifacts 面板统一冷灰。

实施时修正了原方案的对比度计算：`#8B94A3` 在侧栏 `#F6F7F9` 上只有约 2.85:1。muted 文字改用 `#656E7D`，在侧栏上约 4.80:1，在 Artifacts 上约 4.56:1，在表头/禁用背景上约 4.51:1。

## 一、实施前问题清单

| # | 问题 | 现值 | 位置 |
|---|------|------|------|
| 1 | PRIMARY_LIGHT 名为浅主色实为中灰，9 处选中态用它，选中/hover/交替行全是灰无区分 | #F2F4F7 | tokens.py:10, app.qss:110/125/152/360/366/399/457/476/684 |
| 2 | BG_SIDEBAR_INACTIVE 与 BG_SIDEBAR 同值（死 token），还被借用作卡片底色和滚动条 | #F7F8FA | tokens.py:14-15, app.qss:374/542 |
| 3 | 文字灰三套混用：GitHub gray(#1F2328) + Tailwind slate(#64748B/#475569) + 自定义灰背景 | — | tokens.py:12-33 |
| 4 | Artifacts 暖米色紧贴冷灰主画布，并排发黄（已定：统一冷灰） | #F5F4F1/#DDD9D1 | tokens.py:20-21 |
| 5 | 边框 #EEF0F3 与背景 #F2F4F7 明度几乎相同，卡片边界感弱；hover 也是灰 | — | tokens.py:27-29 |
| 6 | TEXT_MUTED 在侧栏上对比度仅 ~2.8:1，不达 WCAG AA 4.5:1 | #94A3B8 | tokens.py:33 |
| 7 | 语义色不成对（emerald 图标配 green 文字）；app.qss 有 5 处硬编码 hex | #10B981 vs #15803D | tokens.py:35, app.qss:358/363/468/690-691 |

## 二、推荐色板

### 中性灰 N（单一冷调 ramp，全 UI 共用）

| 级 | 值 | 用途 |
|----|------|------|
| N0 | #FFFFFF | 主表面（表格、画布） |
| N25 | #FAFBFC | 交替行 |
| N50 | #F6F7F9 | 侧栏、卡片底、窗口底 |
| N100 | #EEF0F4 | subtle 填充（表头）、禁用底 |
| N200 | #E1E5EB | hover |
| N300 | #CBD2DC | 常规边框、分割线 |
| N400 | #8B94A3 | 中间灰阶；对比度不足，不作为小字号文字 |
| N450 | #656E7D | muted 文字（在 N50 上 ≈ 4.80:1） |
| N500 | #626C7B | 次要文字 |
| N600 | #4A5462 | 表头文字 |
| N800 | #23272F | 正文 |

### 主色蓝 P（保留现有蓝）

| 级 | 值 | 用途 |
|----|------|------|
| P50 | #E8F0FE | **选中背景（新，替换灰选中）** |
| P100 | #D6E4FD | 按下态、浅填充 |
| P500 | #3B82F6 | 主色、焦点边框（不变） |
| P600 | #2563EB | hover（不变） |
| P700 | #1D4ED8 | info 文字（不变） |

### 语义色（bg / 图标 / 文字同色相成对）

| 语义 | bg | 图标 | 文字 |
|------|------|------|------|
| INFO | #DBEAFE | #1D4ED8 | #1D4ED8 |
| SUCCESS | #DCFCE7 | #16A34A（原 emerald #10B981 改 green） | #15803D |
| WARNING | #FEF3C7 | #B45309 | #B45309 |
| DANGER | #FEE2E2 | #EF4444 | #B91C1C |

## 三、token 映射表（旧 → 新）

| 旧 token | 旧值 | 新值 | 说明 |
|----------|------|------|------|
| PRIMARY_LIGHT | #F2F4F7 | 拆成两半：选中态改 `PRIMARY_SOFT=#E8F0FE`；其余中性用途归 BG_SUBTLE | 核心改动 |
| BG_SIDEBAR_INACTIVE | #F7F8FA | 删除；窗口失活改用透明度或 N100 | 死 token |
| （新增）BG_CARD | — | #F6F7F9 | 表格卡片底色，替换借用 BG_SIDEBAR_INACTIVE 的 app.qss:374 |
| BG_MAIN / BG_SURFACE | #FFFFFF | #FFFFFF（不变） | |
| BG_SIDEBAR | #F7F8FA | #F6F7F9 | 微调并入统一 ramp |
| BG_SUBTLE | #F2F4F7 | #EEF0F4 | |
| BG_ALTERNATE | #FAFBFC | #FAFBFC（不变，= N25） | |
| BG_HOVER | #E9EDF2 | #E1E5EB | |
| BG_FOCUS | #DDE3EB | #E1E5EB（与 hover 合并）或接 P100 | 焦点优先用 BORDER_FOCUS 蓝边 |
| BG_ARTIFACTS | #F5F4F1 | #F0F1F4 | 已定：统一冷灰 |
| BORDER_ARTIFACTS | #DDD9D1 | #D5D9E0 | |
| BORDER | #EEF0F3 | #E5E8ED（弱边框，与 N100 拉开一档） | 边框要有层级 |
| BORDER_HOVER | #CBD5E1 | #CBD2DC | |
| BORDER_FOCUS | #3B82F6 | #3B82F6（不变） | |
| TEXT_MAIN | #1F2328 | #23272F | |
| TEXT_SUB | #64748B | #626C7B | |
| TEXT_HEADER | #475569 | #4A5462 | |
| TEXT_MUTED | #94A3B8 | #656E7D | 修正原方案计算，满足侧栏、Artifacts 和表头背景的 4.5:1 要求 |
| SUCCESS（图标） | #10B981 | #16A34A | 与文字同色相 |
| INFO/SUCCESS/WARNING/DANGER 对 | — | 不变 | 已成对 |

app.qss 硬编码清理：原 358/363/468 行 `#FFFFFF` → `$bg_surface`；原 690-691 行 tooltip 色彩 → `$tooltip_bg` / `$tooltip_text`。自绘圆角 tooltip 使用相同 token，深底使用 N800，文字使用 N0。

## 四、落地步骤（按顺序）

1. tokens.py 顶部按 `# neutral ramp / # primary ramp / # semantic pairs / # derived roles` 四组重排，加分组注释；语义色改成 `(bg, fg)` 元组或 dict，保证成对不会被拆散
2. 按上表改值 + 新增 `PRIMARY_SOFT`、`BG_CARD`，删除 `BG_SIDEBAR_INACTIVE`
3. app.qss：`$primary_light` 全部替换为 `$primary_soft`；卡片改 `$bg_card`，日志状态栏改 `$bg_sidebar`；5 处硬编码 hex 走 token。表格和文件树 hover 使用 `$bg_hover`；导航选中态在 focus/hover 下保持浅蓝，按下时使用 P100
4. 检查 Python 侧引用：`main_window.py:10`（BG_SIDEBAR_INACTIVE）、`lanegrid.py:17`（PRIMARY_LIGHT 画选中格子）、`code_preview.py:8`（BG_ARTIFACTS）、`artifacts_panel.py` 等 grep 一遍
5. 测试断言更新：`test_qt_artifacts.py:174` 等涉及 QSS 值的断言
6. offscreen 截图对比验收：选中行浅蓝、hover 灰、交替行灰三层分明；Artifacts 冷灰

## 五、验证清单

- [x] 表格选中行 = #E8F0FE（浅蓝），hover = #E1E5EB（灰），交替行 = #FAFBFC，三者肉眼可分；像素断言通过
- [x] TEXT_MUTED #656E7D 在侧栏 #F6F7F9 上对比度 ≥ 4.5:1；Artifacts、表头和白底也通过对比度测试
- [x] Artifacts 面板与主画布并排无冷暖跳变；已检查原生 Windows 和 offscreen 截图
- [x] grep app.qss 无硬编码 hex，渲染后的 QSS 无未替换变量
- [x] Qt 运行代码与测试中 `BG_SIDEBAR_INACTIVE\|PRIMARY_LIGHT` 无残留（本文保留实施前后映射记录）
- [x] 全量测试通过：274 项，272 通过、2 跳过；原生 Windows 的表格三态、选中焦点、菜单字号和文件树检查通过

原生效果截图：[`ui-screenshots/color-scheme-2026-10-09.png`](../ui-screenshots/color-scheme-2026-10-09.png)。offscreen 用于背景像素验收；该平台字体数据库限制下的文字外观另用原生 Windows 验证。

## 2026-10-11 更新：靛蓝色板（3.0.3）

上面的中性灰 + 蓝色方案层次偏弱：侧栏和内容区几乎同色，主色只出现在一个按钮和
选中标签上。3.0.3 改为靛蓝主色，中性灰整体带一点主色的色调；只改 `tokens.py` 里的
取值，布局和 QSS 规则不变。Lucide 图标按次要文字色染色，随之一起带上色调。

| 角色 | 旧值 | 新值 |
|---|---|---|
| N25 交替行 | #FAFBFC | #F8F9FE |
| N50 侧栏、标题栏 | #F6F7F9 | #EEF1FB |
| N100 表头、输入框 | #EEF0F4 | #E4E8F7 |
| N200 hover | #E1E5EB | #D5DBF0 |
| N300 | #CBD2DC | #BCC5E3 |
| N400 | #8B94A3 | #8A91B4 |
| N450 muted 文字 | #656E7D | #5C638B |
| N500 次要文字、图标 | #626C7B | #575E87 |
| N600 | #4A5462 | #444B72 |
| N800 正文 | #23272F | #1B1F3B |
| P50 / P100 | #E8F0FE / #D6E4FD | #E7E9FF / #D4D8FF |
| P500 主色 | #3B82F6 | #4F46E5 |
| P600 / P700 | #2563EB / #1D4ED8 | #4338CA / #3730A3 |
| BORDER | #E5E8ED | #DCE1F2 |
| TEXT_HEADER | #475569 | #3B4268 |

对比度（WCAG）：白字在主色上 6.3:1；次要文字在白底 6.4:1、侧栏 5.6:1、表头底 5.2:1；
muted 文字在侧栏 5.2:1、表头底 4.8:1。成功、警告、危险三组语义色不变，与靛蓝主色
不相近。产物面板沿用 GitHub 浅色主题的独立色板，不随主色变化。

