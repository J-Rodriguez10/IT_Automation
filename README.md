# 🖥️ IT Automation Scripts

A collection of PowerShell scripts that automate common IT support and help desk tasks.  
This project demonstrates practical automation for **onboarding, offboarding, and workstation diagnostics**.

---

## 📂 Scripts

### `New-BulkLocalUser.ps1`
Bulk local user account creation.
- Reads user details from a CSV file.
- Creates accounts with a default password.
- Logs results (`CREATED`, `SKIPPED`, `ERROR`).

### `cleanup-users.ps1`
Bulk local user cleanup.
- Reads usernames from a CSV file.
- Skips accounts that do not exist.
- Removes profile folders (if not in use).
- Deletes local accounts safely.

### `healthcheck.ps1`
Windows workstation health check.
- Reports CPU, memory, and disk usage.
- Counts failed logon attempts (last 24h).
- Tests network connectivity, gateway, and public IP.
- Saves results to TXT and CSV in `output/`.

---

## 🚀 Skills Demonstrated
- PowerShell scripting for automation  
- User account provisioning & cleanup  
- System diagnostics & troubleshooting  
- Structured logging (TXT/CSV)  
- Git & GitHub for version control  

---

👤 Author: Jesus Rodriguez
📅 Created: August 2025  
