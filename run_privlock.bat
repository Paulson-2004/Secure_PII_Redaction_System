@echo off
SETLOCAL EnableDelayedExpansion
TITLE PrivLock AI - Intelligent PII Detection ^& Redaction System

echo ==============================================================
echo PrivLock AI - Intelligent PII Detection ^& Redaction System
echo ==============================================================
echo.

REM 1. Check Prerequisites
echo [*] Checking prerequisites...

REM Check Python (Python 3.11+ supported, verified on 3.14.7)
set PYTHON_CMD=
python -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set PYTHON_CMD=python
) else (
    py -3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        set PYTHON_CMD=py -3
    ) else (
        for %%V in (3.14 3.13 3.12 3.11) do (
            if not defined PYTHON_CMD (
                py -%%V -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
                if !ERRORLEVEL! EQU 0 set PYTHON_CMD=py -%%V
            )
        )
    )
)

if not defined PYTHON_CMD (
    echo [ERROR] Python 3.11 or higher is required ^(verified on Python 3.14.7^).
    echo Please ensure Python 3.11+ is installed and added to PATH.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('!PYTHON_CMD! -c "import sys; print(sys.version.split()[0])"') do set DETECTED_PY_VER=%%i
echo [OK] Python !DETECTED_PY_VER! found (Python 3.11+ supported, verified on 3.14.7).

REM Check Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not installed or not in PATH.
    pause
    exit /b 1
)
echo [OK] Flutter found.

REM Check MySQL/Database Configuration (We assume it's running or SQLite will fallback)
echo [INFO] Assuming database is running (MySQL) or will use SQLite fallback.

echo.
REM 2. Setting up Python Virtual Environment
cd /d "%~dp0PII"

echo [*] Checking virtual environment...
if exist "venv\Scripts\activate.bat" goto VENV_EXISTS

echo [INFO] Creating new virtual environment with Python !DETECTED_PY_VER!...
%PYTHON_CMD% -m venv venv
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create virtual environment.
    pause
    exit /b 1
)

echo [*] Activating virtual environment...
call venv\Scripts\activate.bat

echo [*] Installing dependencies - this may take a moment...
pip install -r requirements.txt >nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Some dependencies may not have installed correctly. Continuing...
)
goto VENV_READY

:VENV_EXISTS
echo [INFO] Existing virtual environment detected. Skipping dependency installation.
call venv\Scripts\activate.bat

:VENV_READY


echo.
REM 3. Launch the Backend
echo [*] Checking backend status...
curl -s http://127.0.0.1:5000/api/health >nul 2>nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] Backend is already running and ready.
    goto BACKEND_READY
)

echo [*] Starting Flask backend...
start "PrivLock Flask Backend" /D "%~dp0PII" cmd /c "call venv\Scripts\activate.bat && python app.py"

echo [*] Waiting for Flask backend to become ready...
set MAX_RETRIES=30
set RETRY_COUNT=0

:HEALTH_CHECK
ping 127.0.0.1 -n 3 >nul
curl -s http://127.0.0.1:5000/api/health >nul 2>nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] Backend is ready.
    goto BACKEND_READY
)
set /a RETRY_COUNT+=1 >nul
if !RETRY_COUNT! GEQ !MAX_RETRIES! (
    echo [ERROR] Backend failed to start within 60 seconds.
    echo Please check the backend logs for errors.
    pause
    exit /b 1
)
goto HEALTH_CHECK

:BACKEND_READY
echo.
REM 4. Launch the Frontend
echo [*] Detecting web browser...
set WEB_DEVICE=
set BROWSER_NAME=

REM Prefer Chrome if available
flutter devices 2>nul | findstr /i /c:"chrome" >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set WEB_DEVICE=chrome
    set BROWSER_NAME=Chrome
    goto BROWSER_DETECTED
)

REM Fall back to Edge if Chrome is not available
flutter devices 2>nul | findstr /i /c:"edge" >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set WEB_DEVICE=edge
    set BROWSER_NAME=Edge
    goto BROWSER_DETECTED
)

:BROWSER_DETECTED
if not defined WEB_DEVICE (
    echo [ERROR] No supported web browser found for Flutter - Chrome or Edge required.
    echo Please ensure Google Chrome or Microsoft Edge is installed.
    pause
    exit /b 1
)

echo [OK] Browser device detected: !BROWSER_NAME!

REM Check if Flutter Frontend is already running
curl -s http://localhost:5080 >nul 2>nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] Flutter Frontend is already running on http://localhost:5080.
    goto FRONTEND_READY
)

echo [*] Starting Flutter Frontend in !BROWSER_NAME!...
start "PrivLock Flutter Frontend" /D "%~dp0PII" cmd /k "flutter run -d !WEB_DEVICE! --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080"

echo [*] Waiting for Flutter Frontend to start on http://localhost:5080...
set FLUTTER_MAX_RETRIES=40
set FLUTTER_RETRY_COUNT=0

:FLUTTER_HEALTH_CHECK
ping 127.0.0.1 -n 2 >nul
curl -s http://localhost:5080 >nul 2>nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] Flutter Frontend is ready.
    goto FRONTEND_READY
)
set /a FLUTTER_RETRY_COUNT+=1 >nul
if !FLUTTER_RETRY_COUNT! GEQ !FLUTTER_MAX_RETRIES! (
    echo [WARNING] Flutter Frontend is taking longer than expected to bind port 5080.
    echo Please check the "PrivLock Flutter Frontend" window for build progress or errors.
    goto FRONTEND_READY
)
goto FLUTTER_HEALTH_CHECK

:FRONTEND_READY
echo.
echo ==============================================================
echo PrivLock AI has been launched.
echo - Flask Backend is running in a separate window.
echo - Flutter Frontend is running on !BROWSER_NAME! (http://localhost:5080).
echo   (PrivLock AI supports any modern web browser: Edge, Chrome, Firefox, Safari)
echo.
echo To gracefully stop the application, run:
echo    scripts\stop_privlock.bat
echo ==============================================================
pause
