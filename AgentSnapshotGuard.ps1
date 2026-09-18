# ============================================================================
#  AgentSnapshotGuard.ps1
#  Rules-driven privacy sentinel for AI coding clients (Windows, PS 5.1+).
#  ----------------------------------------------------------------------------
#  Actions per app rule (rules/*.json):
#    denyWriteDirs      - ACL write-deny (owner-right, no admin needed)
#    deleteDirNames     - any dir with these names: contents get deleted
#    deleteFileNames    - files matching these leaf patterns get deleted
#    quarantineFileNames- files moved to quarantine (reversible, sha256 logged)
#    monitorFileNames   - counted/logged only (observe-first posture)
#
#  Maturity policy:
#    verified   - full forensics published; destructive actions armed by default
#    community  - observe-only unless installed with -Force
#
#  Commands:
#    .\AgentSnapshotGuard.ps1 install  [-App <name|all>] [-Force]
#    .\AgentSnapshotGuard.ps1 status
#    .\AgentSnapshotGuard.ps1 sweep    [-App <name|all>]
#    .\AgentSnapshotGuard.ps1 rules
#    .\AgentSnapshotGuard.ps1 uninstall [-App <name|all>]
#    .\AgentSnapshotGuard.ps1 run       # sentinel foreground (used by autostart)
#
#  License: MIT
# ============================================================================
#Requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('install','status','sweep','uninstall','run','rules')]
  [string]$Action = 'status',

  [string]$App = 'all',
  [switch]$Force,
  [string]$RulesDir = ''
)

$ErrorActionPreference = 'SilentlyContinue'
$StateDir      = Join-Path $env:USERPROFILE '.agent-snapshot-guard'
$StateFile     = Join-Path $StateDir 'state.json'
$QuarantineDir = Join-Path $StateDir 'quarantine'
$GuardLog      = Join-Path $StateDir 'guard.log'
$StartupCmd    = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\agent-snapshot-guard.cmd'
$ScriptFile    = $PSCommandPath
if (-not $RulesDir) { $RulesDir = Join-Path (Split-Path -Parent $ScriptFile) 'rules' }

function Write-Info($m) { Write-Host ("[*] " + $m) }
function Write-Bad($m)  { Write-Host ("[!] " + $m) -ForegroundColor Yellow }
function Write-Ok($m)   { Write-Host ("[+] " + $m) -ForegroundColor Green }

