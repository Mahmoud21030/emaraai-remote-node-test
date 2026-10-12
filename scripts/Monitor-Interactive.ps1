$ErrorActionPreference = 'Stop'
$hub = $env:HUB_URL.TrimEnd('/')
$end = (Get-Date).AddMinutes(350)
$connected = $false
$peak = 0
$samples = 0
$last = ''
while ((Get-Date) -lt $end -and !(Test-Path 'C:\EmaraAI-Test\finish.txt')) {
    $memory = [int]((Get-Process chrome -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum / 1MB)
    $peak = [Math]::Max($peak, $memory)
    $samples++
    try {
        $status = Invoke-RestMethod "$hub/api/v1/ext/status" -TimeoutSec 10
        $ours = [bool]($status.connected -and $status.node -eq $env:COMPUTERNAME)
        if ($ours) { $connected = $true }
        $state = if ($ours) { 'Runner extension connected' } elseif ($status.connected) { 'Another browser serves the Hub' } else { 'Extension disconnected' }
    } catch { $state = 'Hub unreachable' }
    $message = "$state | Chrome working set $memory MB"
    if ($message -ne $last) { Write-Output ((Get-Date -Format 'HH:mm:ss') + ' ' + $message); $last = $message }
    Start-Sleep -Seconds 30
}
"### Browser test observations`n- Runner extension connected at least once: $connected`n- Peak Chrome working set: $peak MB`n- Samples: $samples`n- Prompt completion must be confirmed by the human tester; connection alone is not an end-to-end pass." | Out-File $env:GITHUB_STEP_SUMMARY -Append
if (!$connected) { throw 'Runner extension never connected to the Hub during this test' }
