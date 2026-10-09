# PLM r6 / 2.0.6

日期：2026-10-09。Python 包版本由 `2.0.5` 升级为 `2.0.6`。

## 本轮改动

- 修复 Qt 主窗口、标题栏、导航栏及 Artifacts 面板的布局和折叠交互；统一尺寸、字体、图标及表格卡片样式。
- 缓存按钮尺寸和窗口阴影，合并表格更新与校验，减少项目加载时的重复处理。
- 设置页按需创建 Formatter 参数表；文档在独立文档对象中完成解析和格式化后一次显示，缩短打开时间。
- 实施统一冷灰色板，区分浅蓝选中态、灰色 hover 和交替行；修正 muted 文字对比度并移除 QSS 硬编码色值。
- Generation 页和 CLI 新增 Connection 总线类型选项 `bus` / `flat`，默认 `bus`。
  - `bus` 保持现有二维数组 `logic [W-1:0] a [0:NL-1]`。
  - `flat` 将每个端口展平为一维向量 `logic [NL * W - 1:0] a`；lane 0 位于低位，lane i 对应 `[i * W +: W]`。
  - 保留各控制器独立端口，选择会保存到工作区，并参与生成状态和撤销/重做。

## 构建与验收

```powershell
uv build
uv run python scripts/check_wheel.py dist/plm-2.0.6-py3-none-any.whl --sdist dist/plm-2.0.6.tar.gz
```

发布检查覆盖包内源码及资源一致性、独立环境中的 CLI 和 Qt 入口、两种 PHY 架构、DPR、flat Connection 端口、设置页及文档页。
