# 底部导航独立审查

结论：方案适合当前结构。现状 `AppShellView` 用底部对齐 `ZStack` 将导航叠在各 tab 内容上，四个根页靠 110pt 底部留白补偿；导航自身使用半透明 material，边缘和下方仍可能显示列表。改为 `VStack(spacing: 0)` 为导航实际分配布局高度，可从结构上消除重叠。

实现边界：

- 上部 `rootView.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()`；下部导航使用 `.fixedSize(horizontal: false, vertical: true)` 保留内容所需高度，不要写死数值高度，否则大字体或六语言长标题可能裁切。
- 不透明底色应包住整个底部容器宽度，包括导航横向 22pt 外边距及下方 8pt 空隙；只给胶囊本体加底色不能覆盖两侧与底部。
- 仅底部容器的背景延伸至底部 safe area，例如 `.background(JZColor.background.ignoresSafeArea(.container, edges: .bottom))`。不要让整个内容 VStack 忽略底部 safe area，也不要忽略 keyboard safe area；导航按钮仍应在 Home Indicator 上方。
- 应调整的四页是 `HomeView`、`SourcesView`、`DiscoverySubscriptionsContent`、`RemindersView`（实际 tab 映射见 AppTab）。只将这些根页的旧 110pt 补偿改为 16pt；不批量改详情、表单或 sheet 的间距。
- 保留 AppRootView 的 NavigationStack 和 sandbox 顶部 safeAreaInset，不移动详情/设置到 tab 布局内。当前 root 页 ScrollView 均未自行忽略 safe area，未发现与方案冲突的内部底部 overlay。

真机回归点：

1. 长列表滚到底及底部弹性回弹时，最后一条可完整显示和点击，导航下面、两侧及 Home Indicator 区域均不透出通知。
2. 四个 tab 的登录空态、加载、错误和正常列表没有多余大块底部空白；Home 下拉刷新可用。
3. 明暗模式、横屏、小屏和大字体下，四个按钮可见且不被压缩；底色覆盖整个宽度。
4. 发现页搜索键盘弹出/收起后导航和列表高度恢复，不遮挡输入或留下空隙。
5. 进入通知详情、设置并返回，以及打开/关闭订阅或来源 sheet 后，底部导航只存在于根页；sandbox 顶条仍正常。

本审查只读取源码并写报告；未修改源码、构建、启动模拟器或操作 UI。以上是结构审查，不是已通过的真机视觉验收。
