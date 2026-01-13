# 开发任务列表

- [ ] **Setup**: 创建 `lib/src/features/home/presentation/` 目录结构。
- [ ] **Models**: 定义 `LearningUnit` 和 `UserProgress` 简单模型（用于 Mock 数据）。
- [ ] **UI - Components**:
  - [ ] `HomeHeader`: 实现顶部导航栏（火苗、标题、书本图标）。
  - [ ] `ProgressOverviewCard`: 实现头部大卡片（圆环进度、文字统计）。
  - [ ] `LearningPathNode`: 实现单个学习节点组件（支持 Completed, Active, Locked, Milestone 状态）。
  - [ ] `PathConnector`: 实现节点间的虚线连接。
- [ ] **UI - Screen**:
  - [ ] `HomeScreen`: 组装所有组件，构建垂直滚动的学习路径。
  - [ ] 实现 Mock 数据填充 (4-5 个节点展示不同状态)。
- [ ] **Routing**:
  - [ ] 更新 `app_router.dart`，移除临时 `HomeScreen`，通过 Import 引入新的 `HomeScreen`。
- [ ] **Integration**:
  - [ ] 点击 "正在学习" 节点跳转到 `SentencePracticeScreen` (路由 `/practice/sentence/:id`)。
