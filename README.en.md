# Agent Snapshot Guard

> 🛡️ **Rules-driven** local-data defense framework for AI coding clients: ACL write-deny + kill sentinel + quarantine + observe mode.
> Born from the [ZCode silent workspace-snapshot upload incident](docs/EVIDENCE-zcode.md), but not limited to ZCode.
> Plain user privileges, no admin required. Community ruleset, observe-first, no accusations.

🇬🇧 English | [中文（更完整）](README.md)

## Why

AI coding tools (Copilot, Cursor, Claude Code, ZCode, Trae, Windsurf, ...) all keep private data dirs on your machine: transcripts, checkpoints, indexes, telemetry. When vendor data appetite collides with user privacy (the ZCode incident was the first big blow-up), users need a switch.

This project makes every AI client's local data behavior **visible, controllable, and forensically documentable** — without accusing any vendor.

## Supported clients

| Client | Maturity | Default mode | Notes |
|---|---|---|---|
| **ZCode** (Zhipu) | ✅ verified | **ARMED** (deny+delete) | full forensics: [docs/EVIDENCE-zcode.md](docs/EVIDENCE-zcode.md) |
| Claude Code | community | observe-only | arm with `-Force` |
| Cursor | community | observe-only | local visibility |
| Trae | community | observe-only | experimental |
| Windsurf | community | observe-only | experimental |
| your tool | community | observe-only | copy `custom.example.json` ([guide](docs/RULES.md)) |

## Quick start

```powershell
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard
.\AgentSnapshotGuard.ps1 install                 # all rules (verified armed, rest observe)
.\AgentSnapshotGuard.ps1 install -App zcode      # ZCode only
.\AgentSnapshotGuard.ps1 status
```

## Layers

```
L1 ACL write-deny   dangerous subdirs fail at creation (no admin needed)
L2 kill sentinel    5s sweep: delete/quarantine matching artifacts
L3 network quarantine (optional, admin) hosts pinning / per-exe firewall
L0 observe mode     log-only by default - see first, act later
```

## Commands

```powershell
.\AgentSnapshotGuard.ps1 install [-App <name|all>] [-Force]
.\AgentSnapshotGuard.ps1 status | rules | sweep | run
.\AgentSnapshotGuard.ps1 uninstall [-App <name|all>]
```

Sentinel log with SHA256 evidence trail: `%USERPROFILE%\.agent-snapshot-guard\guard.log`

## Contributing

Every new AI tool = one new rule = one more star. [Rule schema & policy](docs/RULES.md)

## License

[MIT](LICENSE). Not affiliated with any vendor; rules state publicly known behavior only.
