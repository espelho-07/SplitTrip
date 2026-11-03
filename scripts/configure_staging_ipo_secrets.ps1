# scripts/configure_staging_ipo_secrets.ps1
# Automates configuration of IPO Guru and Cron secrets on KITH-STAGING (qfuptgzksecgyjgohtxi)

param(
    [Parameter(Mandatory=$false)]
    [string]$IpoGuruApiKey,

    [Parameter(Mandatory=$false)]
    [string]$CronSecret,

    [switch]$DeployEdgeFunction = $false
)

$StagingRef = "qfuptgzksecgyjgohtxi"
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  KITH - Staging IPO Secrets & Ingestion Configuration     " -ForegroundColor Cyan
Write-Host "  Target: KITH-STAGING ($StagingRef)                       " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Prompt for IPO Guru API key if not supplied
if ([string]::IsNullOrWhiteSpace($IpoGuruApiKey)) {
    Write-Host "`nPlease enter your IPO Guru API key (input is hidden):" -ForegroundColor Yellow
    $secureKey = Read-Host -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $IpoGuruApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

if ([string]::IsNullOrWhiteSpace($IpoGuruApiKey)) {
    Write-Host "[ERROR] IPO Guru API key cannot be empty." -ForegroundColor Red
    exit 1
}

# 2. Generate random Cron Secret if not supplied
if ([string]::IsNullOrWhiteSpace($CronSecret)) {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $CronSecret = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
    Write-Host "`n[OK] Generated secure random CRON_SECRET." -ForegroundColor Green
}

# 3. Configure Supabase Secrets on KITH-STAGING
Write-Host "`n[1/3] Uploading secrets to Supabase KITH-STAGING ($StagingRef)..." -ForegroundColor Cyan
$cmdOutput = & npx supabase secrets set "IPO_GURU_API_KEY=$IpoGuruApiKey" "CRON_SECRET=$CronSecret" --project-ref $StagingRef 2>&1 | Out-String
Write-Host $cmdOutput

# 4. Update server/.env
$serverEnvPath = Join-Path $ProjectRoot "server\.env"
if (Test-Path $serverEnvPath) {
    Write-Host "[2/3] Updating server/.env with API key and Cron secret..." -ForegroundColor Cyan
    $envContent = Get-Content $serverEnvPath -Raw
    
    if ($envContent -match "IPO_GURU_API_KEY=") {
        $envContent = $envContent -replace "IPO_GURU_API_KEY=.*", "IPO_GURU_API_KEY=$IpoGuruApiKey"
    } else {
        $envContent += "`r`nIPO_GURU_API_KEY=$IpoGuruApiKey"
    }

    if ($envContent -match "CRON_SECRET=") {
        $envContent = $envContent -replace "CRON_SECRET=.*", "CRON_SECRET=$CronSecret"
    } else {
        $envContent += "`r`nCRON_SECRET=$CronSecret"
    }

    Set-Content -Path $serverEnvPath -Value $envContent -Encoding UTF8
    Write-Host "  [OK] server/.env updated." -ForegroundColor Green
}

# 5. Optionally deploy the Edge Function
if ($DeployEdgeFunction) {
    Write-Host "`n[3/3] Deploying Edge Function 'ipo-data' to KITH-STAGING ($StagingRef)..." -ForegroundColor Cyan
    $deployOutput = & npx supabase functions deploy ipo-data --project-ref $StagingRef 2>&1 | Out-String
    Write-Host $deployOutput
} else {
    Write-Host "`n[3/3] Edge function deployment skipped. Pass -DeployEdgeFunction to deploy." -ForegroundColor Yellow
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  Configuration Complete!                                   " -ForegroundColor Green
Write-Host "  CRON_SECRET: $CronSecret" -ForegroundColor White
Write-Host "  Keep this CRON_SECRET safe for scheduling sync triggers!  " -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green
