<#
.SYNOPSIS
  Sends a Telegram alert for the latest Windows Logon (Event ID 4624).

.DESCRIPTION
  Detects Physical, SMB, RDP or SSH logons. Omits IP for console logons.
#>

# Load Telegram settings
. "$PSScriptRoot\config.ps1"

# Get the most recent successful logon event (ID 4624)
try {
    $event = Get-WinEvent -LogName "Security" `
                         -FilterXPath "*[System[EventID=4624]]" `
                         -MaxEvents 1 `
                         -ErrorAction Stop

    $xml       = [xml]$event.ToXml()
    $username  = $xml.Event.EventData.Data |
                 Where-Object Name -EQ "TargetUserName" |
                 Select-Object -ExpandProperty '#text'
    $logonTime = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
    $logonType = $xml.Event.EventData.Data |
                 Where-Object Name -EQ "LogonType" |
                 Select-Object -ExpandProperty '#text'
    $ipAddress = $xml.Event.EventData.Data |
                 Where-Object Name -EQ "IpAddress" |
                 Select-Object -ExpandProperty '#text'
}
catch {
    Write-Error "Failed to retrieve latest logon event: $_"
    exit 1
}

$hostname = $env:COMPUTERNAME
$connectionType = $null

# 1) Detect SSH if no IP present
if ([string]::IsNullOrEmpty($ipAddress) -or $ipAddress -eq "-") {
    $sshProc = Get-Process -Name "sshd" -ErrorAction SilentlyContinue
    if ($sshProc) {
        $conn = Get-NetTCPConnection -State Established -OwningProcess $sshProc.Id `
                -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($conn) {
            $ipAddress      = $conn.RemoteAddress
            $connectionType = "SSH"
        }
    }
    else {
        $netstat = netstat -ano | Select-String "ESTABLISHED" | Select-String ":22"
        if ($netstat) {
            $ipAddress      = ($netstat -split "\s+")[2].Split(":")[0]
            $connectionType = "SSH"
        }
    }
}

# 2) Fallback to mapping by LogonType
if (-not $connectionType) {
    $connectionType = switch ($logonType) {
        "2"  { "Physical (console)" }
        "3"  { "SMB / Network"      }
        "10" { "RDP (Remote Desktop)" }
        default { "Other (Type $logonType)" }
    }
}

# Build the alert message
$messageLines = @(
    "⚠️ Login Alert ⚠️",
    "User:       $username",
    "Access:     $connectionType"
)

if ($connectionType -ne "Physical (console)") {
    $messageLines += "IP Address: $ipAddress"
}

$messageLines += "Host:       $hostname",
                 "Time:       $logonTime"

$fullMessage = $messageLines -join "`n"

# Send the Telegram notification
Invoke-RestMethod -Uri "https://api.telegram.org/bot$TelegramToken/sendMessage" `
                  -Method Post `
                  -Body @{
                      chat_id = $ChatID
                      text    = $fullMessage
                  } | Out-Null
