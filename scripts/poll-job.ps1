[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$JobId,
  [int]$IntervalSeconds = 5,
  [int]$TimeoutSeconds = 900,
  [switch]$Raw
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$lastRaw = $null
$lastJob = $null

do {
  $lastRaw = Invoke-NxApi -Method GET -Path "/jobs/$JobId" -Raw
  $lastJob = ConvertFrom-NxJson -Json $lastRaw
  Write-NxStatus ("job {0}: {1} {2}%" -f $JobId, $lastJob.status, $lastJob.progress)

  if ($lastJob.status -eq 'finished') {
    if ($Raw) { $lastRaw } else { Write-NxJson -Value $lastJob }
    exit 0
  }

  if ($lastJob.status -eq 'error') {
    if ($Raw) { $lastRaw } else { Write-NxJson -Value $lastJob }
    exit 2
  }

  Start-Sleep -Seconds $IntervalSeconds
} while ((Get-Date) -lt $deadline)

$timeout = [PSCustomObject]@{
  id = $JobId
  status = 'timeout'
  timeoutSeconds = $TimeoutSeconds
  lastJob = $lastJob
}

if ($Raw -and $lastRaw) {
  $lastRaw
} else {
  Write-NxJson -Value $timeout
}
exit 3
