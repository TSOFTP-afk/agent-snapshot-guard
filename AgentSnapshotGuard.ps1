# ============================================================================
#  AgentSnapshotGuard.ps1
#  Rules-driven privacy sentinel for AI coding clients (Windows, PS 5.1+).
#  ----------------------------------------------------------------------------
#  NEUTRAL BY DESIGN: the engine ships with ZERO active rules and takes no
#  side. Vendor templates in examples/ are inert until the user explicitly:
#      enable  -App <name>   # observe mode (log/count only)
#      arm    -App <name>    # act mode: deny-write + delete + quarantine
#      disarm -App <name>    # back to observe
#      disable -App <name>   # fully off, rule file removed
#  Every step is the user's decision. Nothing is armed by default - including
#  rules with full forensic backing.
#
#  Active rules live in:  %USERPROFILE%\.agent-snapshot-guard\rules
#  Inert templates live in: ./examples
#
#  License: MIT
# ============================================================================
#Requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('install','status','sweep','uninstall','run','rules','examples','enable','disable','arm','disarm')]
  [string]$Action = 'status',

  [string]$App = '',
  [string]$RulesDir = ''
)

$ErrorActionPreference = 'SilentlyContinue'
$StateDir      = Join-Path $env:USERPROFILE '.agent-snapshot-guard'
$StateFile     = Join-Path $StateDir 'state.json'
$QuarantineDir = Join-Path $StateDir 'quarantine'
$GuardLog      = Join-Path $StateDir 'guard.log'
$UserRulesDir  = Join-Path $StateDir 'rules'
$ScriptFile    = $PSCommandPath
$ExamplesDir   = Join-Path (Split-Path -Parent $ScriptFile) 'examples'
$StartupCmd    = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\agent-snapshot-guard.cmd'
if (-not $RulesDir) { $RulesDir = $UserRulesDir }

function Write-Info($m) { Write-Host ("[*] " + $m) }
function Write-Bad($m)  { Write-Host ("[!] " + $m) -ForegroundColor Yellow }
function Write-Ok($m)   { Write-Host ("[+] " + $m) -ForegroundColor Green }

