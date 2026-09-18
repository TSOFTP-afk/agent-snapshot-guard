# 规则规范（asg-rule/v1）与贡献指南

一份规则 = 一个 AI 客户端的本地防御策略。放在 `rules/<app>.json` 即被引擎自动加载。

## Schema

| 字段 | 类型 | 说明 |
|---|---|---|
| `schema` | string | 固定 `asg-rule/v1` |
| `app` | string | 唯一 id（小写连字符），如 `zcode` |
| `vendor` | string | 厂商标识 |
| `display` | string | 展示名 |
| `maturity` | string | `verified`（有完整取证，破坏性动作默认武装）/ `community`（默认只观察，需 `-Force` 武装）/ `experimental` |
| `dataRoots` | string[] | 该应用的本地数据根目录，支持环境变量（`%USERPROFILE%`、`%APPDATA%`），`/` 会自动转 `\` |
| `actions.denyWriteDirs` | string[] | 相对 dataRoot 的子目录，施加 ACL 写拒绝（创建即失败，无需管理员） |
| `actions.deleteDirNames` | string[] | 目录名匹配列表：命中目录内的文件会被删除 |
| `actions.deleteFileNames` | string[] | 文件名通配：命中即删除 |
| `actions.quarantineFileNames` | string[] | 文件名通配：命中则移入隔离区（保留相对路径，记录 SHA256，可恢复） |
| `actions.monitorFileNames` | string[] | 文件名通配：仅计数与展示（观察模式） |
| `telemetryHosts` | string[] | 已知遥测域名（供 `Block-AppNetwork.ps1 -TelemetryHosts` 使用） |
| `notes` | string | 行为说明与证据摘要 |
| `references` | string[] | 取证/报道链接 |

## 动作优先级

`denyWriteDirs`（落盘即失败）> `deleteDirNames` > `deleteFileNames` > `quarantineFileNames` > `monitorFileNames`。
未命中任何规则 = 忽略（永不触碰）。

## 安全红线（违反的 PR 会被拒）

1. **只允许指向应用自己的数据目录**（`~/.<app>` / `%APPDATA%\<app>`），禁止指向用户项目目录、工作区或 `.git` 本体。
2. **maturity=community/experimental 的规则默认只允许 observe**（monitor/quarantine），`delete`/`denyWrite` 需要 `-Force` 武装，且 PR 里必须说明依据。
3. `verified` 必须附可复现的取证材料（产物 schema、时间线、复现步骤）。
4. 不做任何厂商指控性表述；陈述行为，引用公开来源。

## 贡献流程

1. Fork → 新建 `rules/<app>.json`（可复制 `custom.example.json`）
2. 在自己机器上核实 `dataRoots` 真实存在
3. 提交 PR，描述：观察到的行为、依据链接、建议的 maturity
4. CI（规划中）会校验 schema
