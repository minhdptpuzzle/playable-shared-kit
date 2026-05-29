@powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProjectDirFromBat='%~dp0'.TrimEnd('\');$f='%~f0';((Get-Content -LiteralPath $f -Raw)-split '#---PS---\r?\n',2)[1]|Invoke-Expression" & exit
#---PS---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectDir = $ProjectDirFromBat

# --- Cocos Creator 3.8.8 path ---
# Adjust this path if your installation is elsewhere.
$CocosCreatorExe = "C:\ProgramData\cocos\editors\Creator\3.8.8\CocosCreator.exe"

if (-not (Test-Path $CocosCreatorExe)) {
    $Candidates = @(
        "D:\Tools\CC\3.8.8\CocosCreator.exe",
        "C:\Program Files\Cocos\Creator\3.8.8\CocosCreator.exe",
        "D:\CocosCreator\3.8.8\CocosCreator.exe"
    )
    foreach ($c in $Candidates) {
        if (Test-Path $c) { $CocosCreatorExe = $c; break }
    }
}

# --- Restore Cocos login token (bypass repeated login prompt) ---
$CocosProfileDir = Join-Path $env:USERPROFILE ".CocosCreator"
$TokenBackup = Join-Path $CocosProfileDir ".token-backup.json"
$TokenFiles = @(
    (Join-Path $CocosProfileDir "user_token.json"),
    (Join-Path $CocosProfileDir "profiles\user_token.json"),
    (Join-Path $CocosProfileDir "profiles\v2\editor\user.json")
)

if (-not (Test-Path $TokenBackup)) {
    foreach ($tf in $TokenFiles) {
        if ((Test-Path $tf) -and ((Get-Item $tf).Length -gt 10)) {
            Copy-Item $tf $TokenBackup
            Write-Host "  [token] Backup saved from $tf" -ForegroundColor DarkGray
            break
        }
    }
}

if (Test-Path $TokenBackup) {
    foreach ($tf in $TokenFiles) {
        $needRestore = (-not (Test-Path $tf)) -or ((Get-Item $tf).Length -le 10)
        if ($needRestore) {
            $dir = Split-Path $tf -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item $TokenBackup $tf
            Write-Host "  [token] Restored: $tf" -ForegroundColor DarkGray
        }
    }
    Write-Host "  [token] Login token OK." -ForegroundColor DarkGray
} else {
    Write-Host "  [token] No backup found - login once to create it." -ForegroundColor Yellow
}

# --- Open VSCode then Cocos Creator 3.8.8 ---
if (Test-Path $CocosCreatorExe) {
    Write-Host "==> Opening VSCode..." -ForegroundColor Cyan
    $CodeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($CodeCmd) {
        $CodeExe = Join-Path (Split-Path (Split-Path $CodeCmd.Source -Parent) -Parent) "Code.exe"
        if (Test-Path $CodeExe) {
            $codeArgs = "/c set ELECTRON_RUN_AS_NODE=& set ELECTRON_NO_ATTACH_CONSOLE=& start `"`" `"$CodeExe`" `"$ProjectDir`""
            Start-Process -FilePath "cmd.exe" -ArgumentList $codeArgs -WindowStyle Hidden
        } else {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c start `"`" `"$($CodeCmd.Source)`" `"$ProjectDir`"" -WindowStyle Hidden
        }
    } else {
        Write-Host "  [warn] VSCode command 'code' not found." -ForegroundColor Yellow
    }

    $ResolvedProjectDir = [System.IO.Path]::GetFullPath($ProjectDir).TrimEnd('\')
    $OpenCocosProject = Get-CimInstance Win32_Process -Filter "name = 'CocosCreator.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $cmd = $_.CommandLine
            $isSameProject = $false
            if ($cmd) {
                $match = [regex]::Match($cmd, '(?i)--project(?:\s+|=)"([^"]+)"|--project(?:\s+|=)(\S+)')
                if ($match.Success) {
                    $openedProject = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                    try {
                        $isSameProject = [System.IO.Path]::GetFullPath($openedProject).TrimEnd('\') -ieq $ResolvedProjectDir
                    } catch {
                        $isSameProject = $false
                    }
                }
            }
            $isSameProject
        } |
        Select-Object -First 1

    if ($OpenCocosProject) {
        Write-Host "==> Cocos Creator already opened this project. Skipping launch." -ForegroundColor DarkGray
    } else {
        Write-Host "==> Launching Cocos Creator 3.8.8..." -ForegroundColor Cyan

        # Use "cmd /c start" to create a fully detached process group.
        # Cocos's parent will be the transient cmd.exe (which exits immediately),
        # so AttachConsole(ATTACH_PARENT_PROCESS) finds nothing to attach to.
        # Clear Electron's node-mode env var; otherwise CocosCreator.exe exits as a Node CLI.
        $startArgs = "/c set ELECTRON_RUN_AS_NODE=& set ELECTRON_NO_ATTACH_CONSOLE=& start `"`" `"$CocosCreatorExe`" --project `"$ProjectDir`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $startArgs -WindowStyle Hidden
    }

    if (-not ([System.Management.Automation.PSTypeName]'Win32Console').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Console {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
    [DllImport("user32.dll")]   public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;
}
"@
    }

    $consoleHwnd = [Win32Console]::GetConsoleWindow()

    Write-Host ""
    Write-Host "Done. Closing in 5 seconds..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 5

    [Win32Console]::FreeConsole() | Out-Null
    if ($consoleHwnd -ne [IntPtr]::Zero) {
        [Win32Console]::PostMessage($consoleHwnd, [Win32Console]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    }
    Stop-Process -Id $PID -Force
    [Environment]::Exit(0)
} else {
    Write-Host ""
    Write-Host "[ERROR] CocosCreator.exe not found at: $CocosCreatorExe" -ForegroundColor Red
    Write-Host "        Please update the CocosCreatorExe path in this script." -ForegroundColor Yellow
    exit 1
}
