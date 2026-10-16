# PLM Qt 界面美化与缺陷修复方案（第五阶段：16点后反馈深度收口）

> **目标**：彻底解决用户在 16:26 ~ 16:30 提出的 5 项核心体验与审美缺陷。
> **要求**：保留所有 EDA / 硬件专业英文术语；严格保持所有自动化测试 100% 通过（修改相关已过时的折叠栏断言，补充新契约）；确保深色模式优雅高级、无跳动、无断裂。

---

## 目录与待解决清单

1. **【问题一】彻底隐藏/移除底部折叠日志条（`collapsed_log_bar`）**
2. **【问题二】LaneMapping 右键上下文菜单与其它表格彻底统一（中文化+矢量图标）**
3. **【问题三】设置与文档页面边框跳动修复：将返回按钮收纳进画布卡片内**
4. **【问题四】表格单元格编辑与项目名称重命名时，输入框文字跳动/位移修复**
5. **【问题五】暗色模式全新调色升级（从浑浊深蓝升级为现代炭黑/中性冷灰 IDE 质感）**

---

## 一、详细问题分析与具体修改指导

### 1. 彻底隐藏底部折叠日志条（解决界面风格不统一与垂直空间挤占）

#### 缺陷分析
- 底部常驻的折叠状态栏（`collapsed_log_bar`）强行占据了 34px 垂直高度，与上方白色/暗色画布卡片风格不统一，割裂感强。
- 实际上，标题栏右侧已有专用的 `panel-bottom` 输出日志切换按钮，且生成代码时会自动展开日志面板。
- 用户明确要求：“**我觉得还是直接隐藏好**”。

#### 修改方案与代码落地
1. **`src/plm/frontend/qt/main_window.py`**：
   - 默认隐藏 `collapsed_log_bar`（或直接不将其添加到布局中显示）：
     - 在 `_setup_ui` 中，设置 `self.collapsed_log_bar.hide()`。
     - 在 `hide_log(self)` 中，隐藏面板后**不要**调用 `self.collapsed_log_bar.show()`，保持 `self.collapsed_log_bar.hide()`。
     - 在 `show_log(self)` 中，保持原逻辑展开 `log_panel`。
     - 确保标题栏的 `log_toggle_button` 正常切换 `log_panel` 的展开与收起。
     - 这样主配置卡片（`ConfigPage`）可以无缝占满整个高度，底部没有任何突兀残留！
2. **测试适配（`tests/`）**：
   - 更新 `test_qt_redesign.py`、`test_qt_phase4.py` 等测试中对 `collapsed_log.isVisible()` 的断言，改为断言其默认处于 `isHidden()` 状态，并通过标题栏 `log_toggle_button` 或 `show_log()` 验证日志面板的展开与关闭。

---

### 2. LaneMapping 右键菜单与其它表格统一（语言+图标）

#### 缺陷分析
- 用户截图显示：`LaneGrid` 表格右键菜单仍然是英文文本且缺少图标：
  `Insert row above` / `Insert row below` / `Delete current row`。
- 控制器表和信号表早已使用标准中文与 Lucide 矢量图标：
  `[arrow-up] 在上方插入行` / `[arrow-down] 在下方插入行` / `[trash-2] 删除当前行`。

#### 代码落地
在 **`src/plm/frontend/qt/widgets/lanegrid.py`**（约 778-787 行）：
```python
# 修改前:
menu = StyledMenu(self.table)
if row >= 0:
    insert_above = menu.addAction("Insert row above")
    insert_below = menu.addAction("Insert row below")
    menu.addSeparator()
    delete_current = menu.addAction("Delete current row")
else:
    insert_above = None
    insert_below = menu.addAction("Insert row")
    delete_current = None

# 修改后 (引入 load_lucide_icon 与 ICON_SIZE):
menu = StyledMenu(self.table)
if row >= 0:
    insert_above = menu.addAction(load_lucide_icon("arrow-up", "text_sub", ICON_SIZE), "在上方插入行")
    insert_below = menu.addAction(load_lucide_icon("arrow-down", "text_sub", ICON_SIZE), "在下方插入行")
    menu.addSeparator()
    delete_current = menu.addAction(load_lucide_icon("trash-2", "danger", ICON_SIZE), "删除当前行")
else:
    insert_above = None
    insert_below = menu.addAction(load_lucide_icon("arrow-down", "text_sub", ICON_SIZE), "插入行")
    delete_current = None
```

