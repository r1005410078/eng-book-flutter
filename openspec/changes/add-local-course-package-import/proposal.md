# 变更：本地课程包导入与 AI 解析流水线（MVP）

## 为什么 (Why)
当前应用处于个人学习的 MVP 阶段，需要在不引入后端和 API Key 管理复杂度的前提下，把原始视频/音频素材快速转成可学习课程。
用户上传的素材通常缺少字幕与结构化讲解信息，因此系统需要自动补齐字幕、翻译、句子级语法与使用场景，并输出 Flutter 可稳定读取的标准资源包。

## 变更内容 (What Changes)
- 新增 `course-package` 能力，定义原始输入目录（raw）和标准输出目录（package）。
- 新增本地异步任务流水线：扫描 -> ffmpeg 预处理 -> 转写 -> 对齐 -> 翻译 -> 语法/场景增强 -> 打包。
- MVP 阶段采用 Human-in-the-loop：AI 增强步骤由用户在 Codex 中主动触发执行，避免引入 API Key 与自动化服务复杂度。
- 新增句子级结构化字段规范（`en/zh/ipa/grammar/usage`）及降级状态字段。
- 新增任务控制命令面（通过 skills/脚本）：新增课程、删除课程、任务查询、暂停、恢复、停止、重试、删除。
- 明确技能与脚本分层：`~/.codex/skills/` 存放技能编排，仓库内 `tools/` 存放可版本化执行脚本。
- 新增全局命令暴露策略：通过 `~/.local/bin` 或等效 PATH 目录提供 `course-pipeline` wrapper，统一转发到项目脚本，避免在 skill 中复制业务逻辑。
- 新增任务完成通知机制：任务状态落盘、事件日志记录、`task watch` 轮询与本地系统通知。
- 明确 Flutter 端仅消费已发布的标准包，不读取中间文件或原始上传目录。

## 影响范围 (Impact)
- Affected specs: `course-package` (new)
- Affected code:
  - `tools/course_pipeline`：本地课程处理流水线与任务控制脚本（单一实现源）
  - `lib/src/features/*/data`：课程包读取与解析
  - `lib/src/features/*/domain`：课程/课时/句子模型扩展
