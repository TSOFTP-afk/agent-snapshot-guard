# Agent Snapshot Guard（AI 编程工具隐私哨兵）

> 🛡️ **规则驱动**的 AI 编程客户端本地数据防御框架：ACL 拒写 + 歼灭哨兵 + 隔离区 + 观察模式。
> 诞生于 [ZCode 静默上传工作区快照（含完整 .git 历史）事件](docs/EVIDENCE-zcode.md)，但不止于 ZCode。
> **普通用户权限即可部署，无需管理员。** 规则社区共建，观察优先，无指控。

🇨🇳 中文 | [English](README.en.md)

---

## 🎯 为什么需要它

AI 编程工具（Copilot、Cursor、Claude Code、ZCode、Trae、Windsurf、通义灵码……）都会在你本机维护自己的数据目录：对话记录、检查点、索引、遥测。当**厂商的数据需求**与**你的隐私需求**冲突时（ZCode 事件就是第一次大爆发），用户手里需要一个开关。

本项目不开发奸商，只做一件事：**让每个 AI 客户端的本地数据行为，变得可见、可控、可取证。**

```
你的项目目录 (~/.git)     ← 永远不碰
      ▲ 只监控/防御厂商自己的数据目录 (~/.<app>, %APPDATA%\<app>)
┌─────────────────────────────────────────┐
│ 第一层 ACL 拒写   危险子目录创建即失败（无需管理员）      │
│ 第二层 歼灭哨兵   5s 扫描：删除/隔离匹配的快照产物        │
│ 第三层 网络隔离   (可选, 管理员) 遥测 hosts 钉死 / 防火墙   │
│ 第零层 观察模式   只记录不删除 —— 默认姿态，先看清再动手   │
└─────────────────────────────────────────┘
```

## 📦 支持的客户端（规则库持续扩充）

| 客户端 | 成熟度 | 默认模式 | 说明 |
|---|---|---|---|
| **ZCode** (智谱) | ✅ verified | **武装**（拒写+删除） | 完整取证：[docs/EVIDENCE-zcode.md](docs/EVIDENCE-zcode.md) |
| Claude Code | community | 只观察 | 本地对话记录可见性；武装需 `-Force` |
| Cursor | community | 只观察 | 本地数据可见性（Privacy Mode 是产品内设置） |
| Trae (字节) | community | 只观察 | 实验性规则 |
| Windsurf | community | 只观察 | 实验性规则 |
| 你的工具 | community | 只观察 | 复制 `custom.example.json` 即可接入（[贡献指南](docs/RULES.md)） |

> 成熟度体系是本项目的信誉基础：**未验证的应用默认只观察，绝不指控**；`verified` 必须附可复现取证。

## 🚀 快速开始

```powershell
# PowerShell（普通权限）
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard
.\AgentSnapshotGuard.ps1 install                # 安装全部规则（verified 武装，其余观察）
.\AgentSnapshotGuard.ps1 install -App zcode     # 只装 ZCode 防线
.\AgentSnapshotGuard.ps1 install -App cursor -Force  # 武装未验证规则（自行承担）
```

> 💡 国内网络：`git clone` 走代理或镜像；raw 直连可能超时。

## 📖 使用

```powershell
.\AgentSnapshotGuard.ps1 status        # 全局状态矩阵
.\AgentSnapshotGuard.ps1 rules         # 已加载规则清单
.\AgentSnapshotGuard.ps1 sweep         # 手动清扫
.\AgentSnapshotGuard.ps1 uninstall -App zcode
```

`status` 输出示例：

```
[*] engine: rules=6  sentinel=running (pid 13164)  autostart=yes
[*] APP            MODE      MATURITY    ARTIFACTS-NOW
  zcode           ARMED     verified    0
  claude-code     monitor   community   14
  cursor          off       community   0
```

哨兵日志：`%USERPROFILE%\.agent-snapshot-guard\guard.log`（每条删除/隔离都带 SHA256 留痕）。

## ⚙️ 四级动作

| 动作 | 行为 | 适用 |
|---|---|---|
| `denyWrite` | 危险子目录 ACL 拒写，创建即失败 | 确认有害的写入路径 |
| `delete` | 命中即删（不可逆） | 纯恶意产物 |
| `quarantine` | 移入隔离区 + SHA256 留痕（可逆） | 存疑但有取证价值 |
| `monitor` | 只计数与展示 | 一切未验证行为 |

## 🧹 卸载 / 撤防

```powershell
.\AgentSnapshotGuard.ps1 uninstall -App zcode   # 单独撤防
.\AgentSnapshotGuard.ps1 uninstall              # 全部撤防（停哨兵、删自启、解 ACL）
```

## 🪤 局限（必读）

1. 当前仅支持 **Windows**（PS 5.1+）；跨平台在路线图上
2. 厂商控制客户端，可换路径/改文件名——规则库需要社区持续维护
3. 不覆盖网络遥测；需要时用 `Block-AppNetwork.ps1`（管理员）
4. `community` 规则的 dataRoots 来自社区提交，请自行核实

## 📜 起源：ZCode 事件

- [取证报告（已脱敏）](docs/EVIDENCE-zcode.md)：会话结束触发全量快照（含 .git）、开关无效、失败重传、服务端持解密钥匙
- 官方回应（9/18 称已修复、承诺开源）与本地证据的出入也记录在案
- 报道：[BlockBeats](https://en.theblockbeats.news/flash/367816) · [IT之家](https://www.ithome.com/1/004/310.htm) · [腾讯新闻](https://news.qq.com/rain/a/20260918A09XAY00) · [ferstar 逆向](https://blog.ferstar.org/posts/zcode-silent-workspace-snapshot-upload/)

## 🤝 贡献

每个新 AI 工具的爆发 = 一份新规则 = 一次星标。[规则规范与贡献指南](docs/RULES.md)

## 📄 License

[MIT](LICENSE) · 与任何厂商无关联；规则仅陈述公开已知行为，不构成指控。
