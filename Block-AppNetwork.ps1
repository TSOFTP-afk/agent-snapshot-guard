#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Optional layer-3 network quarantine for guarded AI clients (agent-snapshot-guard).

.DESCRIPTION
  Mode B (-TelemetryHosts): pin the rule's known telemetry endpoints to 0.0.0.0
  in the hosts file. Mild, reversible. Does NOT stop dynamic upload endpoints.

  Mode A (-FirewallBlock): outbound firewall block for the app's exe - full
  quarantine mode. Kills ALL traffic including the model API.

  Why not "block vendor cloud IP ranges"? Windows Firewall has no domain-based
  rules, and AI vendors often host model APIs on the same clouds as telemetry -
  IP-range blocks cut your own model access.

.EXAMPLE
  .\Block-AppNetwork.ps1 -App zcode -TelemetryHosts
  .\Block-AppNetwork.ps1 -App zcode -FirewallBlock -Exe F:\Zcode\ZCode.exe
  .\Block-AppNetwork.ps1 -App zcode -Undo
#>
[CmdletBinding()]
param(
  [string]$App = 'zcode',
  [string]$Exe = '',
  [switch]$FirewallBlock,
  [switch]$TelemetryHosts,
  [switch]$Undo
)

$ErrorActionPreference = 'Stop'
$RulesDir = Join-Path (Split-Path -Parent $PSCommandPath) 'rules'
$RuleName = 'agent-snapshot-guard: block ' + $App + ' outbound'
$HostsPath   = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$HostsBackup = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts.asg-backup'
$HBegin = '# BEGIN agent-snapshot-guard (' + $App + ')'
$HEnd   = '# END agent-snapshot-guard'

$pins = @()
if ($TelemetryHosts -or $Undo) {
  $ruleFile = Get-ChildItem -LiteralPath $RulesDir -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
    try { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
  } | Where-Object { $_ -and $_.app -eq $App }
  if (-not $ruleFile) { throw "rule not found for app: " + $App }
  $pins = @($ruleFile.telemetryHosts | ForEach-Object { '0.0.0.0 ' + $_ })
}

if ($Undo) {
  Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  Write-Host '[+] firewall rule removed (if any)'
  if (Test-Path $HostsBackup) {
    Copy-Item $HostsBackup $HostsPath -Force
    Remove-Item $HostsBackup -Force
    Write-Host '[+] hosts restored from backup'
  }
  return
}

if ($FirewallBlock) {
  if (-not ($Exe -and (Test-Path $Exe))) { throw "pass -Exe with the full path of the app's exe (e.g. F:\Zcode\ZCode.exe)" }
  New-NetFirewallRule -DisplayName $RuleName -Direction Outbound -Action Block -Program $Exe -Profile Any | Out-Null
  Write-Host ("[+] outbound BLOCKED for: " + $Exe)
  Write-Host '[!] quarantine mode: model API is also blocked. Use -Undo to restore.'
}

if ($TelemetryHosts) {
  if (@($pins).Count -eq 0) { Write-Host '[i] rule has no telemetryHosts; nothing to pin.'; return }
  if (-not (Test-Path $HostsBackup)) { Copy-Item $HostsPath $HostsBackup -Force }
  $raw = Get-Content $HostsPath -ErrorAction SilentlyContinue
  $kept = @(); $inside = $false
  foreach ($line in $raw) {
    if ($line -eq $HBegin) { $inside = $true; continue }
    if ($line -eq $HEnd)   { $inside = $false; continue }
    if (-not $inside) { $kept += $line }
  }
  Set-Content -Path $HostsPath -Value ($kept + @($HBegin) + $pins + @($HEnd)) -Encoding ASCII
  Write-Host ('[+] pinned ' + @($pins).Count + ' telemetry endpoints for ' + $App + ' (backup at hosts.asg-backup)')
}

if (-not ($FirewallBlock -or $TelemetryHosts)) {
  Write-Host 'Nothing to do. Pass -FirewallBlock and/or -TelemetryHosts (or -Undo).'
}
