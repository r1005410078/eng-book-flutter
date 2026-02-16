## ADDED Requirements
### Requirement: API 客户端配置 (API Client Configuration)
系统必须提供一个统一的 HTTP 客户端用于与后端通信。

#### Scenario: Base URL 配置
- **WHEN** 应用初始化时
- **THEN** 必须初始化 Dio 客户端，并设置 Base URL 为 `http://localhost:8001/api/v1`

#### Scenario: 认证头信息 (Authentication Header)
- **WHEN** 用户处于已登录状态
- **THEN** 所有后续的 API 请求必须在 Header 中携带 `Authorization: Bearer <token>`

### Requirement: 错误处理 (Error Handling)
系统必须处理标准的 HTTP 错误响应。

#### Scenario: 未授权访问 (401 Unauthorized)
- **WHEN** API 返回 401 状态码
- **THEN** 系统必须自动跳转到登录页面，并清除本地会话数据。
