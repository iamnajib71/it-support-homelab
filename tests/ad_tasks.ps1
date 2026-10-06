#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lab_helpers.ps1')
Push-Location $script:LabRoot
try {
    Start-LabEvidence 'ad-tasks'
    Test-LabStep 'AD directory healthy and seeded' {
        $id = Invoke-CheckedDocker 'compose ps directory' @('compose','ps','-q','directory')
        $health = Invoke-CheckedDocker 'directory health' @('inspect','--format','{{.State.Health.Status}}',$id.Trim())
        Assert-Lab ($health.Trim() -eq 'healthy') 'Directory not healthy'
        $null = Invoke-CheckedDocker 'samba-tool ntacl sysvolcheck' @('compose','exec','-T','directory','samba-tool','ntacl','sysvolcheck')
        $ous = Invoke-CheckedDocker 'samba-tool ou list' @('compose','exec','-T','directory','samba-tool','ou','list')
        foreach ($ou in @('Staff','Finance','IT')) { Assert-Lab ($ous.Contains("OU=$ou")) "Missing OU $ou" }
        $users = Invoke-CheckedDocker 'samba-tool user list' @('compose','exec','-T','directory','samba-tool','user','list')
        foreach ($user in @('alice','bob','carol')) { Assert-Lab ($users -match ("(?m)^" + $user + "\r?$")) "Missing $user" }
        foreach ($group in @('GG-Staff','GG-Finance','GG-IT-Admins')) {
            $null = Invoke-CheckedDocker "samba-tool group listmembers $group" @('compose','exec','-T','directory','samba-tool','group','listmembers',$group)
        }
    }
    Test-LabStep 'AD create/reset/force-change/lock/unlock/group/disable' {
        $out = Invoke-CheckedDocker 'samba-tool service desk tasks and real LDAP lockout' @('compose','exec','-T','directory','sh','/lab/service-desk-tasks.sh')
        foreach ($proof in @('PASS create user in Staff','PASS reset password and force change at next logon','PASS five bad binds set lockoutTime','PASS locked account denies correct password','PASS unlock account and authenticate','PASS add user to GG-Finance','PASS disable leaver flag','PASS disabled leaver denied authentication','PASS temporary account removed')) {
            Assert-Lab ($out.Contains($proof)) "Missing proof: $proof"
        }
    }
    Write-Evidence ("RESULT: " + $script:Failures + ' failed checks')
    Write-Evidence ("Evidence: " + $script:EvidencePath)
} finally { Pop-Location }
if ($script:Failures -gt 0) { exit 1 }
exit 0
