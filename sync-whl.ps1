# =============================================================
#  sync-whl.ps1 -- Sync whl files from code to packages directory
#                 Only keeps the latest version of each package
#
#  Usage:   .\sync-whl.ps1           (run sync)
#           .\sync-whl.ps1 -DryRun   (preview only)
# =============================================================

param(
    [string]$SourceDir = "C:\Users\man\Desktop\code",
    [string]$TargetDir = "C:\Users\man\Desktop\packages",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ----------------------------------------------------------
# Compare two version strings (pure PowerShell, no Python needed)
# Returns:  1 if $v1 > $v2, -1 if $v1 < $v2, 0 if equal
# ----------------------------------------------------------
function Compare-Version {
    param([string]$v1, [string]$v2)
    try {
        $a = [version]($v1 -replace '^[^\d]*(\d+[.\d]*).*','$1')
        $b = [version]($v2 -replace '^[^\d]*(\d+[.\d]*).*','$1')
        if ($a -gt $b) { return 1 }
        if ($a -lt $b) { return -1 }
        return 0
    } catch {
        # Fallback: string comparison
        return [string]::Compare($v1, $v2, [StringComparison]::Ordinal)
    }
}

# ----------------------------------------------------------
# Extract version from whl filename
# Format: {pkg}-{ver}-{py}-{abi}-{plat}.whl
# ----------------------------------------------------------
function Get-WhlVersion {
    param([string]$Filename)
    # Remove python/platform suffix: ...-py3-none-any.whl
    $stem = $Filename -replace '-(py3|py2|py27|py\d+)[^-]*\.whl$', ''
    # Extract first numeric version segment: pkg-1.2.3 -> 1.2.3
    if ($stem -match '(\d+\.\d+(?:\.\d+)?)') {
        return $Matches[1]
    }
    return "0"
}

# ----------------------------------------------------------
# Extract package base name from whl filename
# ----------------------------------------------------------
function Get-WhlPackageName {
    param([string]$Filename)
    $ver  = Get-WhlVersion $Filename
    $stem = $Filename -replace '-(py3|py2|py27|py\d+)[^-]*\.whl$', ''
    $base = $stem.Substring(0, [Math]::Max(0, $stem.LastIndexOf("-$ver")))
    # Normalize dashes/underscores for grouping
    return ($base -replace '[-_]', '_').ToLower()
}

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
Write-Host ""
Write-Host "======================================================="
Write-Host "  WHL Sync Script"
Write-Host "  Source : $SourceDir"
Write-Host "  Target : $TargetDir"
Write-Host "  DryRun : $($DryRun.IsPresent)"
Write-Host "======================================================="

if (-not (Test-Path $SourceDir)) {
    Write-Host "ERROR: Source directory not found: $SourceDir" -ForegroundColor Red
    exit 1
}

$allWhl = @(Get-ChildItem $SourceDir -Filter "*.whl" -Recurse -File)

if ($allWhl.Count -eq 0) {
    Write-Host "WARNING: No .whl files found in source directory." -ForegroundColor Yellow
    exit 0
}

# Group by package name, keep only latest version
$latestMap = @{}   # pkgKey -> @{ Version; File; SrcFullName }

foreach ($whl in $allWhl) {
    $fname  = $whl.Name
    $ver    = Get-WhlVersion $fname
    $pkgKey = Get-WhlPackageName $fname

    if (-not $latestMap.ContainsKey($pkgKey)) {
        $latestMap[$pkgKey] = @{ Version = $ver; File = $whl }
    } else {
        $curVer = $latestMap[$pkgKey].Version
        if ((Compare-Version $ver $curVer) -gt 0) {
            $latestMap[$pkgKey] = @{ Version = $ver; File = $whl }
        }
    }
}

Write-Host ""
Write-Host "Detected $(@($latestMap.Keys).Count) packages (latest versions):"
Write-Host "-------------------------------------------------------"

$operations = @()

foreach ($pkg in @($latestMap.Keys | Sort-Object)) {
    $info     = $latestMap[$pkg]
    $srcFile  = $info.File
    $srcName  = $srcFile.Name
    $dstPath  = Join-Path $TargetDir $srcName

    $srcExists = Test-Path $dstPath
    if ($srcExists) {
        $srcHash = (Get-FileHash $srcFile.FullName -Algorithm MD5).Hash
        $dstHash = (Get-FileHash $dstPath -Algorithm MD5).Hash
        $same    = ($srcHash -eq $dstHash)
    } else {
        $same = $false
    }

    $status = if ($same)          { "[SAME  ]" }
              elseif ($srcExists) { "[UPDATE]" }
              else                { "[NEW   ]" }

    Write-Host "  $status  $srcName  (v$($info.Version))"

    $operations += @{
        Action = if ($same) { "skip" } elseif ($srcExists) { "update" } else { "copy" }
        Src    = $srcFile.FullName
        Dst    = $dstPath
        SrcF   = $srcFile
    }
}

Write-Host "-------------------------------------------------------"

if ($DryRun) {
    Write-Host ""
    Write-Host "(Dry-run mode -- no files were modified)" -ForegroundColor Cyan
    exit 0
}

# ----------------------------------------------------------
# Execute sync
# ----------------------------------------------------------
Write-Host ""
Write-Host "Syncing to $TargetDir ..."

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Host "Created target directory." -ForegroundColor Green
}

# Remove old versions of the same packages from target
$targetFiles = @(Get-ChildItem $TargetDir -Filter "*.whl" -File)
$keptSrcNames = @($latestMap.Values | ForEach-Object { $_.File.Name })

foreach ($oldFile in $targetFiles) {
    if ($oldFile.Name -notin $keptSrcNames) {
        # This old file is not among the latest versions -- delete it
        Write-Host "  [DEL] $($oldFile.Name)"
        Remove-Item $oldFile.FullName -Force
    }
}

$copyCount = 0
$skipCount = 0

foreach ($op in $operations) {
    if ($op.Action -eq "skip") {
        $skipCount++
        continue
    }
    Write-Host "  [$(($op.Action).ToUpper())] $($op.SrcF.Name)"
    Copy-Item $op.Src -Destination $op.Dst -Force
    $copyCount++
}

Write-Host ""
Write-Host "======================================================="
Write-Host "  Done!  Copied/Updated: $copyCount   Skipped (up-to-date): $skipCount"
Write-Host "  Target directory: $TargetDir"
Write-Host "======================================================="

Write-Host ""
Write-Host "Files in packages directory:"
Get-ChildItem $TargetDir -Filter "*.whl" | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name)"
}
