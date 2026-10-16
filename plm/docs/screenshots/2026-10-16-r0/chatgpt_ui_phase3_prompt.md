# ChatGPT 提示词：PLM Qt 前端视觉精致度与一致性专项优化（第三阶段）

以下内容为可直接复制交付给 ChatGPT（或 Claude）的完整重构任务书。请严格遵循约束与架构规范进行修改。

---

你是一位精通桌面端 UI/UX 设计与 PyQt5 架构的资深前端工程师。
在前面两个阶段中，项目已经完成了核心设计令牌紧凑化（13px / 32px）、深浅双主题切换（WCAG AA 达标）、异步 Toast 与标题栏控制区右移。经过全量测试验证，系统运行稳定。

现在开启**第三阶段的精致度与视觉一致性专项优化**。本任务书聚焦于消除当前最新截图（`2026-10-16-r0`）中暴露出的排版错位、层级杂糅、认知断层与组件风格不统一问题。

> **注意**：界面中的专业术语（如 `Num of Lanes`、`Tie-off`、`original_pipe`、`bus` 等）属芯片硬件行业通用术语，**保持英文原样，严禁强行翻译**。

---

## 一、硬性约束与工程边界

1. **工作目录**：`src/plm/frontend/qt/` 以及 `tests/`（同步相关断言）。
2. **严禁修改**：
   - 严禁修改 `src/plm/core/`（生成核心算法）。
   - 严禁修改 `test/`（生成黄金比对数据与样例工程）。
   - 严禁引入外部新依赖，继续使用 PyQt5 5.15+。
3. **架构规范**：
   - 保持 MVC 分层、“一类一文件”规范与既有信号槽契约。
   - 所有尺寸与色彩必须严格通过设计令牌管理。
4. **测试要求**：
   - 修改完成后必须运行：
     ```bash
     QT_QPA_PLATFORM=offscreen uv run python -m unittest discover -s tests -v
     ```
   - 保证全部既有单元测试 100% 通过，并为新增行为补充测试断言。

---

## 二、详细实现规格（共 6 项精致度提升）

### 任务 1：Generation 页面卡片输入框纵向对齐（消除错位台阶）

#### 1.1 现状缺陷诊断
在 `GenerationEditor`（`01-generation.png`）中：
- 卡片 1【硬件与架构】：标签 `Connection 总线类型` 字符较多，导致该卡片内的下拉框左边缘起始线约在 **320px** 处；
- 卡片 2【模块与命名】：标签 `模块名前缀` 只有 5 个字，输入框左边缘起始线约在 **260px** 处；
- 结果：上下两个卡片的输入控件在纵向对齐线上形成了明显的“错位台阶”，视觉非常不整齐。

#### 1.2 修复规格（`src/plm/frontend/qt/widgets/config_editor.py`）
1. 为 `GenerationEditor` 中两个 `QFormLayout` 的标签列统一设置对齐策略与最小宽度：
   - 方式一：在两个分组的 `QFormLayout` 中，将所有标签控件统一设置 `setMinimumWidth(140)`（或在 tokens 中定义 `FORM_LABEL_WIDTH = 140`），或者统一使用 `layout.setLabelAlignment(QtCore.Qt.AlignLeft)` 并确保两列基线锁死；
   - 保证上下两个卡片中，所有下拉框（`StyledComboBox`）和前缀输入框（`QLineEdit`）的**左边缘绝对 X 坐标完全一致**。
2. 同步测试：
   - 在 `tests/test_qt_generation.py` 中更新或新增断言，检查上下两卡片控件的 `mapTo(editor, QtCore.QPoint()).x()` 严格相等。

---

### 任务 2：项目标题栏视觉层级优化（标题加粗、路径弱化、状态 Badge 化）

#### 2.1 现状缺陷诊断
在主界面顶部（`01-controller.png`）：
```text
[图标] demo-project   已保存   D:\Users\man\AppData\Local\Temp\plm-ui-laniqqp5\demo-project
```
- 项目名、状态、一长串绝对路径以相同的普通字号和粗细堆在一行，视觉噪音极大；
- 临时长路径像调试信息直接打印在主界面上；`已保存` 只是无样式的裸文本。

#### 2.2 修复规格（`src/plm/frontend/qt/views/config_page.py`）
1. **项目名称**：
   - 设为中半粗体（`font-weight: $font_weight_semibold; font-size: 14px;`），成为主界面的视觉锚点。
2. **状态指示器**：
   - 升级为规范的轻量状态 Badge：
     - 未修改/已保存：浅绿微底色 + 绿色小圆点 + 文字“已保存”；
     - 有未保存修改：浅橙微底色 + 橙色小圆点 + 文字“未保存”。
