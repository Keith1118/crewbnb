#!/bin/bash
# Crewbase - One-click startup script

eval "$(rbenv init - zsh 2>/dev/null || rbenv init - bash 2>/dev/null)"
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

echo "🏠 Starting Crewbase..."
echo ""

# Start PostgreSQL if not running
brew services start postgresql@16 2>/dev/null

# Build assets
echo "Building assets..."
npm run build --silent 2>/dev/null
npm run build:css --silent 2>/dev/null

echo ""
echo "✅ Server starting at: http://localhost:3000"
echo ""
echo "Login accounts (password for all: password123):"
echo "  Admin:  admin@crewbase.ie"
echo "  Host:   host1@crewbase.ie"
echo "  Guest:  guest1@crewbase.ie"
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

bin/rails server -p 3000
