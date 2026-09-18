# Agent Snapshot Guard（AI 编程工具隐私哨兵）

> 🛡️ **规则驱动**的 AI 编程客户端本地数据防御框架。
> **第一原则：决定权在用户。** 引擎出厂零规则、零武装、零立场；模板全部惰性，是否启用、是否武装，每一步都是你自己按下的。
>
> 起源于 [ZCode 静默上传工作区快照（含完整 .git 历史）事件](docs/EVIDENCE-zcode.md)，但不止于任何一家。

🇨🇳 中文 | [English](README.en.md)

---

## 🎯 设计哲学

AI 编程工具（Copilot、Cursor、Claude Code、ZCode、Trae、Windsurf……）都会在你本机维护数据目录：对话记录、检查点、索引、遥测。当**厂商的数据需求**与**你的隐私需求**冲突时，你需要一个开关——但这个开关必须握在你手里：

```
引擎出厂 = 零规则、零武装、零立场
   │
   ├─ examples/      惰性模板（仅供参考，引擎永不自动加载）
   │
   ├─ enable -App x  你的决定①：观察（只计数展示，绝不删除）
   ├─ arm    -App x  你的决定②：武装（拒写 + 删除 + 隔离）
   ├─ disarm -App x  你的决定③：撤回观察
   └─ disable -App x 你的决定④：彻底关闭
```

没有白名单黑名单，没有“我们认为谁可疑”。谁可疑、防多深，**你自己看、你自己定**。

## 🚀 快速开始

```powershell
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard
.\AgentSnapshotGuard.ps1 examples              # ① 看看有哪些模板（全部惰性）
.\AgentSnapshotGuard.ps1 enable -App zcode     # ② 启用观察（不会删任何东西）
.\AgentSnapshotGuard.ps1 status                # ③ 查看观察结果
.\AgentSnapshotGuard.ps1 arm -App zcode        # ④（自行决定）武装防御
.\AgentSnapshotGuard.ps1 disarm -App zcode     # ⑤ 随时撤回观察
```

也支持自带规则：把 `asg-rule/v1` JSON 放进 `%USERPROFILE%\.agent-snapshot-guard\rules\`，然后 `enable -App <id>`。Schema 见 [docs/RULES.md](docs/RULES.md)。

## 📖 命令

| 命令 | 作用 |
|---|---|
| `examples` | 列出惰性模板（引擎不加载） |
| `enable -App <name>` | 激活模板/自有规则 → **观察模式** |
| `arm -App <name>` | 武装：ACL 拒写 + 删除 + 隔离生效 |
| `disarm -App <name>` | 回到观察（拒写解除） |
| `disable -App <name>` | 彻底关闭并移除规则 |
| `status` | 全局状态矩阵 |
| `sweep` | 手动清扫 |
| `rules` | 列出生效规则 |
| `run` | 前台哨兵（开机自启用） |
| `uninstall` | 完整卸载 |

`status` 输出示例：

```
[*] engine: active-rules=1  sentinel=running (pid 13164)  autostart=yes
[*] APP            MODE      EVIDENCE    ARTIFACTS-NOW
  zcode           ARMED     verified    0
```

哨兵日志（含 SHA256 取证）：`%USERPROFILE%\.agent-snapshot-guard\guard.log`

## 🧱 四层防御（对已启用并武装的规则生效）

```
L1 ACL 拒写     危险子目录创建即失败（属主权利，无需管理员）
L2 歼灭哨兵     5s 扫描：删除/隔离匹配产物（SHA256 留痕）
L3 网络隔离     (可选, 管理员) 遥测 hosts 钉死 / 按程序防火墙
L0 观察模式     只记录不删除 —— 引擎默认姿态
```

## 📦 模板（惰性，仅供起点）

| 模板 | 证据标注 | 说明 |
|---|---|---|
| zcode | verified（完整取证） | [docs/EVIDENCE-zcode.md](docs/EVIDENCE-zcode.md) |
| claude-code / cursor / trae / windsurf | community | 本地数据可见性观察 |
| custom.example | — | 自定义起点 |

> 模板描述只陈述公开已知行为；`maturity` 是证据充分度标注，**不影响引擎行为**。

## 🪤 局限

1. 当前仅 Windows（PS 5.1+）
2. 厂商可换路径改文件名——规则需社区持续维护
3. 不覆盖网络遥测（见 `Block-AppNetwork.ps1`，需管理员）
4. 防线目录不针对用户项目/工作区/`.git` 本体——红线见 [RULES.md](docs/RULES.md)

## 📜 起源

[ZCode 事件取证](docs/EVIDENCE-zcode.md) · [官方回应](https://forum.trae.cn/t/topic/181727) · [BlockBeats](https://en.theblockbeats.news/flash/367816) · [IT之家](https://www.ithome.com/1/004/310.htm) · [ferstar 逆向](https://blog.ferstar.org/posts/zcode-silent-workspace-snapshot-upload/)

## 🤝 贡献

每个新 AI 工具 = 一份新模板 = 一波星标。模板只收 `examples/`，措辞中立、永远惰性。[指南](docs/RULES.md)

## 📄 License

[MIT](LICENSE) · 与任何厂商无关联；规则仅陈述公开已知行为，不构成指控。
