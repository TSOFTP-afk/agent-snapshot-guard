# 规则规范（asg-rule/v1）与贡献指南

## 两类规则目录

| 目录 | 性质 | 说明 |
|---|---|---|
| `examples/`（仓库内） | **惰性模板** | 引擎永不自动加载；仅为用户提供起点 |
| `%USERPROFILE%\.agent-snapshot-guard\rules`（本机） | **生效规则** | 只有用户显式 `enable -App <name>`（或亲手放入）才会出现在这里 |

## Schema

| 字段 | 类型 | 说明 |
|---|---|---|
| `schema` | string | 固定 `asg-rule/v1` |
| `app` | string | 唯一 id（小写连字符） |
| `vendor` | string | 厂商标识 |
| `display` | string | 展示名 |
| `maturity` | string | **仅作参考标注**（`verified` / `community` / `experimental`），描述证据充分度，**不影响引擎行为** —— 是否武装永远由用户决定 |
| `dataRoots` | string[] | 应用的本地数据根目录，支持环境变量 |
| `actions.denyWriteDirs` | string[] | 武装后：ACL 写拒绝 |
| `actions.deleteDirNames` | string[] | 武装后：命中目录内文件删除 |
| `actions.deleteFileNames` | string[] | 武装后：命中文件删除 |
| `actions.quarantineFileNames` | string[] | 武装后：命中文件隔离（SHA256 留痕，可恢复） |
| `actions.monitorFileNames` | string[] | 观察模式即生效：仅计数展示 |
| `telemetryHosts` | string[] | 已知遥测域名（供网络层使用） |
| `notes` | string | 行为说明 |
| `references` | string[] | 依据链接 |

## 动作优先级

`denyWriteDirs` > `deleteDirNames` > `deleteFileNames` > `quarantineFileNames` > `monitorFileNames`；未命中 = 忽略（永不触碰）。

## 用户决策流（引擎哲学）

```
enable  -App <name>   # 观察：只计数展示，绝不删除
arm    -App <name>   # 武装：拒写 + 删除 + 隔离（用户显式决定）
disarm -App <name>   # 撤回观察
disable -App <name>  # 彻底关闭并移除规则
```

引擎出厂零规则、零武装；`verified` 标注也**不会**自动武装任何东西。

## 模板贡献红线（违反即拒）

1. 模板只放 `examples/`，且必须保持惰性中立表述；
2. `dataRoots` 只能指向应用自身数据目录，禁止指向用户项目/工作区/`.git` 本体；
3. 陈述行为、引用公开来源，不做指控性措辞；
4. 声称 `verified` 必须附可复现取证（产物 schema、时间线、复现步骤）。
