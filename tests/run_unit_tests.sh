#!/bin/bash
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Unit tests runner
echo "🧪 Running unit tests..."

# Check if busted is available
if command -v busted &> /dev/null; then
    echo "✅ Busted found, running unit tests..."
    
    # Save current directory
    ORIGINAL_DIR=$(pwd)
    
    # Set up the working directory
    cd /opt/kong-plugin-jwt-keycloak
    
    # Ensure Lua paths are set correctly to find our plugin modules
    export LUA_PATH="/opt/kong-plugin-jwt-keycloak/?.lua;/opt/kong-plugin-jwt-keycloak/src/?.lua;;"
    export LUA_CPATH="/usr/local/lib/lua/5.1/?.so;;"
    
    # Create symbolic links to help Lua find the modules
    mkdir -p kong/plugins/jwt-keycloak
    ln -sf /opt/kong-plugin-jwt-keycloak/src/*.lua kong/plugins/jwt-keycloak/
    ln -sf /opt/kong-plugin-jwt-keycloak/src/validators kong/plugins/jwt-keycloak/validators
    
    # Run the unit tests
    echo "Running unit tests with Busted..."
    busted spec/01-unit/ --verbose --output=TAP
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
    
    UNIT_TEST_EXIT_CODE=$?
    if [ $UNIT_TEST_EXIT_CODE -eq 0 ]; then
        echo "✅ All unit tests passed!"
    else
        echo "❌ Some unit tests failed (exit code: $UNIT_TEST_EXIT_CODE)"
    fi
else
    echo "⚠️  Busted not found, skipping unit tests"
    echo "To run unit tests, install busted: luarocks install busted"
    echo "Unit test files are located in spec/01-unit/"
fi