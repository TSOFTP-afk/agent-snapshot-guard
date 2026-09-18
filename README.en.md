# Agent Snapshot Guard

**You use AI coding tools to write code. Do you know what they store on your machine?**

| Tool | What it keeps on your disk |
|---|---|
| Claude Code | `~/.claude/projects/` - your **entire conversation history** (plain JSONL) |
| ZCode (Zhipu) | caught by the community packing the **whole workspace incl. full .git history** for cloud upload, no in-app toggle ([forensics](docs/EVIDENCE-zcode.md), [vendor response](https://forum.trae.cn/t/topic/181727)) |
| Cursor | codebase embeddings **uploaded to vendor cloud by default** for retrieval |
| Trae / Windsurf / ... | their own transcripts, caches, telemetry |

None of these come with a decent viewer. When something breaks, you don't even know where the evidence is.

**This tool does three things:**

1. **See** - inventory what these tools store on your machine
2. **Watch** - monitor their data dirs, log-only, never touching files
3. **Act** - after you've seen enough, *you* decide to deny-write, delete, or quarantine

> 🚫 **It never decides for you.** Ships with zero rules. No vendor is presumed guilty. Every step - enable, arm, disarm - is your explicit keystroke.

---

## 🚀 30-second start

**Windows 10/11 · PowerShell 5.1+ · no admin required**

```powershell
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard

.\AgentSnapshotGuard.ps1 examples            # list inert templates (nothing happens yet)
.\AgentSnapshotGuard.ps1 enable -App zcode   # observe mode: watch, never delete
.\AgentSnapshotGuard.ps1 status
```

```
[*] engine: active-rules=1  sentinel=running (pid 13164)  autostart=yes
[*] APP            MODE      EVIDENCE    ARTIFACTS-NOW
  zcode           observe   verified    0
```

Convinced? Arm it:

```powershell
.\AgentSnapshotGuard.ps1 arm -App zcode      # deny-write / delete / quarantine now active
```

Regret?

```powershell
.\AgentSnapshotGuard.ps1 disarm -App zcode   # back to observe
.\AgentSnapshotGuard.ps1 uninstall           # clean teardown
```

---

## 🛡️ Will it touch my code?

**No.** Hard rules (enforced in [docs/RULES.md](docs/RULES.md)):

- Only operates inside **the tools' own data dirs** (`~/.zcode`, `~/.claude`, `~/.cursor`, ...)
- Your projects, your `.git`, your workspaces are untouchable by design
- **Observe mode deletes nothing**; destructive actions require an explicit `arm`
- Every delete/quarantine is SHA256-logged to `%USERPROFILE%\.agent-snapshot-guard\guard.log`

Four layers (active only for enabled+armed rules): ACL write-deny · kill sentinel (5s sweep) · optional network quarantine (admin) · observe mode (default).

---

## 📦 Templates

| Template | Basis | Default action |
|---|---|---|
| `zcode` | full forensics ([doc](docs/EVIDENCE-zcode.md)) | armable: deny checkpoints dir + delete snapshot artifacts |
| `claude-code` | community observation | observe only |
| `cursor` | community observation | observe only |
| `trae` / `windsurf` | experimental | observe only |
| your tool? | - | copy [`custom.example.json`](examples/custom.example.json), 5 minutes |

Templates live in `examples/` and are **never auto-loaded**; `enable` copies one into your local rules dir. They only state publicly known behavior - no accusations.

---

## ❓ FAQ

**I don't use ZCode - is this relevant to me?**
Yes. Any AI tool's data dir plugs in via a template or a 5-minute custom rule. And even with nothing enabled, you own the logging/forensics framework for the next incident.

**Does observe mode slow my machine?**
No. A directory enumeration every 5 seconds. No service, no driver.

**Antivirus conflicts?**
No install, no driver, no injection - just built-in `icacls` and file ops. Some AVs flag PS scripts; whitelist it.

**macOS / Linux?**
Windows-only today. Rules are JSON; cross-platform PRs welcome.

**Why not just uninstall those tools?**
Uninstalling is indeed cleanest. But if you still need them, this is the only middle ground: keep using them while staying informed and in control.

---

## 📜 Origin

Sep 2026: developer ferstar reverse-engineered Zhipu's ZCode silently packing entire workspaces - full .git history, reflog, packfiles - into encrypted uploads with no opt-out ([forensics](docs/EVIDENCE-zcode.md), [vendor response](https://forum.trae.cn/t/topic/181727), [IT Home](https://www.ithome.com/1/004/310.htm), [BlockBeats](https://en.theblockbeats.news/flash/367816)).

The lesson isn't about one company - it's a structural gap: **users have zero visibility into what AI tools store and send.** This project started as a hotfix for that incident; its stance is general: no side-taking, no accusations - visibility and control back to the user.

---

## 🤝 Contributing

- New tool templates → [schema & red lines](docs/RULES.md) (templates go to `examples/`, always inert, neutral wording)
- Report observed tool behavior (open an issue with logs)
- Cross-platform support

## 📄 License

[MIT](LICENSE) · Not affiliated with any vendor.
