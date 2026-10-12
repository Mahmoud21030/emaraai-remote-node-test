$ErrorActionPreference = 'Stop'
$root = 'C:\EmaraAI-Test'
New-Item -ItemType Directory -Force $root | Out-Null
Copy-Item "$PSScriptRoot\..\EmaraAI-RemoteNode" $root -Recurse -Force
$metadata = Invoke-RestMethod 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json'
$url = ($metadata.channels.Stable.downloads.chrome | Where-Object platform -eq 'win64').url
if (!$url.StartsWith('https://storage.googleapis.com/chrome-for-testing-public/')) { throw 'Unexpected Chrome download host' }
Invoke-WebRequest $url -OutFile "$root\chrome.zip"
Expand-Archive "$root\chrome.zip" "$root\browser" -Force
Remove-Item -LiteralPath "$root\chrome.zip"
$browser = "$root\browser\chrome-win64\chrome.exe"
if (!(Test-Path $browser)) { throw 'Chrome for Testing missing' }
$hub = $env:HUB_URL.TrimEnd('/')
Invoke-RestMethod "$hub/health" -TimeoutSec 30 | Out-Null
@{ hub = $hub; browser = $browser } | ConvertTo-Json | Set-Content "$root\settings.json" -Encoding utf8
$secret = ConvertTo-SecureString $env:RDP_PASSWORD -AsPlainText -Force
New-LocalUser -Name 'EmaraTester' -Password $secret -Description 'Temporary integration-test user' | Out-Null
Add-LocalGroupMember -SID 'S-1-5-32-555' -Member 'EmaraTester'
& icacls.exe $root /grant 'EmaraTester:(OI)(CI)M' /T /Q | Out-Null
if ($LASTEXITCODE) { throw 'Test directory permissions failed' }
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' fDenyTSConnections 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' UserAuthentication 1
# Remove existing inbound RDP allows before opening only this private route.
Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow | Where-Object {
    $rule = $_
    $ports = $rule | Get-NetFirewallPortFilter
    ($rule.Service -eq 'TermService') -or ($ports.LocalPort -contains '3389') -or ($rule.Name -like 'RemoteDesktop*')
} | Disable-NetFirewallRule
$ts = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
$ip = (& $ts ip -4 | Select-Object -First 1).Trim()
New-NetFirewallRule -Name 'EmaraAI-Test-RDP' -DisplayName 'EmaraAI test RDP via Tailscale from owner PC' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3389 -LocalAddress $ip -RemoteAddress $env:TESTER_IP -Profile Any | Out-Null
Start-Service TermService
Copy-Item "$PSScriptRoot\Start-Interactive.ps1" "$root\Start-Interactive.ps1"
@'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\EmaraAI-Test\Start-Interactive.ps1
'@ | Set-Content 'C:\Users\Public\Desktop\Start EmaraAI Test.cmd' -Encoding ascii
@'
@echo off
echo finished>C:\EmaraAI-Test\finish.txt
'@ | Set-Content 'C:\Users\Public\Desktop\Finish Test.cmd' -Encoding ascii
"RDP_ADDRESS=$ip" | Out-File $env:GITHUB_ENV -Append
"### Desktop ready`n- Tailscale IP: $ip`n- Username: .\EmaraTester`n- Chrome for Testing: $($metadata.channels.Stable.version)`n- Double-click Start EmaraAI Test on the desktop.`n- Run your test, then double-click Finish Test to stop early.`n- Password is stored in the RDP_PASSWORD secret; it is never printed here." | Out-File $env:GITHUB_STEP_SUMMARY -Append
Write-Output "Desktop ready: $ip; user .\EmaraTester"