function Expand-RootPath([string]$p) {
  return [Environment]::ExpandEnvironmentVariables(($p -replace '/', '\'))
}

function Get-RuleFilesFrom([string]$dir) {
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  return @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue)
}

function Get-Rules {
  $out = @()
  foreach ($f in (Get-RuleFilesFrom $RulesDir)) {
    $r = $null
    try { $r = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if ($r -and $r.schema -eq 'asg-rule/v1' -and $r.app) { $out += $r }
    else { Write-Bad ("rule skipped (bad schema): " + $f.Name) }
  }
  return $out
}

function Get-ExampleFile([string]$app) {
  foreach ($f in (Get-RuleFilesFrom $ExamplesDir)) {
    $r = $null
    try { $r = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if ($r -and $r.app -eq $app) { return @{ file = $f; rule = $r } }
  }
  return $null
}

function Get-State {
  if (Test-Path -LiteralPath $StateFile) {
    $s = $null
    try { $s = Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if ($s) { return $s }
  }
  return New-Object psobject -Property @{ enabled = @(); armed = @() }
}

function Save-State($s) {
  if (-not (Test-Path -LiteralPath $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
  $s | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StateFile -Encoding ASCII
}

function Write-GuardLog([string]$app,[string]$m) {
  if (-not (Test-Path -LiteralPath $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
  try { Add-Content -LiteralPath $GuardLog -Value ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "][" + $app + "] " + $m) -Encoding ASCII } catch {}
}

function Test-DenyActive([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return $false }
  $probe = Join-Path $p ('.asg-probe-' + [guid]::NewGuid().ToString('N'))
  try {
    New-Item -ItemType Directory -Path $probe -ErrorAction Stop | Out-Null
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    return $false
  } catch { return $true }
}

function Enable-DenyPath([string]$root,[string]$rel) {
  $p = Join-Path $root ($rel -replace '/', '\')
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
  $null = icacls $p /deny "$($env:USERNAME):(OI)(CI)(WD,AD)"
  return (Test-DenyActive $p)
}

function Disable-DenyPath([string]$root,[string]$rel) {
  $p = Join-Path $root ($rel -replace '/', '\')
  if (Test-Path -LiteralPath $p) { $null = icacls $p /remove:d "$($env:USERNAME)" }
}

function Remove-AnyWay([string]$p) {
  for ($i = 0; $i -lt 8; $i++) {
    try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; return $true } catch { }
    $null = cmd /c del /f /q "$p" 2>&1
    if (-not (Test-Path -LiteralPath $p)) { return $true }
    Start-Sleep -Milliseconds 400
  }
  return $false
}

function Get-RelativeInside([string]$full,[string]$root) {
  $r = $root.TrimEnd('\')
  if ($full.Length -le $r.Length) { return '' }
  if (-not $full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { return '' }
  return $full.Substring($r.Length + 1)
}

function Test-NameMatch([string]$full,[string[]]$patterns) {
  if (-not $patterns -or @($patterns).Count -eq 0) { return $false }
  $name = Split-Path $full -Leaf
  foreach ($pat in $patterns) { if ($name -like $pat) { return $true } }
  return $false
}

function Test-SegmentMatch([string]$rel,[string[]]$patterns) {
  if (-not $patterns -or @($patterns).Count -eq 0) { return $false }
  $segs = $rel -split '\\'
  foreach ($pat in $patterns) { foreach ($s in $segs) { if ($s -like $pat) { return $true } } }
  return $false
}

function Invoke-Quarantine([string]$root,[string]$app,[string]$full) {
  $rel = Get-RelativeInside $full $root
  $dest = Join-Path (Join-Path $QuarantineDir $app) $rel
  $destDir = Split-Path $dest -Parent
  if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
  $hash = ''
  try { if ((Get-Item -LiteralPath $full -ErrorAction Stop).Length -lt 64MB) { $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash } } catch {}
  for ($i = 0; $i -lt 8; $i++) {
    try {
      Move-Item -LiteralPath $full -Destination $dest -Force -ErrorAction Stop
      $msg = "quarantined: " + $full
      if ($hash) { $msg = $msg + " sha256=" + $hash }
      Write-GuardLog $app $msg
      return 'quarantined'
    } catch { Start-Sleep -Milliseconds 400 }
  }
  return 'locked'
}

function Test-Armed([string]$app) {
  $s = Get-State
  return (@($s.armed) -contains $app)
}

function Invoke-Classify([string]$root,$rule,[string]$full,[bool]$armed,[bool]$apply = $true) {
  $rel = Get-RelativeInside $full $root
  if (-not $rel) { return 'outside' }
  $a = $rule.actions
  if ($armed) {
    if (Test-SegmentMatch $rel @($a.deleteDirNames)) {
      if (-not $apply) { return 'would-delete' }
      if (Remove-AnyWay $full) { return 'deleted' } else { return 'locked' }
    }
    if (Test-NameMatch $full @($a.deleteFileNames)) {
      if (-not $apply) { return 'would-delete' }
      if (Remove-AnyWay $full) { return 'deleted' } else { return 'locked' }
    }
    if (Test-NameMatch $full @($a.quarantineFileNames)) {
      if (-not $apply) { return 'would-quarantine' }
      return (Invoke-Quarantine $root $rule.app $full)
    }
  }
  if (Test-NameMatch $full @($a.monitorFileNames)) { return 'monitored' }
  return 'ignored'
}

function Invoke-SweepRule($rule) {
  $armed = Test-Armed $rule.app
  $total = 0
  foreach ($rootSpec in @($rule.dataRoots)) {
    $root = Expand-RootPath $rootSpec
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
      $act = Invoke-Classify $root $rule $f.FullName $armed $true
      if ($act -eq 'deleted' -or $act -eq 'quarantined') { $total++ }
    }
  }
  return $total
}

function Get-SentinelPid {
  $me = $PID
  $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue
  foreach ($p in $procs) {
    if ($p.ProcessId -ne $me -and $p.CommandLine -match 'AgentSnapshotGuard' -and $p.CommandLine -match 'run') { return [int]$p.ProcessId }
  }
  return $null
}

function Install-Autostart {
  $engine = (Get-Process -Id $PID).Path
  if (-not $engine) { $engine = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
  $nl = [Environment]::NewLine
  $line = '@echo off' + $nl +
          'start "agent-snapshot-guard" /min "' + $engine + '" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $ScriptFile + '" -Action run' + $nl
  [IO.File]::WriteAllText($StartupCmd, $line, (New-Object System.Text.ASCIIEncoding))
  Write-Ok ("Autostart installed: " + $StartupCmd)
}

function Start-Sentinel {
  $existing = Get-SentinelPid
  if ($existing) { Write-Ok ("Sentinel already running (pid " + $existing + ")"); return }
  $engine = (Get-Process -Id $PID).Path
  if (-not $engine) { $engine = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
  Start-Process -FilePath $engine -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$ScriptFile,'-Action','run') -WindowStyle Hidden
  Start-Sleep -Seconds 2
  $now = Get-SentinelPid
  if ($now) { Write-Ok ("Sentinel started (pid " + $now + ")") } else { Write-Bad "Sentinel failed to start (check log)." }
}

function Invoke-Enable {
  if (-not $App) { Write-Bad "pass -App <name>"; return }
  if (-not (Test-Path -LiteralPath $UserRulesDir)) { New-Item -ItemType Directory -Force -Path $UserRulesDir | Out-Null }
  $dest = Join-Path $UserRulesDir ($App + '.json')
  if (-not (Test-Path -LiteralPath $dest)) {
    $ex = Get-ExampleFile $App
    if ($ex) {
      Copy-Item -LiteralPath $ex.file.FullName -Destination $dest -Force
      Write-Ok ("template activated: " + $App + " (from examples/)")
    } else {
      Write-Bad ("no template for '" + $App + "'. Place your own rule at: " + $dest)
      return
    }
  }
  $s = Get-State
  if (@($s.enabled) -notcontains $App) { $s.enabled = @($s.enabled) + $App }
  Save-State $s
  Write-Ok ("[$App] enabled - OBSERVE mode (count/log only). Nothing is deleted until you run: arm -App " + $App)
  Install-Autostart
  Start-Sentinel
}

function Invoke-Disable {
  if (-not $App) { Write-Bad "pass -App <name>"; return }
  Invoke-Disarm -Quiet
  $dest = Join-Path $UserRulesDir ($App + '.json')
  if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
  $s = Get-State
  $s.enabled = @($s.enabled | Where-Object { $_ -ne $App })
  Save-State $s
  Write-Ok ("[$App] disabled and rule removed.")
  if (@($s.enabled).Count -eq 0) {
    $spid = Get-SentinelPid
    if ($spid) { Stop-Process -Id $spid -Force; Write-Info ("sentinel stopped (pid " + $spid + ")") }
    if (Test-Path -LiteralPath $StartupCmd) { Remove-Item -LiteralPath $StartupCmd -Force; Write-Info "autostart removed." }
  }
}

function Invoke-Disarm([switch]$Quiet) {
  if (-not $App) { Write-Bad "pass -App <name>"; return }
  $rule = Get-Rules | Where-Object { $_.app -eq $App }
  if ($rule) {
    $primaryRoot = Expand-RootPath @($rule.dataRoots)[0]
    foreach ($dw in @($rule.actions.denyWriteDirs)) { Disable-DenyPath $primaryRoot $dw }
  }
  $s = Get-State
  $s.armed = @($s.armed | Where-Object { $_ -ne $App })
  Save-State $s
  if (-not $Quiet) { Write-Ok ("[$App] disarmed - back to observe mode.") }
}

function Invoke-Arm {
  if (-not $App) { Write-Bad "pass -App <name>"; return }
  $rule = Get-Rules | Where-Object { $_.app -eq $App }
  if (-not $rule) { Write-Bad ("rule not enabled for '" + $App + "'. Run: enable -App " + $App); return }
  $s = Get-State
  if (@($s.armed) -notcontains $App) { $s.armed = @($s.armed) + $App }
  Save-State $s
  $primaryRoot = Expand-RootPath @($rule.dataRoots)[0]
  foreach ($dw in @($rule.actions.denyWriteDirs)) {
    $ok = Enable-DenyPath $primaryRoot $dw
    if ($ok) { Write-Ok ("[$App] deny-write ACTIVE: " + (Join-Path $primaryRoot ($dw -replace '/', '\'))) }
    else { Write-Bad ("[$App] deny-write FAILED (not user-owned?): " + $dw) }
  }
  Write-Ok ("[$App] ARMED - delete/quarantine/deny now active. disarm -App " + $App + " to revert.")
}

function Show-Status {
  $rules = Get-Rules
  $s = Get-State
  $spid = Get-SentinelPid
  $sentStr = 'stopped'; if ($spid) { $sentStr = 'running (pid ' + $spid + ')' }
  $asStr = 'no'; if (Test-Path -LiteralPath $StartupCmd) { $asStr = 'yes' }
  Write-Info ("engine: active-rules=" + @($rules).Count + "  sentinel=" + $sentStr + "  autostart=" + $asStr)
  if (@($rules).Count -eq 0) {
    Write-Info "no active rules - nothing is being watched or touched."
    Write-Info ("run 'examples' to list templates, then 'enable -App <name>'.")
    return
  }
  Write-Info ("{0,-14} {1,-9} {2,-11} {3}" -f 'APP','MODE','EVIDENCE','ARTIFACTS-NOW')
  foreach ($r in $rules) {
    $en = @($s.enabled) -contains $r.app
    $armed = Test-Armed $r.app
    $mode = 'observe'
    if ($en -and $armed) { $mode = 'ARMED' } elseif (-not $en) { $mode = 'inactive' }
    $files = 0
    foreach ($rootSpec in @($r.dataRoots)) {
      $root = Expand-RootPath $rootSpec
      if (-not (Test-Path -LiteralPath $root)) { continue }
      $all = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue)
      foreach ($f in $all) {
        $act = Invoke-Classify $root $r $f.FullName $armed $false
        if ($act -ne 'ignored' -and $act -ne 'outside') { $files++ }
      }
    }
    Write-Host ("  {0,-14} {1,-9} {2,-11} {3}" -f $r.app, $mode, $r.maturity, $files)
  }
  if (Test-Path -LiteralPath $GuardLog) {
    Write-Info "log tail:"
    Get-Content -LiteralPath $GuardLog -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ("    " + $_) }
  }
}

switch ($Action) {
  'examples' {
    Write-Info ("shipped templates (INERT until enabled): " + $ExamplesDir)
    foreach ($f in (Get-RuleFilesFrom $ExamplesDir)) {
      $r = $null
      try { $r = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
      if ($r) { Write-Host ("  {0,-14} evidence={1,-11} roots={2}" -f $r.app, $r.maturity, (@($r.dataRoots) -join ', ')) }
    }
    Write-Info "enable one with: enable -App <name>"
  }
  'rules' {
    $act = Get-Rules
    foreach ($r in $act) { Write-Host ("  {0,-14} {1,-11} roots={2}" -f $r.app, $r.maturity, (@($r.dataRoots) -join ', ')) }
    if (@($act).Count -eq 0) { Write-Info "(none active)" }
  }
  'status'    { Show-Status }
  'sweep'     {
    $rules = Get-Rules
    if (@($rules).Count -eq 0) { Write-Bad "no active rules."; return }
    $total = 0
    foreach ($r in $rules) { $n = Invoke-SweepRule $r; $total += $n; Write-Info ("[" + $r.app + "] removed " + $n) }
    Write-Ok ("sweep done, removed " + $total + " file(s)")
  }
  'enable'    { Invoke-Enable }
  'disable'   { Invoke-Disable }
  'arm'       { Invoke-Arm }
  'disarm'    { Invoke-Disarm }
  'install'   {
    Write-Info "nothing to install: this tool ships inert. Flow: examples -> enable -App <name> -> (optionally) arm -App <name>."
    if (@((Get-State).enabled).Count -gt 0) { Install-Autostart; Start-Sentinel }
  }
  'uninstall' {
    foreach ($app in @((Get-State).enabled)) { $App = $app; Invoke-Disable }
    $spid = Get-SentinelPid
    if ($spid) { Stop-Process -Id $spid -Force; Write-Info ("sentinel stopped (pid " + $spid + ")") }
    if (Test-Path -LiteralPath $StartupCmd) { Remove-Item -LiteralPath $StartupCmd -Force; Write-Info "autostart removed." }
    Write-Ok "full teardown complete. Quarantine kept for evidence."
  }
  'run'       {
    $created = $false
    $mutex = New-Object System.Threading.Mutex($true, 'Local\agent-snapshot-guard', [ref]$created)
    if (-not $created) { exit 0 }
    Write-GuardLog 'engine' ("sentinel started (pid " + $PID + ")")
    while ($true) {
      $s = Get-State
      foreach ($app in @($s.enabled)) {
        $rule = Get-Rules | Where-Object { $_.app -eq $app }
        if ($rule) {
          $n = Invoke-SweepRule $rule
          if ($n -gt 0) { Write-GuardLog $app ("sweep removed " + $n + " file(s)") }
        }
      }
      Start-Sleep -Seconds 5
    }
  }
}
