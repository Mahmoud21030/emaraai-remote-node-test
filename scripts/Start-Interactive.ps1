$ErrorActionPreference = 'Stop'
$settings = Get-Content 'C:\EmaraAI-Test\settings.json' -Raw | ConvertFrom-Json
& 'C:\EmaraAI-Test\EmaraAI-RemoteNode\Start-Node.ps1' -Hub $settings.hub -BrowserPath $settings.browser
