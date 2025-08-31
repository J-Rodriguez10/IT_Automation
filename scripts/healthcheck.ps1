<#
.SYNOPSIS
    Windows Health Check / Diagnostics Script

.DESCRIPTION
    This PowerShell script collects key system health information 
    to help IT support specialists quickly diagnose common workstation issues.

    It reports:
        - CPU usage
        - Memory usage (total, used, free, %)
        - Disk usage on the system drive
        - Failed logon attempts in the last 24 hours (Event ID 4625)
        - Network connectivity, ping latency, gateway, and public IP

    The script displays results in the console and saves a timestamped
    report to the IT_Automation\output directory (TXT and CSV formats).

.NOTES
    Author: Jesus Rodriguez
    Created: 2025-08-30
    Project: IT_Automation
    Usage: Run in PowerShell (Administrator recommended for Security log access)

.EXAMPLE
    PS> .\healthcheck.ps1
#>



[CmdletBinding()]
param(
  [string]$ReportPath = "C:\IT_Automation\output"
)

$ErrorActionPreference = "Stop"

# Header
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$HostName  = $env:COMPUTERNAME
$UserName  = $env:USERNAME


# Creating an array and appending the data to it line by line
$lines = @()
$lines += "=== Windows Health Check ==="
$lines += "Host: $HostName  | User: $UserName  | Timestamp: $Timestamp"
$lines += ""

# [System Resources] =========
$lines += "[System Resources]"

# CPU =========
$cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
$cpu = [math]::Round($cpu, 1)
$lines += "CPU Usage: $cpu%"

# Memory =========
$os = Get-CimInstance Win32_OperatingSystem
$memTotalGB = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
$memFreeGB  = [math]::Round($os.FreePhysicalMemory/1MB,1)
$memUsedGB  = [math]::Round($memTotalGB - $memFreeGB,1)
$memPct     = if ($memTotalGB -ne 0) { [math]::Round(($memUsedGB/$memTotalGB)*100,1) } else { 0 }
$lines += ("Memory: {0} GB / {1} GB used ({2}%) | Free: {3} GB" -f $memUsedGB,$memTotalGB,$memPct,$memFreeGB)

# Disk (system drive) =========
$driveLetter = $env:SystemDrive.TrimEnd('\')
try {
  $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$driveLetter'"
} catch {
  $disk = $null
}

#
# Used ChatGpt in this section to accurately partition the disk and perform calculations
#

if (-not $disk) {
  $psd = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $driveLetter.TrimEnd(':') }
  if ($psd) {
    $diskTotalGB = [math]::Round((($psd.Used + $psd.Free)/1GB),1)
    $diskFreeGB  = [math]::Round(($psd.Free/1GB),1)
  }
} else {
  $diskTotalGB = [math]::Round(($disk.Size/1GB),1)
  $diskFreeGB  = [math]::Round(($disk.FreeSpace/1GB),1)
}
if ($diskTotalGB -and $diskTotalGB -ne 0) {
  $diskUsedGB = [math]::Round(($diskTotalGB - $diskFreeGB),1)
  $diskPct    = [math]::Round(($diskUsedGB / $diskTotalGB) * 100,1)
  $lines += ("Disk {0}: {1}% used ({2} GB / {3} GB) | Free: {4} GB" -f $driveLetter, $diskPct, $diskUsedGB, $diskTotalGB, $diskFreeGB)
} else {
  $lines += ("Disk {0}: n/a" -f $driveLetter)
}

$lines += ""
$lines += "[Security / Events - last 24h]"


# Security events (4625 =========
# For this section to work you need to run PowerShell as Administrator
$since = (Get-Date).AddHours(-24)
try {
  $failedLogons = (Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = $since } -ErrorAction Stop | Measure-Object).Count
  $lines += "Failed logon attempts: $failedLogons"
}
catch {
  $lines += "Failed logon attempts: n/a (no access to Security log)"
}

# Network =========

# =========
# Formatting was improved through use of ChatGpt
# =========

$lines += "`n[Network]"

# quick connectivity check (quiet ping)
$netUp = (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue)
$lines += "Active connection: " + ($(if($netUp){"Yes"}else{"No"}))

# latency sample (average of 4 pings)
$ping = try { Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction Stop } catch { $null }
$avg  = if ($ping) { [math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average,1) } else { $null }
$lines += ("Ping 8.8.8.8: " + ($(if($avg){"avg $avg ms"}else{"failed or blocked"})))

# default gateway (best route)
$gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
if ($gw) { $lines += "Default gateway: $gw" }

# public IP (optional; skip quietly if blocked)
try {
  $pub = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 2).ip
  if ($pub) { $lines += "Public IP: $pub" }
} catch { }

$lines += "============================"

$lines -join "`n" | Write-Host




# =================
# ChatGPT was used for the code to format and save the data into CSV and TXT files 
# =================


# ---- Save report to output directory ----
if (-not (Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath | Out-Null
}

$stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"

# Save TXT report
$txtFile = Join-Path $ReportPath "healthcheck_$stamp.txt"
$lines -join "`n" | Out-File -FilePath $txtFile -Encoding UTF8
Write-Host "Report saved to: $txtFile"

# Save CSV (with structured fields)
$csvFile = Join-Path $ReportPath "healthcheck_$stamp.csv"
[pscustomobject]@{
    Timestamp       = $Timestamp
    Host            = $HostName
    User            = $UserName
    CPUPercent      = $cpu
    MemUsedGB       = $memUsedGB
    MemTotalGB      = $memTotalGB
    MemPercentUsed  = $memPct
    DiskPercentUsed = $diskPct
    DiskUsedGB      = $diskUsedGB
    DiskTotalGB     = $diskTotalGB
    FailedLogons24h = $failedLogons
    PingAvgMs       = $avg
    DefaultGateway  = $gw
    PublicIP        = $pub
} | Export-Csv -NoTypeInformation -Path $csvFile
Write-Host "CSV saved to: $csvFile"
