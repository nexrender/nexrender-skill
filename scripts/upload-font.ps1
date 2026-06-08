[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$FamilyName,
  [switch]$DryRun
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '_nx-cloud.ps1')

$resolved = (Resolve-Path -LiteralPath $Path).Path
if ([System.IO.Path]::GetExtension($resolved).ToLowerInvariant() -ne '.ttf') {
  throw 'Nexrender Cloud font uploads support .ttf files only.'
}

if ($DryRun) {
  Write-NxJson -Value ([PSCustomObject]@{
    dryRun = $true
    method = 'POST'
    path = '/fonts'
    font = $resolved
    familyName = $FamilyName
  })
  exit 0
}

$token = Get-NxApiKey
$url = Join-NxUrl -Path '/fonts'
$args = @('-sS', '--fail-with-body', '-X', 'POST', $url, '-H', "Authorization: Bearer $token", '-F', "font=@$resolved")
if ($FamilyName) {
  $args += @('-F', "familyName=$FamilyName")
}

$response = Invoke-NxCurl -Arguments $args
Write-NxJson -Value (ConvertFrom-NxJson -Json $response)
