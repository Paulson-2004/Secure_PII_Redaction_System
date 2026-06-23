@echo off
REM PriLock Flask Backend - Setup and Run Script (Windows)

echo ================================
echo PriLock Flask Backend Setup
echo ================================
echo.

REM Check Python version
echo Checking Python version...
python --version
echo.

REM Create virtual environment
echo Creating virtual environment...
if not exist "venv" (
    python -m venv venv
    echo ^✓ Virtual environment created
) else (
    echo ^✓ Virtual environment already exists
)
echo.

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
echo ^✓ Virtual environment activated
echo.

REM Install dependencies
echo Installing dependencies...
pip install -q -r requirements.txt
echo ^✓ Dependencies installed
echo.

REM Create uploads directory
echo Creating uploads directory...
if not exist "uploads" (
    mkdir uploads
)
echo ^✓ Uploads directory ready
echo.

REM Database setup instructions
echo ================================
echo Database Setup Required
echo ================================
echo.
echo Before running the app, set up the MySQL database:
echo.
echo 1. Make sure MySQL is running (MySQL Command Line Client or MySQL Workbench)
echo.
echo 2. Open MySQL Command Line Client and run:
echo    mysql -u root -p^< schema.sql
echo.
echo 3. Or manually:
echo    mysql -u root -p
echo    ^> source schema.sql;
echo    ^> EXIT;
echo.
echo 4. Verify .env file has correct MySQL credentials
echo.

set /p continue="Have you set up the database? (y/n): "
if /i not "%continue%"=="y" (
    echo Please set up the database first, then run this script again.
    pause
    exit /b 1
)

REM Run the application
echo.
echo ================================
echo Starting Flask Application
echo ================================
echo.
echo Server running on: http://localhost:5000
echo.
echo Available endpoints:
echo   POST /register     - Register new user
echo   POST /login        - Login user
echo   GET  /logout       - Logout user
echo   POST /api/process  - Process document
echo   GET  /audit-logs   - Get audit logs
echo   GET  /download^<filename^> - Download file
echo.
echo Press Ctrl+C to stop the server
echo.

REM Run Flask app
python app.py
pause
