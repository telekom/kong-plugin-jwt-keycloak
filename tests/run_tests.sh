#!/bin/sh
# SPDX-FileCopyrightText: 2025 Deutsche Telekom AG
#
# SPDX-License-Identifier: Apache-2.0

# Ensure we're in the correct directory
cd /opt/tests || { echo "Error: Cannot change to /opt/tests directory"; exit 1; }

echo "Working directory: $(pwd)"
echo "Files available:"
ls -la

# include _env.sh
if [ -f ./_env.sh ]; then
    . ./_env.sh
    prepare_environment
else
    echo "Error: _env.sh not found"
    exit 1
fi

# Run unit tests first (if available)
echo "🧪 Phase 0: Running unit tests..."
if [ -f ./run_unit_tests.sh ]; then
    . ./run_unit_tests.sh
else
    echo "Error: run_unit_tests.sh not found"
    exit 1
fi

# Wait for all services to be ready
wait_for_kong
wait_for_keycloak

# Configure Keycloak for JWT authentication
echo "🔧 Configuring Keycloak for JWT authentication..."
echo "Debug: checking for ./configure_keycloak.sh"
ls -la configure_keycloak.sh
echo "Debug: pwd = $(pwd)"
if [ -f ./configure_keycloak.sh ]; then
    echo "Debug: configure_keycloak.sh found, sourcing..."
    . ./configure_keycloak.sh
else
    echo "Error: configure_keycloak.sh not found"
    echo "Debug: let's see what files are available now:"
    ls -la
    exit 1
fi

# Configure JWT-Keycloak plugin
echo "🔧 Configuring JWT-Keycloak plugin..."
if [ -f ./configure_jwt_plugin.sh ]; then
    . ./configure_jwt_plugin.sh
else
    echo "Error: configure_jwt_plugin.sh not found"
    exit 1
fi

# Test 1: Test JWT-Keycloak plugin
echo "🧪 Phase 1: Testing JWT-Keycloak plugin..."
if [ -f ./test_jwt_keycloak_plugin.sh ]; then
    . ./test_jwt_keycloak_plugin.sh
else
    echo "Error: test_jwt_keycloak_plugin.sh not found"
    exit 1
fi

# Test 2: Test EC algorithms
echo "🧪 Phase 2: Testing EC algorithms..."
if [ -f ./test_ec_algorithms.sh ]; then
    . ./test_ec_algorithms.sh
else
    echo "Error: test_ec_algorithms.sh not found"
    exit 1
fi

# Test 3: Test error conditions
echo "🧪 Phase 3: Testing error conditions..."
if [ -f ./test_error_conditions.sh ]; then
    . ./test_error_conditions.sh
else
    echo "Error: test_error_conditions.sh not found"
    exit 1
fi

# Test 5: Test roles and scopes
echo "🧪 Phase 5: Testing roles and scopes..."
if [ -f ./test_roles_scopes.sh ]; then
    . ./test_roles_scopes.sh
else
    echo "Error: test_roles_scopes.sh not found"
    exit 1
fi

# Test 6: Test security logging functionality
echo "🧪 Phase 6: Testing security logging..."
if [ -f ./test_security_logging.sh ]; then
    . ./test_security_logging.sh
else
    echo "Error: test_security_logging.sh not found"
    exit 1
fi
