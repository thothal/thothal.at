param(
   [string]$Repo = "thothal/personal-cv-data",
   [string]$Ref = "main",
   [string]$SourceSubPath = "data",
   [string]$TargetDir = "data/cv",
   [string[]]$Files = @(
      "profile.yaml",
      "experience.yaml",
      "education.yaml",
      "competencies.yaml",
      "achievements.yaml"
   ),
   [string]$LocalDataPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
   param([string]$Message)
   Write-Host "[sync-cv-data] $Message"
}

function Get-WorkspaceRoot {
   if ($PSScriptRoot) {
      return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
   }
   return (Get-Location).Path
}

function Get-GitHubToken {
   if ($env:GITHUB_TOKEN -and $env:GITHUB_TOKEN.Trim()) {
      return $env:GITHUB_TOKEN.Trim()
   }
   if ($env:GH_TOKEN -and $env:GH_TOKEN.Trim()) {
      return $env:GH_TOKEN.Trim()
   }
   return $null
}

function Expand-GitHubArchive {
   param(
      [string]$RepoName,
      [string]$RepoRef,
      [string]$DestinationDir
   )

   $token = Get-GitHubToken
   if (-not $token) {
      throw "Missing token. Set GITHUB_TOKEN or GH_TOKEN to access '$RepoName'."
   }

   $archivePath = Join-Path $DestinationDir "cv-data.zip"
   $extractPath = Join-Path $DestinationDir "extract"
   $url = "https://api.github.com/repos/$RepoName/zipball/$RepoRef"

   $headers = @{
      Authorization = "Bearer $token"
      Accept        = "application/vnd.github+json"
      "User-Agent"  = "cv-sync-script"
   }

   Write-Info "Downloading $RepoName@$RepoRef"
   Invoke-WebRequest -Uri $url -Headers $headers -OutFile $archivePath

   Write-Info "Extracting archive"
   Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force

   # 🔧 FIX: immer Array erzwingen
   $roots = @(Get-ChildItem -Path $extractPath -Directory)

   if (-not $roots -or $roots.Count -eq 0) {
      throw "No root directory found in GitHub archive at $extractPath"
   }

   if ($roots.Count -ne 1) {
      $names = $roots | Select-Object -ExpandProperty Name
      throw "Unexpected archive structure. Expected 1 root folder, found $($roots.Count): $($names -join ', ')"
   }

   return $roots[0].FullName
}

function Copy-CvDataFiles {
   param(
      [string]$SourceRoot,
      [string]$RelativeDataPath,
      [string]$TargetPath,
      [string[]]$FileList
   )

   $sourceDataDir = Join-Path $SourceRoot $RelativeDataPath

   if (-not (Test-Path -LiteralPath $sourceDataDir)) {
      throw "Source data directory not found: $sourceDataDir"
   }

   New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null

   foreach ($file in $FileList) {
      $sourceFile = Join-Path $sourceDataDir $file
      $targetFile = Join-Path $TargetPath $file

      if (-not (Test-Path -LiteralPath $sourceFile)) {
         throw "Missing required file: $sourceFile"
      }

      Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
      Write-Info "Copied $file"
   }
}

$workspaceRoot = Get-WorkspaceRoot
$targetPath = Join-Path $workspaceRoot $TargetDir
$tempRoot = Join-Path $workspaceRoot ".tmp\cv-sync"

# clean temp
if (Test-Path $tempRoot) {
   Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

try {
   if ($LocalDataPath -and $LocalDataPath.Trim()) {
      $resolvedLocal = (Resolve-Path $LocalDataPath).Path
      Write-Info "Using local path: $resolvedLocal"

      Copy-CvDataFiles `
         -SourceRoot $resolvedLocal `
         -RelativeDataPath "." `
         -TargetPath $targetPath `
         -FileList $Files
   }
   else {
      $archiveRoot = Expand-GitHubArchive `
         -RepoName $Repo `
         -RepoRef $Ref `
         -DestinationDir $tempRoot

      Copy-CvDataFiles `
         -SourceRoot $archiveRoot `
         -RelativeDataPath $SourceSubPath `
         -TargetPath $targetPath `
         -FileList $Files
   }

   $manifest = [ordered]@{
      synced_at_utc = (Get-Date).ToUniversalTime().ToString("o")
      repo          = $Repo
      ref           = $Ref
      source_path   = $SourceSubPath
      files         = $Files
   }

   $manifestPath = Join-Path $targetPath "_sync-manifest.json"
   $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

   Write-Info "Sync complete → $targetPath"
}
finally {
   if (Test-Path $tempRoot) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
   }
}
