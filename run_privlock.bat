@echo off
SETLOCAL EnableDelayedExpansion
TITLE PrivLock AI - Intelligent PII Detection ^& Redaction System

echo ==============================================================
echo PrivLock AI - Intelligent PII Detection ^& Redaction System
echo ==============================================================
echo.

REM 1. Check Prerequisites
echo [*] Checking prerequisites...

REM Check Python 3.14
python --version 2>nul | find "3.14.7" >nul
if %ERRORLEVEL% NEQ 0 (
    py -3.14 --version 2>nul | find "3.14.7" >nul
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Python 3.14.7 is required but not found as default 'python' or 'py -3.14'.
        echo Please ensure Python 3.14.7 is installed and added to PATH.
        pause
        exit /b 1
    ) else (
        set PYTHON_CMD=py -3.14
    )
) else (
    set PYTHON_CMD=python
)
echo [OK] Python 3.14.7 found.

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

echo [INFO] Creating new virtual environment with Python 3.14.7...
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
echo [*] Starting Flask backend...
start "PrivLock Flask Backend" cmd /c "call venv\Scripts\activate.bat && python app.py"

echo [*] Waiting for Flask backend to become ready...
set MAX_RETRIES=30
set RETRY_COUNT=0

:HEALTH_CHECK
ping 127.0.0.1 -n 3 >nul
curl -s http://127.0.0.1:5000/api/health >nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Backend is ready!
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
echo [*] Starting Flutter Frontend in Chrome...
start "PrivLock Flutter Frontend" cmd /c "flutter run -d chrome"

echo.
echo ==============================================================
echo PrivLock AI has been launched!
echo - Flask Backend is running in a separate window.
echo - Flutter Frontend is running in Chrome.
echo.
echo To gracefully stop the application, run:
echo    scripts\stop_privlock.bat
echo ==============================================================
pause
