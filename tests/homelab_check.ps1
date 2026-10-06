#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lab_helpers.ps1')
Push-Location $script:LabRoot
try {
    Start-LabEvidence 'homelab-check'
    foreach ($service in @('wireguard', 'fileserver', 'printserver', 'uptime')) {
        Test-LabStep "$service container running" {
            $id = Invoke-CheckedDocker "compose ps $service" @('compose','--profile','homelab','ps','-q',$service)
            Assert-Lab (-not [string]::IsNullOrWhiteSpace($id)) 'Container missing'
            $state = Invoke-CheckedDocker "inspect $service running" @('inspect','--format','{{.State.Running}}',$id.Trim())
            Assert-Lab ($state.Trim() -eq 'true') 'Container not running'
        }
    }
    Test-LabStep 'Samba shares and access control' {
        $out = Invoke-CheckedDocker 'smbclient: list; Finance ACL; Public read/write' @('compose','exec','-T','fileserver','sh','/lab-check.sh')
        foreach ($text in @('PASS Alice Finance write','PASS Bob Finance denied','PASS alice Public read/write','PASS bob Public read/write')) {
            Assert-Lab ($out.Contains($text)) "Missing proof: $text"
        }
    }
    Test-LabStep 'CUPS queues and completed test page' {
        $out = Invoke-CheckedDocker 'lpstat; Office-PDF job; completed state and PDF artifact' @('compose','exec','-T','printserver','sh','/lab-check.sh')
        Assert-Lab ($out.Contains('Office-Laser') -and $out.Contains('Office-PDF')) 'Missing queue'
        Assert-Lab ($out.Contains('PASS PDF job completed')) 'Completion not proved'
    }
    Test-LabStep 'CUPS public views and authenticated administration' {
        foreach ($path in @('/','/jobs','/printers')) {
            $response = Invoke-WebRequest -UseBasicParsing -Uri ('http://127.0.0.1:6631' + $path) -TimeoutSec 15
            Assert-Lab ($response.StatusCode -eq 200) "CUPS $path failed"
            Write-Evidence ("GET $path => HTTP 200")
        }
        $status = 0
        try { $null = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:6631/admin/' -TimeoutSec 15 }
        catch { if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode } else { throw } }
        Assert-Lab ($status -eq 401) "Anonymous /admin returned $status"
        Write-Evidence 'GET /admin/ without credentials => HTTP 401'
        $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('print:' + $script:LabEnv['CUPS_ADMIN_PASSWORD']))
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:6631/admin/' -Headers @{Authorization = ('Basic ' + $token)} -TimeoutSec 15
        Assert-Lab ($response.StatusCode -eq 200) 'Admin login failed'
        Write-Evidence 'GET /admin/ as print => HTTP 200'
    }
    Test-LabStep 'WireGuard UI and peer create/list/delete' {
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:51821' -TimeoutSec 15
        Assert-Lab ($response.StatusCode -eq 200) 'UI failed'
        $session = Open-WgSession
        $name = 'check-' + [Guid]::NewGuid().ToString('N').Substring(0,12)
        try {
            $null = Invoke-RestMethod -Uri 'http://127.0.0.1:51821/api/wireguard/client' -Method Post -ContentType 'application/json' -Body (@{name=$name}|ConvertTo-Json) -WebSession $session
            $peer = Get-WgClients $session | Where-Object { $_.name -eq $name }
            Assert-Lab ($null -ne $peer) 'New peer absent'
            Write-Evidence ("POST /api/session => success; peer listed: " + $peer.name + ' ' + $peer.address)
        } finally {
            foreach ($item in @(Get-WgClients $session | Where-Object { $_.name -eq $name })) {
                $null = Invoke-RestMethod -Uri ('http://127.0.0.1:51821/api/wireguard/client/' + $item.id) -Method Delete -WebSession $session
            }
        }
        Assert-Lab (@(Get-WgClients $session | Where-Object {$_.name -eq $name}).Count -eq 0) 'Peer still present'
        Write-Evidence 'DELETE peer => success; absent on subsequent GET'
    }
    Test-LabStep 'Uptime Kuma HTTP response' {
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:13001' -TimeoutSec 15
        Assert-Lab ($response.StatusCode -eq 200) 'Uptime Kuma failed'
        Write-Evidence 'GET http://127.0.0.1:13001 => HTTP 200'
    }
    Write-Evidence ("RESULT: " + $script:Failures + ' failed checks')
    Write-Evidence ("Evidence: " + $script:EvidencePath)
} finally { Pop-Location }
if ($script:Failures -gt 0) { exit 1 }
exit 0
