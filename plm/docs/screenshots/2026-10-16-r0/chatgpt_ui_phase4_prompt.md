# PLM Qt 界面美化与缺陷修复方案（第四阶段：13点后用户反馈全量整改）

> **目标**：根据用户在 13:13 ~ 13:25 之间提出的 8 项具体视觉与交互反馈，进行统一梳理与重构。
> **要求**：严格保持所有 EDA / 硬件专业术语（如 `Num of Lanes`、`Tie-off`、`original_pipe`、`bus` 等）不变；深浅色模式全部适配；既有 403 项自动化测试必须全量通过，并新增针对本轮修改的测试覆盖。

---

## 目录与待解决问题清单

1. **【问题一】底部折叠日志状态条与垃圾桶割裂**（13:13 反馈）
2. **【问题二】LaneGrid 控制器色块拥挤与多控制器排布**（13:14 反馈）
3. **【问题三】设置页“通用”与“工具”界面不对齐**（13:20 反馈）
4. **【问题四】标题栏新增界面主题快捷切换按钮**（13:20 反馈）
5. **【问题五】移除 Artifacts 面板左侧阴影**（13:20 反馈）
6. **【问题六】表格搜索框内清除叉号（`x`）上下居中**（13:22 反馈）
7. **【问题七】表格工具栏“+ 添加行”去除加号**（13:23 反馈）
8. **【问题八】复选框（如启用 DPR）指示器颜色与背景融合看不清**（13:24 反馈）

---

## 一、详细问题分析与具体修改指导

### 1. 底部折叠日志状态条一体化（解决断裂与裸露垃圾桶）

#### 缺陷分析
- `LogCollapsedButton`（左侧大条）是一个带浅灰底色（`$bg_subtle`）、1px 边框与 6px 圆角的独立控件，并在右侧收口。
- 右侧的清空按钮 `LogClearButton`（垃圾桶图标）却脱离在外部白底上，与圆角之间留出 4px 缝隙，形成凹凸不平的破裂感。

#### 修改方案
将底部重构为**一体化胶囊状态栏（Integrated Status Bar Container）**：
外层 `self.collapsed_log_bar` 统一持有底色、描边和圆角，主按钮透明平铺在左侧，清空垃圾桶内嵌在最右侧内部：
```
旧方案：[ 🗖 输出日志 · 输出已过期 (圆角) ]  (空白裂隙)  [ 🗑 ] (裸露悬空)
新方案：╭─────────────────────────────────────────────────────────────╮
        │ 🗖 输出日志 · 输出已过期                                 🗑 │
        ╰─────────────────────────────────────────────────────────────╯
```

#### 代码落地
1. **`src/plm/frontend/qt/main_window.py`**（约 420-438 行）：
   - `self.collapsed_log_bar` 设置：
     ```python
     self.collapsed_log_bar = QtWidgets.QFrame()
     self.collapsed_log_bar.setObjectName("LogCollapsedBar")
     self.collapsed_log_bar.setAttribute(QtCore.Qt.WA_StyledBackground, True)
     self.collapsed_log_bar.setFixedHeight(LOG_COLLAPSED_HEIGHT)
     ```
   - 布局 `collapsed_layout` 边距微调：
     `collapsed_layout.setContentsMargins(0, 0, 4, 0)`，间距 `spacing(0)`。
2. **`src/plm/frontend/qt/styles/app.qss`**：
   ```qss
   QFrame#LogCollapsedBar {
       background-color: $bg_subtle;
       border: 1px solid $border;
       border-radius: $radius_control;
   }
   QPushButton#LogCollapsedButton {
       text-align: left;
       background-color: transparent;
       color: $text_sub;
       border: none;
       border-radius: 0;
       padding: 0 12px;
   }
   QPushButton#LogCollapsedButton:hover,
   QPushButton#LogCollapsedButton:focus:!pressed {
       background-color: transparent;
       color: $text_main;
   }
   QPushButton#LogClearButton {
       background-color: transparent;
       border: none;
       border-radius: $radius_control;
   }
   QPushButton#LogClearButton:hover {
       background-color: $bg_hover;
       color: $text_main;
   }
   ```

---

### 2. LaneGrid 控制器色块拥挤与排布（解决连体与超长/多数控制器）

#### 缺陷分析
- `LaneGrid` 内部的 `_palette_flow` 被硬编码为 `_FlowLayout(h_spacing=0, v_spacing=0)`，导致色块贴合在一起，完全没有水平呼吸间隙。
- 当控制器数量较多（6~12个）或名称较长时，排布需要保证换行自然、间距均匀、不被挤压变形，且与左侧的 `Num of Lanes` 顶部齐平。

#### 修改方案与代码落地
1. **`src/plm/frontend/qt/widgets/lanegrid.py`**：
   - 修复 FlowLayout 间距（约 352 行）：
     ```python
     self._palette_flow = _FlowLayout(h_spacing=SPACING_SM, v_spacing=6)
     ```
     （`SPACING_SM` 为 8px，提供清晰舒适的水平间隙；换行时有 6px 垂直间隙）
