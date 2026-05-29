@echo off
setlocal
set "ProjectDirFromBat=%~dp0"
set "CleanScriptArgs=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProjectDirFromBat=$env:ProjectDirFromBat.TrimEnd('\');$RawArgs=$env:CleanScriptArgs;$ScriptArgs=if([string]::IsNullOrWhiteSpace($RawArgs)){@()}else{$RawArgs -split '\s+'};$f='%~f0';((Get-Content -LiteralPath $f -Raw)-split '#---PS---\r?\n',2)[1]|Invoke-Expression"
exit /b %ERRORLEVEL%
#---PS---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectDir = [System.IO.Path]::GetFullPath($ProjectDirFromBat).TrimEnd('\')
$ScriptArgs = @($ScriptArgs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$Yes = @($ScriptArgs | Where-Object { $_ -match '^(?i)(/y|-y|--yes)$' }).Count -gt 0
$DryRun = @($ScriptArgs | Where-Object { $_ -match '^(?i)(/dry-run|-dry-run|--dry-run)$' }).Count -gt 0
$NoPause = @($ScriptArgs | Where-Object { $_ -match '^(?i)(/nopause|-nopause|--no-pause)$' }).Count -gt 0

$TargetNames = @(
    'node_modules',
    'library',
    'temp',
    'local',
    'build',
    'native',
    'profiles',
    'log',
    'logs',
    '.vscode',
    '.idea',
    '.cache',
    '.parcel-cache',
    '.turbo',
    '.vite',
    'coverage'
)

function Exit-Script {
    param([int]$Code)

    if (-not $NoPause) {
        Write-Host ''
        Read-Host 'Press Enter to exit' | Out-Null
    }

    exit $Code
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $pathFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')

    if ($pathFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return '.'
    }

    $rootPrefix = $rootFull + '\'
    if ($pathFull.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $pathFull.Substring($rootPrefix.Length)
    }

    return $pathFull
}

function Get-GitRootForPath {
    param([string]$Path)

    $root = @(& git -C $Path rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        return $null
    }

    return [System.IO.Path]::GetFullPath($root[0]).TrimEnd('\')
}

function Test-DirectoryHasTrackedFiles {
    param([string]$Path)

    $gitRoot = Get-GitRootForPath $Path
    if (-not $gitRoot) {
        return $false
    }

    $relativeToGitRoot = Get-RelativePath $gitRoot $Path
    if ($relativeToGitRoot -eq '.') {
        return $true
    }

    $pathspec = ($relativeToGitRoot -replace '\\', '/') + '/'
    $trackedFiles = & git -C $gitRoot ls-files -- $pathspec 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $true
    }

    return @($trackedFiles).Count -gt 0
}

function Find-CleanupTargets {
    param([System.IO.DirectoryInfo]$Root)

    $children = @()
    try {
        $children = @($Root.EnumerateDirectories())
    } catch {
        Write-Host "  [warn] Cannot scan: $($Root.FullName)" -ForegroundColor Yellow
        return
    }

    foreach ($child in $children) {
        if ($child.Name -ieq '.git') {
            continue
        }

        $isTarget = $TargetNameSet.Contains($child.Name)
        if ($isTarget) {
            $script:CandidateDirs.Add($child) | Out-Null
            continue
        }

        $isReparsePoint = (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        if ($isReparsePoint) {
            continue
        }

        Find-CleanupTargets $child
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '[ERROR] git command not found. Cannot verify unversioned directories.' -ForegroundColor Red
    Exit-Script 1
}

$projectGitRoot = Get-GitRootForPath $ProjectDir
if (-not $projectGitRoot) {
    Write-Host "[ERROR] Not a git worktree: $ProjectDir" -ForegroundColor Red
    Exit-Script 1
}

$TargetNameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in $TargetNames) {
    $TargetNameSet.Add($name) | Out-Null
}

$CandidateDirs = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

Write-Host "==> Project: $ProjectDir" -ForegroundColor Cyan
Write-Host '==> Scanning unversioned cleanup folders recursively...' -ForegroundColor Cyan

Find-CleanupTargets ([System.IO.DirectoryInfo]$ProjectDir)

$candidates = foreach ($dir in $CandidateDirs) {
    $fullName = [System.IO.Path]::GetFullPath($dir.FullName).TrimEnd('\')
    $relative = Get-RelativePath $ProjectDir $fullName

    [pscustomobject]@{
        FullName = $fullName
        Relative = $relative
        HasTrackedFiles = Test-DirectoryHasTrackedFiles $fullName
        Depth = @($relative -split '\\').Count
    }
}

$skipped = @($candidates | Where-Object { $_.HasTrackedFiles } | Sort-Object Relative)
$cleanable = @($candidates | Where-Object { -not $_.HasTrackedFiles } | Sort-Object Depth, Relative)

$targets = [System.Collections.Generic.List[object]]::new()
foreach ($candidate in $cleanable) {
    $isInsideExistingTarget = $false

    foreach ($target in $targets) {
        $targetPrefix = $target.FullName + '\'
        if ($candidate.FullName.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $isInsideExistingTarget = $true
            break
        }
    }

    if (-not $isInsideExistingTarget) {
        $targets.Add($candidate) | Out-Null
    }
}

if ($skipped.Count -gt 0) {
    Write-Host ''
    Write-Host 'Skipped because tracked files exist:' -ForegroundColor Yellow
    foreach ($item in $skipped) {
        Write-Host "  - $($item.Relative)"
    }
}

if ($targets.Count -eq 0) {
    Write-Host ''
    Write-Host 'No cleanable unversioned directories found.' -ForegroundColor Green
    Exit-Script 0
}

Write-Host ''
Write-Host 'Directories to delete:' -ForegroundColor Yellow
foreach ($target in $targets) {
    Write-Host "  - $($target.Relative)"
}

if ($DryRun) {
    Write-Host ''
    Write-Host 'Dry run only. No directories were deleted.' -ForegroundColor DarkGray
    Exit-Script 0
}

if (-not $Yes) {
    Write-Host ''
    $answer = Read-Host 'Type YES to delete these directories'
    if ($answer -cne 'YES') {
        Write-Host 'Cancelled.' -ForegroundColor DarkGray
        Exit-Script 0
    }
}

Write-Host ''
$failedCount = 0
foreach ($target in $targets) {
    Write-Host "Deleting: $($target.Relative)" -ForegroundColor Cyan

    try {
        if (Test-Path -LiteralPath $target.FullName) {
            Remove-Item -LiteralPath $target.FullName -Recurse -Force -ErrorAction Stop
        }
    } catch {
        $failedCount++
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
if ($failedCount -gt 0) {
    Write-Host "Done with $failedCount error(s)." -ForegroundColor Yellow
    Exit-Script 1
}

Write-Host 'Clean completed successfully.' -ForegroundColor Green
Exit-Script 0
