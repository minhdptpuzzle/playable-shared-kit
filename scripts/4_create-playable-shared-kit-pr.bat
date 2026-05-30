@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem AI AGENT NOTE: bump CREATE_PLAYABLE_SHARED_KIT_PR_VERSION every time this file is updated.
set "CREATE_PLAYABLE_SHARED_KIT_PR_VERSION=1.0.1"
set "SUBMODULE_NAME=playable-shared-kit"
set "REPO_WEB_URL=https://github.com/minhdptpuzzle/playable-shared-kit"
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT="
set "REPO_DIR="
set "BASE_BRANCH=main"
set "CURRENT_BRANCH="
set "HAS_DIRTY="

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
echo =========== CREATE PLAYABLE SHARED KIT PR TOOL v%CREATE_PLAYABLE_SHARED_KIT_PR_VERSION% ===========
echo ================================================================================
echo [info] Project root: %PROJECT_ROOT%
echo [info] Repo dir: %REPO_DIR%
echo.

if not exist "%REPO_DIR%\.git" (
    echo [create-pr] Repo not found: "%REPO_DIR%"
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [create-pr] Git repository is not valid: "%REPO_DIR%"
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

for /f "usebackq delims=" %%i in (`git -C "%REPO_DIR%" rev-parse --abbrev-ref HEAD 2^>nul`) do set "CURRENT_BRANCH=%%i"
if not defined CURRENT_BRANCH (
    echo [create-pr] Unable to determine the current branch.
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

for /f "usebackq delims=" %%i in (`git -C "%REPO_DIR%" symbolic-ref refs/remotes/origin/HEAD 2^>nul`) do set "BASE_BRANCH=%%i"
if defined BASE_BRANCH set "BASE_BRANCH=!BASE_BRANCH:refs/remotes/origin/=!"
if not defined BASE_BRANCH set "BASE_BRANCH=main"

echo [info] Base branch: !BASE_BRANCH!
echo [info] Current branch: !CURRENT_BRANCH!

if /I "!CURRENT_BRANCH!"=="HEAD" (
    echo [create-pr] Detached HEAD detected. Checkout a feature branch first.
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

if /I "!CURRENT_BRANCH!"=="!BASE_BRANCH!" (
    echo [create-pr] Current branch matches the base branch. Create or checkout a feature branch first.
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

git -C "%REPO_DIR%" ls-remote --exit-code --heads origin "!CURRENT_BRANCH!" >nul 2>&1
if errorlevel 1 (
    echo [create-pr] Remote branch origin/!CURRENT_BRANCH! was not found.
    echo [create-pr] Push it first with:
    echo     git -C "%REPO_DIR%" push -u origin !CURRENT_BRANCH!
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

for /f "usebackq delims=" %%i in (`git -C "%REPO_DIR%" status --porcelain`) do set "HAS_DIRTY=1"
if defined HAS_DIRTY (
    echo [warning] Uncommitted changes exist in "%REPO_DIR%".
    echo [warning] The PR will only include committed changes already pushed to origin/!CURRENT_BRANCH!.
    set "CONTINUE_WITH_DIRTY="
    set /p "CONTINUE_WITH_DIRTY=Continue anyway? [y/N]: "
    if /I not "!CONTINUE_WITH_DIRTY!"=="Y" (
        if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
        exit /b 1
    )
)

where gh >nul 2>&1
if not errorlevel 1 (
    echo.
    echo [create-pr] Creating PR with GitHub CLI...
    pushd "%REPO_DIR%"
    call gh pr create --fill --base "!BASE_BRANCH!" --head "!CURRENT_BRANCH!"
    set "GH_EXIT=!ERRORLEVEL!"
    popd
    if not "!GH_EXIT!"=="0" (
        echo [create-pr] GitHub CLI failed to create the PR.
        if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
        exit /b !GH_EXIT!
    )
    echo [done] PR flow completed through GitHub CLI.
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 0
)

set "COMPARE_URL=%REPO_WEB_URL%/compare/!BASE_BRANCH!...!CURRENT_BRANCH!?expand=1"
echo.
echo [create-pr] GitHub CLI ^(gh^) is not installed on this machine.
echo [create-pr] Opening the browser PR page instead:
echo !COMPARE_URL!
start "" "!COMPARE_URL!"
if errorlevel 1 (
    echo [create-pr] Failed to open the browser automatically.
    echo [create-pr] Open this URL manually:
    echo !COMPARE_URL!
    if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo [done] Browser opened. Complete the PR form on GitHub.
if /I not "%CREATE_PR_NO_PAUSE%"=="1" pause
exit /b 0