2. **`src/plm/frontend/qt/widgets/config_editor.py`**（`LaneMappingWrapper` 约 65-80 行）：
   - `controls` 布局对齐：确保左侧的 `Num of Lanes` 标签和下拉框与右侧 `palette_bar` 在多行时**顶部对齐**（`controls.setAlignment(QtCore.Qt.AlignTop)` 或在首行垂直居中、多行时优雅向上对齐）。
3. **`src/plm/frontend/qt/widgets/controller_swatch.py`**：
   - 维持最大宽度限制 `LANE_SWATCH_MAX_WIDTH = 200`，超长名称右侧平滑省略（保留 `id: ` 前缀），并在 tooltip 中显示完整名称，保证长短控制器排布整齐。

---

### 3. 设置页“通用”与“工具”界面对齐（解决切换跳动与不对齐）

#### 缺陷分析
- “通用”偏好包裹在白底卡片 `QGroupBox#FormCard` 内部，有边框和外边距；
- “工具”（Verible 格式化配置）没有卡片，直接裸露平铺；
- 两个子页面的最大宽度不同（`SETTINGS_MAX_WIDTH=640` vs `FORMATTER_MAX_WIDTH=760`），顶部间距不同（24px vs 12px），导致切换 Tab 时整个界面的宽度、左边缘和上边距剧烈跳动。

#### 修改方案与代码落地
1. **`src/plm/frontend/qt/views/settings_page.py`**：
   - 统一宽度基准：`_show_section(self, index)` 中将两个 section 的最大宽度统一为同一基准（例如统一为 `FORMATTER_MAX_WIDTH = 760` 或 `SETTINGS_MAX_WIDTH`），禁止切换时容器最大宽度发生改变。
   - 统一顶部与左侧边距：
     - 去除 `content_top_spacing.changeSize(0, 12 if is_formatter else 24)` 的不对称设置，统一为一致的顶部间距（如 16px）。
     - 确保“通用”卡片的左边框与“工具”平铺区域的左边线对齐，切换时左侧基准线完全稳定（0 像素漂移）。
   - （可选优雅提升）在“工具”页，将顶部的 Verible 路径和参数选择区同样包裹入卡片容器，或统一切换区域的内边距，使两个 Tab 展现一致的规整感。

---

### 4. 标题栏新增界面主题快捷切换按钮（Sun/Moon 快速切换）

#### 需求与修改方案
- 在主窗口自定义标题栏 `title_bar` 的右侧面板操作区（紧挨在 `log_toggle_button` 与 `artifacts_toggle_button` 旁边），增加一个主题切换图标按钮。
- 当当前主题为浅色时，显示月亮图标（提示“切换到深色模式”）；当当前为深色时，显示太阳图标（提示“切换到浅色模式”）。
- 点击后立即调用 `MainWindow.apply_theme()` 切换并自动保存设置中的偏好，同时刷新设置界面的主题下拉框。

#### 代码落地
1. **新增图标素材**：
   - `src/plm/frontend/qt/assets/icons/sun.svg`：
     ```svg
     <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>
     ```
   - `src/plm/frontend/qt/assets/icons/moon.svg`：
     ```svg
     <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>
     ```
2. **`src/plm/frontend/qt/main_window.py`**：
   - 在 `_create_title_bar` 中创建并添加 `self.theme_toggle_button`：
     ```python
     self.theme_toggle_button = make_icon_button(
         "moon", "切换深色模式", "HeaderButton", ICON_BUTTON_SIZE, ICON_SIZE
     )
     self.theme_toggle_button.clicked.connect(self._toggle_theme_shortcut)
     self.title_bar.add_panel_action(self.theme_toggle_button)
     ```
   - 实现切换逻辑并在 `apply_theme()` 时更新按钮图标与提示：
     ```python
     def _toggle_theme_shortcut(self):
         from plm.frontend.qt.styles.tokens import get_active_theme
         target = "dark" if get_active_theme() == "light" else "light"
         self.apply_theme(target)
         self.settings_store.save_preferences({"theme": target})
         self.settings_page.refresh_theme()

     def _update_theme_toggle_icon(self, theme):
         icon_name = "sun" if theme == "dark" else "moon"
         tooltip = "切换到浅色模式" if theme == "dark" else "切换到深色模式"
         self.theme_toggle_button.setIcon(load_lucide_icon(icon_name, "text_sub"))
         self.theme_toggle_button.setToolTip(tooltip)
     ```

---

### 5. 移除 Artifacts 面板左侧阴影（保持纯净扁平线条）

#### 缺陷分析
- `ConfigPage` 中包含一个 `ArtifactsShadow`（18px 宽的半透明线性渐变遮罩），展开时在 ArtifactsPanel 左侧投射黑色阴影，显得厚重杂乱。

