# CURRENT_UI_COLOR_SYSTEM

文档状态：当前 macOS UI / 颜色 / 字体合同
最近核对：2026-08-28
产品基线：v0.10（build 49）

## 当前视觉方向

Councis 使用 Apple 系统动态外观，不把浅色/深色解释为固定白色、黑色、暖色或
品牌 Hex：

- window/detail canvas 使用动态 `windowBackground`；
- sidebar 由 `NavigationSplitView` 与系统 sidebar material拥有；
-文字使用 `.primary`、`.secondary` 和系统 accent；
-边界使用动态 separator；
-导航与交互控件在支持的系统上使用原生 Liquid Glass；
-不得自绘玻璃、固定渐变、阴影光晕或采样别的产品配色。

`docs/UI_COLOR_SYSTEM.md` 只保存上一版暖中性/香槟色历史，不是当前规范。

## 实现所有权

Councis App层：

- `Apps/CouncisMac/Sources/CouncisDesign.swift`：系统动态颜色、
  `IntatisThreadStyle.councisMac` 与 App-local surfaces；
- `CouncisMacRootView.swift`：Cowork-only navigation、Sidebar、Recent/New/Settings；
- `CouncisSessionNewAction.swift`：保持两项 New 菜单；
- `CouncisMacApp.swift`：Code/Cowork composition与inspector；
- Councis图标、本地化和产品文案。

共享实现直接来自：

```text
/Users/vita/Vitemis/Intatis/Packages/IntatisSharedUI
```

其中包含thread/composer/rail、message renderer、native glass helpers、
JetBrains Mono typography和accessibility plumbing。Councis不复制SharedUI或
renderer，只在App composition边界提供自己的主题与可见文案。

## 对话层级

- user：唯一普通气泡，使用native regular glass；
- assistant/agent/system：正文直接位于canvas，不添加普通卡片背景；
- permission/task/error/Goal/MCP：保留结构化surface；
- Stop：系统destructive red；
- selected/active状态使用系统accent，不写死蓝色或金色；
- Markdown/LaTeX/code内容不因App配色而改写源文本。

## 字体

可见产品字体由当前 IntatisSharedUI 资源注册：

- Latin/English：JetBrains Mono；
- 简体中文：同字重Apple中文fallback；
- Markdown prose/code/selection继承共享configuration；
- LaTeX继续由iosMath自己的数学字体排版。

Councis不再分发一份独立的16-static-face SharedUI字体runtime；字体源码、
资源、hash和许可证由唯一Intatis checkout维护并随其resource bundle链接。
视觉验收仍须证明名义size/weight、中文fallback和数学字体隔离没有回归。

## Cowork-only 与 New 菜单

- macOS根导航只显示Cowork；
- Chat/Code兼容实现和CLI仍编译，但不显示为平行模式；
- Sidebar `+`与空白页`New`只显示`Choose Folder…` / `No Folder`；
- 不增加说明卡、第三种模式或独立工作区页面；
- `No Folder`继续创建owner-only、per-session managed workspace。

## 不可破坏项

- 不把其他产品或Intatis视觉/品牌文案带入Councis；
- 不把内部`Intatis*` Swift type名称误当作用户品牌问题；
- 不为重命名内部类型复制SharedUI/renderer；
- 不恢复本地`Vendor/SwiftStreamingMarkdown`；
- 不恢复消息粒度自制缓存、远程Markdown图片或模型输出代码执行；
- UI投影不得改变EventLog、runtime thread、permission或tool事实。

## 验证

至少检查：

1. `CouncisDesign.swift`没有固定RGB/Hex背景；
2. root navigation仍为Cowork-only；
3.两项New菜单仍存在；
4. `CouncisMac`编译`IntatisSharedUI`；
5. Light/Dark、Increase Contrast、Reduce Transparency；
6. Agents rail、Goal、Tasks、permission、error、MCP和composer布局；
7. JetBrains Mono、中文fallback、Markdown与LaTeX；
8. `scripts/check-brand-boundary.sh`；
9.最终App资源/NOTICE inventory。

未运行真实GUI/VoiceOver时必须标记为`UNKNOWN`，不能仅凭build通过宣称视觉完全验收。
