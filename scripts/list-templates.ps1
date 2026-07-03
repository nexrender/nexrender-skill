[CmdletBinding()]
param(
  [switch]$Raw,
  [switch]$Legacy
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

$path = '/v3/templates'
if ($Legacy) {
  $path = '/templates'
}

$response = Invoke-NxApi -Method GET -Path $path -Raw
if ($Raw) {
  $response
  exit 0
}

$templates = ConvertFrom-NxJson -Json $response
Write-NxJson -Value @($templates)
