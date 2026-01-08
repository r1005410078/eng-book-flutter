## ADDED Requirements

### Requirement: Feature-First 目录结构

系统 SHALL 采用 Feature-First 架构模式组织代码，确保功能模块之间解耦且易于扩展。

#### Scenario: 功能模块独立性

- **GIVEN** 项目包含多个功能模块（如音频播放、材料管理）
- **THEN** 每个功能模块应在 `lib/src/features/[feature-name]/` 目录下独立存在
- **AND** 模块内部包含 `models/`, `providers/`, `screens/`, `widgets/` 子目录

#### Scenario: 共享代码隔离

- **GIVEN** 多个功能模块需要使用相同的 UI 组件或工具函数
- **THEN** 这些共享代码应放置在 `lib/src/common/` 目录下
- **AND** 按类型分类（widgets, utils, constants, theme）

---

### Requirement: 应用入口与路由配置

系统 SHALL 提供清晰的应用入口和路由管理机制。

#### Scenario: 应用启动流程

- **GIVEN** 用户启动应用
- **WHEN** `main.dart` 被执行
- **THEN** 应用应初始化 Riverpod ProviderScope
- **AND** 加载 `App` 组件作为应用根

#### Scenario: 路由管理

- **GIVEN** 应用使用 go_router 进行路由管理
- **THEN** 所有路由配置应集中在 `lib/src/routing/app_router.dart` 中
- **AND** 路由路径常量应定义在 `lib/src/routing/routes.dart` 中

---

### Requirement: 主题配置

系统 SHALL 提供统一的主题配置，确保 UI 风格一致。

#### Scenario: 应用主题

- **GIVEN** 应用需要统一的视觉风格
- **THEN** 主题配置应定义在 `lib/src/common/theme/app_theme.dart` 中
- **AND** 包含亮色和暗色主题（如果适用）

#### Scenario: 主题应用

- **GIVEN** 用户打开应用
- **THEN** 应用应使用配置的主题渲染所有页面
- **AND** 主题应通过 `MaterialApp` 的 `theme` 属性统一应用

---

### Requirement: 代码组织规范

系统 SHALL 遵循统一的代码组织规范，确保项目可维护性。

#### Scenario: 文件命名规范

- **GIVEN** 开发者创建新文件
- **THEN** 文件名应使用 snake_case 命名（如 `audio_player_screen.dart`）
- **AND** 类名应使用 PascalCase 命名（如 `AudioPlayerScreen`）

#### Scenario: 目录结构一致性

- **GIVEN** 新增功能模块
- **THEN** 模块目录结构应遵循 `models/`, `providers/`, `screens/`, `widgets/` 的标准布局
- **AND** 如果某个子目录暂时为空，可以稍后创建
