#!/bin/bash
# Crewbnb - One-click startup script

eval "$(rbenv init - zsh 2>/dev/null || rbenv init - bash 2>/dev/null)"
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

echo "🏠 Starting Crewbnb..."
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
echo "  Admin:  admin@crewbnb.ie"
echo "  Host:   host1@crewbnb.ie"
echo "  Guest:  guest1@crewbnb.ie"
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

bin/rails server -p 3000
