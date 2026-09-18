# Agent Snapshot Guard

**你用 AI 编程工具写代码，但你知道它们在你电脑上存了什么吗？**

| 你在用的工具 | 它在你电脑上存了什么 |
|---|---|
| Claude Code | `~/.claude/projects/` 里是你和 AI 的**全部对话记录**（JSONL 明文） |
| ZCode（智谱） | 被社区抓到把**整个工作区连 .git 历史打包加密**待上传云端，应用内无开关（[取证报告](docs/EVIDENCE-zcode.md)，[官方已回应](https://forum.trae.cn/t/topic/181727)） |
| Cursor | 代码库索引（embedding）**默认上传厂商云端**做检索，隐私模式需手动开 |
| Trae / Windsurf / 通义灵码 | 各自的会话记录、缓存、遥测数据 |

这些目录没有一个有好用的查看界面。出了事，你甚至不知道证据在哪。

**这个工具只做三件事：**

1. **看见** —— 盘点这些工具在你电脑上存了什么、存在哪
2. **观察** —— 盯着它们的数据目录，只记录不动手
3. **动手** —— 你看清楚之后，自己决定要不要拒写、删除、隔离

> 🚫 **它不会替你做决定。** 引擎出厂零规则：不预设哪家是坏人，不自动删除任何东西。
> 每一步——启用、武装、撤回——都是你自己按下的。

---

## 🚀 30 秒上手

**Windows 10/11 · PowerShell 5.1+ · 无需管理员**

```powershell
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard

# 第一步：看看有哪些现成模板（此刻什么都没发生，引擎是空的）
.\AgentSnapshotGuard.ps1 examples

# 第二步：启用观察 —— 只看，不删
.\AgentSnapshotGuard.ps1 enable -App zcode

# 第三步：查看它观察到了什么
.\AgentSnapshotGuard.ps1 status
```

`status` 长这样：

```
[*] engine: active-rules=1  sentinel=running (pid 13164)  autostart=yes
[*] APP            MODE      EVIDENCE    ARTIFACTS-NOW
  zcode           observe   verified    0
```

观察几天，觉得确实需要防：

```powershell
.\AgentSnapshotGuard.ps1 arm -App zcode      # 从这一刻起才会拒写/删除/隔离
```

反悔了：

```powershell
.\AgentSnapshotGuard.ps1 disarm -App zcode   # 退回观察
.\AgentSnapshotGuard.ps1 uninstall           # 全部撤干净，像没装过一样
```

---

## 🛡️ 它会动我的代码吗？

**不会。** 这是硬性红线（[规则规范](docs/RULES.md)里写死的）：

- 只在**工具自己的数据目录**里活动（`~/.zcode`、`~/.claude`、`~/.cursor`…）
- 你的项目、你的 `.git`、你的任何工作目录，引擎碰都碰不到
- **观察模式下零删除**；删除/拒写必须你显式 `arm`
- 每一次删除/隔离都带 SHA256 留痕，日志在 `%USERPROFILE%\.agent-snapshot-guard\guard.log`

四层防御（只对「已启用且已武装」的规则生效）：

| 层 | 手段 | 一句话 |
|---|---|---|
| L1 | ACL 拒写 | 危险目录创建即失败，属主权利，无需管理员 |
| L2 | 歼灭哨兵 | 每 5 秒扫一遍，SHA256 留痕 |
| L3 | 网络隔离 | 可选、需管理员：遥测域名钉死 / 按程序断网 |
| L0 | 观察模式 | 只记录不删除 —— 默认姿态 |

---

## 📦 现成模板

| 模板 | 依据 | 默认动作 |
|---|---|---|
| `zcode` | 完整取证（[文档](docs/EVIDENCE-zcode.md)） | 可武装：拒写检查点目录 + 删快照包 |
| `claude-code` | 社区观察 | 只观察（对话记录可见性） |
| `cursor` | 社区观察 | 只观察（本地库可见性） |
| `trae` / `windsurf` | 实验性 | 只观察 |
| 自带工具？ | —— | 复制 [`custom.example.json`](examples/custom.example.json) 花五分钟写一份 |

模板全在 `examples/`，**引擎永不自动加载**；`enable` 之后才拷入你本机的规则目录。这些模板只陈述公开已知的行为，不构成对任何厂商的指控。

---

## ❓ 常见问题

**我不用 ZCode，这跟我有关系吗？**
有。任何 AI 编程工具的数据目录都能接进来——用现成模板或自己写一份。而且就算什么都不启用，下一个类似事件爆发时，你手里已经有了日志和取证框架。

**观察模式会拖慢电脑吗？**
不会。每 5 秒扫一遍几个数据目录，纯文件枚举，无后台服务、无驱动。

**会跟杀软冲突吗？**
无安装、无驱动、无持久化注入，只调系统自带的 `icacls` 和文件操作。个别杀软可能对 PS 脚本告警，加白名单即可。

**支持 Mac / Linux 吗？**
目前仅 Windows。规则是 JSON、引擎无 Windows 专有依赖的部分欢迎 PR 跨平台。

**和直接卸载这些工具比呢？**
卸载当然最干净。但如果你还要用它们，这是目前唯一的中间态：继续用，同时看得见、管得住。

---

## 📜 背景故事

2026 年 9 月，开发者 ferstar 逆向发现智谱 ZCode 在用户不知情时把整个工作区——包括完整 `.git` 历史、reflog、pack 文件——打包加密上传云端；应用内没有开关，隐私开关也拦不住（[取证](docs/EVIDENCE-zcode.md)，[官方回应](https://forum.trae.cn/t/topic/181727)，[IT之家](https://www.ithome.com/1/004/310.htm)，[BlockBeats](https://en.theblockbeats.news/flash/367816)）。

这件事暴露的不是一家公司的问题，而是一个空缺：**AI 工具在你电脑上存什么、传什么，用户毫无可见性。** 本项目从那个临时补丁演化而来，立场是通用的：不站队、不指控，把可见性和决定权还给用户。

---

## 🤝 参与

- 给新工具写模板 → [规范与红线](docs/RULES.md)，模板只收 `examples/`，永远惰性、措辞中立
- 报告你观察到的工具行为（开 issue，附日志）
- 跨平台支持

## 📄 License

[MIT](LICENSE) · 与任何厂商无关联
