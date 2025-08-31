<#
.SYNOPSIS
    Bulk local user cleanup script.

.DESCRIPTION
    Reads a list of usernames from a CSV file and removes the 
    corresponding local user accounts from the machine. 
    Useful for offboarding or resetting a lab/test environment.

    Features:
        - Reads usernames from a CSV file.
        - Skips accounts that do not exist.
        - Removes associated profile folders if they are not loaded.
        - Ensures accounts in use are not forcefully removed.
        - Provides clear SKIP, PROFILE REMOVED, and ACCOUNT DELETED messages.

.PARAMETER CsvPath
    Path to the input CSV file containing the usernames to remove.

.NOTES
    Author: Jesus Rodriguez
    Created: 2025-08-26
    Project: IT_Automation
    Usage: Run in PowerShell as Administrator.

.EXAMPLE
    PS> .\cleanup-users.ps1 -CsvPath "C:\IT_Automation\data\users.csv"
#>

# cleanup-users.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CsvPath = "C:\IT_Automation\data\users.csv"
)

# Load all usernames from CSV
$users = (Import-Csv -Path $CsvPath -ErrorAction Stop).UserName |
         Where-Object { $_ } | Sort-Object -Unique

foreach ($u in $users) {
    try {
        # Get the local user object (skip if it doesn't exist)
        $lu = Get-LocalUser -Name $u -ErrorAction SilentlyContinue
        if (-not $lu) {
            Write-Host "SKIP: ${u} not found"
            continue
        }

        # Remove profile folder if it exists and isn't loaded
        $sid = $lu.SID.Value
        $prof = Get-CimInstance Win32_UserProfile -Filter "SID='$sid'" -ErrorAction SilentlyContinue
        if ($prof -and -not $prof.Loaded) {
            Remove-CimInstance $prof -ErrorAction Stop
            Write-Host "PROFILE REMOVED: ${u}"
        } elseif ($prof -and $prof.Loaded) {
            Write-Warning "Profile in use for ${u} (sign out first)"
        }

        # Remove the local account
        Remove-LocalUser -Name $u -ErrorAction Stop
        Write-Host "ACCOUNT DELETED: ${u}"
    }
    catch {
        Write-Warning "ERROR deleting ${u}: $($_.Exception.Message)"
    }
}
