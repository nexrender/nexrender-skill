function Write-NxStatus {
  param([Parameter(Mandatory = $true)][string]$Message)
  [Console]::Error.WriteLine($Message)
}

function Get-NxCurlCommand {
  $isWindows = $false
  try {
    $isWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT'
  } catch {
    $isWindows = $env:OS -eq 'Windows_NT'
  }

  if ($isWindows) {
    $cmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }

  $fallback = Get-Command curl -ErrorAction SilentlyContinue
  if (-not $fallback) {
    throw 'curl is required for Nexrender Cloud calls but was not found on PATH.'
  }
  return $fallback.Source
}

function Get-NxApiKey {
  if ($env:NEXRENDER_API_KEY) {
    return $env:NEXRENDER_API_KEY
  }

  $envPath = Join-Path (Get-Location) '.env'
  if (Test-Path -LiteralPath $envPath) {
    foreach ($rawLine in (Get-Content -LiteralPath $envPath)) {
      $line = $rawLine.Trim()
      if (-not $line -or $line.StartsWith('#')) { continue }
      if ($line -match '^\s*(?:export\s+)?NEXRENDER_API_KEY\s*=\s*(.*)\s*$') {
        $value = $matches[1].Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
          $value = $value.Substring(1, $value.Length - 2)
        }
        if ($value) { return $value }
      }
    }
  }

  throw 'NEXRENDER_API_KEY was not found in the process environment or current project .env. Generate a team token from https://app.nexrender.com/team/settings and store it as NEXRENDER_API_KEY=... without committing .env.'
}

function Get-NxBaseUrl {
  if ($env:NEXRENDER_BASE_URL) {
    return $env:NEXRENDER_BASE_URL.TrimEnd('/')
  }
  return 'https://api.nexrender.com/api/v2'
}

function Join-NxUrl {
  param([Parameter(Mandatory = $true)][string]$Path)
  $base = Get-NxBaseUrl
  if ($Path.StartsWith('/')) {
    return "$base$Path"
  }
  return "$base/$Path"
}

function New-NxTempPath {
  param([string]$Extension = '.tmp')
  return (Join-Path ([System.IO.Path]::GetTempPath()) ('nx-cloud-' + [guid]::NewGuid().ToString('N') + $Extension))
}

function New-NxTempJsonFile {
  param([Parameter(Mandatory = $true)][object]$Value)
  $path = New-NxTempPath -Extension '.json'
  if ($Value -is [string]) {
    $json = $Value
  } else {
    $json = ConvertTo-Json -InputObject $Value -Depth 50 -Compress
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
  [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
  return $path
}

function Read-NxJsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $raw = Get-Content -LiteralPath $resolved -Raw
  if (-not $raw.Trim()) {
    return $null
  }
  return $raw | ConvertFrom-Json
}

function ConvertFrom-NxJson {
  param([Parameter(Mandatory = $true)][string]$Json)
  if (-not $Json.Trim()) {
    return $null
  }
  return $Json | ConvertFrom-Json
}

function Write-NxJson {
  param([Parameter(Mandatory = $true)][object]$Value)
  ConvertTo-Json -InputObject $Value -Depth 50
}

function Invoke-NxCurl {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  $curl = Get-NxCurlCommand
  $stderrFile = New-NxTempPath -Extension '.stderr'
  try {
    $output = & $curl @Arguments 2> $stderrFile
    $exitCode = $LASTEXITCODE
    $stdout = ($output -join [Environment]::NewLine)
    $stderr = ''
    if (Test-Path -LiteralPath $stderrFile) {
      $stderrContent = Get-Content -LiteralPath $stderrFile -Raw
      if ($null -ne $stderrContent) {
        $stderr = $stderrContent
      }
    }
    if ($exitCode -ne 0) {
      $details = @($stderr.Trim(), $stdout.Trim()) | Where-Object { $_ }
      throw ('curl failed with exit code {0}. {1}' -f $exitCode, ($details -join [Environment]::NewLine))
    }
    if ($stderr.Trim()) {
      Write-NxStatus $stderr.Trim()
    }
    return $stdout
  } finally {
    if (Test-Path -LiteralPath $stderrFile) {
      Remove-Item -LiteralPath $stderrFile -Force
    }
  }
}

function Invoke-NxApi {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [object]$Body,
    [switch]$Raw
  )

  $token = Get-NxApiKey
  $url = Join-NxUrl -Path $Path
  $args = @('-sS', '--fail-with-body', '-X', $Method.ToUpperInvariant(), $url, '-H', "Authorization: Bearer $token")
  $bodyFile = $null
  try {
    if ($PSBoundParameters.ContainsKey('Body')) {
      $bodyFile = New-NxTempJsonFile -Value $Body
      $args += @('-H', 'Content-Type: application/json', '--data-binary', "@$bodyFile")
    }
    $response = Invoke-NxCurl -Arguments $args
  } finally {
    if ($bodyFile -and (Test-Path -LiteralPath $bodyFile)) {
      Remove-Item -LiteralPath $bodyFile -Force
    }
  }

  if ($Raw) {
    return $response
  }
  return ConvertFrom-NxJson -Json $response
}

