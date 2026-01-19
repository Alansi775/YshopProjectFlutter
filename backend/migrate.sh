#!/bin/bash

echo "🔧 Firebase to MySQL Migration Tool"
echo "===================================="
echo ""
echo "To migrate data from Firebase to MySQL, you need to:"
echo ""
echo "1. Get Firebase Admin SDK credentials:"
echo "   - Go to: https://console.firebase.google.com"
echo "   - Select your project"
echo "   - Click Settings ⚙️ > Project Settings"
echo "   - Go to 'Service Accounts' tab"
echo "   - Click 'Generate New Private Key'"
echo "   - Save the JSON file as 'firebase-adminsdk.json' in the backend directory"
echo ""
echo "2. Run the migration:"
echo "   node database/migrations/migrate_from_firebase.js"
echo ""
echo "===================================="
echo ""

# Check if firebase-adminsdk.json exists
if [ ! -f "./firebase-adminsdk.json" ]; then
    echo "❌ firebase-adminsdk.json not found"
    echo "Please follow the instructions above"
    exit 1
else
    echo " firebase-adminsdk.json found, running migration..."
    node database/migrations/migrate_from_firebase.js
fi
