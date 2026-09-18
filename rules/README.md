# Active rules live here

This is where the engine looks for YOUR rules:
`%USERPROFILE%\.agent-snapshot-guard\rules`

It is empty by design - the engine ships with zero rules and takes no side.

Get started:

```
.\AgentSnapshotGuard.ps1 examples               # list inert templates
.\AgentSnapshotGuard.ps1 enable -App template-01   # copy a template here (observe mode)
.\AgentSnapshotGuard.ps1 arm -App template-01      # your explicit decision to act
```

Or write your own asg-rule/v1 JSON, drop it here, then:
`enable -App <app-id>`

See docs/RULES.md for the schema.
