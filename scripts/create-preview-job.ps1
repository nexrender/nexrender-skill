[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$TemplateId,
  [Parameter(Mandatory = $true)][string]$Composition,
  [string]$AssetsJson,
  [string]$FontsJson,
  [string]$WebhookUrl,
  [switch]$DryRun
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

$assets = @()
if ($AssetsJson) {
  $assets = @(Read-NxJsonFile -Path $AssetsJson)
}

$payload = [ordered]@{
  template = [ordered]@{
    id = $TemplateId
    composition = $Composition
  }
  preview = $true
  assets = $assets
}

if ($FontsJson) {
  $payload.fonts = @(Read-NxJsonFile -Path $FontsJson)
}

if ($WebhookUrl) {
  $payload.webhook = [ordered]@{
    url = $WebhookUrl
  }
}

if ($DryRun) {
  Write-NxJson -Value ([PSCustomObject]@{
    dryRun = $true
    method = 'POST'
    path = '/jobs'
    bodyTransport = '--data-binary @temp-json-file'
    payload = $payload
    settingsOmittedBecausePreview = $true
  })
  exit 0
}

$job = Invoke-NxApi -Method POST -Path '/jobs' -Body $payload
Write-NxJson -Value $job
