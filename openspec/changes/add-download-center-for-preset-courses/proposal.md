# Change: Add Download Center For Preset Courses

## Why
当前课程主要来自本地导入，用户首次使用门槛较高。为了降低启动成本，需要提供可直接下载的预置课程，并与现有本地课程播放链路无缝接入。

## What Changes
- 移除首页与课程选择中的本地视频 mock 数据依赖，不再以内置 mock 课程作为默认可学习内容。
- 新增首页“空课程引导”状态：当本地无可学习课程时展示引导页，并提供一键进入下载中心的 CTA。
- 新增“下载中心”能力：展示预置课程列表，支持分类筛选、下载、暂停/继续、安装、删除。
- 课程下载完成后安装到本地目录，并复用现有本地课程包解析与播放能力。
- 每条课程支持左滑删除（下载中/暂停/失败/已下载），删除时清理下载缓存或安装目录。
- 下载与安装引入完整性校验（hash），并提供失败回滚与可见错误状态。
- 统一课程来源抽象：本地导入课程与下载课程使用同一读取入口。

## MVP Scope
- 移除本地内置 mock 课程与 mock 视频数据作为首页默认数据源。
- 当本地课程为空时，首页显示引导下载中心的空状态页面。
- 远端 `catalog.json` + `zip` 课程包下载与安装。
- 下载进度展示、暂停/继续、失败重试。
- 课程左滑删除（含确认弹窗）。
- 本地课程列表自动合并“手动导入 + 下载中心安装”。

## Future Enhancements
- 断点续传跨重启恢复。
- 可更新（版本升级）策略与增量下载。
- 空间管理与批量清理。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/home/presentation/*`
  - `lib/src/features/home/data/*`
  - `lib/src/features/practice/data/local_course_package_loader_*`
  - `lib/src/features/practice/data/mock_data.dart`
  - `lib/src/features/practice/application/*`
  - `lib/src/features/practice/presentation/*`
  - `lib/src/routing/*`