function Normalize-NxTemplateUploadResponse {
  param([Parameter(Mandatory = $true)][object]$Response)

  $template = $Response
  if ($Response.PSObject.Properties.Name -contains 'template') {
    $template = $Response.template
  }

  $uploadInfo = $null
  if ($Response.PSObject.Properties.Name -contains 'uploadInfo') {
    $uploadInfo = $Response.uploadInfo
  }

  $uploadUrl = $null
  if ($uploadInfo -and $uploadInfo.url) {
    $uploadUrl = $uploadInfo.url
  } elseif ($Response.PSObject.Properties.Name -contains 'uploadUrl') {
    $uploadUrl = $Response.uploadUrl
  } elseif ($Response.PSObject.Properties.Name -contains 'url') {
    $uploadUrl = $Response.url
  }

  if (-not $template.id) {
    throw 'Template create/upload response did not include a template id.'
  }
  if (-not $uploadUrl) {
    throw 'Template create/upload response did not include uploadInfo.url or uploadUrl.'
  }

  return [PSCustomObject]@{
    template = $template
    templateId = $template.id
    uploadUrl = $uploadUrl
    uploadInfo = $uploadInfo
  }
}

function Invoke-NxStoragePut {
  param(
    [Parameter(Mandatory = $true)][string]$UploadUrl,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$ContentType = 'application/octet-stream'
  )

  $resolved = Resolve-Path -LiteralPath $Path
  $args = @(
    '-sS',
    '--fail-with-body',
    '-X',
    'PUT',
    $UploadUrl,
    '-H',
    "Content-Type: $ContentType",
    '--data-binary',
    "@$resolved"
  )
  [void](Invoke-NxCurl -Arguments $args)
}

function Wait-NxTemplateUploaded {
  param(
    [Parameter(Mandatory = $true)][string]$TemplateId,
    [int]$TimeoutSeconds = 180,
    [int]$IntervalSeconds = 2
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $template = Invoke-NxApi -Method GET -Path "/templates/$TemplateId"
    Write-NxStatus ("template {0}: {1}" -f $TemplateId, $template.status)
    if ($template.status -eq 'uploaded' -or $template.status -eq 'error') {
      return $template
    }
    Start-Sleep -Seconds $IntervalSeconds
  } while ((Get-Date) -lt $deadline)

  throw "Timed out waiting for template $TemplateId to become uploaded."
}

function Get-NxExtensionType {
  param([Parameter(Mandatory = $true)][string]$Path)
  $extension = [System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
  if ($extension -notin @('aep', 'zip', 'mogrt')) {
    throw "Unsupported template extension '$extension'. Expected .aep, .zip, or .mogrt."
  }
  return $extension
}
