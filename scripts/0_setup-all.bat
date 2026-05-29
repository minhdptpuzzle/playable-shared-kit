@echo off
setlocal EnableDelayedExpansion
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

call :install "%ROOT%" "root"

if exist "%ROOT%\extensions\" (
    for /d %%D in ("%ROOT%\extensions\*") do (
        call :install "%%D" "extensions\%%~nxD"
    )
)

if exist "%ROOT%\tools\" (
    for /d %%D in ("%ROOT%\tools\*") do (
        call :install "%%D" "tools\%%~nxD"
    )
)

echo.
echo All packages installed successfully.
pause
exit /b 0

:install
if not exist "%~1\package.json" (
    echo [skip] No package.json in %~2
    exit /b 0
)
echo.
echo ==^> Installing: %~2
pushd "%~1"
call npm install
popd
if !errorlevel! neq 0 (
    echo [ERROR] npm install failed in %~2
    pause
    exit /b 1
)
echo [ok] %~2
exit /b 0
