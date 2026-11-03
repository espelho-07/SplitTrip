# scripts/android_device_setup.ps1
# Automated ADB device discovery and verification module for KITH QA

param(
    [switch]$RequireTwoDevices = $false,
    [int]$MaxRetries = 3,
    [int]$RetryDelaySeconds = 2
)

$ErrorActionPreference = "Continue"

function Check-AdbAvailable {
    $adbCmd = Get-Command "adb" -ErrorAction SilentlyContinue
    if (-not $adbCmd) {
        Write-Error "ADB (Android Debug Bridge) is not found in system PATH."
        exit 1
    }
    adb start-server 2>$null | Out-Null
}

function Get-AdbDeviceList {
    $rawOutput = adb devices -l | Out-String
    $lines = $rawOutput -split "`r?`n"
    $devices = @()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("*") -or $trimmed.StartsWith("List of devices")) { continue }

        $parts = -split $trimmed
        if ($parts.Length -lt 2) { continue }

        $serial = $parts[0]
        $state = $parts[1].ToLower()

        $model = "Unknown"
        $product = "Unknown"
        $isEmulator = $serial.StartsWith("emulator-")

        foreach ($p in $parts[2..($parts.Length - 1)]) {
            if ($p.StartsWith("model:")) { $model = $p.Substring(6) }
            if ($p.StartsWith("product:")) { $product = $p.Substring(8) }
        }

        $deviceObj = [PSCustomObject]@{
            Serial         = $serial
            State          = $state
            Model          = $model
            Product        = $product
            IsEmulator     = $isEmulator
            IsAuthorized   = ($state -eq "device")
            AndroidVersion = "N/A"
            SdkLevel       = "N/A"
            WifiIp         = "N/A"
            Subnet         = "N/A"
        }

        if ($state -eq "device") {
            try {
                $propModel = (adb -s $serial shell getprop ro.product.model).Trim()
                if ($propModel) { $deviceObj.Model = $propModel }

                $propVer = (adb -s $serial shell getprop ro.build.version.release).Trim()
                if ($propVer) { $deviceObj.AndroidVersion = $propVer }

                $propSdk = (adb -s $serial shell getprop ro.build.version.sdk).Trim()
                if ($propSdk) { $deviceObj.SdkLevel = $propSdk }

                # Query wlan0 IP
                $ipOutput = adb -s $serial shell ip -4 addr show wlan0 2>$null | Out-String
                if ($ipOutput -match 'inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([0-9]+)') {
                    $deviceObj.WifiIp = $Matches[1]
                    $deviceObj.Subnet = "$($Matches[1])/$($Matches[2])"
                }
            } catch {
                # Fallback gracefully if property queries fail
            }
        }

        $devices += $deviceObj
    }

    return $devices
}

Check-AdbAvailable

$devices = @(Get-AdbDeviceList)
$retryCount = 0

while ($retryCount -lt $MaxRetries) {
    $hasPendingAuth = @($devices | Where-Object { $_.State -in @("authorizing", "unauthorized") })
    if ($hasPendingAuth.Count -gt 0) {
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "[ACTION REQUIRED] USB Debugging Authorization Pending!" -ForegroundColor Yellow
        foreach ($d in $hasPendingAuth) {
            Write-Host "  -> Device Serial: $($d.Serial) (Status: $($d.State))" -ForegroundColor Cyan
        }
        Write-Host "Please unlock the screen on the device and tap 'Allow USB debugging'." -ForegroundColor Yellow
        Write-Host "(Recommendation: Check 'Always allow from this computer')" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow

        Start-Sleep -Seconds $RetryDelaySeconds
        $devices = @(Get-AdbDeviceList)
        $retryCount++
    } else {
        break
    }
}

$usableDevices = @($devices | Where-Object { $_.IsAuthorized -eq $true })
$unauthorizedDevices = @($devices | Where-Object { $_.State -in @("authorizing", "unauthorized") })
$offlineDevices = @($devices | Where-Object { $_.State -eq "offline" })

$result = [PSCustomObject]@{
    Timestamp           = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    TotalDevicesFound   = $devices.Count
    UsableCount         = $usableDevices.Count
    UnauthorizedCount   = $unauthorizedDevices.Count
    OfflineCount        = $offlineDevices.Count
    DeviceA             = if ($usableDevices.Count -ge 1) { $usableDevices[0] } else { $null }
    DeviceB             = if ($usableDevices.Count -ge 2) { $usableDevices[1] } else { $null }
    AllDevices          = $devices
    CanExecuteTwoDevice = ($usableDevices.Count -ge 2)
    CanExecuteSingle    = ($usableDevices.Count -ge 1)
}

$result | ConvertTo-Json -Depth 4
