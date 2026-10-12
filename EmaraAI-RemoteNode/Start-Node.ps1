# EmaraAI remote node: runs the browser side of the hub (Chrome + the hub's extension + your ChatGPT session) on THIS machine.
# The hub itself stays on your own PC; this machine only holds the ChatGPT tabs and their memory.
# Nothing is installed by this script. It needs: Google Chrome, and Tailscale signed in to the same account as the hub's PC.
param(
    [string]$Hub = "",              # the hub's private (Tailscale) address; asked once and remembered
    [double]$RestartHours = 0,      # restart Chrome every N hours to give its memory back (0 = never)
    [switch]$Throttled,             # start Chrome WITHOUT the switches that keep covered windows and background tabs awake
    [switch]$NoDevTools,            # do NOT open the inspector (DevTools) with every tab
    [string]$BrowserPath = ""       # optional Chrome for Testing executable
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ext = Join-Path $here "extension"
$data = Join-Path $env:LOCALAPPDATA "EmaraAI-Node"
$profileDir = Join-Path $data "chrome-profile"
$cfgFile = Join-Path $data "node.cfg"
New-Item -ItemType Directory -Force -Path $data | Out-Null

function Say($text, $color = "Gray") { Write-Host $text -ForegroundColor $color }
function Stop-Here($text) { Say ""; Say $text "Yellow"; Say ""; Read-Host "Press Enter to close" | Out-Null; exit 1 }

Say "EmaraAI remote node" "Cyan"
Say "-------------------"

# 1. Chrome
$chrome = @($BrowserPath, "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $chrome) { Stop-Here "Google Chrome is not installed on this machine. Install it from https://www.google.com/chrome/ and start this again." }
Say "Chrome:     found"

# 2. Tailscale
$ts = @("$env:ProgramFiles\Tailscale\tailscale.exe", "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $ts) { Stop-Here "Tailscale is not installed on this machine. Install it from https://tailscale.com/download, sign in with the SAME account as the hub's PC, and start this again." }
$status = (& $ts status 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $status -match "Logged out|NeedsLogin|stopped") { Stop-Here "Tailscale is installed but not connected. Open Tailscale, sign in with the same account as the hub's PC, and start this again." }
Say "Tailscale:  connected"

# 3. the hub's address
if (-not $Hub -and (Test-Path $cfgFile)) { $Hub = (Get-Content $cfgFile -Raw).Trim() }
while ($true) {
    if (-not $Hub) {
        Say ""
        Say "Paste the hub's private address. You find it on the hub's PC: Control Center > Settings > Remote access." "White"
        Say "(It looks like https://<pc-name>.<your-tailnet>.ts.net:8797 - never share it publicly.)"
        $Hub = (Read-Host "Hub address").Trim().TrimEnd("/")
    }
    try {
        $h = Invoke-RestMethod -Uri ($Hub + "/health") -TimeoutSec 15
        Say ("Hub:        reachable (version " + $h.version + ")")
        break
    } catch {
        Say ("The hub did not answer at that address: " + $_.Exception.Message) "Yellow"
        Say "Check that the hub is running, that Remote access is switched on there, and that both machines are on the same Tailscale account."
        $Hub = ""
    }
}
Set-Content -Path $cfgFile -Value $Hub -Encoding ascii
# the extension reads its hub address from node.json next to it (its popup can still change it)
$node = @{ hub = $Hub; name = $env:COMPUTERNAME } | ConvertTo-Json -Compress
[IO.File]::WriteAllText((Join-Path $ext "node.json"), $node, (New-Object Text.UTF8Encoding($false)))

# 4. Chrome with its own profile for the node
$flags = @("--user-data-dir=`"$profileDir`"", "--no-first-run", "--no-default-browser-check", "--restore-last-session", "--load-extension=`"$ext`"")
# The owner's rule: the inspector (DevTools) is open with every tab - conversations seem to load better with it. It costs memory per tab.
if (-not $NoDevTools) { $flags += "--auto-open-devtools-for-tabs" }
if (-not $Throttled) { $flags += @("--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding", "--disable-background-timer-throttling") }
$first = -not (Test-Path (Join-Path $profileDir "Default"))

function Start-NodeChrome {
    $pages = @("https://chatgpt.com/")
    if ($first) { $pages += "chrome://extensions/" }
    Start-Process -FilePath $chrome -ArgumentList ($flags + $pages)
}
function Stop-NodeChrome {
    # only the node's own Chrome (the one that uses the node's profile folder), asked to close the normal way first
    $mine = Get-CimInstance Win32_Process -Filter "name='chrome.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) }
    foreach ($p in $mine | Where-Object { $_.CommandLine -notmatch "--type=" }) { try { (Get-Process -Id $p.ProcessId).CloseMainWindow() | Out-Null } catch {} }
    Start-Sleep -Seconds 8
    Get-CimInstance Win32_Process -Filter "name='chrome.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
}
function Test-Connected {
    try { $a = Invoke-RestMethod -Uri ($Hub + "/api/v1/ext/status") -TimeoutSec 10; return $a } catch { return $null }
}

Start-NodeChrome
Say ""
Say "Chrome was started for the node." "Green"
if ($first) {
    Say ""
    Say "FIRST TIME ON THIS MACHINE - do these once, in the Chrome window that opened:" "White"
    Say "  1. Sign in to ChatGPT (your own account). The hub never sees your password."
    Say "  2. On the tab chrome://extensions : if 'EmaraAI Hub Connector' is NOT listed, switch on 'Developer mode' (top right),"
    Say "     press 'Load unpacked' and choose this folder:"
    Say ("        " + $ext) "White"
    Say "  3. On the hub's own PC: close Chrome or switch the extension off there. Only one browser serves the hub at a time."
    Say ""
    Say "Your ChatGPT connectors (EmaraAI Master / Agent / Reply) belong to your ChatGPT account: nothing has to be connected again."
}
Say ""
Say "Leave this window open. It shows whether this browser is the one serving the hub." "Gray"
if ($RestartHours -gt 0) { Say ("Chrome is restarted every " + $RestartHours + " hour(s) to give its memory back.") }

$nextRestart = if ($RestartHours -gt 0) { (Get-Date).AddHours($RestartHours) } else { $null }
$last = ""
while ($true) {
    Start-Sleep -Seconds 30
    $st = Test-Connected
    $line = if ($null -eq $st) { "hub not reachable" } elseif ($st.connected -and $st.node -eq $env:COMPUTERNAME) { "serving the hub (extension " + $st.version + ")" }
            elseif ($st.connected) { "the hub is served by another browser (" + $st.node + ")" } else { "extension not connected yet" }
    $mem = [int]((Get-Process chrome -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum / 1MB)
    $free = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
    $show = "$line | Chrome $mem MB | free $free MB"
    if ($show -ne $last) { Say ((Get-Date -Format "HH:mm:ss") + "  " + $show); $last = $show }
    if (-not (Get-Process chrome -ErrorAction SilentlyContinue)) { Say ((Get-Date -Format "HH:mm:ss") + "  Chrome is not running: starting it again") "Yellow"; $first = $false; Start-NodeChrome }
    if ($nextRestart -and (Get-Date) -ge $nextRestart) {
        Say ((Get-Date -Format "HH:mm:ss") + "  restarting Chrome (every " + $RestartHours + " h)") "Yellow"
        Stop-NodeChrome; $first = $false; Start-NodeChrome
        $nextRestart = (Get-Date).AddHours($RestartHours)
    }
}