---

### 3. 设置/文档页面边框跳动修复：返回按钮与卡片外框一体化

#### 缺陷分析
- 用户反馈：“这是设置界面的样子，退出后，怎么边框还变化了？为什么设置按钮没有在边框内？”
- 原因：
  - `ConfigPage` 是一个整体的大白底圆角卡片，标题栏下方紧接着就是卡片顶部，项目标题 `ConfigHeader` 在卡片内部。
  - 而 `SecondaryPage`（设置/文档页）中，返回按钮 `← 设置`（`SecondaryPageHeader`）被放在了卡片外面的灰色窗口底色上！下方的 `SecondaryPageArea` 才是卡片。
  - 导致进入设置时，白底卡片凭空下移了 48px 并出现了一圈独立的上边框；退出设置回到主页时，白底卡片又突然上跳贴顶，造成了剧烈的边框突变和“设置按钮游离在框外”的错觉。

#### 修改方案与代码落地
在 **`src/plm/frontend/qt/views/secondary_page.py`**：
1. 重构结构：让 `SecondaryPage` 本身直接使用统一的卡片外框（或将 `SecondaryPageHeader` 放入 `SecondaryPageArea` 的顶部）：
   - `SecondaryPageArea` 顶满上方（移除外部 header 的挤压），或者将 `SecondaryPageHeader` 作为 `SecondaryPageArea` 内部的顶部第一行，左侧与 Tab 严格左对齐。
   - `SecondaryPage` 的外框几何范围与 `ConfigPage` 完全一致（相同的左/上/右/下边距与圆角）。
2. 在 **`src/plm/frontend/qt/styles/app.qss`** 中：
   - 确保 `SecondaryPageArea` 的外边距、圆角与 `ConfigPage` 统一对齐，使打开/关闭设置页面时，底部的白色/暗色卡片外框完全静止不动，只有内部内容切换。

---

### 4. 表格单元格编辑与项目名称重命名时，输入框文字跳动/位移修复

#### 缺陷分析
- 用户截图显示：双击表格单元格或项目名称重命名时，弹出的 `QLineEdit` 带有圆角和大内边距，导致文字瞬间向右下偏移跳动，视觉体验极其晃眼。
- 原因：
  - 全局 QSS 定义了通用 `QLineEdit { padding: 4px 10px; border-radius: 6px; }`。
  - 表格单元格原本的文本内边距是 `padding: 0 8px;`，而且单元格不需要 6px 圆角。
  - 项目标题 `ConfigSessionTitle` 平时内边距为 0，双击变成 `ConfigSessionEditor` 时被应用了 8px~10px padding 和 1px border，导致文字右移。

#### 修改方案与代码落地
在 **`src/plm/frontend/qt/styles/app.qss`**：
1. **针对表格内嵌编辑框（In-place Table Editor）**：
   - 去掉圆角与多余上下边距，使编辑框文字与原有单元格文字像素级重合：
   ```qss
   QTableWidget QLineEdit {
       background-color: $bg_surface;
       border: 1px solid $primary;
       border-radius: 0;
       padding: 0 8px;
       margin: 0;
       color: $text_main;
       selection-background-color: $primary_soft;
       selection-color: $text_main;
   }
   ```
2. **针对标题与项目重命名输入框**：
   - 修正 `QLineEdit#ConfigSessionEditor` 与 `QLineEdit#ProjectNameEditor`：
   ```qss
   QLineEdit#ConfigSessionEditor {
       padding: 0 4px;
       margin: 0;
       border: 1px solid $primary;
       border-radius: $radius_control;
       font-size: $font_size_title;
       font-weight: $font_weight_semibold;
       background-color: $bg_subtle;
   }
   QLineEdit#ProjectNameEditor {
       padding: 0 4px;
       margin: 0;
       border: 1px solid $primary;
       border-radius: $radius_control;
       font-size: $font_size_body;
       background-color: $bg_subtle;
   }
   ```
   同时微调对应 Label 的起始内边距，使双击切换前后文字位置保持稳定、零跳动。

---

