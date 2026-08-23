[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$JobId
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

Invoke-NxApi -Method GET -Path "/jobs/$JobId/logs" -Raw