function Expand-RootPath([string]$p) {
  return [Environment]::ExpandEnvironmentVariables(($p -replace '/', '\'))
}

function Get-Rules {
  $out = @()
  if (-not (Test-Path -LiteralPath $RulesDir)) { return $out }
  $fs = @(Get-ChildItem -LiteralPath $RulesDir -Filter '*.json' -File -ErrorAction SilentlyContinue)
  foreach ($f in $fs) {
    $r = $null
    try { $r = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if ($r -and $r.schema -eq 'asg-rule/v1' -and $r.app) { $out += $r }
    else { Write-Bad ("rule skipped (bad schema): " + $f.Name) }
  }
  return $out
}

function Get-SelectedRules {
  $all = Get-Rules
  if ($App -eq 'all') { return $all }
  return @($all | Where-Object { $_.app -eq $App })
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

function Is-Armed($rule) {
  if ($rule.maturity -eq 'verified') { return $true }
  if ($Force) { return $true }
  $s = Get-State
  return (@($s.armed) -contains $rule.app)
}

function Invoke-Classify([string]$root,$rule,[string]$full,[bool]$armed) {
  $rel = Get-RelativeInside $full $root
  if (-not $rel) { return 'outside' }
  $a = $rule.actions
  if ($armed) {
    if (Test-SegmentMatch $rel @($a.deleteDirNames)) {
      if (Remove-AnyWay $full) { return 'deleted' } else { return 'locked' }
    }
    if (Test-NameMatch $full @($a.deleteFileNames)) {
      if (Remove-AnyWay $full) { return 'deleted' } else { return 'locked' }
    }
    if (Test-NameMatch $full @($a.quarantineFileNames)) { return (Invoke-Quarantine $root $rule.app $full) }
  }
  if (Test-NameMatch $full @($a.monitorFileNames)) { return 'monitored' }
  return 'ignored'
}

function Invoke-SweepRule($rule) {
  $armed = Is-Armed $rule
  $total = 0
  foreach ($rootSpec in @($rule.dataRoots)) {
    $root = Expand-RootPath $rootSpec
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
      $act = Invoke-Classify $root $rule $f.FullName $armed
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
  Start-Process -FilePath $engine -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',("'" + $ScriptFile + "'"),'-Action','run') -WindowStyle Hidden
  Start-Sleep -Seconds 2
  $now = Get-SentinelPid
  if ($now) { Write-Ok ("Sentinel started (pid " + $now + ")") } else { Write-Bad "Sentinel failed to start (check log)." }
}

function Invoke-Install {
  $rules = Get-SelectedRules
  if (@($rules).Count -eq 0) { Write-Bad ("no rules matched: " + $App); return }
  $s = Get-Stater
  $enabledList = @($s.enabled); $armedList = @($s.armed)
  foreach ($rule in $rules) {
    $armed = ($rule.maturity -eq 'verified') -or $Force
    $primaryRoot = Expand-RootPath @($rule.dataRoots)[0]
    foreach ($dw in @($rule.actions.denyWriteDirs)) {
      $ok = Enable-DenyPath $primaryRoot $dw
      if ($ok) { Write-Ok ("[" + $rule.app + "] deny-write ACTIVE: " + (Join-Path $primaryRoot ($dw -replace '/', '\'))) }
      else { Write-Bad ("[" + $rule.app + "] deny-write FAILED (not user-owned?): " + $dw) }
    }
    $n = Invoke-SweepRule $rule
    Write-Info ("[" + $rule.app + "] initial sweep removed " + $n + " file(s)")
    if ($armed) {
      if ($armedList -notcontains $rule.app) { $armedList += $rule.app }
    } else {
      Write-Info ("[" + $rule.app + "] monitor-only (maturity=" + $rule.maturity + "; arm with: install -App " + $rule.app + " -Force)")
    }
    if ($enabledList -notcontains $rule.app) { $enabledList += $rule.app }
  }
  $s.enabled = $enabledList; $s.armed = $armedList
  Save-State $s
  Install-Autostart
  Start-Sentinel
}

function Invoke-Uninstall {
  $rules = Get-SelectedRules
  $s = Get-State
  foreach ($rule in $rules) {
    $primaryRoot = Expand-RootPath @($rule.dataRoots)[0]
    foreach ($dw in @($rule.actions.denyWriteDirs)) { Disable-DenyPath $primaryRoot $dw }
    $s.enabled = @($s.enabled | Where-Object { $_ -ne $rule.app })
    $s.armed   = @($s.armed   | Where-Object { $_ -ne $rule.app })
    Write-Info ("[" + $rule.app + "] defenses removed")
  }
  Save-State $s
  if (@($s.enabled).Count -eq 0) {
    $spid = Get-SentinelPid
    if ($spid) { Stop-Process -Id $spid -Force; Write-Info ("sentinel stopped (pid " + $spid + ")") }
    if (Test-Path -LiteralPath $StartupCmd) { Remove-Item -LiteralPath $StartupCmd -Force; Write-Info "autostart removed." }
    Write-Ok "full teardown complete."
  } else {
    Write-Info ("still guarding: " + (@($s.enabled) -join ', '))
  }
}

function Show-Status {
  $rules = Get-Rulesr
  $s = Get-State
  $spid = Get-SentinelPid
  $sentStr = 'stopped'; if ($spid) { $sentStr = 'running (pid ' + $spid + ')' }
  $asStr = 'no'; if (Test-Path -LiteralPath $StartupCmd) { $asStr = 'yes' }
  Write-Info ("engine: rules=" + @($rules).Count + "  sentinel=" + $sentStr + "  autostart=" + $asStr)
  Write-Info ("{0,-14} {1,-9} {2,-11} {3}" -f 'APP','MODE','MATURITY','ARTIFACTS-NOW')
  foreach ($r in $rules) {
    $en = @($s.enabled) -contains $r.app
    $armed = Is-Armed $r
    $mode = 'off'
    if ($en -and $armed) { $mode = 'ARMED' } elseif ($en) { $mode = 'monitor' }
    $files = 0
    foreach ($rootSpec in @($r.dataRoots)) {
      $root = Expand-RootPath $rootSpec
      if (-not (Test-Path -LiteralPath $root)) { continue }
      $all = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue)
      foreach ($f in $all) {
        $act = Invoke-Classify $root $r $f.FullName $armed
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
  'rules' {
    foreach ($r in Get-Rules) {
      Write-Host ("  {0,-14} {1,-11} roots={2}" -f $r.app, $r.maturity, (@($r.dataRoots) -join ', '))
      if ($r.notes) { $first = ([string]$r.notes).Split("`n")[0]; Write-Host ("      " + $first) }
    }
  }
  'status'    { Show-Status }
  'sweep'     {
    $total = 0
    foreach ($r in Get-SelectedRules) { $n = Invoke-SweepRule $r; $total += $n; Write-Info ("[" + $r.app + "] removed " + $n) }
    Write-Ok ("sweep done, removed " + $total + " file(s)")
  }
  'install'   { Invoke-Install }
  'uninstall' { Invoke-Uninstall }
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
