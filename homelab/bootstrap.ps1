#Requires -Version 5.1
# Generates only homelab credentials. Existing nonempty credentials are retained.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$path = Join-Path $root '.env'
if (-not (Test-Path -LiteralPath $path)) { throw 'Copy .env.example to .env first (values can stay empty).' }
$text = [IO.File]::ReadAllText($path)
$values = @{}
foreach ($line in ($text -split '\r?\n')) {
    if ($line -match '^([A-Z0-9_]+)=(.*)$') { $values[$Matches[1]] = $Matches[2].Trim() }
}
function New-LabPassword {
    $bytes = New-Object byte[] 18
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return ('Aa1!' + [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant())
}
foreach ($key in @('SMB_ALICE_PASSWORD','SMB_BOB_PASSWORD','WG_ADMIN_PASSWORD','AD_ADMIN_PASSWORD','AD_ALICE_PASSWORD','AD_BOB_PASSWORD','AD_CAROL_PASSWORD','CUPS_ADMIN_PASSWORD','KUMA_ADMIN_PASSWORD')) {
    if (-not $values[$key]) {
        $values[$key] = New-LabPassword
        if ($text -match ("(?m)^" + $key + '=')) {
            $text = [regex]::Replace($text, ("(?m)^" + $key + '=[^\r\n]*'), ($key + '=' + $values[$key]))
        } else { $text = $text.TrimEnd() + [Environment]::NewLine + $key + '=' + $values[$key] + [Environment]::NewLine }
    }
}
if (-not $values['WG_HOST']) {
    $values['WG_HOST'] = 'localhost'
    $text = [regex]::Replace($text, '(?m)^WG_HOST=[^
]*', 'WG_HOST=localhost')
}
if (-not $values['WG_PASSWORD_HASH']) {
    $output = & docker run --rm ghcr.io/wg-easy/wg-easy:14 wgpw $values['WG_ADMIN_PASSWORD'] 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'wgpw failed; output suppressed to protect the password.' }
    $match = [regex]::Match(($output | Out-String), '\$2[aby]\$\d\d\$[./A-Za-z0-9]{53}')
    if (-not $match.Success) { throw 'wgpw returned no valid bcrypt hash.' }
    $escaped = $match.Value.Replace('$', '$$')
    if ($text -match '(?m)^WG_PASSWORD_HASH=') {
        $replacement = 'WG_PASSWORD_HASH=' + $escaped
        $text = [regex]::Replace($text, '(?m)^WG_PASSWORD_HASH=[^\r\n]*', [Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement })
    } else { $text = $text.TrimEnd() + [Environment]::NewLine + 'WG_PASSWORD_HASH=' + $escaped + [Environment]::NewLine }
}
[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
Write-Host 'Homelab credentials ready in .env; no secret values printed.'
