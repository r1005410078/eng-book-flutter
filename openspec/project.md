# Project Context

## Purpose

本项目是一个**英语学习应用**，致力于帮助用户更高效地提升英语水平。

核心目标：

- 快速构建英语学习的核心功能（如阅读、词汇、听力等）。
- 支持 Vibe Coding（敏捷开发，快速迭代验证想法）。
- 在保持开发速度的同时，建立清晰的架构边界。

当前阶段重点：

- 专注于 MVP (最小可行性产品) 开发。
- 优先适配移动端体验。

## Tech Stack

### 核心技术

- **Flutter 3.x**
- **Dart** (Null Safety)

### 状态管理

- **Riverpod**:
  - 用于全局状态管理和依赖注入。
  - 优势：编译时安全、解耦 UI 与逻辑、易于测试。

### 路由管理

- **go_router**:
  - 声明式路由管理。
  - 支持 Deep Linking 和复杂的导航场景。

### 平台支持

- Android / iOS (首选)
- Web (次选)

## Project Conventions

### Code Style

- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 最佳实践。
- 使用 `flutter_lints` 或 strict rules 进行代码静态分析。
- 保持强类型定义，避免过度使用 `dynamic`。
- 文件命名使用 snake_case (e.g., `user_profile.dart`).
- 类名使用 PascalCase (e.g., `UserProfile`).
- 提交代码前确保运行 `dart format`。

### Architecture Patterns

- 采用 **Feature-first** (按功能分层) 的架构模式。
  - `lib/src/features/`: 包含独立的功能模块 (如 `auth`, `products`)。
  - `lib/src/common/`: 包含通用的 UI 组件和工具类。
- 推荐使用 Riverpod 或 Provider 进行状态管理。
- 保持 UI 层 (Presentation) 与 业务逻辑层 (Domain/Data) 分离。

### Testing Strategy

- **单元测试 (Unit Tests)**: 针对业务逻辑、Models 和 Repositories 编写测试。
- **组件测试 (Widget Tests)**: 针对可复用的 UI 组件编写测试，确保渲染和交互正常。
- **集成测试 (Integration Tests)**: 针对关键的用户完整操作流程进行测试。
- 所有的 Pull Request 必须包含相应的测试代码。

### Git Workflow

- 主分支: `main` (生产环境/稳定版本)。
- 开发分支: 基于 `main` 创建特性分支。
- 分支命名规范:
  - 功能开发: `feat/feature-name`
  - 修复 Bug: `fix/bug-description`
  - 代码重构: `refactor/change-description`
- 提交信息 (Commit Message) 遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范:
  - `feat: add user login page`
  - `fix: resolve crash on startup`

## Domain Context

### 核心学习理念

本项目深受 **Krashen 的二语习得理论 (Second Language Acquisition)** 和 **100LS 训练法** 的启发，旨在为用户提供高效的英语练习环境。

1.  **低错误成本与大量练习 (Massive Practice with Low Error Cost)**:

    - 与数学等学科不同，英语学习的“错误成本”较低。
    - 语言习得的关键在于**海量的输入与输出练习**，而非死记硬背语法规则。
    - 应用将鼓励用户大胆练习，通过高频次的接触来建立语感。

2.  **Krashen 的“可理解性输入” (Comprehensible Input)**:

    - 学习材料的难度应略高于用户当前的水平 (i+1)。
    - 强调在低焦虑环境下进行习得 (Affective Filter Hypothesis)。

3.  **100LS 训练法 (100 Listen & Speak)**:
    - **Listening**: 反复聆听真实的英语素材（如电影、演讲、有声书）。
    - **Speaking**: 模仿跟读，直到能够同步说出，形成肌肉记忆。
    - 目标是通过 100 遍的听读训练，彻底吃透学习材料，实现从“听懂”到“脱口而出”的质变。

## Important Constraints

[List any technical, business, or regulatory constraints]

## External Dependencies

### 音视频处理库

为了支持 100LS 训练法（海量听读练习），项目依赖以下 Flutter 第三方库：

#### 音频播放（核心功能）

- **just_audio** (`^0.9.36`) ⭐ 核心推荐
  - 功能强大的音频播放库，支持精确控制。
  - 支持倍速播放、AB 循环、精确定位。
  - 支持多种音频格式（MP3, AAC, WAV 等）。
  - 内置缓存支持，适合离线学习场景。
  - **用途**：听力练习、跟读训练的核心播放器。

#### 视频播放（可选）

- **better_player** (`^0.0.83`)
  - 基于官方 `video_player` 封装的增强型播放器。
  - 内置播放控制 UI，支持字幕（SRT, VTT）。
  - 支持 HLS, DASH 流媒体协议。
  - **用途**：播放带字幕的英语视频材料（如 TED, 电影片段）。

#### 录音与跟读

- **record** (`^5.0.0`)
  - 简洁的音频录制库。
  - 支持暂停/继续录制，支持多种编码格式。
  - **用途**：用户跟读录音，用于后续对比或提交。

#### 音频可视化

- **audio_waveforms** (`^1.0.5`)
  - 实时音频波形显示。
  - 美观的播放/录音可视化 UI。
  - **用途**：跟读时的音频反馈，增强交互体验。

#### 后台播放（可选）

- **audio_service** (`^0.18.12`)
  - 支持后台音频播放，锁屏控制。
  - 支持系统通知栏音频控制。
  - **用途**：用户希望在后台继续听力练习（如通勤时）。

### 其他服务

- **待补充**：根据后续需求，可能引入语音识别 API（如 Google Speech-to-Text）或 AI 发音评测服务。
