# PowerShell 5.1. Evidence captures redacted check output, never raw sessions.
$script:LabRoot = Split-Path $PSScriptRoot -Parent
$script:LabEnv = @{}
Get-Content -LiteralPath (Join-Path $script:LabRoot '.env') | ForEach-Object {
    if ($_ -match '^([A-Z0-9_]+)=(.*)$') {
        $script:LabEnv[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'").Replace('$$', '$')
    }
}
$script:Failures = 0
function Protect-LabText([string]$Text) {
    foreach ($key in $script:LabEnv.Keys) {
        if ($key -match 'PASSWORD|HASH|TOKEN|KEY' -and $script:LabEnv[$key]) {
            $Text = $Text.Replace($script:LabEnv[$key], '[REDACTED]')
        }
    }
    $Text = $Text -replace '(?im)^((?:PrivateKey|PresharedKey)\s*=\s*).+$', '$1[REDACTED]'
    return ($Text -replace '\$2[aby]\$\d\d\$[./A-Za-z0-9]{53}', '[REDACTED-BCRYPT]')
}
function Write-Evidence([string]$Text) {
    $safe = Protect-LabText $Text
    Write-Host $safe
    Add-Content -LiteralPath $script:EvidencePath -Value $safe -Encoding UTF8
}
function Start-LabEvidence([string]$Prefix) {
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById('AUS Eastern Standard Time')
    $now = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $zone)
    $folder = Join-Path $script:LabRoot 'docs\evidence'
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $script:EvidencePath = Join-Path $folder ($Prefix + '-' + $now.ToString('yyyyMMdd-HHmmss-fff') + '.txt')
    Write-Evidence ("Lab simulation; " + $now.ToString('yyyy-MM-dd HH:mm:ss') + ' Australia/Sydney')
    Write-Evidence ("PowerShell " + $PSVersionTable.PSVersion)
}
function Invoke-LabDocker([string[]]$DockerArgs) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& docker @DockerArgs 2>&1 | ForEach-Object { $_.ToString() } | Out-String)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $old }
    return [PSCustomObject]@{ Code = $code; Output = (Protect-LabText $output).Trim() }
}
function Invoke-CheckedDocker([string]$Label, [string[]]$DockerArgs) {
    Write-Evidence ('> ' + $Label)
    $result = Invoke-LabDocker $DockerArgs
    if ($result.Output) { Write-Evidence $result.Output }
    if ($result.Code -ne 0) { throw "$Label exited $($result.Code)" }
    return $result.Output
}
function Test-LabStep([string]$Name, [scriptblock]$Body) {
    try { & $Body; Write-Evidence ("PASS " + $Name) }
    catch { $script:Failures++; Write-Evidence ("FAIL " + $Name + ': ' + $_.Exception.Message) }
}
function Assert-Lab([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Open-WgSession {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $body = @{ password = $script:LabEnv['WG_ADMIN_PASSWORD'] } | ConvertTo-Json -Compress
    $null = Invoke-RestMethod -Uri 'http://127.0.0.1:51821/api/session' -Method Post -ContentType 'application/json' -Body $body -WebSession $session
    return $session
}
function Get-WgClients($Session) {
    Invoke-RestMethod -Uri 'http://127.0.0.1:51821/api/wireguard/client' -WebSession $Session | ForEach-Object { foreach ($client in $_) { $client } }
}