3. **工程路径弱化展示**：
   - 路径文本颜色设为次级弱化色（`$text_muted; font-size: 12px;`）；
   - 如果路径过长，使用 `fontMetrics.elidedText` 优雅省略中间目录（例如 `D:/.../demo-project`），并在鼠标悬停时提供完整路径 Tooltip。

---

### 任务 3：标签栏（Tabs）设计语言归一化

#### 3.1 现状缺陷诊断
- 主配置页（Controller / LaneMapping / Signals / Generation）：采用的是**底部下划线指示条（Underline Tab）**；
- 设置页面（通用 / 工具，`04-settings-general.png`）：采用的是**灰色实心填充胶囊（Segmented Pill Tab）**；
- 软件内并存两套截然不同的 Tab 风格，破坏了系统一致性。

#### 3.2 修复规格（`src/plm/frontend/qt/views/settings_page.py` & `styles/app.qss`）
1. 统一风格：将 `SettingsPage` 中的分类 Tab 改为与主界面一致的下划线标签栏（或共用 `ConfigTabBar` 的微调变体）；
2. 消除深浅模式切换时的样式生硬，保持两处 Tab 的内边距、字号（13px）、选中态下划线颜色（`$primary`）完全统一。

---

### 任务 4：LaneMapping 顶部色块标注编号（消除心智负担）

#### 4.1 现状缺陷诊断
在 `01-lane-mapping.png` 中：
- 顶部控制器色块只写了名称：`[CtrlA]`、`[CtrlB]`、`[CtrlC]`、`[CtrlD]`；
- 下方矩阵表格里填写的却是数字编号：`0`、`1`、`2`、`3`；
- 用户在进行物理 Lane 映射时，必须在大脑中心算“CtrlA 到底对应几号”。

#### 4.2 修复规格（`src/plm/frontend/qt/widgets/lanegrid.py`）
1. 优化顶部控制器选择色板（Swatch Button）的文字排版：
   - 将按钮文字由纯名称 `CtrlA` 调整为 **`0: CtrlA`**、**`1: CtrlB`**（或带微标签的 `[0] CtrlA`）；
   - 如果名称过长，保留编号完整并自适应 elide 名称；
2. 保证色块上的数字与下方网格单元格中的控制器 ID 建立直观映射，大幅降低用户心智负担。

---

### 任务 5：表格右键菜单增加行操作图标（消除左侧空槽悬空感）

#### 5.1 现状缺陷诊断
在 `01-controller-context-menu.png` 中：
- `在上方插入行`（无图标）；
- `在下方插入行`（无图标）；
- `[垃圾桶图标] 删除当前行`（带红色图标）；
- 因为 `StyledMenu` 为每一行都预留了统一的 16px 图标槽，导致前两行文字左侧留出了一大块明显的“空白窟窿”，视觉上显得突兀、像图标加载缺失。

#### 5.2 修复规格（`src/plm/frontend/qt/widgets/tables.py`）
1. 在 `_show_row_context_menu` 中，为插入行操作补充标准 Lucide 图标：
   - `在上方插入行`：配置图标 `arrow-up-to-line`（或 `arrow-up`）；
   - `在下方插入行`：配置图标 `arrow-down-to-line`（或 `arrow-down`）；
2. 确保菜单中所有项均有对应的线性图标，使整个上下文菜单视觉饱满、左侧图标与文字排版整齐划一。

---

### 任务 6：标题栏右上角抽屉按钮图标符号学呼应

#### 6.1 现状缺陷诊断
- 右上角 Artifacts 抽屉按钮目前使用的是 `file-text`（文件图标），与左侧边栏底部的“文档”按钮图标完全撞车；
- 从交互符号学来看，左边是控制底部面板开闭的 `panel-bottom`，右边对应控制右侧抽屉开闭的应当是 `panel-right`。

#### 6.2 修复规格（`src/plm/frontend/qt/main_window.py`）
1. 将 `MainWindow.__init__` 中的 `self.artifacts_toggle_button` 图标从 `"file-text"` 修改为 **`"panel-right"`**；
2. Tooltip 保持 `"显示/隐藏 Artifacts"`；
3. 与左侧的 `panel-bottom` 形成“底部面板 + 右侧抽屉”的标准对称符号对偶，彻底消除与侧栏“文档”图标的混淆。

---

## 三、验收与交付标准

1. **测试结果**：
   - 执行 `QT_QPA_PLATFORM=offscreen uv run python -m unittest discover -s tests -v`；
   - 保证全部既有测试 100% 通过，更新或补充因控件命名/图标微调受影响的测试断言。
2. **多主题与视觉复核**：
   - 验证浅色与深色模式下，新增的菜单图标颜色正常，Generation 页面两张卡片输入框在各分辨率下保持垂直对齐。
3. **交付产物**：
   - 按文件输出修改后的完整代码段或精准 diff，并附上测试日志。
