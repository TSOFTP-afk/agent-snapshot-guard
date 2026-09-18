# Agent Snapshot Guard

> 🛡️ **Rules-driven** local-data defense framework for AI coding clients.
> **First principle: the user holds the trigger.** The engine ships with zero rules, zero armed behavior, zero stance. Templates are inert; enabling, arming, and disarming are always your explicit decisions.

🇬🇧 English | [中文（更完整）](README.md)

## Philosophy

AI coding tools keep private data dirs on your machine: transcripts, checkpoints, indexes, telemetry. When vendor data appetite collides with user privacy, you need a switch - one that **you** control:

```
engine ships = zero rules, zero arming, zero stance
  examples/            inert templates (never auto-loaded)
  enable -App x        your decision #1: observe (count/log only, never deletes)
  arm    -App x        your decision #2: act (deny-write + delete + quarantine)
  disarm -App x        your decision #3: back to observe
  disable -App x       your decision #4: fully off
```

## Quick start

```powershell
git clone https://github.com/TSOFTP-afk/agent-snapshot-guard.git
cd agent-snapshot-guard
.\AgentSnapshotGuard.ps1 examples
.\AgentSnapshotGuard.ps1 enable -App zcode
.\AgentSnapshotGuard.ps1 status
.\AgentSnapshotGuard.ps1 arm -App zcode        # only if YOU decide to
```

Own rule: drop an asg-rule/v1 JSON into `%USERPROFILE%\.agent-snapshot-guard\rules\`, then `enable -App <id>`. Schema: [docs/RULES.md](docs/RULES.md)

## Commands

`examples | rules | enable | disable | arm | disarm | status | sweep | run | uninstall`

Sentinel log with SHA256 evidence trail: `%USERPROFILE%\.agent-snapshot-guard\guard.log`

## Templates (inert)

zcode (verified forensics: [docs/EVIDENCE-zcode.md](docs/EVIDENCE-zcode.md)) · claude-code · cursor · trae · windsurf · custom.example - all observe-first, none auto-loaded.

## Origin

[ZCode incident forensics](docs/EVIDENCE-zcode.md) · [vendor response](https://forum.trae.cn/t/topic/181727) · [BlockBeats](https://en.theblockbeats.news/flash/367816) · [ferstar reverse-engineering](https://blog.ferstar.org/posts/zcode-silent-workspace-snapshot-upload/)

## License

[MIT](LICENSE). Not affiliated with any vendor; rules state publicly known behavior only.
