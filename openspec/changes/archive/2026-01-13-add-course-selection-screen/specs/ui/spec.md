# key: add-course-selection-screen

# UI Spec: 课程选择页面

## ADDED Requirements

### Requirement: 入口

必须 (MUST) 通过首页右上角的特定图标打开课程选择页面。

#### Scenario: 打开选择页

- **Given** 用户在首页
- **When** 用户点击右上角的“书本/菜单”图标
- **Then** 课程选择页面应以全屏弹窗的形式出现

### Requirement: 分类筛选

页面必须 (MUST) 显示一个横向滚动的分类列表。

#### Scenario: 选择分类

- **Given** 筛选栏显示“全部”、“我的”等
- **When** 用户点击“视频”
- **Then** 该标签变为激活状态（橙色背景）
- **And** 课程列表仅显示视频类型的课程（Mock 逻辑：更新 UI 状态即可）

### Requirement: 课程网格

页面必须 (MUST) 以网格布局展示课程。

#### Scenario: 查看课程

- **Given** 用户查看网格列表
- **Then** 每个卡片显示封面图、标题、章节数
- **And** 正在学习的课程显示“继续学习”标签
- **And** 不同的图标代表不同的媒体类型（播客 vs 视频） - (Mock 数据)
