[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$DisplayName,
  [ValidateSet('aep', 'zip', 'mogrt')][string]$Type,
  [int]$TimeoutSeconds = 180,
  [switch]$DryRun
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

$resolved = (Resolve-Path -LiteralPath $Path).Path
if (-not $Type) {
  $Type = Get-NxExtensionType -Path $resolved
}
if (-not $DisplayName) {
  $DisplayName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
}

$payload = [ordered]@{
  displayName = $DisplayName
  type = $Type
}

if ($DryRun) {
  Write-NxJson -Value ([PSCustomObject]@{
    dryRun = $true
    create = [PSCustomObject]@{
      method = 'POST'
      path = '/templates'
      payload = $payload
      bodyTransport = '--data-binary @temp-json-file'
    }
    upload = [PSCustomObject]@{
      file = $resolved
      contentType = 'application/octet-stream'
      authHeader = $false
      copyUploadInfoFields = $false
    }
    poll = [PSCustomObject]@{
      path = '/templates/{id}'
      timeoutSeconds = $TimeoutSeconds
    }
  })
  exit 0
}

Write-NxStatus "creating template '$DisplayName'"
$created = Invoke-NxApi -Method POST -Path '/templates' -Body $payload
$upload = Normalize-NxTemplateUploadResponse -Response $created

Write-NxStatus ("uploading template file to presigned storage URL for {0}" -f $upload.templateId)
Invoke-NxStoragePut -UploadUrl $upload.uploadUrl -Path $resolved -ContentType 'application/octet-stream'

$template = Wait-NxTemplateUploaded -TemplateId $upload.templateId -TimeoutSeconds $TimeoutSeconds
Write-NxJson -Value $template
