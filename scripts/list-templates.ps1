[CmdletBinding()]
param(
  [switch]$Raw
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

$response = Invoke-NxApi -Method GET -Path '/templates' -Raw
if ($Raw) {
  $response
  exit 0
}

$templates = ConvertFrom-NxJson -Json $response
Write-NxJson -Value @($templates)
