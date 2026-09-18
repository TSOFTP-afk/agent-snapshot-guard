# Agent Snapshot Guard

**What do AI coding tools store on your machine - and what do they quietly send out? See it, then decide for yourself.**

A small community-built, open-source tool. No side-taking, no naming names, no decisions made on your behalf.

> 🇬🇧 English | [中文（更完整）](README.md)

---

## When you see one cockroach

An AI coding tool got caught packing users' entire workspaces for upload - .git history included, no in-app toggle, privacy settings be damned. Official apology, fix, open-source promise... and then what?

Not an isolated case. Caught overseas, caught domestically. The old saying holds: **when you spot one cockroach, the walls are already crawling.**

- Apart from a handful of open-source agents, **nobody knows what closed-source tools do behind your back**
- Indie devs mostly don't care about data safety - but the moment **commercial code, client data, internal docs** are involved, privacy in B2B is a hard line
- What's missing: making AI tools' local data behavior **visible, controllable, and forensically documentable**

This project fills that gap. Community-grade, minimal, honest - it does not claim "enterprise-grade security".

---

## What it does

Three steps, each pressed by you:

```powershell
# Windows 10/11 · PowerShell 5.1+ · no admin required
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard

.\AgentSnapshotGuard.ps1 examples            # 1) list inert templates (nothing happens yet)
.\AgentSnapshotGuard.ps1 enable -App <name>  # 2) observe mode: log only, never deletes
.\AgentSnapshotGuard.ps1 status              # 3) see what it observed
.\AgentSnapshotGuard.ps1 arm -App <name>     # 4) your call: deny-write + delete + quarantine
```

`status` looks like:

```
[*] engine: active-rules=1  sentinel=running (pid 13164)  autostart=yes
[*] APP            MODE      EVIDENCE    ARTIFACTS-NOW
  <your-app>     observe   community   3
```

Regret anytime:

```powershell
.\AgentSnapshotGuard.ps1 disarm -App <name>   # back to observe
.\AgentSnapshotGuard.ps1 disable -App <name>  # fully off
.\AgentSnapshotGuard.ps1 uninstall            # clean teardown, like it never existed
```

---

## Factory principles: zero rules, zero arming, zero stance

- The engine contains **no product-specific rules**; bundled templates live in `examples/`, inert - until `enable`, not a single byte is touched
- Observe mode **only logs**; deleting/deny-write requires your explicit `arm`
- Operates only inside the tools' own data dirs; your projects, your `.git`, your workspaces are untouchable by design
- Every delete/quarantine is SHA256-logged - verifiable, recoverable
- Own tool? Copy [`custom.example.json`](examples/custom.example.json) and edit ([schema](docs/RULES.md))

## 🪤 What it can and cannot stop

Honesty first:

**Can stop:**
- Known snapshot/checkpoint artifacts at write time (deny-write makes creation fail)
- Known artifact patterns before upload (found = destroyed)
- Known telemetry domains (optional network layer, admin)

**Cannot stop:**
- Vendors relocating storage, changing protocols, altering file signatures - a cat-and-mouse game requiring constant community updates
- Purely server-side behavior (you can't block what you can't see)
- **Real, strong privacy protection** (sandboxing, full-traffic audit, DLP) - that's commercial products' job; a community tool doing "visibility + minimal interception" is already pulling its weight

Bottom line: this tool is a window screen, not a vault. But a screen beats an open door.

## Four layers

| Layer | Means | In one line |
|---|---|---|
| L0 | observe mode | log only, default posture |
| L1 | ACL write-deny | dangerous dirs fail at creation, owner-right, no admin |
| L2 | kill sentinel | 5s sweep, SHA256 evidence trail |
| L3 | network quarantine | optional, admin |

## FAQ

**Which templates should I enable?**
Look and decide. This tool's stance is precisely not to make that call for you.

**Will it touch my project files?**
No. Rules may only target the tools' own data dirs - your projects, `.git`, workspaces are hard red lines ([policy](docs/RULES.md)).

**Performance impact?**
Directory enumeration every 5 seconds. No service, no driver, no injection.

**macOS / Linux?**
Windows-only today. Rules are JSON - PRs welcome.

**Are templates trustworthy?**
Community observations only, inert, sourced; `verified` requires reproducible forensics. Don't trust it - verify it, or write your own.

## Origin

Started as a hotfix after one incident ([forensics](docs/EVIDENCE-incident.md)). Then it clicked: one vendor caught means all of them deserve a look - a patch shouldn't serve a single tool.

## Contributing

- Templates for new tools ([docs/RULES.md](docs/RULES.md): neutral wording, always inert)
- Report observed behavior (issue + logs)
- Cross-platform (PS 7 / *nix)

## License

[MIT](LICENSE) · Not affiliated with any vendor; rules state publicly known behavior only.
