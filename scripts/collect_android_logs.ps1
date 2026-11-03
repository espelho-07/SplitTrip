# scripts/collect_android_logs.ps1
# Captures and filters ADB logcat logs for a specified device

param(
    [Parameter(Mandatory=$true)]
    [string]$Serial,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [string]$Filter = "flutter|CRASH|FATAL|P2P|Sync|HMAC|LocalDb|Supabase",
    [switch]$ClearFirst = $false,
    [int]$Lines = 500
)

$ErrorActionPreference = "SilentlyContinue"

$targetDir = Split-Path -Path $OutputPath -Parent
if ($targetDir -and -not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

if ($ClearFirst) {
    adb -s $Serial logcat -c 2>$null
}

$rawLogs = adb -s $Serial logcat -d -t $Lines 2>$null | Out-String

if ($Filter) {
    $filteredLines = ($rawLogs -split "`r?`n") | Where-Object { $_ -match $Filter }
    $content = $filteredLines -join "`r`n"
} else {
    $content = $rawLogs
}

if ([string]::IsNullOrWhiteSpace($content)) {
    $content = "[LOG EMPTY OR NO MATCHES FOR FILTER '$Filter']`r`nCaptured at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

Set-Content -Path $OutputPath -Value $content -Encoding UTF8
Write-Host "Captured logs for $Serial -> $OutputPath"
