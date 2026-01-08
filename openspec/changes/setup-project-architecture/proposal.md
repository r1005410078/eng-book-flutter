# Change: 搭建项目基础架构

## Why

在实现具体功能之前，需要建立清晰的项目结构，以确保：

- 代码组织有序，易于维护和扩展
- 团队（或未来的开发者）能快速理解项目结构
- 为后续功能开发提供统一的规范

目前项目使用默认的 Flutter 模板结构，不适合中型项目的长期发展。

## What Changes

- ✅ 采用 **Feature-First** 架构模式
- ✅ 创建分层目录结构（features, common, routing）
- ✅ 初始化核心文件：
  - `app.dart` - 应用根组件
  - `app_router.dart` - 路由配置（go_router）
  - `app_theme.dart` - 主题配置
- ✅ 为已计划的功能预留目录结构
- ✅ 保留 `main.dart` 作为应用入口

## Impact

### 新增能力

- **Specs**: `project-structure`（新建）

### 涉及代码

- `lib/src/` - 新建源代码目录
- `lib/src/features/` - 功能模块目录
- `lib/src/common/` - 共享代码目录
- `lib/src/routing/` - 路由管理目录
- `lib/app.dart` - 应用根组件
- `lib/main.dart` - 更新入口文件

### 依赖

- `go_router: ^14.8.1` (已添加)
- `flutter_riverpod: ^2.6.1` (已添加)