### 5. 暗色模式调色升级（从偏蓝发浑升级为现代炭黑/中性冷灰 IDE 质感）

#### 缺陷分析
- 用户反馈：“暗色界面配色不好看，换一种”。
- 当前使用的深色色板偏深蓝且对比度略混（`#0D1117` / `#161B22` / `#21262D` / 偏蓝紫），在文档与表格页呈现出冷蓝黑相间的塑料感。
- 参考现代顶级 IDE（**VS Code Dark Modern / JetBrains New UI / Linear Dark / Tailwind Zinc**）的高级暗色质感：以**中性炭黑与金属冷灰**为基底，搭配纯正高对比度的文字与适度克制的紫/蓝主色。

#### 修改方案与代码落地
在 **`src/plm/frontend/qt/styles/tokens.py`** 中升级 `DARK_COLORS` 色板：

```python
DARK_COLORS = {
    # 窗口与卡片背景：纯正、沉稳的深炭黑阶梯（无浑浊偏蓝）
    "bg_main": "#121316",              # 最底层窗口底色
    "bg_surface": "#1A1B20",           # 主卡片与画布背景（略微提亮，形成清晰层次）
    "bg_subtle": "#22242B",            # 输入框、次级容器、折叠底色
    "bg_hover": "#2B2E38",             # 悬停高亮底色
    "bg_active": "#323642",            # 按压/激活态底色
    "bg_alternate": "#18191E",         # 表格交替行条纹色

    # 侧边栏与头部
    "bg_sidebar": "#0E0F12",           # 侧边栏采用最深色沉底
    "bg_sidebar_hover": "#1D1E24",     # 侧边栏悬停
    "bg_header": "#121316",

    # Artifacts 侧栏
    "bg_artifacts": "#16171C",
    "border_artifacts": "#2A2D36",

    # 主题色与强调色：洗练克制的科技靛蓝（Indigo）
    "primary": "#6366F1",
    "primary_hover": "#818CF8",
    "primary_soft": "#25283D",
    "primary_pressed": "#4F46E5",

    # 边框与分割线：精细、通透的中性冷灰
    "border": "#282B34",
    "border_panel": "#282B34",
    "border_hover": "#3E4351",
    "border_focus": "#818CF8",
    "border_checkbox": "#525866",

    # 文字层次：极佳阅读对比度（WCAG AAA 级清晰）
    "text_main": "#F3F4F6",            # 主标题与正文（高纯度冷白）
    "text_sub": "#9CA3AF",             # 次级说明与未激活 tab（中性中灰）
    "text_header": "#E5E7EB",          # 表头文本
    "text_muted": "#6B7280",           # 占位符与微弱路径
    "text_on_primary": "#FFFFFF",      # 主按钮文字（纯白）
    "text_primary": "#A5B4FC",         # 高亮关键字与下划线

    # 状态色（成功绿、警告黄、危险红、信息蓝）
    "success": "#10B981", "success_bg": "#0D2E23", "success_text": "#34D399",
    "warning": "#F59E0B", "warning_bg": "#332408", "warning_text": "#FBBF24",
    "danger": "#EF4444",  "danger_bg": "#351416",  "danger_text": "#F87171",
    "info": "#3B82F6",    "info_bg": "#12253D",    "info_text": "#60A5FA",
}
```

---

## 二、验收与测试验证

1. **测试用例适配与新增**：
   - 更新既有测试（如 `test_qt_redesign.py`），去除对已隐藏折叠栏可见性的旧假设；
   - 新增 `test_qt_phase5.py`：
     - 验证 `collapsed_log_bar` 处于隐藏状态，点击标题栏日志按钮能正确弹出/收起日志面板；
     - 验证 `LaneGrid` 右键菜单包含 `在上方插入行`、`在下方插入行`、`删除当前行` 且均配备对应的矢量图标；
     - 验证设置页面与主界面的卡片外框基准坐标一致；
     - 验证表格单元格编辑框无额外位移（文字水平起点一致）；
     - 验证新暗色色板 Contrast Ratio $\ge 4.5:1$。
2. **全量回归运行**：
   - 运行 `$env:QT_QPA_PLATFORM="offscreen"; uv run python -m unittest discover -s tests -v`。
   - 要求：全量测试 100% 通过（0 失败，0 错误）。
