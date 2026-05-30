@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem AI AGENT NOTE: bump PUSH_PLAYABLE_SHARED_KIT_BRANCH_VERSION every time this file is updated.
set "PUSH_PLAYABLE_SHARED_KIT_BRANCH_VERSION=1.0.0"
set "SUBMODULE_NAME=playable-shared-kit"
set "REPO_WEB_URL=https://github.com/minhdptpuzzle/playable-shared-kit"
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT="
set "REPO_DIR="
set "PROJECT_NAME_RAW="
set "PROJECT_NAME_SLUG="
set "TIMESTAMP_UTC="
set "AUTO_BRANCH="
set "COMMIT_MESSAGE="
set "BASE_BRANCH=main"
set "BRANCH_URL="
set "HAS_STAGED_CHANGES="

if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

if exist "%SCRIPT_DIR%\playable-shared-kit\scripts\" (
    set "PROJECT_ROOT=%SCRIPT_DIR%"
    set "REPO_DIR=!PROJECT_ROOT!\%SUBMODULE_NAME%"
) else (
    for %%I in ("%SCRIPT_DIR%\..") do set "REPO_DIR=%%~fI"
    for %%I in ("!REPO_DIR!\..") do set "PROJECT_ROOT=%%~fI"
)

echo.
echo ================================================================================
echo ======== PUSH PLAYABLE SHARED KIT BRANCH TOOL v%PUSH_PLAYABLE_SHARED_KIT_BRANCH_VERSION% ========
echo ================================================================================
echo [info] Project root: %PROJECT_ROOT%
echo [info] Repo dir: %REPO_DIR%
echo.

if not exist "%REPO_DIR%\.git" (
    echo [push-branch] Repo not found: "%REPO_DIR%"
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [push-branch] Git repository is not valid: "%REPO_DIR%"
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

for %%I in ("%PROJECT_ROOT%") do set "PROJECT_NAME_RAW=%%~nxI"

for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$name = $env:PROJECT_NAME_RAW; $slug = [regex]::Replace($name.ToLowerInvariant(), '[^a-z0-9._-]+', '-').Trim('-'); if ([string]::IsNullOrWhiteSpace($slug)) { $slug = 'project' }; Write-Output $slug"`) do set "PROJECT_NAME_SLUG=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')"`) do set "TIMESTAMP_UTC=%%i"

if not defined PROJECT_NAME_SLUG set "PROJECT_NAME_SLUG=project"
if not defined TIMESTAMP_UTC (
    echo [push-branch] Failed to generate a UTC timestamp.
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

set "AUTO_BRANCH=auto-%PROJECT_NAME_SLUG%-%TIMESTAMP_UTC%"
set "COMMIT_MESSAGE=chore: sync %PROJECT_NAME_SLUG% %TIMESTAMP_UTC%"
set "BRANCH_URL=%REPO_WEB_URL%/tree/%AUTO_BRANCH%"

for /f "usebackq delims=" %%i in (`git -C "%REPO_DIR%" symbolic-ref refs/remotes/origin/HEAD 2^>nul`) do set "BASE_BRANCH=%%i"
if defined BASE_BRANCH set "BASE_BRANCH=!BASE_BRANCH:refs/remotes/origin/=!"
if not defined BASE_BRANCH set "BASE_BRANCH=main"

echo [info] Base branch: !BASE_BRANCH!
echo [info] Auto branch: !AUTO_BRANCH!
echo [info] Auto commit message: !COMMIT_MESSAGE!

git -C "%REPO_DIR%" fetch origin
if errorlevel 1 (
    echo [push-branch] Failed to fetch origin.
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" rev-parse --verify --quiet "refs/heads/!AUTO_BRANCH!" >nul
if not errorlevel 1 (
    echo [push-branch] Generated local branch already exists: !AUTO_BRANCH!
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" ls-remote --exit-code --heads origin "!AUTO_BRANCH!" >nul 2>&1
if not errorlevel 1 (
    echo [push-branch] Generated remote branch already exists: !AUTO_BRANCH!
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

if /I "%PUSH_BRANCH_DRY_RUN%"=="1" (
    echo.
    echo [dry-run] Would create and checkout branch: !AUTO_BRANCH!
    echo [dry-run] Would stage changes with: git -C "%REPO_DIR%" add -A
    echo [dry-run] Would commit with message: !COMMIT_MESSAGE!
    echo [dry-run] Would push with: git -C "%REPO_DIR%" push -u origin !AUTO_BRANCH!
    echo [dry-run] Would open browser to: !BRANCH_URL!
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 0
)

echo.
echo [push-branch] Creating branch !AUTO_BRANCH!...
git -C "%REPO_DIR%" switch -c "!AUTO_BRANCH!"
if errorlevel 1 (
    echo [push-branch] Failed to create branch !AUTO_BRANCH!.
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" add -A
if errorlevel 1 (
    echo [push-branch] Failed to stage changes.
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" diff --cached --quiet --exit-code
if errorlevel 1 (
    set "HAS_STAGED_CHANGES=1"
)

if defined HAS_STAGED_CHANGES (
    echo [push-branch] Creating commit...
    git -C "%REPO_DIR%" commit -m "!COMMIT_MESSAGE!"
    if errorlevel 1 (
        echo [push-branch] Failed to create commit.
        if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
        exit /b 1
    )
) else (
    echo [push-branch] No local file changes detected. Pushing current HEAD on the new branch.
)

echo [push-branch] Pushing branch to origin...
git -C "%REPO_DIR%" push -u origin "!AUTO_BRANCH!"
if errorlevel 1 (
    echo [push-branch] Failed to push branch !AUTO_BRANCH! to origin.
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo.
echo [push-branch] Opening browser to branch page:
echo !BRANCH_URL!
start "" "!BRANCH_URL!"
if errorlevel 1 (
    echo [push-branch] Failed to open the browser automatically.
    echo [push-branch] Open this URL manually:
    echo !BRANCH_URL!
    if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo [done] Branch !AUTO_BRANCH! is available on origin.
if /I not "%PUSH_BRANCH_NO_PAUSE%"=="1" pause
exit /b 0