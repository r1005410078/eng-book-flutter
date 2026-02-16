## ADDED Requirements
### Requirement: 原始课程目录导入 (Raw Course Folder Ingestion)
The system MUST support importing raw course assets from a local folder and build lesson order by numeric key.

#### Scenario: 仅上传媒体文件
- **WHEN** 用户上传仅包含 `01_xxx.mp4`、`02_xxx.mp3` 这类有序媒体文件的目录
- **THEN** 系统必须按编号识别课时并创建处理任务
- **AND** 不得因为缺少字幕或 Markdown 直接拒绝导入

#### Scenario: 编号匹配附属文件
- **WHEN** 目录中存在 `01.md`、`01.en.srt`、`01.zh.srt` 等附属文件
- **THEN** 系统必须通过编号 `01` 关联到对应课时
- **AND** 不得依赖标题字符串进行匹配

### Requirement: 本地 AI 解析流水线 (Local AI Parsing Pipeline)
The system MUST execute a local course parsing pipeline as an asynchronous task and expose retryable stage states.

#### Scenario: 阶段化处理
- **WHEN** 新课程任务开始处理
- **THEN** 系统必须按 `ffmpeg -> asr -> align -> translate -> grammar -> summary -> package` 顺序执行
- **AND** 每个阶段必须记录独立状态（`pending/running/done/failed`）

#### Scenario: 阶段失败与重试
- **WHEN** 任一阶段失败
- **THEN** 任务状态必须变为 `failed` 并记录错误码与失败阶段
- **AND** 用户必须可以从指定阶段发起重试

#### Scenario: Human-in-the-loop 触发 AI 步骤
- **WHEN** 任务进入 `translate`、`grammar` 或 `summary` 阶段
- **THEN** 系统必须支持由用户通过 Codex 命令 `task run-step <task_id> <step>` 主动触发执行
- **AND** 执行完成后必须回写阶段状态与输出文件路径

### Requirement: 标准课程包输出 (Normalized Package Output)
The system MUST output a stable normalized course package that Flutter clients can read directly.

#### Scenario: 课程包目录结构
- **WHEN** 任务处理成功
- **THEN** 系统必须输出 `course_manifest.json` 与 `lessons/{lesson_id}/lesson.json`
- **AND** 每个课时目录必须包含标准化媒体文件与字幕文件路径

#### Scenario: 句子级学习数据
- **WHEN** 生成 `lesson.json`
- **THEN** 每个句子必须包含 `sentence_id`、时间轴、`en`、`zh`、`ipa`、`grammar.pattern`、`usage.scene`
- **AND** 必须包含 `translation_ready`、`ipa_ready`、`grammar_ready`、`usage_ready` 状态字段

### Requirement: 任务控制命令接口 (Task Control Commands)
The system MUST provide scriptable command interfaces for course task management.

#### Scenario: 查询任务
- **WHEN** 用户执行 `task get <task_id>` 或 `task list`
- **THEN** 系统必须返回任务当前状态、阶段进度、失败信息与最近更新时间

#### Scenario: 控制任务生命周期
- **WHEN** 用户执行 `task pause`、`task resume`、`task stop`、`task delete` 或 `task retry`
- **THEN** 系统必须执行对应状态迁移并返回结构化 JSON 结果

### Requirement: 技能编排与任务通知 (Skill Orchestration And Task Notification)
The system MUST separate skill orchestration from executable pipeline scripts and provide completion notifications for long-running tasks.

#### Scenario: 技能与脚本位置约束
- **WHEN** 实现课程处理命令接口
- **THEN** 技能编排必须位于 `~/.codex/skills/course-pipeline-ops`
- **AND** 可执行脚本必须位于仓库内 `tools/course_pipeline`

#### Scenario: 全局命令暴露与单一实现源
- **WHEN** 需要在终端和 skill 中统一调用课程流水线命令
- **THEN** 系统必须提供全局命令 `course-pipeline` 作为 wrapper 或 symlink
- **AND** 全局命令必须仅转发到项目脚本 `tools/course_pipeline/course_pipeline_ops.py`
- **AND** skill 不得内置或复制项目业务脚本实现

#### Scenario: 任务完成通知
- **WHEN** 用户执行 `task watch <task_id>` 并且任务进入 `ready` 或 `failed`
- **THEN** 系统必须输出最终任务摘要并触发一次本地系统通知
- **AND** 必须将最终状态写入 `runtime/tasks/<task_id>.json` 且追加事件到 `runtime/tasks/events.log`

### Requirement: Flutter 消费约束 (Flutter Consumption Contract)
The system MUST ensure the client consumes only published course packages and never depends on intermediate artifacts.

#### Scenario: 仅读取 ready 课时
- **WHEN** Flutter 加载课程清单
- **THEN** 客户端必须仅展示 `ready` 状态课时
- **AND** 不得直接读取 raw 上传目录或处理中间文件

#### Scenario: 资源缺失降级
- **WHEN** 某课时缺失可选增强内容（如语法细项或替代表达）
- **THEN** 客户端必须使用降级展示并保持页面可用
- **AND** 不得因为可选字段缺失导致页面崩溃
