# PLM GUI 界面设计重构与美化实施方案 (UI Redesign Proposal)

> **目标**：彻底解决当前 PLM GUI 界面存在的“空间空旷荒漠感、视觉层级扁平、局部饱和度过高、日志常驻霸屏、表单设置排版松散”等毛坯感问题，将其重构成现代工业级、专业精致的桌面 EDA/开发工具风格（对标 VS Code / Linear / macOS 现代化工具）。
>
> **适用对象**：此文档为自动化重构指导规范，LLM（如 GPT-4 / Claude）可直接按照本文档的分模块代码改动清单分步执行。

---

## 目录
1. [现状核心痛点与缺陷诊断](#一现状核心痛点与缺陷诊断)
2. [设计重构总体原则与设计系统规范](#二设计重构总体原则与设计系统规范)
3. [模块 1：设计 Tokens 与色彩系统重构 (`tokens.py`)](#三模块-1设计-tokens-与色彩系统重构-tokenspy)
4. [模块 2：QSS 全局样式与组件精修 (`app.qss`)](#四模块-2qss-全局样式与组件精修-appqss)
5. [模块 3：主窗体布局与日志抽屉化改造 (`main_window.py`)](#五模块-3主窗体布局与日志抽屉化改造-main_windowpy)
6. [模块 4：核心工作区各页面结构重塑](#六模块-4核心工作区各页面结构重塑)
   - 4.1 [Controller 与 Signals 表格页 (`tables.py`, `config_editor.py`)](#41-controller-与-signals-表格页)
   - 4.2 [LaneMapping 通道映射调色与排版 (`lanegrid.py`)](#42-lanemapping-通道映射调色与排版)
   - 4.3 [Generation 生成配置页卡片化 (`config_editor.py`)](#43-generation-生成配置页卡片化)
   - 4.4 [Settings 设置页收拢与 Formatter 分组 (`settings_page.py`)](#44-settings-设置页收拢与-formatter-分组)
   - 4.5 [Documentation 文档与 Artifacts 预览页 (`documentation_page.py`, `artifacts_panel.py`)](#45-documentation-文档与-artifacts-预览页)
7. [分步实施提示词模板 (Prompt for GPT)](#七分步实施提示词模板-prompt-for-gpt)

---

## 一、现状核心痛点与缺陷诊断

基于 `docs/screenshots/2026-10-15/` 下的全量截图审计，当前界面主要有以下 5 大硬伤：

### 1. 空间与密度失衡（“空旷荒漠感”与“霸屏感”并存）
* **巨大留白无意义**：
  * **Controller 表格**（`01-controller.png`）：整张表仅 4 行 3 列，横向铺满 1280 宽屏，纵向下半部分是占全屏近 40% 的死白荒原。
  * **通用设置**（`04-settings-general.png`）：整页仅 2 个选项，左侧标签“界面主题”在 x=20px，右侧下拉框被拉伸到 x=1200px 边缘，中间隔着 1000px 的空白；“保存设置”孤立地悬挂在右下角，视线严重断裂。
  * **Generation 页面**（`01-generation.png`）：所有单行输入框均全宽拉满，松散空洞。
  * **文档页面**（`05-docs-getting-started.png`）：正文没有最大阅读行宽限制（`max-width`），文本横贯 1200+ 像素，单行超长，阅读体验差。
* **底部输出日志常年霸屏**：
  * 底部输出面板（LogPanel）在 Controller、Signals、LaneMapping 等所有配置界面都默认占据了 200px 垂直高度（约 25%~30% 屏高）。大部分时候仅显示两行历史日志，侵占了极其宝贵的表格编辑空间。

### 2. 视觉层级弱，缺乏做工（“线框草稿感”）
* **项目头部缺乏上下文**：
  * 主工作区上方仅有一个粗体文本 `demo-project`，无项目图标、无路径提示、无已修改（dirty）醒目标识，缺乏现代化工作区 Header 的仪式感。
  * 标签栏（Controller / LaneMapping / Signals / Generation）直接散落在项目名下方，选中态仅是一个淡紫背景药丸，未选中态是散落灰字，缺少清晰的导航容器或底部高亮指示线（Indicator）。
* **字体排版单一无韵律**：
  * 全站几乎统一使用 13px 单一字号，标题与正文之间缺乏清晰的阶梯级差（缺少 Title 18-20px、Section 14-16px、Body 13px、Caption 11-12px 的层次）。

### 3. 色彩与对比度缺陷
* **单一高饱和度纯紫**：主色调过度依赖饱和度偏高的纯紫（`#4F46E5` / `#6366F1`），选中态、按钮、高亮全是一模一样的紫色块，缺乏主次搭配。
* **LaneMapping 对比度灾难**（`01-lane-mapping.png`）：
  * `CtrlA`（深紫）、`CtrlB`（亮青）、`CtrlC`（紫罗兰）、`CtrlD`（亮橙）色彩饱和度刺眼，像儿童跳棋玩具。
  * 深紫色背景单元格中使用了深黑色/暗色字体，严重违反 WCAG 4.5:1 可读性对比度标准，几乎看不清数字。
* **深色模式缺乏景深层次**（`dark-*.png`）：
  * 背景是纯黑/死黑，内容卡片与背景融为一体，缺少通过细微明度差（Surface Elevation）和细腻半透明描边（`rgba(255,255,255,0.08)`）营造的立体感。

### 4. 关键交互组件做工原始
* **数据表格只读感严重**：表头全显示底层代码字段名（`ctrl_id`, `mac_phy_txdata`, `safe_state`），无中文说明；缺少行内操作按钮（新增行、删除行、克隆行），全靠隐蔽的右键菜单。
* **设置页的 15 个连续下拉框**（`04-settings-formatter.png`）：Verible 格式化设置以 15 个一模一样的下拉框垂直堆叠，没有分类（对齐类、缩进类等），没有说明或即时效果预览。

---

## 二、设计重构总体原则与设计系统规范

1. **结构原则：收放有度（Container & Max-Width）**：
   * 表单与设置类内容一律限制在合适宽度（居中容器或双列卡片，`max-width: 720px ~ 860px`），禁止无意义的全屏横向拉伸。
   * 文档正文限制最大阅读宽度 `800px`，遵循可读性黄金排版。
2. **布局原则：抽屉式日志（Drawer-based Log Panel）**：
   * 将常驻垂直 Splitter 改造为：默认收起为底部紧凑状态条（高度 32px，显示“`>_ 输出日志 | 就绪`”），点击或执行“生成”时才向上展开；或支持一键贴底隐藏。
3. **色彩原则：现代沉稳工程风（Modern Industrial Palette）**：
   * 主色调采用精致的科技蓝调（`#2563EB` 或现代紫蓝 `#4F46E5`），搭配高级 Slate 灰阶（`#0F172A`, `#1E293B`, `#F8FAFC`, `#E2E8F0`）。
   * LaneMapping 网格改用现代调色板，根据背景明度动态计算前景字色（白字/黑字），确保对比度达标。
4. **组件原则：卡片化与分组（Card & Section Grouping）**：
   * 将散落的控件收敛入语义明确的卡片中（如 Generation 拆分为“RTL 架构配置”与“命名规范”两个卡片；设置页按“对齐规则”、“缩进规则”分组）。

---

## 三、模块 1：设计 Tokens 与色彩系统重构 (`tokens.py`)

**文件路径**：`src/plm/frontend/qt/styles/tokens.py`

### 1.1 优化灰阶与主色调
在 `tokens.py` 中更新色彩变量，提升浅色与深色模式下的表面层级：

```python
# -------------------------------------------------------------
# 1. 主题主色 (Primary & Brand) - 更加现代、沉稳
# -------------------------------------------------------------
PRIMARY = "#3B82F6"          # 浅色下使用沉稳科技蓝 (或保留 "#4F46E5" 但降低辅色饱和度)
PRIMARY_HOVER = "#2563EB"
PRIMARY_SOFT = "#EFF6FF"     # 选中背景更柔和清透 (之前为 #EEF2FF)
PRIMARY_PRESSED = "#DBEAFE"

# -------------------------------------------------------------
# 2. 深浅模式表面层级 (Surfaces & Elevation)
# -------------------------------------------------------------
# 浅色模式保持清爽白底，增加细微卡片灰
BG_MAIN = "#F8FAFC"          # 窗体底层背景 (Slate-50)
BG_SURFACE = "#FFFFFF"       # 卡片、表格表面纯白
BG_CARD = "#FFFFFF"
BG_SUBTLE = "#F1F5F9"        # 浅色控件背景 (Slate-100)
BG_SIDEBAR = "#F1F5F9"       # 侧边栏稍深于主背景，形成边界
BORDER = "#E2E8F0"           # 边框更加细腻 (Slate-200)
BORDER_PANEL = "#CBD5E1"     # 面板分割线

# 深色模式：解决死黑问题，拉开背景 (Slate-950) 与卡片 (Slate-900/800) 的层次
DARK_COLORS = {
    "bg_main": "#090D16",            # 最底层背景 (接近纯黑但带微弱深蓝倾向)
    "bg_surface": "#131B2E",         # 主内容卡片/工作区 (清晰拉开层级)
    "bg_sidebar": "#0D1322",         # 侧边栏
    "bg_sidebar_hover": "#1A233A",
    "bg_card": "#182238",            # 控件卡片背景
    "bg_subtle": "#1E2942",          # 输入框、按钮底色
    "bg_alternate": "#0F1626",       # 表格斑马纹
    "bg_hover": "#253352",
    "bg_switch_hover": "#253352",
    "bg_focus": "#253352",
    "primary": "#3B82F6",
    "primary_hover": "#60A5FA",
    "primary_soft": "#172554",       # 深色选中态 (深蓝底)
    "primary_pressed": "#1E3A8A",
    "border": "#222F4D",             # 细腻边框
    "border_panel": "#2A3B61",
    "border_hover": "#475569",
    "border_focus": "#3B82F6",
    "text_main": "#F8FAFC",          # 高对比主文字
    "text_sub": "#94A3B8",           # 次要文字
    "text_header": "#E2E8F0",
    "text_muted": "#64748B",
    "text_on_primary": "#FFFFFF",
    "text_primary": "#60A5FA",
    # ... 其余 semantic 与 diff 颜色保持映射
}
```

### 1.2 修复 LaneMapping 调色板与文字对比度
原调色板颜色过亮且对比度失真。替换为更具工程严谨感的专业调色板：

```python
# 更加协调、专业的通道颜色 (Indigo, Teal, Violet, Amber, Emerald, Rose)
LANE_GRID_PALETTE = (
    "#4F46E5",  # CtrlA: 靛青
    "#0D9488",  # CtrlB: 蓝绿/Teal
    "#7C3AED",  # CtrlC: 紫罗兰
    "#D97706",  # CtrlD: 暖琥珀
    "#059669",  # 备用: 翠绿
    "#E11D48",  # 备用: 玫红
)

def get_contrasting_text_color(hex_color: str) -> str:
    """根据背景色的相对明度 (Luminance) 自动返回黑色或白色文本，确保 WCAG AA 达标。"""
    color = hex_color.lstrip('#')
    r, g, b = [int(color[i:i+2], 16) for i in (0, 2, 4)]
    # 相对明度公式
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    return "#000000" if luminance > 0.55 else "#FFFFFF"
```

### 1.3 增加尺寸与排版常量
```python
FORM_MAX_WIDTH = 760           # 表单最大内容宽度
DOCS_MAX_WIDTH = 840           # 文档最大阅读宽度
DRAWER_COLLAPSED_HEIGHT = 34   # 底部日志抽屉收起高度
DRAWER_EXPANDED_HEIGHT = 200   # 底部日志抽屉展开高度
```

---

## 四、模块 2：QSS 全局样式与组件精修 (`app.qss`)

**文件路径**：`src/plm/frontend/qt/styles/app.qss`

### 2.1 Tab 栏美化（由生硬药丸改为现代化选项卡）
替换当前 `QTabWidget#ConfigTabs` 的样式，支持优雅的下划线指示条（Underline Tab）或精致胶囊：
```css
/* 现代化 Segmented / Underline Tab */
QTabWidget#ConfigTabs QTabBar {
    background: transparent;
    border-bottom: 1px solid $border;
    margin-bottom: 12px;
}
QTabWidget#ConfigTabs QTabBar::tab {
    background: transparent;
    color: $text_sub;
    padding: 8px 18px;
    margin-right: 4px;
    border: none;
    border-bottom: 2px solid transparent;
    font-size: 13px;
    font-weight: 500;
}
QTabWidget#ConfigTabs QTabBar::tab:hover {
    color: $text_main;
    background-color: $bg_subtle;
    border-top-left-radius: 6px;
    border-top-right-radius: 6px;
}
QTabWidget#ConfigTabs QTabBar::tab:selected {
    color: $primary;
    font-weight: 600;
    border-bottom: 2px solid $primary;
    background-color: transparent;
}
```

### 2.2 表格组件精细化（Controller / Signals 表格）
消除生硬的纯灰底，增加微边框、悬浮态与更舒服的行高：
```css
QTableWidget {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: 8px;
    gridline-color: $border;
    selection-background-color: $primary_soft;
    selection-color: $text_main;
    outline: none;
}
QHeaderView::section {
    background-color: $bg_subtle;
    border: none;
    border-bottom: 1px solid $border;
    border-right: 1px solid $border;
    padding: 8px 12px;
    font-size: 12px;
    font-weight: 600;
    color: $text_sub;
    text-transform: uppercase;
}
QTableWidget::item {
    padding: 6px 12px;
    border-bottom: 1px solid $border;
}
QTableWidget::item:hover {
    background-color: $bg_hover;
}
```

### 2.3 卡片化表单容器与分组（QGroupBox / Form Cards）
用于 Generation 页面与设置页面的卡片化容器：
```css
QGroupBox#FormCard {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: 10px;
    margin-top: 18px;
    padding: 16px 20px 20px 20px;
    font-weight: 600;
    font-size: 14px;
    color: $text_main;
}
QGroupBox#FormCard::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    left: 14px;
    padding: 0 6px;
    background-color: $bg_surface;
}
```

### 2.4 主 CTA 按钮（生成按钮）增强
让“生成”按钮具备视觉重心：
```css
QPushButton#ConfigGenerateButton {
    background-color: $primary;
    border: none;
    border-radius: 6px;
    padding: 8px 24px;
    font-size: 14px;
    font-weight: 600;
    color: #FFFFFF;
}
QPushButton#ConfigGenerateButton:hover {
    background-color: $primary_hover;
}
QPushButton#ConfigGenerateButton:pressed {
    background-color: $primary_pressed;
}
QPushButton#ConfigGenerateButton:disabled {
    background-color: $bg_subtle;
    color: $text_muted;
    border: 1px solid $border;
}
```

---

## 五、模块 3：主窗体布局与日志抽屉化改造 (`main_window.py`)

**文件路径**：`src/plm/frontend/qt/main_window.py`

### 3.1 改造核心思路
1. **取消强制 200px 常驻霸屏**：
   * 原代码：`self.content_splitter.addWidget(self.config_page)` 与 `self.log_panel`，`self._log_sizes = [700, 200]`。
   * 新方案：将 `LogPanel` 封装为**可折叠抽屉模式**。
   * 默认状态：抽屉处于收起状态（高度仅 34px，作为底部状态栏的一部分，仅露出标题 `>_ 输出 (就绪)` 与清空/展开按钮）。
   * 点击标题或触发生成时：平滑展开至 `200px`；生成完毕无报错时，可自动缩回或由用户一键折叠。

### 3.2 窗体顶部 Header 强化
在 `WindowTitleBar` 或 `ConfigHeader` 中强化工程上下文：
* 原来仅显示纯文本 `demo-project`。
* 改造为：
  ```
  [📁 项目图标] demo-project   [· 已保存 / ● 未保存 (橙色)]   [C:/Users/1/Desktop/code/plm/demo]
  ```
  让工作区路径作为次要字体呈现，大幅提升开发专业度。

---

## 六、模块 4：核心工作区各页面结构重塑

### 4.1 Controller 与 Signals 表格页
**涉及文件**：`src/plm/frontend/qt/widgets/tables.py`、`config_editor.py`

#### 改造点：
1. **添加表格操作工具栏**：
   * 在表格上方增加水平工具栏：
     * `[+ 添加行]` 按钮
     * `[- 删除选中行]` 按钮
     * `[📋 复制行]` 按钮
     * `[🔍 搜索过滤]` 输入框（当信号有几十个时尤其有用）
2. **表头语义中文化与副标题**：
   * `ctrl_id` -> **编号 (ID)**
   * `ctrl_name` -> **控制器名称 (Name)**
   * `max_width` -> **最大通道位宽 (Max Width)**
   * `signal_name` -> **信号名称**
   * `direction` -> **方向 (Direction)**（去掉突兀的 `⇄` 符号，改用标准的 `in`、`out` 标签或微型 Badge）
   * `safe_state` -> **安全状态**
   * `tie_off` -> **绑死状态 (Tie-off)**
3. **表格最大宽度自适应**：
   * Controller 表格只有 3 列时，将其居中限制在 `max-width: 800px`，避免 4 行数据横向散架铺满 1200 像素。

---

### 4.2 LaneMapping 通道映射调色与排版
**涉及文件**：`src/plm/frontend/qt/widgets/lanegrid.py`

#### 改造点：
1. **消除反差灾难**：
   * 在绘制网格文字时（`painter.drawText(...)`），**严禁写死黑色字体**。必须调用 `get_contrasting_text_color(cell_color)`，深色背景格子强制绘制白色粗体文字，浅色背景绘制深色文字。
2. **顶部控制器图例优化**：
   * 将 `Num of Lanes [x12 v]` 下拉框与 `[CtrlA] [CtrlB] [CtrlC] [CtrlD]` 图例合并在同一行紧凑工具栏中，左侧为通道数选择，右侧为控制器拾色器。
3. **网格视觉提升**：
   * 单元格增加 3px 圆角与 2px 的 Cell Spacing（间距），外层包裹在 `1px solid $border` 的卡片内部，行列标头采用淡灰背景，彻底摆脱“低幼积木感”。

---

### 4.3 Generation 生成配置页卡片化
**涉及文件**：`src/plm/frontend/qt/widgets/config_editor.py`

#### 改造点：
1. **表单卡片化双分组**：
   将目前垂直全宽摊平的 7 个表单项，重构为两个并排（或垂直紧凑的）卡片：
   * **卡片 A：【硬件与架构配置】**
     * PHY 架构 (`original_pipe`)
     * PCLK 模式 (`pclk_as_phy_output`)
     * Connection 总线类型 (`bus`)
     * DPR 选项 (`启用 DPR` 复选框)
   * **卡片 B：【模块与命名规范】**
     * 模块名前缀
     * 文件名前缀
     * 宏名前缀
2. **两列网格排版**：
   * 标签在左（宽度固定 140px，右对齐或左对齐加粗），输入控件在右（固定宽度 280px）。
   * 整体表单容器限制 `max-width: 720px` 居中展示，告别全屏拉伸的空荡感。
3. **生成区域（CTA 区）重构**：
   * 在卡片底部设计专门的 Action Bar：
     * 左侧：状态指示徽章（如 `[● 输出已是最新]` 绿色 Badge，或 `[● 配置已变更，需重新生成]` 橙色 Badge）。
     * 右侧：大号 `[⚡ 立即生成 RTL / Testbench]` 主按钮。

---

### 4.4 Settings 设置页收拢与 Formatter 分组
**涉及文件**：`src/plm/frontend/qt/views/settings_page.py`

#### 改造点：
1. **通用设置页（`04-settings-general.png`）收拢**：
   * 移除全宽拉伸的 `_setting_row`；
   * 将“界面主题”与“默认编辑器”放在一个居中的配置卡片（`max-width: 640px`）中；
   * 每行左侧为“配置标题 + 详细说明小字”，右侧为控件；
   * “保存设置”按钮直接跟随在配置卡片右下方，不再跨越 1000 像素悬空。
2. **格式化工具设置页（`04-settings-formatter.png`）分类折叠**：
   * 严禁 15 个下拉框毫无组织地一列到底！
   * 利用 `QTabWidget` 或折叠卡片（Collapsible Section）分为三组：
     * **分组 1：代码对齐 (Alignment)**：语句对齐、case 分支对齐、类成员对齐、枚举赋值对齐等。
     * **分组 2：代码缩进 (Indentation)**：形参缩进、命名端口缩进等。
     * **分组 3：命名与其它 (Naming & Misc)**。
   * 为每个参数增加简要的中英文 Tooltip 解释其含义。

---

### 4.5 Documentation 文档与 Artifacts 预览页
**涉及文件**：`src/plm/frontend/qt/views/documentation_page.py`、`artifacts_panel.py`

#### 改造点：
1. **文档页面阅读优化**：
   * 增加内容容器 `max-width: 820px` 并水平居中，让文字单行长度符合人类阅读习惯；
   * 标题增加左侧 4px 品牌色装饰条；
   * 代码块采用圆角暗色代码框。
2. **Diff 差异视图优化**（`08-artifacts-diff.png`）：
   * 弱化整片刺眼的粉红色块（原 `#FFEBE9`），采用现代 GitHub 风格的极淡红底（`#FFF1F0` / 深色下 `#3B1C1D`）；
   * Gutter（行号区）与代码区分界清晰；
   * 搜索栏收敛为浮动快捷条（Ctrl+F 呼出，默认不永久霸占顶部一行空间）。

---

## 七、分步实施提示词模板 (Prompt for GPT)

如果你将本任务拆分给 GPT 或其它模型执行，可直接使用以下分步提示词（分批发送，避免一次性生成超出上下文）：

### Prompt 1: 颜色系统与设计 Tokens 重构
```text
请阅读项目中的 src/plm/frontend/qt/styles/tokens.py。
我们需要提升整体界面的工业级质感与对比度合规：
1. 将 LANE_GRID_PALETTE 替换为现代高质感调色板，并实现 get_contrasting_text_color 函数，根据背景色相对明度计算前景色（确保 WCAG AA 4.5:1 对比度标准）。
2. 优化 DARK_COLORS 深色模式配置：拉开底层背景 bg_main (#090D16) 与内容卡片 bg_surface (#131B2E) 的明度差，使卡片有清晰的悬浮感，边框 border 改为细腻的 #222F4D。
3. 在 tokens.py 中补充 FORM_MAX_WIDTH=760、DOCS_MAX_WIDTH=840 等尺寸常量。
请输出修改后的 tokens.py 或精确的 diff。
```

### Prompt 2: QSS 样式表与现代 Tab / 表格美化
```text
请阅读 src/plm/frontend/qt/styles/app.qss。
根据现代桌面工具设计风格重构以下组件样式：
1. QTabWidget#ConfigTabs：由当前的淡紫药丸形状改为现代化 Underline Tab 风格（选中有 2px 主色底边指示条，未选中 hover 有淡背景）。
2. QTableWidget 与 QHeaderView：增加清晰的细分割线、表头统一使用淡色背景与半加粗次要文本，单元格增加悬浮态 hover 背景。
3. 表单卡片 QGroupBox#FormCard 与主按钮 QPushButton#ConfigGenerateButton 的现代化视觉微调。
请提供针对 app.qss 的具体改动代码。
```

### Prompt 3: 底部日志抽屉化与 Controller/Signals 表格优化
```text
请阅读 src/plm/frontend/qt/main_window.py 和 src/plm/frontend/qt/views/log_panel.py。
当前最大的交互问题是底部日志面板（200px）在每个配置页面永久常驻，导致表格空间被严重压缩。
请改造 ContentSplitter 与 LogPanel：
1. 支持将 LogPanel 折叠为 34px 的底部抽屉条，仅显示 ">_ 输出" 和状态文本，点击时展开至 200px。
2. 在 Generation 生成完成或报错时自动唤起展开。
3. 优化窗口顶部标题栏，在项目名旁增加工作区路径与更优雅的状态显示。
```

### Prompt 4: Generation 页面卡片化与设置页 15 下拉框分组
```text
请阅读 src/plm/frontend/qt/widgets/config_editor.py 与 src/plm/frontend/qt/views/settings_page.py。
1. Generation 页面：将全宽摊平的表单改为两个双列卡片（“硬件与架构配置”与“命名规范”），限制最大宽度 760px 居中排版，将“生成”按钮做成醒目的卡片主操作按钮。
2. Settings 页面：
   - 通用设置：限制宽度居中（max-width: 640px），保存按钮跟随在卡片下方，解决跨屏 1000 像素悬空问题。
   - Formatter 页面：将 15 个平铺的 Verible 下拉框按照“对齐配置”、“缩进配置”、“命名及其它”进行折叠/分组展示。
```

