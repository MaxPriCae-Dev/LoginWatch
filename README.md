# LoginAlert PowerShell Script

This repository contains a PowerShell script that:

- Monitors the latest Windows Security logon event (Event ID 4624).
- Classifies logons as Physical, SMB, RDP or SSH.
- Omits the IP address for console logons.
- Sends a formatted alert to a Telegram bot.

## Repository Structure

LoginWatch
-LoginAlert.ps1
-config.ps1

# 1. Create your config
Edit config.ps1 and insert your Telegram bot token and chat ID

# 2. (Optional) Sign the script
### 1. Create the self-signed code-signing certificate
New-SelfSignedCertificate -Type CodeSigning -Subject "CN=LocalLoginAlert" -KeyUsage DigitalSignature -CertStoreLocation Cert:\LocalMachine\My

### 2. Retrieve the thumbprint of the certificate
$thumb = (Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -Match "LocalLoginAlert").Thumbprint

### 3. Export the certificate to a file
Export-Certificate -Cert "Cert:\LocalMachine\My\$thumb" -FilePath .\LocalLoginAlert.cer

### 4. Import the certificate to the Trusted Root Certification Authorities store
Import-Certificate -FilePath .\LocalLoginAlert.cer -CertStoreLocation Cert:\LocalMachine\Root

### 5. Sign the script using the certificate
Set-AuthenticodeSignature -FilePath .\LoginAlert.ps1 -Certificate (Get-Item "Cert:\LocalMachine\My\$thumb")

# 3. Enforce script signing
Set-ExecutionPolicy AllSigned -Scope LocalMachine

# 4. Schedule at startup (local)
Open Task Scheduler → Create Task

Trigger: At startup

Action:

  Program:
  
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    
  Arguments:
  
    -NoProfile -ExecutionPolicy AllSigned -File "C:\Scripts\LoginAlert\LoginAlert.ps1"
    
Run as SYSTEM or a dedicated local service account.

Enable “Run with highest privileges.”

## Security Notes

Use AllSigned policy and code signing to prevent tampering.

Store your script in a locked‑down folder (NTFS ACLs).

Enable PowerShell logging and file integrity monitoring if possible.
