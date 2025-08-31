<#
.SYNOPSIS
    Bulk local user account creation script.

.DESCRIPTION
    Reads user details from a CSV file and creates corresponding
    local user accounts on the machine. Designed for onboarding
    scenarios or lab environments where multiple accounts need
    to be provisioned quickly.

    Features:
        - Imports users from a CSV file (username, first name, last name, department).
        - Creates new accounts with a default password.
        - Skips users that already exist.
        - Logs all actions (CREATED, SKIPPED, ERROR) to an output log file.

.PARAMETER CsvPath
    Path to the input CSV file containing user details.

.PARAMETER LogPath
    Path to the log file where results will be recorded.

.NOTES
    Author: [Your Name]
    Created: 2025-08-30
    Project: IT_Automation
    Usage: Run in PowerShell as Administrator.

.EXAMPLE
    PS> .\New-BulkLocalUser.ps1 -CsvPath "C:\IT_Automation\data\users.csv" `
                                -LogPath "C:\IT_Automation\output\onboarding-log.txt"
#>


param (
    [string]$CsvPath = "C:\IT_Automation\data\users.csv",
    [string]$LogPath = "C:\IT_Automation\output\onboarding-log.txt"
)

# Ensure log folder exists
$null = New-Item -ItemType Directory -Force -Path (Split-Path $LogPath -Parent)

# Clear the log file if it exists
Clear-Content -Path $LogPath -ErrorAction SilentlyContinue

# Import users from CSV
$users = Import-Csv -Path $CsvPath

# Define a simple default password for all accounts
$defaultPassword = ConvertTo-SecureString "password1" -AsPlainText -Force

foreach ($user in $users) {
    $username = $user.UserName
    $fullname = "$($user.FirstName) $($user.LastName)"
    $dept = $user.Department

    try {
        # Skip if already exists
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            $line = "SKIPPED: $username already exists"
        }
        else {
            # Create user with default password
            New-LocalUser -Name $username -Password $defaultPassword `
                          -FullName $fullname -Description $dept -ErrorAction Stop

            # Ensure account is enabled
            Enable-LocalUser -Name $username -ErrorAction SilentlyContinue

            $line = "CREATED: $username ($fullname) Dept=$dept (password: password1)"
        }

        Write-Output $line
        Add-Content -Path $LogPath -Value $line
    }
    catch {
        $err = "ERROR: $username -> $($_.Exception.Message)"
        Write-Output $err
        Add-Content -Path $LogPath -Value $err
    }
}

Write-Output "DONE! Log written successfully, check the output directory!"
