# Change: Refactor Remove Zombie Code

## Why
当前代码库存在一批已无入口、无调用链的历史页面与路由常量，继续保留会增加维护成本，并让规范与实际实现发生漂移。

## What Changes
- 删除未被引用的历史 UI 代码与路由常量（僵尸代码）。
- 清理对应导入、路由注册与跳转分支，保证主学习链路保持最小可用。
- 更新 `ui` 规范，移除已废弃的“课程选择/课程详情”要求，统一到当前小视频首页主路径。
- 保留仍在使用的本地课程包播放、阅读模式入口与播放设置能力。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/practice/presentation/widgets/practice_controls.dart`
  - `lib/src/features/home/presentation/course_selection_screen.dart`
  - `lib/src/features/home/presentation/course_detail_screen.dart`
  - `lib/src/routing/routes.dart`
  - `lib/src/routing/app_router.dart`