#### 修改方案与代码落地
1. **`src/plm/frontend/qt/views/config_page.py`**：
   - 将 `ArtifactsShadow` 的绘制或尺寸置空（或在 `_position_artifacts` 中保持隐藏）：
     ```python
     self.artifacts_shadow.hide()  # 不再显示渐变投射阴影
     ```
   - 依赖 `ArtifactsPanel` 自身的细边框 `1px solid $border_artifacts`，界面呈现干净、极简的现代分栏线条。

---

### 6. 表格搜索框内的叉号按钮（`x`）上下垂直居中

#### 缺陷分析
- 用户截图显示：`QLineEdit`（搜索框）内部由 `setClearButtonEnabled(True)` 激活的清空叉号图标偏向底部，没有上下垂直居中。
- 原因：QSS 中为 `QLineEdit` 统一定义了 `padding: $field_padding_y $control_padding_x;`，内部子控件 `QToolButton` 未重置 margin 与 padding，或高度被拉伸时 icon 偏离中心。

#### 修改方案与代码落地
1. **`src/plm/frontend/qt/styles/app.qss`**：
   显式定义 `QLineEdit` 内部 `QToolButton`（清除按钮）的样式，使其保持居中：
   ```qss
   QLineEdit QToolButton {
       border: none;
       background: transparent;
       margin: 0;
       padding: 0;
   }
   QLineEdit QToolButton:hover {
       background: transparent;
   }
   ```
2. 在 `src/plm/frontend/qt/widgets/tables.py` 中，如果需要，为 `self.search_input` 设定明确的内容内边距，确保内置 action 图标与文本字体基线、垂直中心绝对居中。

---

### 7. 表格工具栏“+ 添加行”去除加号（统一文本形态）

#### 需求与修改方案
- 现有表格工具栏三按钮为：`+ 添加行`、`复制行`、`删除行`。
- 去除 `+ ` 前缀，改为纯文本 `添加行`，使三个按钮全部保持统一的 3 字符结构，排版整洁对称。

#### 代码落地
- **`src/plm/frontend/qt/widgets/tables.py`**（约 285 行）：
  ```python
  # 修改前:
  self.add_button = QtWidgets.QPushButton("+ 添加行")
  # 修改后:
  self.add_button = QtWidgets.QPushButton("添加行")
  ```

---

### 8. 复选框（如启用 DPR）指示器颜色与可见性

#### 缺陷分析
- 在表单卡片中，`QGroupBox#FormCard QCheckBox` 只有一行 `background: transparent;`，缺少 `QCheckBox::indicator` 的具体样式。
- 导致未选中时没有边框，方框完全融入卡片背景不可见；选中时只浮现一个对勾，没有任何容器框，用户极难发现它是一个可以点击的勾选框。

#### 修改方案与代码落地
1. **新增对勾图标素材**：
   - `src/plm/frontend/qt/assets/icons/check.svg`：
     ```svg
     <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
     ```
2. **`src/plm/frontend/qt/styles/tokens.py`**：
   在 `QSS_TOKENS` 中注册 checkmark 图标路径：
   ```python
   "checkmark_icon": (ICON_DIR / "check.svg").as_posix(),
   ```
3. **`src/plm/frontend/qt/styles/app.qss`**：
   为全应用提供标准、精致的 `QCheckBox` 规范：
   ```qss
   QCheckBox {
       spacing: 8px;
       color: $text_main;
       font-size: $font_size_body;
       background: transparent;
   }
   QCheckBox::indicator {
       width: 16px;
       height: 16px;
       border: 1px solid $border;
       border-radius: 4px;
       background-color: $bg_subtle;
   }
   QCheckBox::indicator:hover {
       border-color: $border_hover;
       background-color: $bg_hover;
   }
   QCheckBox::indicator:checked {
       background-color: $primary;
       border-color: $primary;
       image: url("$checkmark_icon");
   }
   QCheckBox::indicator:checked:hover {
       background-color: $primary_hover;
       border-color: $primary_hover;
   }
   ```
   （未勾选时呈现清晰的 16x16 浅灰底 + 细边框方框；悬停时高亮边框；勾选后填充主题色 `$primary` 并显示高对比白色对勾，深浅色模式均清晰显眼）

---

## 二、验收与测试规范

1. **新增 Phase 4 针对性测试 `tests/test_qt_phase4.py`**：
   - 验证标题栏存在主题快捷切换按钮，点击能往返切换 theme。
   - 验证 `LogCollapsedBar` 统一外框存在，且 `LogCollapsedButton` 与 `LogClearButton` 在同一行内正常响应点击。
   - 验证 `LaneGrid` 中的 Controller 按钮之间 `h_spacing >= 8`。
   - 验证 `QCheckBox::indicator` 具备固定尺寸与边框。
   - 验证表格添加行按钮文本为“添加行”。
   - 验证设置页两 tab 切换时，容器对齐线一致。
2. **全量回归验证**：
   - 运行：`$env:QT_QPA_PLATFORM="offscreen"; uv run python -m unittest discover -s tests -v`
   - 要求：原有 403 项测试必须全部通过，无任何失败和报错。
