@echo off
TITLE PrivLock AI - Shutdown
echo ==============================================================
echo Stopping PrivLock AI...
echo ==============================================================
echo.

REM Stop Flask backend
echo [*] Stopping Flask Backend...
taskkill /FI "WINDOWTITLE eq PrivLock Flask Backend*" /T /F >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Backend stopped.
) else (
    echo [INFO] Backend was not running or could not be stopped automatically.
)

REM Stop Flutter frontend process
echo [*] Stopping Flutter Frontend...
taskkill /FI "WINDOWTITLE eq PrivLock Flutter Frontend*" /T /F >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Frontend stopped.
) else (
    echo [INFO] Frontend was not running or could not be stopped automatically.
)

echo.
echo ==============================================================
echo PrivLock AI stopped.
echo ==============================================================
pause
