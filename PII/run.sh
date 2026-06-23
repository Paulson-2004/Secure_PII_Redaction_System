#!/bin/bash
# PriLock Flask Backend - Setup and Run Script

echo "================================"
echo "PriLock Flask Backend Setup"
echo "================================"
echo ""

# Check Python version
echo "Checking Python version..."
python_version=$(python --version 2>&1)
echo "Found: $python_version"
echo ""

# Create virtual environment
echo "Creating virtual environment..."
if [ ! -d "venv" ]; then
    python -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi
echo ""

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
echo "✓ Virtual environment activated"
echo ""

# Install dependencies
echo "Installing dependencies..."
pip install -q -r requirements.txt
echo "✓ Dependencies installed"
echo ""

# Create uploads directory
echo "Creating uploads directory..."
mkdir -p uploads
echo "✓ Uploads directory ready"
echo ""

# Database setup instructions
echo "================================"
echo "Database Setup Required"
echo "================================"
echo ""
echo "Before running the app, set up the MySQL database:"
echo ""
echo "1. Make sure MySQL is running:"
echo "   - macOS: brew services start mysql"
echo "   - Windows: Start MySQL service"
echo "   - Linux: sudo service mysql start"
echo ""
echo "2. Create the database:"
echo "   mysql -u root -p < schema.sql"
echo ""
echo "3. Or manually run these commands:"
echo "   mysql -u root -p"
echo "   > source schema.sql;"
echo "   > EXIT;"
echo ""
echo "4. Verify credentials in .env match your MySQL setup"
echo ""

# Ask to continue
read -p "Have you set up the database? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please set up the database first, then run this script again."
    exit 1
fi

# Run the application
echo ""
echo "================================"
echo "Starting Flask Application"
echo "================================"
echo ""
echo "Server running on: http://localhost:5000"
echo ""
echo "Available endpoints:"
echo "  POST /register     - Register new user"
echo "  POST /login        - Login user"
echo "  GET  /logout       - Logout user"
echo "  POST /api/process  - Process document"
echo "  GET  /audit-logs   - Get audit logs"
echo "  GET  /download/<filename> - Download file"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run Flask app
python app.py
