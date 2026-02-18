## REMOVED Requirements
### Requirement: 分类筛选
**Reason**: 课程分类筛选页已从当前主学习流移除，不再有可达入口。
**Migration**: 使用首页小视频主学习流与右上角阅读模式入口替代课程分类入口。

### Requirement: 课程网格
**Reason**: 课程网格页面已废弃，当前实现不再提供该交互。
**Migration**: 课程切换改为学习流内切换（句子/单元）与本地课程包加载。

### Requirement: 课程详情查看
**Reason**: 课程详情页在当前版本无调用链，保留会造成规范与实现不一致。
**Migration**: 用户直接进入首页学习流，无需先进入课程详情。

## MODIFIED Requirements
### Requirement: 入口
必须 (MUST) 通过首页右上角图标进入阅读模式页面，而不是进入课程选择页面。

#### Scenario: 打开阅读模式
- **Given** 用户在首页小视频学习流
- **When** 用户点击右上角图标
- **Then** 应用跳转到当前句子的阅读模式页面
- **And** 阅读模式应保持当前课程上下文（如 `package` 与 `course` 参数）
