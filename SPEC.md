# 自动连点器 Spec 计划

## 目标

构建一款 Android Flutter 自动连点器。用户在主界面完成无障碍权限和悬浮窗权限授权后，点击启动按钮，在其他应用上展示悬浮按钮组和一个可拖动的圆形十字准星。用户可以移动准星到目标位置，设置点击频率和随机偏移范围，开始或停止点击，并保存上次位置。

## 设计原则

- 所有自动点击都必须由用户主动启动、可随时停止。
- 无障碍服务只执行用户配置的点击动作，不采集敏感输入内容。
- 悬浮窗控制按钮必须始终可见并提供停止/关闭入口。
- 默认启用随机偏移，避免每次命中完全相同坐标。
- UI 使用 `shadcn_ui`，入口采用 `ShadApp.custom + MaterialApp`，主题主色使用 Bilibili 粉 `#FB7299`。

## 功能范围

### 主界面

- 权限状态卡片：无障碍权限、悬浮窗权限。
- 启动按钮：权限齐备后启动 Android 悬浮窗服务。
- 悬浮层预览：展示按钮组和圆形十字准星的视觉状态。
- 设置区域：点击频率、随机偏移半径、启动时加载上次位置。

### 悬浮层

- 悬浮按钮组：开始、停止/关闭、保存位置、打开设置。
- 准星控件：圆形外框 + 十字线，可拖动定位。
- 位置保存：保存准星中心点、按钮组位置、最近设置。
- 状态反馈：运行中、已暂停、权限丢失。

### 点击引擎

- 通过 Android `AccessibilityService.dispatchGesture` 执行点击。
- 点击坐标 = 准星中心点 + 随机偏移。
- 支持频率范围：1-20 次/秒，后续可扩展为毫秒间隔。
- 停止逻辑必须能立刻取消循环任务。

## Android 原生模块

### 权限

- 悬浮窗权限：`Settings.canDrawOverlays`，跳转 `ACTION_MANAGE_OVERLAY_PERMISSION`。
- 无障碍权限：跳转 `Settings.ACTION_ACCESSIBILITY_SETTINGS`，回到 App 后刷新状态。
- Manifest 声明：`SYSTEM_ALERT_WINDOW`、无障碍服务、服务配置 XML。

### 服务

- `FloatingOverlayService`：管理悬浮按钮组和准星窗口。
- `AutoClickAccessibilityService`：执行点击手势，接收启动/停止/更新配置指令。
- `MethodChannel` 或 `EventChannel`：Flutter 与 Android 原生层通信。

### 数据存储

- 首选 Flutter 侧统一保存：点击频率、偏移半径、准星坐标、按钮组坐标。
- Android 服务启动时从 Flutter 传入最新配置。
- 后续如需服务独立恢复，可增加原生 `SharedPreferences` 镜像。

## Flutter 架构

- `lib/main.dart`：启动框架、主题、首页骨架。
- `lib/features/permissions/`：权限状态、跳转授权、状态刷新。
- `lib/features/settings/`：频率和偏移配置。
- `lib/features/overlay/`：悬浮层控制入口和预览状态。
- `lib/platform/android_autoclicker_channel.dart`：平台通道封装。
- `lib/data/app_settings_store.dart`：本地设置存储。

## UI 组件计划

- `ShadCard`：权限卡片、悬浮层预览、设置区域。
- `ShadButton`：启动、授权、保存、关闭。
- `ShadSlider`：点击频率、偏移范围。
- `ShadSwitch`：启动时加载保存位置。
- Lucide 图标：开始、关闭、保存、设置、盾牌、准星。

## 开发阶段

### Phase 1：UI 与 spec 骨架

- 替换默认 Flutter 计数器。
- 配置 `ShadApp.custom + MaterialApp`。
- 设置 Bilibili 淡粉主题。
- 建立首页权限、启动、预览、设置 UI。
- 编写本 spec。

### Phase 2：权限检测与跳转

- 已完成 Android 平台通道。
- 已完成悬浮窗权限检测和跳转。
- 已完成无障碍权限检测和跳转。
- 已完成 Flutter 首页展示真实授权状态。

### Phase 3：悬浮窗服务

- 已完成原生悬浮按钮组。
- 已完成可拖动准星 View。
- 已完成保存并恢复按钮组和准星位置。
- 已完成从 Flutter 启动/关闭悬浮服务。

### Phase 4：无障碍点击引擎

- 已完成 `AccessibilityService` 基础声明与点击入口。
- 已完成频率控制和随机偏移。
- 已完成悬浮按钮组的开始/停止事件。
- 处理权限关闭、服务断开、应用退出等边界状态。

### Phase 5：测试与打磨

- Flutter widget 测试覆盖首页关键状态。
- Android 真机测试权限流程、悬浮窗拖动、点击稳定性。
- 校验不同分辨率和横竖屏坐标转换。
- 增加异常提示和安全停止路径。

## 待确认

- 是否需要多点位点击队列，还是先只做单准星点位。
- 是否需要导入/导出配置。
- 点击频率上限是否固定 20 次/秒。
- 随机偏移使用圆形半径分布还是 X/Y 独立矩形分布。
